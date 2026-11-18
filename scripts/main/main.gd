extends Node2D
## CENTRAL 112 – MIGUELTURRA
## Escena principal: crea el mapa, las unidades y la interfaz, y coordina
## los turnos, las llamadas, los avisos automáticos y las intervenciones.
##
## Tres fuentes de información, separadas:
##   1. Llamadas ciudadanas      (_sonar_llamada, _contestar_llamada...)
##   2. Avisos automáticos       (_crear_aviso_trafico, _crear_incendio)
##   3. Avisos de las unidades   (_aviso_patrulla)

const RedViaria = preload("res://scripts/routing/red_viaria.gd")
const MapaCiudad = preload("res://scripts/map/mapa_ciudad.gd")
const Vehiculo = preload("res://scripts/vehicles/vehiculo.gd")
const Incidente = preload("res://scripts/incidents/incidente.gd")
const Hud = preload("res://scripts/interface/hud.gd")
const Llamada = preload("res://scripts/calls/llamada.gd")
const DatosLlamadas = preload("res://data/dialogues/llamadas.gd")
const RUTA_MAPA := "res://data/map/miguelturra.json"
const RUTA_PARTIDA := "user://partida.cfg"

## Un turno de 12 horas dura 15 minutos reales: 43200 s / 900 s = 48.
const SEGUNDOS_SIM_POR_SEGUNDO := 48.0
const TURNOS := {
	"dia": {"nombre": "Turno de día", "inicio": 8.0, "fin": 20.0},
	"noche": {"nombre": "Turno de noche", "inicio": 20.0, "fin": 32.0},
}
## Segundos que pierde una unidad buscando el lugar según la precisión.
const TIEMPO_BUSQUEDA := [16.0, 14.0, 7.0, 0.0]
const SEGUNDOS_PARA_COLGAR := 25.0
const COLOR_RADIO_AMBULANCIA := Color("f4d35e")
const COLOR_RADIO_POLICIA := Color("6fb1ff")
const COLOR_RADIO_BOMBEROS := Color("ff8a65")
const COLOR_SISTEMA := Color("ffa630")
const COLOR_LLAMADA := Color("ff6b6b")
const NOMBRES_SERVICIO := {"ambulancia": "Ambulancia", "policia": "Policía", "bomberos": "Bomberos"}

var red := RedViaria.new()
var datos_mapa: Dictionary = {}
var tamano_mapa := Vector2(3000, 3000)
var nodo_salida := 0
var mundo: Node2D
var mapa
var camara: Camera2D
var capa_rutas: Node2D
var modulador: CanvasModulate
var hud
var sonidos := {}
var vehiculos: Array = []
var incidentes: Array = []
var seleccion = null
var sospechoso = null
var sospechoso_acelero := false

# Tiempo
var segundos_sim := 8.0 * 3600.0
var tiempo_juego := 0.0
var velocidades := [1.0, 2.0, 4.0]
var indice_velocidad := 0
var pausa_tactica := false

# Turno y partida
var en_menu := true
var turno := "dia"
var turno_id := 0
var fin_turno_sim := 0.0
var turno_terminando := false
var stats := {}
var partida := {"dia": 1, "turnos": 0, "resueltas": 0, "estrellas": 0, "valoradas": 0}

# Llamadas
var llamada = null
var llamada_datos: Dictionary = {}
var llamada_lugar: Dictionary = {}
var llamada_sonando := false
var hora_llamada := ""
var contador_llamadas := 0
var contador_incidentes := 0
var ultima_llamada_id := ""

# Mando
var paso_calibracion := 0
var boton_x := -1
var debug_activo := false
var ultimo_evento := "(pulsa cualquier botón)"
var _t_barra := 0.0
var _t_trafico := 0.0


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

	capa_rutas = Node2D.new()
	capa_rutas.draw.connect(_dibujar_rutas)
	mundo.add_child(capa_rutas)

	modulador = CanvasModulate.new()
	mundo.add_child(modulador)

	camara = Camera2D.new()
	camara.position = _pos_lugar("Plaza de España", tamano_mapa / 2.0)
	camara.zoom = Vector2(0.8, 0.8)
	mundo.add_child(camara)
	camara.make_current()

	# Unidades y bases (ficticias, junto a edificios reales).
	# Velocidad = metros por segundo real yendo en emergencia.
	var n_amb1 := _nodo_lugar("Centro de Salud de Miguelturra")
	var n_amb2 := _nodo_lugar("Complejo Candelario León Rivas")
	var n_pol1 := _nodo_lugar("Ayuntamiento de Miguelturra")
	var n_pol2 := _nodo_lugar("CEIP El Cristo")
	var n_bom := _nodo_lugar("Estación de Servicio Moeve La Estrella")
	_crear_unidad("A-01", "ambulancia", n_amb1, COLOR_RADIO_AMBULANCIA, 55.0, 0.0)
	_crear_unidad("A-02", "ambulancia", n_amb2, COLOR_RADIO_AMBULANCIA, 55.0, 0.0)
	_crear_unidad("P-01", "policia", n_pol1, Color("4d96ff"), 65.0, 450.0)
	_crear_unidad("P-02", "policia", n_pol2, Color("4d96ff"), 65.0, 550.0)
	_crear_unidad("B-01", "bomberos", n_bom, Color("e74c3c"), 45.0, 0.0)
	mapa.anadir_base("Base ambulancias 1", red.pos(n_amb1) + Vector2(0, -40), COLOR_RADIO_AMBULANCIA, "A")
	mapa.anadir_base("Base ambulancias 2", red.pos(n_amb2) + Vector2(0, -40), COLOR_RADIO_AMBULANCIA, "A")
	mapa.anadir_base("Policía Local", red.pos(n_pol1) + Vector2(-40, 30), Color("4d96ff"), "P")
	mapa.anadir_base("Parque de bomberos", red.pos(n_bom) + Vector2(40, -40), Color("e74c3c"), "B")

	_crear_sonidos()
	hud = Hud.new()
	add_child(hud)
	hud.llamada_contestada.connect(_contestar_llamada)
	hud.opcion_llamada.connect(_elegir_opcion)

	_cargar_partida()
	if not Controles.cargar_configuracion() and Input.get_connected_joypads().size() > 0:
		_empezar_calibracion()
	_mostrar_menu_turno()


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


func _crear_unidad(id: String, servicio: String, nodo: int, color: Color, velocidad: float, zona: float) -> void:
	var v = Vehiculo.new()
	v.configurar(id, servicio, color, id.left(1), velocidad, red)
	v.nodo_base = nodo
	v.zona_centro = red.pos(nodo)
	v.zona_radio = zona
	v.colocar_en(nodo)
	v.ha_llegado.connect(_on_unidad_llega)
	v.interceptado.connect(_on_interceptado)
	mundo.add_child(v)
	vehiculos.append(v)


## Ejecuta una acción dentro de X segundos de juego (se detiene en pausa).
## Si mientras tanto empieza otro turno, la acción ya no se ejecuta.
func _programar(segundos: float, accion: Callable) -> void:
	var id := turno_id
	get_tree().create_timer(segundos, false).timeout.connect(func(): _si_mismo_turno(id, accion))


func _si_mismo_turno(id: int, accion: Callable) -> void:
	if id == turno_id:
		accion.call()


# ================================================================ TURNOS Y PARTIDA

func _cargar_partida() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_PARTIDA) == OK:
		for k in partida:
			partida[k] = cfg.get_value("partida", k, partida[k])


func _guardar_partida() -> void:
	var cfg := ConfigFile.new()
	for k in partida:
		cfg.set_value("partida", k, partida[k])
	cfg.save(RUTA_PARTIDA)


func _mostrar_menu_turno() -> void:
	en_menu = true
	get_tree().paused = true
	hud.set_pausa(false)
	var media := 0.0
	if partida["valoradas"] > 0:
		media = float(partida["estrellas"]) / partida["valoradas"]
	var texto := "Día %d de servicio\n\nTurnos completados: %d\nEmergencias resueltas en total: %d\nValoración media: %.1f de 5\n\nElige tu turno:" % [
		partida["dia"], partida["turnos"], partida["resueltas"], media]
	hud.mostrar_panel("CENTRAL 112 · MIGUELTURRA", texto, [
		{"texto": "Turno de día (08:00 - 20:00): más llamadas, accidentes y caídas", "accion": _empezar_turno.bind("dia")},
		{"texto": "Turno de noche (20:00 - 08:00): peleas, robos y persecuciones", "accion": _empezar_turno.bind("noche")},
		{"texto": "Empezar una partida nueva (borra el progreso)", "accion": _borrar_partida},
		{"texto": "Salir del juego", "accion": _salir},
	], true)


func _borrar_partida() -> void:
	partida = {"dia": 1, "turnos": 0, "resueltas": 0, "estrellas": 0, "valoradas": 0}
	_guardar_partida()
	_mostrar_menu_turno()


func _empezar_turno(tipo: String) -> void:
	turno_id += 1
	turno = tipo
	en_menu = false
	turno_terminando = false
	hud.cerrar_panel()
	# Limpiar lo que quedara del turno anterior
	for inc in incidentes:
		inc.queue_free()
	incidentes.clear()
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.queue_free()
	sospechoso = null
	llamada = null
	llamada_sonando = false
	hud.ocultar_aviso_llamada()
	if hud.llamada_abierta():
		hud.cerrar_llamada()
	for v in vehiculos:
		v.perseguir = null
		v.incidente = null
		v.en_emergencia = false
		v.deambular = false
		v.fase = ""
		v.estado = "Disponible"
		v.colocar_en(v.nodo_base)
		if v.servicio == "policia":
			v.patrullar()
	stats = {"llamadas": 0, "falsas": 0, "perdidas": 0, "resueltas": 0, "estrellas": 0,
		"valoradas": 0, "tiempo_total": 0.0, "con_tiempo": 0, "empeoradas": 0}
	var t: Dictionary = TURNOS[tipo]
	segundos_sim = float(t["inicio"]) * 3600.0
	fin_turno_sim = float(t["fin"]) * 3600.0
	indice_velocidad = 0
	pausa_tactica = false
	hud.pausa_tactica = false
	get_tree().paused = false
	_aplicar_escala()
	hud.set_pausa(false)
	hud.notificar("Día %d · %s. Central 112 operativa." % [partida["dia"], t["nombre"]])
	_programar(5.0, _sonar_llamada)
	_programar(20.0, _evento_aleatorio)


func _comprobar_fin_turno() -> void:
	if en_menu:
		return
	if not turno_terminando and segundos_sim >= fin_turno_sim:
		turno_terminando = true
		hud.notificar("FIN DEL TURNO: no entrarán más avisos. Resuelve las emergencias pendientes.", Color("ffd166"))
		_sonido("alerta")
	if turno_terminando and not llamada_sonando and llamada == null and not hud.llamada_abierta():
		for inc in incidentes:
			if inc.activo():
				return
		if sospechoso != null and is_instance_valid(sospechoso):
			return
		_mostrar_resumen()


func _mostrar_resumen() -> void:
	en_menu = true
	get_tree().paused = true
	var media := 0.0
	if stats["valoradas"] > 0:
		media = float(stats["estrellas"]) / stats["valoradas"]
	var tiempo_medio := 0.0
	if stats["con_tiempo"] > 0:
		tiempo_medio = stats["tiempo_total"] / stats["con_tiempo"]
	var texto := "Día %d · %s terminado\n\nLlamadas atendidas: %d (falsas: %d)\nLlamadas perdidas: %d\nEmergencias resueltas: %d\nEmergencias que empeoraron: %d\nTiempo medio de llegada: %d s\n\nValoración media del turno: %.1f de 5" % [
		partida["dia"], TURNOS[turno]["nombre"], stats["llamadas"], stats["falsas"], stats["perdidas"],
		stats["resueltas"], stats["empeoradas"], int(tiempo_medio), media]
	partida["dia"] += 1
	partida["turnos"] += 1
	partida["resueltas"] += stats["resueltas"]
	partida["estrellas"] += stats["estrellas"]
	partida["valoradas"] += stats["valoradas"]
	_guardar_partida()
	texto += "\n\nPartida guardada."
	_sonido("envio")
	hud.mostrar_panel("RESUMEN DEL TURNO", texto, [
		{"texto": "Elegir el siguiente turno", "accion": _mostrar_menu_turno},
		{"texto": "Salir del juego", "accion": _salir},
	], true)


## Genera llamadas y avisos al azar, con ratos de calma entre medias.
func _evento_aleatorio() -> void:
	if en_menu or turno_terminando:
		return
	var dificultad := maxf(0.6, 1.0 - (partida["dia"] - 1) * 0.05)
	var espera := randf_range(22.0, 40.0) if turno == "dia" else randf_range(30.0, 50.0)
	_programar(espera * dificultad, _evento_aleatorio)
	var activos := 0
	for inc in incidentes:
		if inc.activo():
			activos += 1
	if activos >= 3 + mini(partida["dia"] - 1, 3):
		return
	var r := randf()
	var prob_llamada := 0.6 if turno == "dia" else 0.5
	if r < prob_llamada:
		if not llamada_sonando and llamada == null:
			_sonar_llamada()
	elif r < prob_llamada + 0.15 and sospechoso == null:
		_crear_aviso_trafico()
	elif r < prob_llamada + 0.27:
		_crear_incendio()
	else:
		_aviso_patrulla()


# ================================================================ BUCLE

func _process(delta: float) -> void:
	_actualizar_debug()
	if get_tree().paused and not pausa_tactica:
		return
	if not pausa_tactica:
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
	_t_trafico -= delta
	if _t_trafico <= 0.0:
		_t_trafico = 1.0
		_actualizar_trafico()
	_comprobar_fin_turno()


## Más atascos en las horas punta del día; calles vacías de madrugada.
func _actualizar_trafico() -> void:
	var h := fmod(segundos_sim / 3600.0, 24.0)
	var f := 1.0
	if (h >= 8.0 and h < 9.5) or (h >= 13.5 and h < 15.0) or (h >= 18.0 and h < 20.0):
		f = 0.8
	elif h >= 23.0 or h < 6.0:
		f = 1.15
	for v in vehiculos:
		v.factor_trafico = f
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.factor_trafico = f


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
	# La cámara va a la misma velocidad aunque el tiempo esté acelerado o lento
	var d := delta / maxf(Engine.time_scale, 0.01)
	var v := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	camara.position += v * 650.0 * d / camara.zoom.x
	var z := Input.get_action_strength("zoom_mas") - Input.get_action_strength("zoom_menos")
	if absf(z) > 0.05:
		var nz := clampf(camara.zoom.x * (1.0 + z * 1.6 * d), 0.3, 2.2)
		camara.zoom = Vector2(nz, nz)
	camara.position = camara.position.clamp(Vector2.ZERO, tamano_mapa)


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
	var ancho := 5.0 / camara.zoom.x
	for v in vehiculos:
		if v.ruta.is_empty() or not v.en_emergencia:
			continue
		var pts := PackedVector2Array([v.position])
		for n in v.ruta:
			pts.append(red.pos(n))
		if pts.size() < 2:
			continue
		capa_rutas.draw_polyline(pts, Color(0.6, 0.85, 1.0, 0.18), ancho * 3.0)
		capa_rutas.draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.45), ancho * 1.6)
		capa_rutas.draw_polyline(pts, Color(1, 1, 1, 0.95), ancho * 0.6)
		capa_rutas.draw_circle(pts[pts.size() - 1], ancho * 1.4, Color.WHITE)


func _hora(s: float) -> String:
	return "%02d:%02d" % [int(s / 3600.0) % 24, int(s / 60.0) % 60]


func _texto_segundos(s: float) -> String:
	return "%d s" % maxi(1, ceili(s))


# ================================================================ VELOCIDAD DEL TIEMPO

## Velocidad real del juego: la elegida (x1, x2, x4) y, si hay una llamada
## en curso, cuatro veces más lento para poder atenderla con calma.
func _aplicar_escala() -> void:
	if pausa_tactica or (get_tree().paused and en_menu):
		return
	var lento: bool = hud.llamada_abierta()
	Engine.time_scale = velocidades[indice_velocidad] * (0.25 if lento else 1.0)
	var texto := "Tiempo x%d" % int(velocidades[indice_velocidad])
	if lento:
		texto += " · llamada (lento)"
	hud.set_velocidad(texto)


## R1 sube la velocidad del tiempo y L1 la baja. L1 en x1 detiene el tiempo.
func _fijar_velocidad(indice: int) -> void:
	if indice < 0:
		if not pausa_tactica:
			pausa_tactica = true
			hud.pausa_tactica = true
			get_tree().paused = true
			Engine.time_scale = 1.0
			hud.set_pausa(true)
			hud.notificar("Tiempo detenido. Puedes mirar el mapa y dar órdenes. R1 para continuar.", Color("ffd166"))
			_sonido("click")
		return
	if pausa_tactica:
		pausa_tactica = false
		hud.pausa_tactica = false
		get_tree().paused = false
		hud.set_pausa(false)
		indice_velocidad = 0
		_aplicar_escala()
		hud.notificar("El tiempo continúa (x1)", Color("9fb3c8"))
		_sonido("click")
		return
	var nuevo := clampi(indice, 0, velocidades.size() - 1)
	if nuevo == indice_velocidad:
		return
	indice_velocidad = nuevo
	_aplicar_escala()
	hud.notificar("Velocidad del tiempo: x%d" % int(velocidades[indice_velocidad]), Color("9fb3c8"))
	_sonido("click")


# ================================================================ MANDO

func _unhandled_input(event: InputEvent) -> void:
	if hud.calibrando() or en_menu:
		return
	if event.is_action_pressed("depuracion"):
		debug_activo = not debug_activo
		return
	if not get_tree().paused or pausa_tactica:
		if event.is_action_pressed("categoria_siguiente"):
			_fijar_velocidad(indice_velocidad + 1)
			return
		if event.is_action_pressed("categoria_anterior"):
			_fijar_velocidad(indice_velocidad - 1)
			return
	if event.is_action_pressed("pausa"):
		_alternar_pausa()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused and not pausa_tactica:
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
	if v.incidente != null and is_instance_valid(v.incidente):
		texto += "\nAsignada a: %s" % v.incidente.id_incidente
	if v.en_movimiento and v.en_emergencia:
		texto += "\nLlega en: %s" % _texto_segundos(v.tiempo_restante())
	if v.servicio == "policia" and v.estado == "Patrullando":
		texto += "\nPatrullando su zona"
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


func _texto_servicios(inc) -> String:
	var partes := []
	for sv in inc.servicios:
		var nombre: String = NOMBRES_SERVICIO.get(sv, sv)
		if sv == inc.servicio_necesario and inc.servicios.size() > 1:
			nombre += " (principal)"
		partes.append(nombre)
	return ", ".join(PackedStringArray(partes))


func _mostrar_incidente(inc) -> void:
	camara.position = inc.position
	_marcar_seleccion(inc)
	if inc.tipo == "aviso_trafico":
		_mostrar_aviso(inc)
		return
	var texto := "Origen: %s\nEstado: %s\nLocalización: %s\nServicios: %s" % [inc.fuente, inc.estado, inc.texto_precision(), _texto_servicios(inc)]
	if inc.esperando_ayuda():
		texto += "\nEmpeora en: %s" % _texto_segundos(inc.urgencia_restante)
	if inc.tipo == "incendio":
		texto += "\nIntensidad del fuego: %d de 3" % inc.intensidad
	for i in inc.informacion:
		texto += "\n· %s" % i
	var opciones := []
	if inc.activo():
		var destino: int = inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado
		for v in vehiculos:
			var libre: bool = v.disponible()
			var etiqueta := "Enviar %s (%s) · llega en %s" % [v.id_unidad, v.nombre_servicio(), _texto_segundos(v.tiempo_estimado(destino))]
			if not libre:
				etiqueta = "%s no disponible (%s)" % [v.id_unidad, v.estado]
			opciones.append({"texto": etiqueta, "accion": _enviar_unidad.bind(v, inc), "activo": libre})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, inc.titulo], texto, opciones)


# ================================================================ LLAMADAS

func _sonar_llamada() -> void:
	if en_menu or turno_terminando or llamada_sonando or llamada != null:
		return
	# Elegir una llamada del turno (sin repetir la anterior)
	var posibles := []
	for d in DatosLlamadas.LLAMADAS:
		if (d["turno"] == turno or d["turno"] == "ambos") and d["id"] != ultima_llamada_id:
			posibles.append(d)
	if posibles.is_empty():
		return
	llamada_datos = posibles[randi() % posibles.size()]
	ultima_llamada_id = llamada_datos["id"]
	# Elegir un lugar real de Miguelturra como referencia
	var lugares := []
	for l in datos_mapa["lugares"]:
		if l["tipo"] in llamada_datos["referencias"] and String(l.get("calle", "")) != "":
			lugares.append(l)
	if lugares.is_empty():
		lugares = datos_mapa["lugares"]
	llamada_lugar = lugares[randi() % lugares.size()]
	llamada_sonando = true
	hora_llamada = _hora(segundos_sim)
	contador_llamadas += 1
	hud.mostrar_aviso_llamada("Localidad: Miguelturra · %s" % hora_llamada)
	hud.notificar("Llamada entrante al 112", COLOR_LLAMADA)
	_sonido("llamada")
	_programar(SEGUNDOS_PARA_COLGAR, _llamada_sin_contestar.bind(contador_llamadas))


func _llamada_sin_contestar(numero: int) -> void:
	if llamada_sonando and numero == contador_llamadas:
		llamada_sonando = false
		sonidos["llamada"].stop()
		hud.ocultar_aviso_llamada()
		stats["perdidas"] += 1
		hud.notificar("La persona ha colgado: llamada perdida.", COLOR_LLAMADA)


func _contestar_llamada() -> void:
	if not llamada_sonando:
		return
	llamada_sonando = false
	sonidos["llamada"].stop()
	hud.ocultar_aviso_llamada()
	if hud.panel_abierto():
		_cerrar_panel()
	stats["llamadas"] += 1
	llamada = Llamada.new()
	llamada.iniciar(llamada_datos, {"lugar": llamada_lugar.get("nombre", "la plaza"), "calle": llamada_lugar.get("calle", "una calle del centro")})
	hud.abrir_llamada()
	_aplicar_escala()
	_refrescar_llamada()


func _refrescar_llamada() -> void:
	var cabecera := "Llamada 112-%04d  ·  %s  ·  %s  ·  Miguelturra" % [contador_llamadas, hora_llamada, llamada_datos["llamante"]]
	var textos := []
	for o in llamada.opciones_actuales:
		textos.append(o["texto"])
	hud.actualizar_llamada(cabecera, llamada.texto_actual, llamada.calma, llamada.estado_emocional(),
		Incidente.NOMBRES_PRECISION[llamada.precision], llamada.informacion, textos)


func _elegir_opcion(indice: int) -> void:
	if llamada == null:
		return
	_sonido("click")
	llamada.elegir(indice)
	if llamada.terminada:
		_terminar_llamada()
	else:
		_refrescar_llamada()


func _terminar_llamada() -> void:
	hud.cerrar_llamada()
	_aplicar_escala()
	if llamada_datos.get("falsa", false):
		stats["falsas"] += 1
		hud.notificar("Llamada sin emergencia real: no se crea ningún incidente.", Color("9fb3c8"))
		llamada = null
		return
	var d: Dictionary = llamada_datos["incidente"]
	var nodo := int(llamada_lugar.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.tipo = "llamada"
	inc.fuente = "Llamada al 112 (112-%04d)" % contador_llamadas
	inc.titulo = d["titulo"]
	inc.servicios = d["servicios"].duplicate()
	inc.servicio_necesario = d["principal"]
	inc.urgencia_total = d["urgencia"]
	inc.urgencia_restante = d["urgencia"]
	inc.traslado = d.get("traslado", false)
	inc.tiempo_intervencion = d.get("intervencion", 10.0)
	inc.informacion = llamada.informacion.duplicate()
	inc.marcas = llamada.marcas.duplicate()
	inc.precision = llamada.precision
	inc.calma_final = llamada.calma
	inc.nodo_real = nodo
	inc.pos_exacta = red.pos(nodo)
	inc.pos_calle = Vector2(float(llamada_lugar.get("x", inc.pos_exacta.x)), float(llamada_lugar.get("y", inc.pos_exacta.y)))
	inc.radio_calle = 140.0
	inc.pos_zona = inc.pos_exacta + Vector2.from_angle(randf() * TAU) * 200.0
	inc.radio_zona = 380.0
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
	if not v.disponible() or not inc.activo():
		hud.notificar("No es posible enviar %s ahora mismo." % v.id_unidad)
		return
	v.deambular = false
	v.en_emergencia = true
	v.estado = "En desplazamiento"
	v.fase = "ida"
	v.incidente = inc
	inc.unidades.append(v)
	_sonido("sirena")
	if v.servicio == inc.servicio_necesario:
		if inc.precision_al_enviar < 0:
			inc.precision_al_enviar = inc.precision
		if inc.estado == "Pendiente":
			inc.estado = "Unidad en camino"
	var destino: int = inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado
	v.ir_a(destino)
	_radio(v, "Recibido, central. Salimos con sirenas hacia %s." % inc.id_incidente)
	_cerrar_panel()


func _on_unidad_llega(v) -> void:
	match v.fase:
		"ida":
			var inc = v.incidente
			if inc == null or not is_instance_valid(inc):
				_regresar(v)
				return
			if inc.precision < 3:
				v.fase = "buscando"
				v.estado = "Buscando el lugar"
				_radio(v, "Estamos en la zona, pero no localizamos el incidente. Buscando...")
				_programar(TIEMPO_BUSQUEDA[inc.precision], _fin_busqueda.bind(v))
			else:
				_comenzar_intervencion(v)
		"buscando2":
			_comenzar_intervencion(v)
		"traslado":
			v.fase = "hospital"
			_radio(v, "Paciente entregado en el Hospital General de Ciudad Real.")
			_programar(6.0, _regresar.bind(v))
		"regreso":
			v.estado = "Disponible"
			v.fase = ""
			v.incidente = null
			_radio(v, "En base y disponibles.")


func _fin_busqueda(v) -> void:
	var inc = v.incidente
	if inc == null or not is_instance_valid(inc):
		return
	inc.precision = 3
	inc.actualizar_posicion()
	v.fase = "buscando2"
	v.estado = "En desplazamiento"
	_radio(v, "Localizado. Nos dirigimos al lugar exacto.")
	v.ir_a(inc.nodo_real)


func _comenzar_intervencion(v) -> void:
	var inc = v.incidente
	if inc == null or not is_instance_valid(inc):
		_regresar(v)
		return
	v.estado = "En intervención"
	v.fase = "intervencion"
	v.en_emergencia = false
	if not inc.activo():
		_radio(v, "En el lugar. La situación ya está controlada, volvemos.")
		_programar(4.0, _regresar.bind(v))
		return
	if v.servicio == inc.servicio_necesario:
		if inc.tiempo_llegada < 0.0:
			inc.tiempo_llegada = tiempo_juego
		inc.estado = "En intervención"
		match inc.tipo:
			"incendio":
				_radio(v, "En el lugar. Comenzamos la extinción.")
				_programar(10.0 + inc.intensidad * 5.0, _fin_intervencion.bind(v))
			_:
				match v.servicio:
					"ambulancia":
						_radio(v, "En el lugar. Atendiendo al paciente.")
					"policia":
						_radio(v, "En el lugar. Intervenimos.")
					_:
						_radio(v, "En el lugar. Comenzamos a trabajar.")
				_programar(inc.tiempo_intervencion, _fin_intervencion.bind(v))
	else:
		match v.servicio:
			"policia":
				_radio(v, "En el lugar. Zona asegurada y tráfico cortado.")
			"ambulancia":
				_radio(v, "En el lugar. Atendemos a los afectados leves.")
			_:
				_radio(v, "En el lugar. Asegurando la zona.")
		_programar(8.0, _regresar.bind(v))


func _fin_intervencion(v) -> void:
	var inc = v.incidente
	if inc == null or not is_instance_valid(inc):
		_regresar(v)
		return
	if inc.activo():
		inc.estado = "Resuelta"
		match inc.tipo:
			"incendio":
				_radio(v, "Incendio extinguido.")
			_:
				match v.servicio:
					"ambulancia":
						_radio(v, "Paciente estabilizado.")
					"policia":
						_radio(v, "Situación resuelta.")
					_:
						_radio(v, "Trabajo terminado.")
		_informe_incidente(inc)
	if v.servicio == "ambulancia" and inc.traslado:
		_trasladar(v)
	else:
		_regresar(v)


func _trasladar(v) -> void:
	v.fase = "traslado"
	v.estado = "Traslado al hospital"
	v.en_emergencia = true
	_radio(v, "Trasladamos al paciente al Hospital General de Ciudad Real.")
	v.ir_a(nodo_salida)


func _regresar(v) -> void:
	v.en_emergencia = false
	v.incidente = null
	if v.servicio == "policia":
		v.patrullar()
		return
	v.fase = "regreso"
	v.estado = "Regresando"
	v.ir_a(v.nodo_base)


func _informe_incidente(inc) -> void:
	var t_llegada: float = inc.tiempo_llegada - inc.tiempo_creacion
	var estrellas := 1
	var consecuencias := []
	if inc.tipo == "llamada":
		if inc.precision_al_enviar >= 3:
			estrellas += 1
		else:
			consecuencias.append("La localización imprecisa obligó a buscar el lugar.")
		if inc.calma_final >= 60:
			estrellas += 1
		elif inc.calma_final < 40:
			consecuencias.append("La persona que llamó terminó muy nerviosa.")
		if inc.informacion.size() >= 3:
			estrellas += 1
		else:
			consecuencias.append("Se obtuvo poca información durante la llamada.")
	else:
		estrellas += 2
	if t_llegada <= inc.urgencia_total * 0.5:
		estrellas += 1
	if inc.marcas.has("consejo_bueno"):
		estrellas += 1
	if inc.marcas.has("consejo_malo"):
		estrellas -= 1
		consecuencias.append("Alguna de las instrucciones dadas por teléfono no fue adecuada.")
	if inc.empeorado:
		estrellas -= 1
		stats["empeoradas"] += 1
		consecuencias.append("La espera hizo que la situación empeorara.")
	if inc.tipo == "incendio" and inc.intensidad > 1:
		estrellas -= inc.intensidad - 1
		consecuencias.append("El fuego se extendió antes de que llegaran los bomberos (nivel %d)." % inc.intensidad)
	estrellas = clampi(estrellas, 1, 5)
	_sumar_estadisticas(estrellas, t_llegada)
	var texto := "Tiempo de llegada: %s\nLocalización al enviar: %s\nServicios: %s\n\nValoración: %d de 5" % [
		_texto_segundos(t_llegada), Incidente.NOMBRES_PRECISION[clampi(inc.precision_al_enviar, 0, 3)], _texto_servicios(inc), estrellas]
	if consecuencias.size() > 0:
		texto += "\n\nConsecuencias:"
		for c in consecuencias:
			texto += "\n· " + c
	else:
		texto += "\n\n¡Intervención impecable!"
	hud.mostrar_panel("INFORME · %s · %s" % [inc.id_incidente, inc.titulo], texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])


func _sumar_estadisticas(estrellas: int, t_llegada: float) -> void:
	stats["resueltas"] += 1
	stats["estrellas"] += estrellas
	stats["valoradas"] += 1
	if t_llegada >= 0.0:
		stats["tiempo_total"] += t_llegada
		stats["con_tiempo"] += 1


func _vigilar_urgencias() -> void:
	for inc in incidentes:
		if not inc.esperando_ayuda() or inc.urgencia_restante > 0.0 or inc.empeorado:
			continue
		if inc.tipo == "incendio" and inc.intensidad < 3:
			inc.intensidad += 1
			inc.urgencia_restante = inc.urgencia_total
			hud.notificar("%s: ¡el incendio se está extendiendo! (nivel %d de 3)" % [inc.id_incidente, inc.intensidad], COLOR_RADIO_BOMBEROS)
		else:
			inc.empeorado = true
			hud.notificar("%s: la ayuda tarda demasiado, la situación empeora." % inc.id_incidente, COLOR_LLAMADA)
		_sonido("alerta")


# ================================================================ AVISOS DE LAS PATRULLAS

func _aviso_patrulla() -> void:
	var patrullas := []
	for v in vehiculos:
		if v.servicio == "policia" and v.estado == "Patrullando":
			patrullas.append(v)
	if patrullas.is_empty():
		_sonar_llamada()
		return
	var v = patrullas[randi() % patrullas.size()]
	var opciones_dia := [
		["Vehículo averiado cortando la calzada", ["policia"], "policia", 90.0],
		["Accidente leve sin heridos", ["policia"], "policia", 80.0],
		["Persona mayor desorientada", ["policia", "ambulancia"], "policia", 80.0],
	]
	var opciones_noche := [
		["Pelea entre dos personas", ["policia"], "policia", 70.0],
		["Persona dormida en un portal, muy bebida", ["policia", "ambulancia"], "ambulancia", 85.0],
		["Coche sospechoso merodeando", ["policia"], "policia", 90.0],
	]
	var lista: Array = opciones_dia if turno == "dia" else opciones_noche
	var o: Array = lista[randi() % lista.size()]
	var nodo: int = v.siguiente_nodo
	var calle := red.calle_de_nodo(nodo)
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.tipo = "aviso_unidad"
	inc.fuente = "Aviso de la patrulla %s" % v.id_unidad
	inc.titulo = o[0]
	inc.servicios = o[1].duplicate()
	inc.servicio_necesario = o[2]
	inc.urgencia_total = o[3]
	inc.urgencia_restante = o[3]
	inc.tiempo_intervencion = 8.0
	inc.informacion = ["Visto por %s en %s" % [v.id_unidad, calle]]
	inc.precision = 3
	inc.nodo_real = nodo
	inc.nodo_aproximado = nodo
	inc.pos_exacta = red.pos(nodo) + Vector2(25, -25)
	inc.tiempo_creacion = tiempo_juego
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	_radio(v, "Central, vemos: %s en %s. ¿Intervenimos?" % [o[0].to_lower(), calle])


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
	inc.servicios = ["bomberos"]
	inc.titulo = "Incendio en edificio"
	inc.fuente = "Aviso automático (detector de humo)"
	inc.informacion = ["Sale humo de un edificio en %s" % calle]
	if randf() < 0.5:
		inc.servicios = ["bomberos", "ambulancia"]
		inc.informacion.append("Un vecino ha inhalado humo")
	else:
		inc.informacion.append("No se sabe si hay personas dentro")
	inc.precision = 3
	inc.nodo_real = nodo
	inc.nodo_aproximado = nodo
	inc.pos_exacta = centro
	inc.urgencia_total = 55.0
	inc.urgencia_restante = 55.0
	inc.tiempo_creacion = tiempo_juego
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	hud.notificar("AVISO AUTOMÁTICO: humo detectado en un edificio de %s. Pulsa Triángulo para verlo." % calle, COLOR_RADIO_BOMBEROS)
	_sonido("alerta")


# ================================================================ AVISO DE TRÁFICO + PERSECUCIÓN

func _crear_aviso_trafico() -> void:
	# Aparece en una calle al azar, lejos del borde del mapa
	var nodo_inicio := red.nodo_mas_cercano(_pos_lugar("Plaza de España", tamano_mapa / 2.0) + Vector2(randf_range(-600, 600), randf_range(-500, 500)))
	var calle_inicio := red.calle_de_nodo(nodo_inicio)
	var limite := 50
	var medida := randi_range(85, 125) if turno == "dia" else randi_range(95, 140)
	sospechoso = Vehiculo.new()
	sospechoso.configurar("", "sospechoso", Color("ff4d6d"), "!", 50.0, red)
	sospechoso.en_emergencia = true
	sospechoso.colocar_en(nodo_inicio)
	sospechoso.ha_llegado.connect(_on_sospechoso_llega)
	mundo.add_child(sospechoso)
	sospechoso.empezar_deambular()
	sospechoso_acelero = false

	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "AV-%03d" % contador_incidentes
	inc.tipo = "aviso_trafico"
	inc.servicios = ["policia"]
	inc.servicio_necesario = "policia"
	inc.fuente = "Aviso automático (radar de tráfico)"
	inc.titulo = "Vehículo a %d km/h (límite %d)" % [medida, limite]
	inc.informacion = ["Detectado por radar en %s" % calle_inicio, "Turismo de color rojo"]
	if turno == "noche":
		inc.informacion.append("Posible conductor bebido")
	inc.precision = 3
	inc.vehiculo_seguido = sospechoso
	inc.tiempo_creacion = tiempo_juego
	inc.position = sospechoso.position
	mundo.add_child(inc)
	incidentes.append(inc)
	hud.notificar("AVISO AUTOMÁTICO: vehículo a %d km/h en %s. Pulsa Triángulo para verlo." % [medida, calle_inicio], COLOR_SISTEMA)
	_sonido("alerta")
	_programar(60.0, _aviso_caduca.bind(inc))


func _mostrar_aviso(inc) -> void:
	var texto := "Origen: %s\nEstado: %s" % [inc.fuente, inc.estado]
	for i in inc.informacion:
		texto += "\n· %s" % i
	var opciones := []
	if inc.estado == "Pendiente":
		for v in vehiculos:
			if v.servicio == "policia":
				var libre: bool = v.disponible()
				var etiqueta: String = ("Enviar patrulla %s" % v.id_unidad) if libre else ("%s no disponible (%s)" % [v.id_unidad, v.estado])
				opciones.append({"texto": etiqueta, "accion": _iniciar_persecucion.bind(v, inc), "activo": libre})
		opciones.append({"texto": "Mantener vigilancia", "accion": _cerrar_panel})
		opciones.append({"texto": "No intervenir", "accion": _descartar_aviso.bind(inc)})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, inc.titulo], texto, opciones)


func _iniciar_persecucion(v, inc) -> void:
	if sospechoso == null or not is_instance_valid(sospechoso) or inc.estado != "Pendiente":
		return
	v.deambular = false
	v.en_emergencia = true
	v.estado = "Persecución"
	v.fase = "persecucion"
	v.incidente = inc
	v.perseguir = sospechoso
	inc.estado = "Persecución en curso"
	inc.unidades.append(v)
	_sonido("sirena")
	_radio(v, "Recibido, central. Vamos tras el vehículo.")
	_cerrar_panel()


func _vigilar_persecucion() -> void:
	if sospechoso_acelero or sospechoso == null or not is_instance_valid(sospechoso):
		return
	for v in vehiculos:
		if v.perseguir == sospechoso and v.position.distance_to(sospechoso.position) < 300.0:
			sospechoso_acelero = true
			sospechoso.velocidad = 58.0
			_radio(v, "¡El vehículo acelera al vernos! Seguimos detrás.")
			return


func _on_interceptado(patrulla, objetivo) -> void:
	var inc = patrulla.incidente
	objetivo.detener()
	patrulla.estado = "En intervención"
	patrulla.fase = "intervencion"
	patrulla.en_emergencia = false
	_radio(patrulla, "Vehículo detenido. Conductor identificado y denunciado.")
	if inc != null and is_instance_valid(inc) and inc.activo():
		inc.estado = "Resuelta"
		var t: float = tiempo_juego - inc.tiempo_creacion
		var estrellas := 5 if t <= 40.0 else (4 if t <= 70.0 else 3)
		_sumar_estadisticas(estrellas, -1.0)
		var texto := "Resultado: vehículo interceptado por %s.\nTiempo desde el aviso: %s\nNo hubo heridos.\n\nValoración: %d de 5" % [patrulla.id_unidad, _texto_segundos(t), estrellas]
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


# ================================================================ SONIDO

func _crear_sonidos() -> void:
	for nombre in ["llamada", "radio", "alerta", "envio", "click", "sirena"]:
		var reproductor := AudioStreamPlayer.new()
		var ruta := "res://assets/audio/%s.wav" % nombre
		if ResourceLoader.exists(ruta):
			reproductor.stream = load(ruta)
		reproductor.volume_db = -4.0 if nombre != "sirena" else -8.0
		add_child(reproductor)
		sonidos[nombre] = reproductor
	sonidos["llamada"].finished.connect(_repetir_tono)


func _repetir_tono() -> void:
	if llamada_sonando:
		sonidos["llamada"].play()


func _sonido(nombre: String) -> void:
	if sonidos.has(nombre) and sonidos[nombre].stream != null:
		sonidos[nombre].play()


# ================================================================ PAUSA

func _alternar_pausa() -> void:
	if pausa_tactica:
		# Desde el tiempo detenido, Options abre el menú
		pausa_tactica = false
		hud.pausa_tactica = false
		_mostrar_menu_pausa()
		return
	if get_tree().paused:
		get_tree().paused = false
		hud.set_pausa(false)
		_cerrar_panel()
		_aplicar_escala()
	else:
		get_tree().paused = true
		hud.set_pausa(true)
		_mostrar_menu_pausa()


func _mostrar_menu_pausa() -> void:
	var queda := maxf(fin_turno_sim - segundos_sim, 0.0) / SEGUNDOS_SIM_POR_SEGUNDO
	var texto := "%s · Día %d\nHora: %s (quedan unos %d min reales de turno)\nLlamadas atendidas: %d\nEmergencias resueltas: %d" % [
		TURNOS[turno]["nombre"], partida["dia"], _hora(segundos_sim), int(queda / 60.0), stats["llamadas"], stats["resueltas"]]
	hud.mostrar_panel("PAUSA", texto, [
		{"texto": "Continuar", "accion": _alternar_pausa},
		{"texto": "Velocidad del tiempo: x%d" % int(velocidades[indice_velocidad]), "accion": _cambiar_velocidad},
		{"texto": "Prueba de mando: %s" % ("activada" if debug_activo else "desactivada"), "accion": _alternar_debug_menu},
		{"texto": "Configurar botones del mando", "accion": _calibrar_desde_menu},
		{"texto": "Salir del juego", "accion": _salir},
	])


func _cambiar_velocidad() -> void:
	indice_velocidad = (indice_velocidad + 1) % velocidades.size()
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
