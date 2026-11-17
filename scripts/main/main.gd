extends Node2D
## CENTRAL 112 – Prototipo Fase 1
## Escena principal: crea el mapa, las unidades, la interfaz y coordina
## las llamadas, los avisos automáticos y las intervenciones.
##
## Tres fuentes de información, separadas:
##   1. Llamadas ciudadanas (_sonar_llamada, _contestar_llamada...)
##   2. Avisos automáticos del sistema (_crear_aviso_trafico...)
##   3. Mensajes de radio de las unidades (hud.notificar con color de servicio)

const RedViaria = preload("res://scripts/routing/red_viaria.gd")
const MapaCiudad = preload("res://scripts/map/mapa_ciudad.gd")
const Vehiculo = preload("res://scripts/vehicles/vehiculo.gd")
const Incidente = preload("res://scripts/incidents/incidente.gd")
const Hud = preload("res://scripts/interface/hud.gd")
const Llamada = preload("res://scripts/calls/llamada.gd")
const RUTA_MAPA := "res://data/map/miguelturra.json"
const LlamadaAccidente = preload("res://data/dialogues/llamada_accidente.gd")

## Cada segundo real equivale a 20 segundos dentro del juego (a velocidad x1).
const SEGUNDOS_SIM_POR_SEGUNDO := 20.0
## Segundos que pierde una unidad buscando el lugar según la precisión.
const TIEMPO_BUSQUEDA := [16.0, 14.0, 7.0, 0.0]
const COLOR_RADIO_AMBULANCIA := Color("f4d35e")
const COLOR_RADIO_POLICIA := Color("6fb1ff")
const COLOR_RADIO_BOMBEROS := Color("ff8a65")
const NOMBRES_SERVICIO := {"ambulancia": "Ambulancia", "policia": "Policía", "bomberos": "Bomberos"}
const COLOR_SISTEMA := Color("ffa630")
const COLOR_LLAMADA := Color("ff6b6b")

var red := RedViaria.new()
var datos_mapa: Dictionary = {}
var tamano_mapa := Vector2(3000, 3000)
var nodo_salida := 0
var paso_calibracion := 0
var boton_x := -1
var mundo: Node2D
var mapa
var camara: Camera2D
var hud
var vehiculos: Array = []
var incidentes: Array = []
var seleccion = null
var segundos_sim := 8.0 * 3600.0
var tiempo_juego := 0.0
var velocidades := [1.0, 2.0, 4.0]
var indice_velocidad := 0
var llamada = null
var llamada_sonando := false
var hora_llamada := ""
var contador_llamadas := 0
var contador_incidentes := 0
var sospechoso = null
var sospechoso_acelero := false
var estadisticas := {"llamadas": 0, "resueltas": 0, "atendidas": 0}
var debug_activo := false
var ultimo_evento := "(pulsa cualquier botón)"
var capa_rutas: Node2D
var modulador: CanvasModulate
var sonidos := {}
var _t_barra := 0.0


# ================================================================ INICIO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	datos_mapa = _cargar_mapa()
	red.cargar(datos_mapa)
	tamano_mapa = Vector2(float(datos_mapa["tamano"][0]), float(datos_mapa["tamano"][1]))
	nodo_salida = red.nodo_mas_al_oeste()

	# Todo lo que se detiene en pausa va dentro de "mundo"
	mundo = Node2D.new()
	mundo.name = "Mundo"
	mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(mundo)

	mapa = MapaCiudad.new()
	mapa.datos = datos_mapa
	mundo.add_child(mapa)

	# Rutas de las unidades (debajo de los vehículos)
	capa_rutas = Node2D.new()
	capa_rutas.draw.connect(_dibujar_rutas)
	mundo.add_child(capa_rutas)

	# Día y noche: oscurece el mapa según la hora
	modulador = CanvasModulate.new()
	mundo.add_child(modulador)

	camara = Camera2D.new()
	camara.position = _pos_lugar("Plaza de España", tamano_mapa / 2.0)
	camara.zoom = Vector2(0.8, 0.8)
	mundo.add_child(camara)
	camara.make_current()

	# Bases (ficticias) junto a edificios reales
	var nodo_amb := _nodo_lugar("Centro de Salud de Miguelturra")
	var nodo_pol := _nodo_lugar("Ayuntamiento de Miguelturra")
	_crear_unidad("A-01", "ambulancia", nodo_amb, COLOR_RADIO_AMBULANCIA, "A", 160.0)
	_crear_unidad("P-01", "policia", nodo_pol, Color("4d96ff"), "P", 210.0)
	mapa.anadir_base("Base ambulancias", red.pos(nodo_amb) + Vector2(0, -40), COLOR_RADIO_AMBULANCIA, "A")
	mapa.anadir_base("Base Policía Local", red.pos(nodo_pol) + Vector2(-40, 30), Color("4d96ff"), "P")
	var nodo_bom := _nodo_lugar("Estación de Servicio Moeve La Estrella")
	_crear_unidad("B-01", "bomberos", nodo_bom, Color("e74c3c"), "B", 145.0)
	mapa.anadir_base("Parque de bomberos", red.pos(nodo_bom) + Vector2(40, -40), Color("e74c3c"), "B")
	_crear_sonidos()

	hud = Hud.new()
	add_child(hud)
	hud.llamada_contestada.connect(_contestar_llamada)
	hud.opcion_llamada.connect(_elegir_opcion)

	hud.notificar("Turno iniciado. Central 112 operativa. Unidades A-01, P-01 y B-01 disponibles.")
	if not Controles.cargar_configuracion() and Input.get_connected_joypads().size() > 0:
		_empezar_calibracion()
	_programar(8.0, _sonar_llamada)
	_programar(60.0, _crear_aviso_trafico)
	_programar(150.0, _crear_incendio)


func _cargar_mapa() -> Dictionary:
	var texto := FileAccess.get_file_as_string(RUTA_MAPA)
	var d = JSON.parse_string(texto)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("No se ha podido leer el mapa: " + RUTA_MAPA)
		return {}
	return d


func _lugar(nombre: String) -> Dictionary:
	for l in datos_mapa["lugares"]:
		if l["nombre"] == nombre:
			return l
	push_warning("Lugar no encontrado en el mapa: " + nombre)
	return {}


func _nodo_lugar(nombre: String) -> int:
	var l := _lugar(nombre)
	if l.is_empty():
		return red.nodo_mas_cercano(tamano_mapa / 2.0)
	return int(l["nodo"])


func _pos_lugar(nombre: String, por_defecto: Vector2) -> Vector2:
	var l := _lugar(nombre)
	if l.is_empty():
		return por_defecto
	return Vector2(float(l["x"]), float(l["y"]))


func _crear_unidad(id: String, servicio: String, nodo: int, color: Color, letra: String, velocidad: float) -> void:
	var v = Vehiculo.new()
	v.configurar(id, servicio, color, letra, velocidad, red)
	v.nodo_base = nodo
	v.colocar_en(v.nodo_base)
	v.ha_llegado.connect(_on_unidad_llega)
	v.interceptado.connect(_on_interceptado)
	mundo.add_child(v)
	vehiculos.append(v)


## Ejecuta una acción dentro de X segundos de juego (se detiene en pausa).
func _programar(segundos: float, accion: Callable) -> void:
	get_tree().create_timer(segundos, false).timeout.connect(accion)


# ================================================================ BUCLE

func _process(delta: float) -> void:
	_actualizar_debug()
	if get_tree().paused:
		return
	tiempo_juego += delta
	segundos_sim += delta * SEGUNDOS_SIM_POR_SEGUNDO
	hud.set_reloj(_hora(segundos_sim))
	if not hud.ventana_abierta() and not hud.calibrando():
		_mover_camara(delta)
	_vigilar_persecucion()
	_vigilar_urgencias()
	_ajustar_iconos()
	modulador.color = _color_hora(fmod(segundos_sim / 3600.0, 24.0))
	capa_rutas.queue_redraw()
	_t_barra -= delta
	if _t_barra <= 0.0:
		_t_barra = 0.5
		var lista := []
		for v in vehiculos:
			lista.append([v.id_unidad, v.estado, v.color])
		hud.actualizar_unidades(lista)


## Color del ambiente según la hora (amanecer, día, atardecer, noche).
func _color_hora(h: float) -> Color:
	var noche := Color(0.42, 0.48, 0.78)
	var atardecer := Color(1.0, 0.78, 0.62)
	if h < 6.0 or h >= 21.0:
		return noche
	if h < 8.0:
		return noche.lerp(Color.WHITE, (h - 6.0) / 2.0)
	if h < 19.0:
		return Color.WHITE
	if h < 20.0:
		return Color.WHITE.lerp(atardecer, h - 19.0)
	return atardecer.lerp(noche, h - 20.0)


func _dibujar_rutas() -> void:
	var ancho := 7.0 / camara.zoom.x
	for v in vehiculos:
		if v.ruta.is_empty() or v.estado == "Disponible" or v.estado == "Regresando":
			continue
		var pts := PackedVector2Array([v.position])
		for n in v.ruta:
			pts.append(red.pos(n))
		if pts.size() < 2:
			continue
		capa_rutas.draw_polyline(pts, Color(v.color, 0.7), ancho)
		capa_rutas.draw_circle(pts[pts.size() - 1], ancho * 1.6, Color(v.color, 0.9))


func _vigilar_urgencias() -> void:
	for inc in incidentes:
		if not inc.esperando_ayuda() or inc.urgencia_restante > 0.0 or inc.empeorado:
			continue
		if inc.tipo == "incendio" and inc.intensidad < 3:
			inc.intensidad += 1
			inc.urgencia_restante = inc.urgencia_total
			hud.notificar("%s: ¡el incendio se está extendiendo! (nivel %d de 3)" % [inc.id_incidente, inc.intensidad], COLOR_RADIO_BOMBEROS)
			_sonido("alerta")
		else:
			inc.empeorado = true
			if inc.tipo == "incendio":
				hud.notificar("%s: el incendio es ya muy grave." % inc.id_incidente, COLOR_RADIO_BOMBEROS)
			else:
				hud.notificar("%s: la ayuda tarda demasiado, el estado del herido empeora." % inc.id_incidente, COLOR_LLAMADA)
			_sonido("alerta")


# ================================================================ SONIDO

func _crear_sonidos() -> void:
	for nombre in ["llamada", "radio", "alerta", "envio", "click"]:
		var reproductor := AudioStreamPlayer.new()
		var ruta := "res://assets/audio/%s.wav" % nombre
		if ResourceLoader.exists(ruta):
			reproductor.stream = load(ruta)
		reproductor.volume_db = -4.0
		add_child(reproductor)
		sonidos[nombre] = reproductor
	sonidos["llamada"].finished.connect(_repetir_tono)


func _repetir_tono() -> void:
	if llamada_sonando:
		sonidos["llamada"].play()


func _sonido(nombre: String) -> void:
	if sonidos.has(nombre) and sonidos[nombre].stream != null:
		sonidos[nombre].play()


## Los iconos se mantienen legibles aunque se aleje el mapa.
func _ajustar_iconos() -> void:
	var s := clampf(0.85 / camara.zoom.x, 0.8, 2.6)
	for v in vehiculos:
		v.scale = Vector2(s, s)
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.scale = Vector2(s, s)
	for inc in incidentes:
		inc.escala_icono = s
	mapa.mostrar_nombres(camara.zoom.x >= 0.7)


func _mover_camara(delta: float) -> void:
	# La cámara va a la misma velocidad aunque el tiempo esté acelerado
	var d := delta / maxf(Engine.time_scale, 0.01)
	var v := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	camara.position += v * 650.0 * d / camara.zoom.x
	var z := Input.get_action_strength("zoom_mas") - Input.get_action_strength("zoom_menos")
	if absf(z) > 0.05:
		var nz := clampf(camara.zoom.x * (1.0 + z * 1.6 * d), 0.3, 2.2)
		camara.zoom = Vector2(nz, nz)
	camara.position = camara.position.clamp(Vector2.ZERO, tamano_mapa)


func _hora(s: float) -> String:
	return "%02d:%02d" % [int(s / 3600.0) % 24, int(s / 60.0) % 60]


func _minutos(segundos_juego: float) -> float:
	return segundos_juego * SEGUNDOS_SIM_POR_SEGUNDO / 60.0


func _texto_minutos(segundos_juego: float) -> String:
	return "%d min" % maxi(1, ceili(_minutos(segundos_juego)))


# ================================================================ MANDO

func _unhandled_input(event: InputEvent) -> void:
	if hud.calibrando():
		return
	if event.is_action_pressed("depuracion"):
		debug_activo = not debug_activo
		return
	if event.is_action_pressed("pausa"):
		_alternar_pausa()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		if event.is_action_pressed("cancelar"):
			_alternar_pausa()
			get_viewport().set_input_as_handled()
		return
	if hud.panel_abierto():
		if event.is_action_pressed("cancelar"):
			_cerrar_panel()
			get_viewport().set_input_as_handled()
		return
	if hud.llamada_abierta():
		return
	if event.is_action_pressed("seleccionar"):
		_seleccionar_en_mira()
	elif event.is_action_pressed("abrir_unidades"):
		_mostrar_lista_unidades()
	elif event.is_action_pressed("abrir_emergencias"):
		_mostrar_lista_emergencias()


func _notification(what: int) -> void:
	# En Android/Fire TV el botón "atrás" no cierra el juego: actúa como Círculo.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var ev := InputEventAction.new()
		ev.action = "cancelar"
		ev.pressed = true
		Input.parse_input_event(ev)


func _input(event: InputEvent) -> void:
	if hud.calibrando():
		_calibrar(event)
		get_viewport().set_input_as_handled()
		return
	# Solo para la "prueba de mando": muestra qué botón llega al juego.
	if not debug_activo:
		return
	var boton := event as InputEventJoypadButton
	var eje := event as InputEventJoypadMotion
	var tecla := event as InputEventKey
	if boton != null and boton.pressed:
		ultimo_evento = "Mando %d · botón %d" % [boton.device, boton.button_index]
	elif eje != null and absf(eje.axis_value) > 0.6:
		ultimo_evento = "Mando %d · eje %d = %.2f" % [eje.device, eje.axis, eje.axis_value]
	elif tecla != null and tecla.pressed and not tecla.echo:
		ultimo_evento = "Tecla: %s (código %d)" % [OS.get_keycode_string(tecla.keycode), tecla.keycode]


func _actualizar_debug() -> void:
	if not debug_activo:
		hud.set_debug(false, "")
		return
	var mandos := ""
	for id in Input.get_connected_joypads():
		mandos += "\n  #%d %s" % [id, Input.get_joy_name(id)]
	if mandos == "":
		mandos = "\n  (ningún mando detectado)"
	hud.set_debug(true, "PRUEBA DE MANDO (Share o F1 para ocultar)\nFPS: %d\nMandos:%s\nÚltimo: %s" % [Engine.get_frames_per_second(), mandos, ultimo_evento])


# ================================================================ SELECCIÓN Y PANELES

func _marcar_seleccion(obj) -> void:
	if seleccion != null and is_instance_valid(seleccion):
		seleccion.seleccionado = false
	seleccion = obj
	if obj != null:
		obj.seleccionado = true


func _cerrar_panel() -> void:
	_marcar_seleccion(null)
	hud.cerrar_panel()


func _seleccionar_en_mira() -> void:
	var centro := camara.position
	var mejor = null
	var mejor_d := 80.0 / camara.zoom.x
	for inc in incidentes:
		if inc.activo():
			var d: float = inc.position.distance_to(centro)
			if d < mejor_d:
				mejor = inc
				mejor_d = d
	for v in vehiculos:
		var d: float = v.position.distance_to(centro)
		if d < mejor_d:
			mejor = v
			mejor_d = d
	if mejor == null:
		hud.notificar("No hay nada dentro de la mira. Acércala a una unidad o a una emergencia.")
	elif mejor is Incidente:
		_mostrar_incidente(mejor)
	else:
		_mostrar_unidad(mejor)


func _mostrar_lista_unidades() -> void:
	var opciones := []
	for v in vehiculos:
		opciones.append({"texto": "%s · %s · %s" % [v.id_unidad, v.nombre_servicio(), v.estado], "accion": _mostrar_unidad.bind(v)})
	hud.mostrar_panel("UNIDADES", "Elige una unidad para localizarla en el mapa.", opciones)


func _mostrar_unidad(v) -> void:
	camara.position = v.position
	_marcar_seleccion(v)
	var texto := "Servicio: %s\nEstado: %s" % [v.nombre_servicio(), v.estado]
	if v.incidente != null:
		texto += "\nAsignada a: %s" % v.incidente.id_incidente
	if v.en_movimiento:
		texto += "\nLlegada estimada: %s" % _texto_minutos(v.tiempo_restante())
	hud.mostrar_panel(v.id_unidad, texto, [{"texto": "Volver al mapa", "accion": _cerrar_panel}])


func _mostrar_lista_emergencias() -> void:
	var opciones := []
	if llamada_sonando:
		opciones.append({"texto": "Contestar la llamada entrante", "accion": _contestar_llamada})
	for inc in incidentes:
		if inc.activo():
			opciones.append({"texto": "%s · %s · %s" % [inc.id_incidente, inc.titulo, inc.estado], "accion": _mostrar_incidente.bind(inc)})
	var texto := "Elige una emergencia para ver los detalles."
	if opciones.is_empty():
		texto = "No hay emergencias activas en este momento."
		opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("EMERGENCIAS ACTIVAS", texto, opciones)


func _mostrar_incidente(inc) -> void:
	camara.position = inc.position
	_marcar_seleccion(inc)
	if inc.tipo == "aviso_trafico":
		_mostrar_aviso(inc)
		return
	var texto := "Origen: %s\nEstado: %s\nLocalización: %s\nServicio necesario: %s" % [inc.fuente, inc.estado, inc.texto_precision(), NOMBRES_SERVICIO.get(inc.servicio_necesario, "-")]
	if inc.esperando_ayuda():
		texto += "\nEmpeora en: %s" % _texto_minutos(inc.urgencia_restante)
	if inc.tipo == "incendio":
		texto += "\nIntensidad del fuego: %d de 3" % inc.intensidad
	for i in inc.informacion:
		texto += "\n· %s" % i
	var opciones := []
	if inc.activo():
		for v in vehiculos:
			var libre: bool = v.estado == "Disponible"
			var destino: int = inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado
			var etiqueta := "Enviar %s (%s) · llega en %s" % [v.id_unidad, v.nombre_servicio(), _texto_minutos(v.tiempo_estimado(destino))]
			if not libre:
				etiqueta = "%s no disponible (%s)" % [v.id_unidad, v.estado]
			opciones.append({"texto": etiqueta, "accion": _enviar_unidad.bind(v, inc), "activo": libre})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, inc.titulo], texto, opciones)


# ================================================================ LLAMADAS

func _sonar_llamada() -> void:
	llamada_sonando = true
	hora_llamada = _hora(segundos_sim)
	hud.mostrar_aviso_llamada("Localidad: Miguelturra · %s" % hora_llamada)
	_sonido("llamada")
	hud.notificar("Llamada entrante al 112", COLOR_LLAMADA)


func _contestar_llamada() -> void:
	if not llamada_sonando:
		return
	llamada_sonando = false
	sonidos["llamada"].stop()
	hud.ocultar_aviso_llamada()
	if hud.panel_abierto():
		_cerrar_panel()
	contador_llamadas += 1
	estadisticas["llamadas"] += 1
	llamada = Llamada.new()
	llamada.iniciar(LlamadaAccidente.DATOS)
	hud.abrir_llamada()
	_refrescar_llamada()


func _refrescar_llamada() -> void:
	var d: Dictionary = LlamadaAccidente.DATOS
	var cabecera := "Llamada 112-%04d  ·  %s  ·  %s  ·  %s" % [contador_llamadas, hora_llamada, d["llamante"], d["localidad"]]
	var textos := []
	for o in llamada.opciones_actuales:
		textos.append(o["texto"])
	hud.actualizar_llamada(cabecera, llamada.texto_actual, llamada.calma, llamada.estado_emocional(),
		Incidente.NOMBRES_PRECISION[llamada.precision], llamada.informacion, textos)


func _elegir_opcion(indice: int) -> void:
	if llamada == null:
		return
	llamada.elegir(indice)
	if llamada.terminada:
		_terminar_llamada()
	else:
		_refrescar_llamada()


func _terminar_llamada() -> void:
	hud.cerrar_llamada()
	var d: Dictionary = LlamadaAccidente.DATOS["incidente"]
	var nodo_lugar := _nodo_lugar(d["lugar"])
	var pos_lugar := _pos_lugar(d["lugar"], red.pos(nodo_lugar))
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.tipo = "llamada"
	inc.servicio_necesario = "ambulancia"
	inc.urgencia_total = 35.0
	inc.urgencia_restante = 35.0
	inc.fuente = "Llamada al 112 (112-%04d)" % contador_llamadas
	inc.titulo = d["titulo"]
	inc.informacion = llamada.informacion.duplicate()
	inc.marcas = llamada.marcas.duplicate()
	inc.precision = llamada.precision
	inc.calma_final = llamada.calma
	inc.nodo_real = nodo_lugar
	inc.pos_exacta = red.pos(nodo_lugar)
	inc.pos_calle = pos_lugar
	inc.radio_calle = d["radio_referencia"]
	inc.pos_zona = inc.pos_exacta + d["desplazamiento_zona"]
	inc.radio_zona = d["radio_zona"]
	inc.nodo_aproximado = red.nodo_mas_cercano(inc.posicion_aproximada())
	inc.tiempo_creacion = tiempo_juego
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	llamada = null
	hud.notificar("Incidente %s creado: %s (%s)" % [inc.id_incidente, inc.titulo, inc.texto_precision()], COLOR_LLAMADA)
	_mostrar_incidente(inc)


# ================================================================ UNIDADES E INTERVENCIONES

func _radio(v, mensaje: String) -> void:
	var color := COLOR_RADIO_POLICIA
	if v.servicio == "ambulancia":
		color = COLOR_RADIO_AMBULANCIA
	elif v.servicio == "bomberos":
		color = COLOR_RADIO_BOMBEROS
	hud.notificar("%s: «%s»" % [v.id_unidad, mensaje], color)
	_sonido("radio")


func _enviar_unidad(v, inc) -> void:
	if v.estado != "Disponible" or not inc.activo():
		hud.notificar("No es posible enviar %s ahora mismo." % v.id_unidad)
		return
	v.estado = "En desplazamiento"
	v.fase = "ida"
	v.incidente = inc
	inc.unidades.append(v)
	_sonido("envio")
	if v.servicio == inc.servicio_necesario:
		if inc.precision_al_enviar < 0:
			inc.precision_al_enviar = inc.precision
		if inc.estado == "Pendiente":
			inc.estado = "Unidad en camino"
	var destino: int = inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado
	v.ir_a(destino)
	_radio(v, "Recibido, central. Salimos hacia %s." % inc.id_incidente)
	_cerrar_panel()


func _on_unidad_llega(v) -> void:
	match v.fase:
		"ida":
			var inc = v.incidente
			if inc.precision < 3:
				v.fase = "buscando"
				v.estado = "Buscando el lugar"
				_radio(v, "Estamos en la zona, pero no localizamos el incidente. Buscando...")
				_programar(TIEMPO_BUSQUEDA[inc.precision], _fin_busqueda.bind(v))
			else:
				_comenzar_intervencion(v)
		"buscando2":
			_comenzar_intervencion(v)
		"regreso":
			v.estado = "Disponible"
			v.fase = ""
			v.incidente = null
			_radio(v, "En base y disponibles.")
		"salida":
			pass


func _fin_busqueda(v) -> void:
	var inc = v.incidente
	if inc == null:
		return
	inc.precision = 3
	inc.actualizar_posicion()
	v.fase = "buscando2"
	v.estado = "En desplazamiento"
	_radio(v, "Localizado. Nos dirigimos al lugar exacto.")
	v.ir_a(inc.nodo_real)


func _comenzar_intervencion(v) -> void:
	var inc = v.incidente
	v.estado = "En intervención"
	v.fase = "intervencion"
	if v.servicio == inc.servicio_necesario:
		if inc.tiempo_llegada < 0.0:
			inc.tiempo_llegada = tiempo_juego
		inc.estado = "En intervención"
		if inc.tipo == "incendio":
			_radio(v, "En el lugar. Comenzamos la extinción.")
			_programar(10.0 + inc.intensidad * 5.0, _fin_intervencion.bind(v))
		else:
			_radio(v, "En el lugar. Atendiendo al herido.")
			_programar(10.0, _fin_intervencion.bind(v))
	else:
		match v.servicio:
			"policia":
				_radio(v, "En el lugar. Zona asegurada y tráfico cortado.")
			"ambulancia":
				_radio(v, "En el lugar. Quedamos en prevención por si hay heridos.")
			_:
				_radio(v, "En el lugar. Asegurando la zona y limpiando la calzada.")
		_programar(8.0, _regresar.bind(v))


func _fin_intervencion(v) -> void:
	var inc = v.incidente
	if inc.activo():
		inc.estado = "Resuelta"
		estadisticas["resueltas"] += 1
		if inc.tipo == "incendio":
			_radio(v, "Incendio extinguido. No hay víctimas.")
			_mostrar_informe_incendio(inc)
		else:
			estadisticas["atendidas"] += 1
			_radio(v, "Herido estabilizado. Lo trasladamos al hospital.")
			_mostrar_informe_llamada(inc)
	_regresar(v)


func _regresar(v) -> void:
	v.fase = "regreso"
	v.estado = "Regresando"
	v.ir_a(v.nodo_base)


func _mostrar_informe_llamada(inc) -> void:
	var minutos := _minutos(inc.tiempo_llegada - inc.tiempo_creacion)
	var estrellas := 1
	var consecuencias := []
	if inc.precision_al_enviar >= 3:
		estrellas += 1
	else:
		consecuencias.append("La localización imprecisa obligó a la ambulancia a buscar el lugar.")
	if inc.calma_final >= 60:
		estrellas += 1
	elif inc.calma_final < 40:
		consecuencias.append("La llamante terminó muy nerviosa.")
	if minutos <= 5.0:
		estrellas += 1
	if inc.informacion.size() >= 2:
		estrellas += 1
	else:
		consecuencias.append("Se obtuvo poca información sobre el herido.")
	if inc.empeorado:
		estrellas -= 1
		consecuencias.append("La espera hizo que el estado del herido empeorara.")
	if inc.marcas.has("mover_herido"):
		estrellas -= 1
		consecuencias.append("Indicar que se moviera al herido pudo agravar sus lesiones.")
	estrellas = clampi(estrellas, 1, 5)
	var texto := "Tiempo de respuesta: %.1f min\nLocalización al enviar: %s\nEstado final de la llamante: %d/100\nDatos obtenidos: %d\n\nValoración: %d de 5" % [
		minutos, Incidente.NOMBRES_PRECISION[maxi(inc.precision_al_enviar, 0)], inc.calma_final, inc.informacion.size(), estrellas]
	if consecuencias.size() > 0:
		texto += "\n\nConsecuencias:"
		for c in consecuencias:
			texto += "\n· " + c
	else:
		texto += "\n\n¡Intervención impecable!"
	hud.mostrar_panel("INFORME · %s" % inc.id_incidente, texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])


# ================================================================ INCENDIOS

func _crear_incendio() -> void:
	var edificios: Array = datos_mapa["edificios"]
	if edificios.is_empty():
		return
	var base_bomberos: Vector2 = Vector2.ZERO
	for v in vehiculos:
		if v.servicio == "bomberos":
			base_bomberos = red.pos(v.nodo_base)
	var centro := Vector2.ZERO
	for intento in 20:
		var e: Array = edificios[randi() % edificios.size()]
		centro = Vector2.ZERO
		var n := e.size() / 2
		for i in n:
			centro += Vector2(float(e[i * 2]), float(e[i * 2 + 1]))
		centro /= float(n)
		if centro.distance_to(base_bomberos) > 500.0:
			break
	var nodo := red.nodo_mas_cercano(centro)
	var calle := red.calle_de_nodo(nodo)
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.tipo = "incendio"
	inc.servicio_necesario = "bomberos"
	inc.titulo = "Incendio en edificio"
	inc.fuente = "Aviso automático (detector de humo)"
	inc.informacion = ["Sale humo de un edificio en %s" % calle, "Se desconoce si hay personas dentro"]
	inc.precision = 3
	inc.nodo_real = nodo
	inc.nodo_aproximado = nodo
	inc.pos_exacta = centro
	inc.urgencia_total = 40.0
	inc.urgencia_restante = 40.0
	inc.tiempo_creacion = tiempo_juego
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	hud.notificar("AVISO AUTOMÁTICO: humo detectado en un edificio de %s. Pulsa Triángulo para verlo." % calle, COLOR_RADIO_BOMBEROS)
	_sonido("alerta")
	_programar(randf_range(240.0, 360.0), _crear_incendio)


func _mostrar_informe_incendio(inc) -> void:
	var minutos := _minutos(inc.tiempo_llegada - inc.tiempo_creacion)
	var estrellas: int = 5 - (inc.intensidad - 1)
	var consecuencias := []
	if inc.intensidad > 1:
		consecuencias.append("El fuego se extendió antes de que llegaran los bomberos (nivel %d)." % inc.intensidad)
	if inc.empeorado:
		estrellas -= 1
		consecuencias.append("El edificio ha sufrido daños graves.")
	estrellas = clampi(estrellas, 1, 5)
	var texto := "Tiempo de llegada de bomberos: %.1f min\nIntensidad final: %d de 3\n\nValoración: %d de 5" % [minutos, inc.intensidad, estrellas]
	if consecuencias.size() > 0:
		texto += "\n\nConsecuencias:"
		for c in consecuencias:
			texto += "\n· " + c
	else:
		texto += "\n\n¡Incendio controlado a tiempo!"
	hud.mostrar_panel("INFORME · %s" % inc.id_incidente, texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])


# ================================================================ AVISO AUTOMÁTICO + PERSECUCIÓN

func _crear_aviso_trafico() -> void:
	sospechoso = Vehiculo.new()
	var nodo_inicio := _nodo_lugar("Restaurante Autopista")
	var calle_inicio := red.calle_de_nodo(nodo_inicio)
	sospechoso.configurar("", "sospechoso", Color("ff4d6d"), "!", 150.0, red)
	sospechoso.colocar_en(nodo_inicio)
	sospechoso.ha_llegado.connect(_on_sospechoso_llega)
	mundo.add_child(sospechoso)
	sospechoso.empezar_deambular()
	sospechoso_acelero = false

	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "AV-%03d" % contador_incidentes
	inc.tipo = "aviso_trafico"
	inc.fuente = "Aviso automático (radar de tráfico)"
	inc.titulo = "Vehículo a 112 km/h (límite 50)"
	inc.informacion = ["Detectado por radar en %s" % calle_inicio, "Turismo de color rojo", "Fiabilidad del aviso: alta"]
	inc.precision = 3
	inc.vehiculo_seguido = sospechoso
	inc.tiempo_creacion = tiempo_juego
	inc.position = sospechoso.position
	mundo.add_child(inc)
	incidentes.append(inc)
	hud.notificar("AVISO AUTOMÁTICO: vehículo a 112 km/h en %s (límite 50). Pulsa Triángulo para verlo." % calle_inicio, COLOR_SISTEMA)
	_sonido("alerta")
	_programar(75.0, _aviso_caduca.bind(inc))


func _mostrar_aviso(inc) -> void:
	var texto := "Origen: %s\nEstado: %s" % [inc.fuente, inc.estado]
	for i in inc.informacion:
		texto += "\n· %s" % i
	var opciones := []
	if inc.estado == "Pendiente":
		for v in vehiculos:
			if v.servicio == "policia":
				var libre: bool = v.estado == "Disponible"
				var etiqueta: String = ("Enviar patrulla %s" % v.id_unidad) if libre else ("%s no disponible (%s)" % [v.id_unidad, v.estado])
				opciones.append({"texto": etiqueta, "accion": _iniciar_persecucion.bind(v, inc), "activo": libre})
		opciones.append({"texto": "Mantener vigilancia", "accion": _cerrar_panel})
		opciones.append({"texto": "No intervenir", "accion": _descartar_aviso.bind(inc)})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, inc.titulo], texto, opciones)


func _iniciar_persecucion(v, inc) -> void:
	if sospechoso == null or not is_instance_valid(sospechoso) or inc.estado != "Pendiente":
		return
	v.estado = "Persecución"
	v.fase = "persecucion"
	v.incidente = inc
	v.perseguir = sospechoso
	inc.estado = "Persecución en curso"
	inc.unidades.append(v)
	_radio(v, "Recibido, central. Vamos tras el vehículo.")
	_cerrar_panel()


func _vigilar_persecucion() -> void:
	if sospechoso_acelero or sospechoso == null or not is_instance_valid(sospechoso):
		return
	for v in vehiculos:
		if v.perseguir == sospechoso and v.position.distance_to(sospechoso.position) < 300.0:
			sospechoso_acelero = true
			sospechoso.velocidad = 172.0
			_radio(v, "¡El vehículo acelera al vernos! Seguimos detrás.")
			return


func _on_interceptado(patrulla, objetivo) -> void:
	var inc = patrulla.incidente
	objetivo.detener()
	patrulla.estado = "En intervención"
	patrulla.fase = "intervencion"
	_radio(patrulla, "Vehículo detenido. Conductor identificado y denunciado.")
	if inc != null and inc.activo():
		inc.estado = "Resuelta"
		estadisticas["resueltas"] += 1
		var minutos := _minutos(tiempo_juego - inc.tiempo_creacion)
		var estrellas := 5 if minutos <= 10.0 else (4 if minutos <= 20.0 else 3)
		var texto := "Resultado: vehículo interceptado por %s.\nTiempo desde el aviso: %.0f min\nNo hubo heridos.\n\nValoración: %d de 5" % [patrulla.id_unidad, minutos, estrellas]
		hud.mostrar_panel("INFORME · %s" % inc.id_incidente, texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])
	_programar(6.0, _retirar_sospechoso.bind(patrulla, objetivo))


func _retirar_sospechoso(patrulla, objetivo) -> void:
	if is_instance_valid(objetivo):
		objetivo.queue_free()
	sospechoso = null
	_regresar(patrulla)


func _descartar_aviso(inc) -> void:
	_cerrar_panel()
	_sospechoso_se_va(inc, "Has decidido no intervenir. El vehículo se dirige hacia Ciudad Real.")


func _aviso_caduca(inc) -> void:
	if inc.estado == "Pendiente":
		_sospechoso_se_va(inc, "Nadie ha intervenido: el vehículo sale hacia Ciudad Real.")


func _sospechoso_se_va(inc, mensaje: String) -> void:
	inc.estado = "Resuelta"
	hud.notificar("%s: %s" % [inc.id_incidente, mensaje], COLOR_SISTEMA)
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.deambular = false
		sospechoso.fase = "salida"
		sospechoso.ir_a(nodo_salida)


func _on_sospechoso_llega(v) -> void:
	if v.fase == "salida":
		v.queue_free()
		sospechoso = null


# ================================================================ PAUSA

func _alternar_pausa() -> void:
	if get_tree().paused:
		get_tree().paused = false
		hud.set_pausa(false)
		_cerrar_panel()
	else:
		get_tree().paused = true
		hud.set_pausa(true)
		_mostrar_menu_pausa()


func _mostrar_menu_pausa() -> void:
	var texto := "Hora: %s\nLlamadas atendidas: %d\nEmergencias resueltas: %d" % [_hora(segundos_sim), estadisticas["llamadas"], estadisticas["resueltas"]]
	hud.mostrar_panel("PAUSA", texto, [
		{"texto": "Continuar", "accion": _alternar_pausa},
		{"texto": "Velocidad del tiempo: x%d" % int(velocidades[indice_velocidad]), "accion": _cambiar_velocidad},
		{"texto": "Prueba de mando: %s" % ("activada" if debug_activo else "desactivada"), "accion": _alternar_debug_menu},
		{"texto": "Configurar botones del mando", "accion": _calibrar_desde_menu},
		{"texto": "Salir del juego", "accion": _salir},
	])


func _cambiar_velocidad() -> void:
	indice_velocidad = (indice_velocidad + 1) % velocidades.size()
	Engine.time_scale = velocidades[indice_velocidad]
	hud.set_velocidad("Tiempo x%d" % int(velocidades[indice_velocidad]))
	_mostrar_menu_pausa()


func _alternar_debug_menu() -> void:
	debug_activo = not debug_activo
	_mostrar_menu_pausa()


func _calibrar_desde_menu() -> void:
	_alternar_pausa()
	_empezar_calibracion()


# ================================================================ CONFIGURAR MANDO

func _empezar_calibracion() -> void:
	paso_calibracion = 1
	boton_x = -1
	hud.mostrar_calibracion("CONFIGURAR EL MANDO\n\nPulsa el botón X (cruz) del mando de PS4\n\n(Con teclado: pulsa Enter para omitir)")


func _calibrar(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla != null and tecla.pressed and tecla.keycode == KEY_ENTER:
		hud.ocultar_calibracion()
		return
	var b := event as InputEventJoypadButton
	if b == null or not b.pressed:
		return
	if paso_calibracion == 1:
		boton_x = b.button_index
		paso_calibracion = 2
		hud.mostrar_calibracion("X guardado (botón %d)\n\nAhora pulsa el botón CÍRCULO" % boton_x)
	elif paso_calibracion == 2 and b.button_index != boton_x:
		Controles.guardar_configuracion(boton_x, b.button_index)
		paso_calibracion = 0
		hud.ocultar_calibracion()
		hud.notificar("Mando configurado: X = botón %d, Círculo = botón %d" % [boton_x, b.button_index], Color("8fd3a0"))


func _salir() -> void:
	get_tree().quit()
