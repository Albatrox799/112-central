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
const Catalogo = preload("res://data/gestion/catalogo.gd")
const DatosHistorias = preload("res://data/historias/historias.gd")
const RUTA_OPCIONES := "user://opciones.cfg"
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
var partida := {}
var bases := {}            # nombre de base -> nodo del mapa
var turno_elegido := "dia"

# Llamadas
var llamada = null
var llamada_datos: Dictionary = {}
var llamada_lugar: Dictionary = {}
var llamada_sonando := false
var hora_llamada := ""
var contador_llamadas := 0
var contador_incidentes := 0
var ultima_llamada_id := ""
var llamada_historia: Dictionary = {}
var llamada_desenlace := ""
var llamada_perfil := ""
var llamada_calma := -1
var llamada_vars: Dictionary = {}
var llamada_rel_inc = null
var cola_relacionadas: Array = []   # [incidente, clave de llamada]

# Portada, opciones, tutorial y objetivos
var en_portada := false
var decoracion: Node2D
var rutas_decor: Array = []
var _t_portada := 0.0
var opciones := {"volumen": 1.0, "texto_grande": false, "dificultad": "normal"}
var tutorial_activo := false
var consejos_vistos: Array = []
var objetivos: Array = []
var _t_historias := 0.0

# Mando
var paso_calibracion := 0
var boton_x := -1
var boton_circulo := -1
var nav_abajo: Dictionary = {}
var debug_activo := false
var ultimo_evento := "(pulsa cualquier botón)"
var _t_barra := 0.0
var unidad_a_enviar = null   # unidad elegida con X que espera destino en el mapa
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

	# Luces animadas de la portada (siguen moviéndose aunque el juego esté en pausa)
	decoracion = Node2D.new()
	decoracion.process_mode = Node.PROCESS_MODE_ALWAYS
	decoracion.draw.connect(_dibujar_decoracion)
	mundo.add_child(decoracion)

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
	bases = {"ambulancia1": n_amb1, "ambulancia2": n_amb2, "policia": n_pol1, "policia_zona2": n_pol2, "bomberos": n_bom}
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
	_cargar_opciones()
	if not Controles.cargar_configuracion() and Input.get_connected_joypads().size() > 0:
		_empezar_calibracion()
	_preparar_decoracion()
	_mostrar_portada()


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


const COLOR_SERVICIO := {"ambulancia": Color("f4d35e"), "policia": Color("4d96ff"), "bomberos": Color("e74c3c")}
const LETRA_SERVICIO := {"ambulancia": "A", "policia": "P", "bomberos": "B"}


## Identificadores (A-01, P-02...) en el orden de la flota.
func _ids_flota() -> Array:
	var cuenta := {}
	var ids := []
	for u in partida["flota"]:
		var sv: String = Catalogo.VEHICULOS[u["tipo"]]["servicio"]
		cuenta[sv] = int(cuenta.get(sv, 0)) + 1
		ids.append("%s-%02d" % [LETRA_SERVICIO[sv], cuenta[sv]])
	return ids


## Crea los vehículos del mapa a partir de la flota comprada.
func _construir_flota() -> void:
	for v in vehiculos:
		v.queue_free()
	vehiculos.clear()
	var ids := _ids_flota()
	var n_policia := 0
	for i in partida["flota"].size():
		var u: Dictionary = partida["flota"][i]
		var datos: Dictionary = Catalogo.VEHICULOS[u["tipo"]]
		var sv: String = datos["servicio"]
		var v = Vehiculo.new()
		v.configurar(ids[i], sv, COLOR_SERVICIO[sv], LETRA_SERVICIO[sv], float(datos["velocidad"]), red)
		v.tipo = u["tipo"]
		v.nombre_tipo = datos["nombre"]
		v.bono = datos["bono"]
		v.personal = int(u["personal"])
		v.heridos = u["heridos"].duplicate()
		v.equipo = u["equipo"].duplicate()
		v.indice_flota = i
		var nodo: int = bases.get(u["base"], bases["policia"])
		v.nodo_base = nodo
		v.zona_radio = 0.0
		if sv == "policia":
			# Las patrullas se reparten entre dos zonas de Miguelturra
			var zona_nodo: int = bases["policia"] if n_policia % 2 == 0 else bases["policia_zona2"]
			v.zona_centro = red.pos(zona_nodo)
			v.zona_radio = 450.0 if n_policia % 2 == 0 else 550.0
			n_policia += 1
		v.colocar_en(nodo)
		v.ha_llegado.connect(_on_unidad_llega)
		v.interceptado.connect(_on_interceptado)
		mundo.add_child(v)
		vehiculos.append(v)
		if v.efectivos() == 0:
			v.estado = "Sin personal"
		elif sv == "policia":
			v.patrullar()


## Guarda en la flota los cambios de personal (heridos) de los vehículos.
func _sincronizar_flota() -> void:
	for v in vehiculos:
		if v.indice_flota >= 0 and v.indice_flota < partida["flota"].size():
			partida["flota"][v.indice_flota]["heridos"] = v.heridos.duplicate()


## Ejecuta una acción dentro de X segundos de juego (se detiene en pausa).
## Si mientras tanto empieza otro turno, la acción ya no se ejecuta.
func _programar(segundos: float, accion: Callable) -> void:
	var id := turno_id
	get_tree().create_timer(segundos, false).timeout.connect(func(): _si_mismo_turno(id, accion))


func _si_mismo_turno(id: int, accion: Callable) -> void:
	if id == turno_id:
		accion.call()


# ================================================================ TURNOS Y PARTIDA

func _partida_nueva() -> Dictionary:
	return {"dia": 1, "turnos": 0, "resueltas": 0, "estrellas": 0, "valoradas": 0,
		"dinero": Catalogo.DINERO_INICIAL, "flota": Catalogo.FLOTA_INICIAL.duplicate(true)}


func _cargar_partida() -> void:
	partida = _partida_nueva()
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_PARTIDA) == OK:
		for k in partida:
			partida[k] = cfg.get_value("partida", k, partida[k])
	hud.set_dinero(partida["dinero"])


func _cambiar_dinero(cantidad: int) -> void:
	partida["dinero"] = int(partida["dinero"]) + cantidad
	hud.set_dinero(partida["dinero"])
	if not en_menu:
		stats["ingresos"] = int(stats.get("ingresos", 0)) + cantidad


func _guardar_partida() -> void:
	var cfg := ConfigFile.new()
	for k in partida:
		cfg.set_value("partida", k, partida[k])
	cfg.save(RUTA_PARTIDA)


func _mostrar_menu_turno() -> void:
	en_portada = false
	hud.mostrar_portada(false)
	decoracion.visible = false
	en_menu = true
	get_tree().paused = true
	hud.set_pausa(false)
	var media := 0.0
	if partida["valoradas"] > 0:
		media = float(partida["estrellas"]) / partida["valoradas"]
	var texto := "Día %d de servicio · Dinero: %s\nTurnos completados: %d · Resueltas: %d · Valoración media: %.1f\n\nElige tu turno:" % [
		partida["dia"], Hud.formato_euros(partida["dinero"]), partida["turnos"], partida["resueltas"], media]
	hud.mostrar_panel("CENTRAL 112 · MIGUELTURRA", texto, [
		{"texto": "Turno de día (08:00 - 20:00): más llamadas, accidentes y caídas", "accion": _elegir_turno.bind("dia")},
		{"texto": "Turno de noche (20:00 - 08:00): peleas, robos y persecuciones", "accion": _elegir_turno.bind("noche")},
		{"texto": "Volver a la portada", "accion": _mostrar_portada},
	], true)


func _borrar_partida() -> void:
	partida = _partida_nueva()
	hud.set_dinero(partida["dinero"])
	_guardar_partida()
	_mostrar_menu_turno()


func _elegir_turno(tipo: String) -> void:
	turno_elegido = tipo
	_mostrar_equipos()


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
	hud.ocultar_lugar(hud.vista_lugar.inc)
	_construir_flota()
	_cancelar_envio()
	stats = {"llamadas": 0, "falsas": 0, "perdidas": 0, "resueltas": 0, "estrellas": 0,
		"valoradas": 0, "tiempo_total": 0.0, "con_tiempo": 0, "empeoradas": 0, "ingresos": 0, "heridos": 0,
		"historias": 0, "historias_buenas": 0, "relacionadas": 0}
	cola_relacionadas.clear()
	_elegir_objetivos()
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


# ================================================================ EQUIPOS Y TIENDA

func _sueldos_turno() -> int:
	var total := 0
	for u in partida["flota"]:
		total += int(u["personal"]) * Catalogo.SUELDO_POR_TURNO
	return total


func _mostrar_equipos() -> void:
	var ids := _ids_flota()
	var texto := "Dinero: %s · Sueldos por turno: %s\nElige un vehículo para ver su personal y comprarle equipo." % [
		Hud.formato_euros(partida["dinero"]), Hud.formato_euros(_sueldos_turno())]
	var opciones := [{"texto": ">> EMPEZAR %s <<" % TURNOS[turno_elegido]["nombre"].to_upper(), "accion": _empezar_turno.bind(turno_elegido)}]
	for i in partida["flota"].size():
		var u: Dictionary = partida["flota"][i]
		var datos: Dictionary = Catalogo.VEHICULOS[u["tipo"]]
		var aviso := ""
		if u["heridos"].size() > 0:
			aviso = " · %d de baja" % u["heridos"].size()
		opciones.append({"texto": "%s · %s · Personal %d/%d%s · Equipo: %d" % [
			ids[i], datos["nombre"], int(u["personal"]), int(datos["plazas"]), aviso, u["equipo"].size()],
			"accion": _mostrar_ficha.bind(i)})
	opciones.append({"texto": "Tienda: comprar un vehículo nuevo", "accion": _mostrar_tienda_vehiculos})
	opciones.append({"texto": "Volver a elegir turno", "accion": _mostrar_menu_turno})
	hud.mostrar_panel("EQUIPOS", texto, opciones, true)


func _mostrar_ficha(i: int) -> void:
	var u: Dictionary = partida["flota"][i]
	var datos: Dictionary = Catalogo.VEHICULOS[u["tipo"]]
	var sv: String = datos["servicio"]
	var id: String = _ids_flota()[i]
	var equipo_txt := "ninguno"
	if u["equipo"].size() > 0:
		var nombres := []
		for e in u["equipo"]:
			nombres.append(Catalogo.EQUIPO[e]["nombre"])
		equipo_txt = ", ".join(PackedStringArray(nombres))
	var texto := "%s · Velocidad %d · Plazas %d\nPersonal: %d (de baja: %d)\nEquipo: %s\nDinero: %s" % [
		datos["nombre"], int(datos["velocidad"]), int(datos["plazas"]), int(u["personal"]), u["heridos"].size(),
		equipo_txt, Hud.formato_euros(partida["dinero"])]
	var dinero: int = partida["dinero"]
	var opciones := []
	if int(u["personal"]) < int(datos["plazas"]):
		opciones.append({"texto": "Contratar a una persona (%s + %s/turno)" % [Hud.formato_euros(Catalogo.PRECIO_CONTRATAR), Hud.formato_euros(Catalogo.SUELDO_POR_TURNO)],
			"accion": _contratar.bind(i), "activo": dinero >= Catalogo.PRECIO_CONTRATAR})
	elif int(u["personal"]) > 1:
		opciones.append({"texto": "Despedir a una persona (ahorra sueldo)", "accion": _despedir.bind(i)})
	for clave in Catalogo.EQUIPO:
		var e: Dictionary = Catalogo.EQUIPO[clave]
		if e["servicio"] == sv and not u["equipo"].has(clave):
			opciones.append({"texto": "Comprar %s (%s): %s" % [e["nombre"], Hud.formato_euros(e["precio"]), e["ayuda"]],
				"accion": _comprar_equipo.bind(i, clave), "activo": dinero >= int(e["precio"])})
	var mismos := 0
	for otro in partida["flota"]:
		if Catalogo.VEHICULOS[otro["tipo"]]["servicio"] == sv:
			mismos += 1
	if mismos > 1:
		opciones.append({"texto": "Vender este vehículo (+%s)" % Hud.formato_euros(int(datos["precio"]) / 2), "accion": _vender.bind(i)})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	hud.mostrar_panel("%s · %s" % [id, datos["nombre"]], texto, opciones, true)


func _contratar(i: int) -> void:
	partida["flota"][i]["personal"] = int(partida["flota"][i]["personal"]) + 1
	_cambiar_dinero(-Catalogo.PRECIO_CONTRATAR)
	_guardar_partida()
	_sonido("envio")
	_mostrar_ficha(i)


func _despedir(i: int) -> void:
	partida["flota"][i]["personal"] = int(partida["flota"][i]["personal"]) - 1
	var heridos: Array = partida["flota"][i]["heridos"]
	while heridos.size() > int(partida["flota"][i]["personal"]):
		heridos.pop_back()
	_guardar_partida()
	_mostrar_ficha(i)


func _comprar_equipo(i: int, clave: String) -> void:
	partida["flota"][i]["equipo"].append(clave)
	_cambiar_dinero(-int(Catalogo.EQUIPO[clave]["precio"]))
	_guardar_partida()
	_sonido("envio")
	_mostrar_ficha(i)


func _vender(i: int) -> void:
	var datos: Dictionary = Catalogo.VEHICULOS[partida["flota"][i]["tipo"]]
	partida["flota"].remove_at(i)
	_cambiar_dinero(int(datos["precio"]) / 2)
	_guardar_partida()
	_mostrar_equipos()


func _mostrar_tienda_vehiculos() -> void:
	var dinero: int = partida["dinero"]
	var opciones := []
	var nombres := {"ambulancia": "Sanitario", "policia": "Policía", "bomberos": "Bomberos"}
	for clave in Catalogo.VEHICULOS:
		var d: Dictionary = Catalogo.VEHICULOS[clave]
		opciones.append({"texto": "%s · %s · Vel. %d · %d plazas · %s" % [nombres[d["servicio"]], d["nombre"], int(d["velocidad"]), int(d["plazas"]), Hud.formato_euros(d["precio"])],
			"accion": _comprar_vehiculo.bind(clave), "activo": dinero >= int(d["precio"])})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	hud.mostrar_panel("TIENDA DE VEHÍCULOS", "Dinero: %s\nCada vehículo nuevo viene con su personal mínimo." % Hud.formato_euros(dinero), opciones, true)


func _comprar_vehiculo(clave: String) -> void:
	var d: Dictionary = Catalogo.VEHICULOS[clave]
	partida["flota"].append({"tipo": clave, "base": Catalogo.BASE_SERVICIO[d["servicio"]],
		"personal": mini(2, int(d["plazas"])), "heridos": [], "equipo": []})
	_cambiar_dinero(-int(d["precio"]))
	_guardar_partida()
	_sonido("envio")
	_mostrar_equipos()


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
	# Sueldos del personal y recuperación de heridos
	_sincronizar_flota()
	var sueldos := 0
	for u in partida["flota"]:
		sueldos += int(u["personal"]) * Catalogo.SUELDO_POR_TURNO
		var quedan := []
		for t in u["heridos"]:
			if int(t) > 1:
				quedan.append(int(t) - 1)
		u["heridos"] = quedan
	partida["dinero"] = int(partida["dinero"]) - sueldos
	hud.set_dinero(partida["dinero"])
	texto += "\n\nIngresos del turno: %s\nSueldos del personal: -%s\nDinero total: %s" % [
		Hud.formato_euros(stats["ingresos"]), Hud.formato_euros(sueldos), Hud.formato_euros(partida["dinero"])]
	if stats["heridos"] > 0:
		texto += "\nPersonal herido este turno: %d" % stats["heridos"]
	partida["dia"] += 1
	partida["turnos"] += 1
	partida["resueltas"] += stats["resueltas"]
	partida["estrellas"] += stats["estrellas"]
	partida["valoradas"] += stats["valoradas"]
	_guardar_partida()
	texto += "\n\nObjetivos del turno:" + _texto_objetivos(true)
	if stats["historias"] > 0:
		texto += "\nHistorias: %d (con buen final: %d) · Llamadas relacionadas: %d" % [stats["historias"], stats["historias_buenas"], stats["relacionadas"]]
	tutorial_activo = false
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
	var factor: float = {"tranquila": 1.4, "normal": 1.0, "caotica": 0.7}.get(opciones["dificultad"], 1.0)
	_programar(espera * dificultad * factor, _evento_aleatorio)
	var activos := 0
	for inc in incidentes:
		if inc.activo():
			activos += 1
	var extra_max: int = {"tranquila": -1, "normal": 0, "caotica": 2}.get(opciones["dificultad"], 0)
	if activos >= 3 + mini(partida["dia"] - 1, 3) + extra_max:
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
	if en_portada:
		_animar_portada(delta)
		return
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
	if not pausa_tactica:
		_actualizar_eventos(delta)
		_t_historias -= delta
		if _t_historias <= 0.0:
			_t_historias = 1.0
			_vigilar_historias()
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
	if unidad_a_enviar != null and event.is_action_pressed("cancelar"):
		_cancelar_envio()
		hud.notificar("Envío cancelado.")
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


func _cancelar_envio() -> void:
	unidad_a_enviar = null
	hud.modo_envio = ""
	_marcar_seleccion(null)


func _seleccionar_en_mira() -> void:
	var centro := camara.position
	if unidad_a_enviar != null:
		var v = unidad_a_enviar
		var elegido = null
		var dist := 90.0 / camara.zoom.x
		for inc in incidentes:
			if inc.activo():
				var d: float = inc.position.distance_to(centro)
				if d < dist:
					elegido = inc
					dist = d
		if elegido == null:
			hud.notificar("No hay ninguna emergencia en la mira. Acércate más o pulsa Círculo para cancelar.")
			return
		_cancelar_envio()
		if is_instance_valid(v) and v.disponible():
			_enviar_desde_unidad(v, elegido)
		else:
			hud.notificar("%s ya no está disponible." % v.id_unidad)
		return
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
	var texto := "Vehículo: %s\nEstado: %s\nPersonal: %d (de baja: %d) · Equipo: %d" % [v.nombre_servicio(), v.estado, v.personal, v.heridos.size(), v.equipo.size()]
	if v.incidente != null and is_instance_valid(v.incidente):
		texto += "\nAsignada a: %s" % v.incidente.id_incidente
	if v.en_movimiento and v.en_emergencia:
		texto += "\nLlega en: %s" % _texto_segundos(v.tiempo_restante())
	if v.servicio == "policia" and v.estado == "Patrullando":
		texto += "\nPatrullando su zona"
	var opciones := []
	if v.disponible():
		opciones.append({"texto": "Elegir la emergencia en el mapa (con la mira)", "accion": _empezar_envio_con_mira.bind(v)})
		# Emergencias activas ordenadas por cercanía
		var lista := []
		for inc in incidentes:
			if inc.activo() and inc.evento != "terminado":
				lista.append([v.tiempo_estimado(_destino_de(inc)), inc])
		lista.sort_custom(func(a, b): return a[0] < b[0])
		for par in lista:
			var inc = par[1]
			opciones.append({"texto": "Enviar a %s · %s · llega en %s" % [inc.id_incidente, inc.titulo, _texto_segundos(par[0])],
				"accion": _enviar_desde_unidad.bind(v, inc)})
		if lista.is_empty():
			texto += "\nNo hay emergencias activas a las que enviarla."
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel(v.id_unidad, texto, opciones)


func _destino_de(inc) -> int:
	if inc.vehiculo_seguido != null and is_instance_valid(inc.vehiculo_seguido):
		return inc.vehiculo_seguido.siguiente_nodo
	return inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado


## Envía una unidad elegida primero (con X) a una emergencia.
func _enviar_desde_unidad(v, inc) -> void:
	if inc.tipo == "aviso_trafico":
		if v.servicio == "policia" and inc.estado == "Pendiente":
			_iniciar_persecucion(v, inc)
		else:
			hud.notificar("Para este aviso hay que enviar una patrulla de policía.")
			_cerrar_panel()
		return
	_enviar_unidad(v, inc)


func _empezar_envio_con_mira(v) -> void:
	_cerrar_panel()
	unidad_a_enviar = v
	_marcar_seleccion(v)
	hud.modo_envio = v.id_unidad
	hud.notificar("Mueve la mira hasta una emergencia y pulsa X para enviar %s. Círculo para cancelar." % v.id_unidad, Color("9ff3ff"))


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
	if inc.requeridas.size() > 0:
		texto += "\nUnidades: %s" % inc.texto_requeridas()
	for c in inc.confirmados:
		texto += "\nCONFIRMADO: %s" % c
	for i in inc.informacion:
		texto += "\n· %s" % i
	if inc.cronologia.size() > 0:
		texto += "\nÚltimos hechos:"
		for k in range(maxi(0, inc.cronologia.size() - 4), inc.cronologia.size()):
			texto += "\n  %s  %s" % [inc.cronologia[k][0], inc.cronologia[k][1]]
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
	if en_menu or llamada_sonando or llamada != null:
		return
	# Primero, las llamadas relacionadas con incidentes que ya existen
	while not cola_relacionadas.is_empty():
		var par: Array = cola_relacionadas.pop_front()
		var inc_rel = par[0]
		if is_instance_valid(inc_rel) and inc_rel.activo():
			_preparar_llamada_relacionada(inc_rel, par[1])
			_hacer_sonar()
			return
	if turno_terminando:
		return
	llamada_rel_inc = null
	llamada_historia = {}
	llamada_desenlace = ""
	# Historias (menos frecuentes que las llamadas sencillas)
	var historias := []
	for h in DatosHistorias.HISTORIAS:
		if h["turno"] == turno or h["turno"] == "ambos":
			historias.append(h)
	if not historias.is_empty() and randf() < 0.45:
		_preparar_historia(_elegir_historia(historias))
	else:
		var posibles := []
		for d in DatosLlamadas.LLAMADAS:
			if (d["turno"] == turno or d["turno"] == "ambos") and d["id"] != ultima_llamada_id:
				posibles.append(d)
		if posibles.is_empty():
			return
		llamada_datos = posibles[randi() % posibles.size()]
		ultima_llamada_id = llamada_datos["id"]
		llamada_lugar = _elegir_lugar(llamada_datos["referencias"])
		llamada_perfil = llamada_datos["llamante"]
		llamada_calma = -1
		llamada_vars = {"lugar": llamada_lugar.get("nombre", "la plaza"), "calle": llamada_lugar.get("calle", "una calle del centro")}
	_hacer_sonar()


func _hacer_sonar() -> void:
	llamada_sonando = true
	hora_llamada = _hora(segundos_sim)
	contador_llamadas += 1
	var extra := " · posible relación con %s" % llamada_rel_inc.id_incidente if llamada_rel_inc != null else ""
	hud.mostrar_aviso_llamada("Localidad: Miguelturra · %s%s" % [hora_llamada, extra])
	hud.notificar("Llamada entrante al 112", COLOR_LLAMADA)
	_sonido("llamada")
	_consejo("llamada", "Te están llamando: pulsa X para contestar. Si tardas más de 25 segundos, la persona cuelga.")
	_programar(SEGUNDOS_PARA_COLGAR, _llamada_sin_contestar.bind(contador_llamadas))


func _elegir_lugar(tipos: Array) -> Dictionary:
	var lugares := []
	for l in datos_mapa["lugares"]:
		if l["tipo"] in tipos and String(l.get("calle", "")) != "":
			lugares.append(l)
	if lugares.is_empty():
		lugares = datos_mapa["lugares"]
	return lugares[randi() % lugares.size()]


## Elige la historia que hace más tiempo que no sale.
func _elegir_historia(historias: Array) -> Dictionary:
	var vistas: Array = partida.get("vistas", [])
	var mejor: Dictionary = historias[randi() % historias.size()]
	var mejor_pos := 99999
	for h in historias:
		var pos := vistas.rfind(h["id"])
		if pos < mejor_pos:
			mejor_pos = pos
			mejor = h
	vistas.append(mejor["id"])
	while vistas.size() > 30:
		vistas.pop_front()
	partida["vistas"] = vistas
	return mejor


func _preparar_historia(h: Dictionary) -> void:
	llamada_historia = h
	llamada_datos = h
	ultima_llamada_id = h["id"]
	# Lo que pasa de verdad, en secreto
	var total := 0.0
	for d in h["desenlaces"]:
		total += float(h["desenlaces"][d].get("peso_noche" if turno == "noche" else "peso", h["desenlaces"][d].get("peso", 1)))
	var tirada := randf() * total
	for d in h["desenlaces"]:
		tirada -= float(h["desenlaces"][d].get("peso_noche" if turno == "noche" else "peso", h["desenlaces"][d].get("peso", 1)))
		if tirada <= 0.0:
			llamada_desenlace = d
			break
	if llamada_desenlace == "":
		llamada_desenlace = h["desenlaces"].keys()[0]
	# Quién llama
	var perfiles: Array = h["llamantes"]
	var perfil: Dictionary = perfiles[randi() % perfiles.size()]
	var nombres: Array = perfil["nombres"]
	var personalidades: Array = perfil["personalidades"]
	var pers: Array = personalidades[randi() % personalidades.size()]
	var nombre: String = nombres[randi() % nombres.size()]
	llamada_perfil = "%s · %s, %s" % [nombre, perfil["desc"], pers[0]]
	llamada_calma = clampi(int(perfil["calma"]) + int(pers[1]), 5, 90)
	llamada_lugar = _elegir_lugar(h["referencias"])
	llamada_vars = {"lugar": llamada_lugar.get("nombre", "la plaza"), "calle": llamada_lugar.get("calle", "una calle del centro"), "nombre": nombre}


func _preparar_llamada_relacionada(inc, clave: String) -> void:
	llamada_rel_inc = inc
	llamada_historia = inc.historia
	llamada_desenlace = inc.desenlace
	var d: Dictionary = inc.historia["llamadas"][clave].duplicate()
	d["relacionada"] = true
	llamada_datos = d
	llamada_perfil = d["llamante"]
	llamada_calma = int(d.get("calma", 40))
	llamada_vars = inc.variables


func _llamada_sin_contestar(numero: int) -> void:
	if llamada_sonando and numero == contador_llamadas:
		llamada_sonando = false
		sonidos["llamada"].stop()
		hud.ocultar_aviso_llamada()
		stats["perdidas"] += 1
		_cambiar_dinero(-300)
		hud.notificar("La persona ha colgado: llamada perdida (-300 €).", COLOR_LLAMADA)
		_programar(3.0, _sonar_llamada)


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
	llamada.iniciar(llamada_datos, llamada_vars, llamada_desenlace, llamada_calma)
	hud.abrir_llamada()
	_aplicar_escala()
	_refrescar_llamada()
	_consejo("conversacion", "Elige qué decir con la cruceta. Tranquiliza a la persona y averigua dónde está: cuanto más precisa sea la localización, antes llegará la ayuda.")


func _refrescar_llamada() -> void:
	var rel := " · relacionada con %s" % llamada_rel_inc.id_incidente if llamada_rel_inc != null and is_instance_valid(llamada_rel_inc) else ""
	var cabecera := "Llamada 112-%04d  ·  %s  ·  %s%s" % [contador_llamadas, hora_llamada, llamada_perfil, rel]
	var textos := []
	for o in llamada.opciones_actuales:
		textos.append(o["texto"])
	var datos_vistos: Array = llamada.informacion.duplicate()
	for c in llamada.confirmados:
		datos_vistos.append("CONFIRMADO: " + c)
	hud.actualizar_llamada(cabecera, llamada.texto_actual, llamada.calma, llamada.estado_emocional(),
		Incidente.NOMBRES_PRECISION[llamada.precision], datos_vistos, textos)


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
	# Llamada relacionada: se une al incidente que ya existe
	if llamada_rel_inc != null:
		var inc_rel = llamada_rel_inc
		llamada_rel_inc = null
		if is_instance_valid(inc_rel):
			_unir_llamada(inc_rel, llamada)
		llamada = null
		_programar(2.0, _sonar_llamada)
		return
	if llamada_datos.get("falsa", false):
		stats["falsas"] += 1
		_cambiar_dinero(200)
		hud.notificar("Llamada sin emergencia real: no se crea ningún incidente (+200 €).", Color("9fb3c8"))
		llamada = null
		_programar(2.0, _sonar_llamada)
		return
	var d: Dictionary = llamada_datos["incidente"]
	var nodo := int(llamada_lugar.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.tipo = llamada_datos.get("tipo", "llamada") if not llamada_historia.is_empty() else "llamada"
	inc.fuente = "Llamada al 112 (112-%04d)" % contador_llamadas
	inc.titulo = d["titulo"]
	inc.servicios = d["servicios"].duplicate()
	inc.servicio_necesario = d["principal"]
	inc.urgencia_total = d["urgencia"]
	inc.urgencia_restante = d["urgencia"]
	inc.traslado = d.get("traslado", false)
	inc.tiempo_intervencion = d.get("intervencion", 10.0)
	inc.categoria = d.get("categoria", "medico")
	inc.requeridas = d.get("requeridas", {d["principal"]: 1}).duplicate()
	inc.informacion = llamada.informacion.duplicate()
	inc.confirmados = llamada.confirmados.duplicate()
	# Si hay alguien atrapado en un coche, hacen falta bomberos con equipo técnico
	for dato in inc.informacion:
		if String(dato).to_lower().contains("atrapad"):
			inc.categoria = "atrapado"
			inc.requeridas["bomberos"] = 1
			if not inc.servicios.has("bomberos"):
				inc.servicios.append("bomberos")
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
	inc.variables = llamada_vars
	if not llamada_historia.is_empty():
		inc.historia = llamada_historia
		inc.desenlace = llamada_desenlace
		stats["historias"] += 1
	_aplicar_efectos_historia(inc, llamada.efectos_incidente)
	inc.registrar(hora_llamada, "Llamada de %s" % llamada_perfil)
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	llamada = null
	hud.notificar("Incidente %s creado: %s (%s)" % [inc.id_incidente, inc.titulo, inc.texto_precision()], COLOR_LLAMADA)
	_mostrar_incidente(inc)
	_consejo("incidente", "Elige en la lista qué unidad enviar y pulsa X. Fíjate en los colores del hexágono: blanco ambulancia, azul policía, rojo bomberos.")
	_programar(2.0, _sonar_llamada)


## Une una llamada relacionada al incidente que ya existía (sin duplicarlo).
func _unir_llamada(inc, ll) -> void:
	stats["relacionadas"] += 1
	inc.llamadas_relacionadas += 1
	for i in ll.informacion:
		if not inc.informacion.has(i):
			inc.informacion.append(i)
	for c in ll.confirmados:
		if not inc.confirmados.has(c):
			inc.confirmados.append(c)
	for m in ll.marcas:
		inc.marcas.append(m)
	_aplicar_efectos_historia(inc, ll.efectos_incidente)
	inc.registrar(hora_llamada, "Nueva llamada relacionada: %s" % llamada_perfil)
	hud.notificar("%s: la nueva llamada se ha unido a esta emergencia (no se duplica)." % inc.id_incidente, Color("9ff3ff"))
	_consejo("relacionada", "Varias llamadas pueden ser del mismo suceso. Se unen a la misma emergencia y pueden aportar datos nuevos o contradictorios.")
	if inc.evento == "en_curso" and not inc.requeridas_cumplidas():
		_pedir_refuerzos(inc)


# ================================================================ HISTORIAS (después de colgar)

## Comprueba si toca algún acontecimiento de la historia. Devuelve true si
## queda una decisión pendiente para el jugador.
func _procesar_historia(inc, cuando: String, servicio: String = "") -> bool:
	if inc.historia == null or not inc.activo():
		return false
	for ev in inc.historia.get("eventos", []):
		if inc.eventos_hechos.has(ev["id"]) or ev.get("cuando", "") != cuando:
			continue
		if cuando == "llegada" and ev.get("servicio", "") != servicio:
			continue
		if cuando == "tiempo" and tiempo_juego - inc.tiempo_creacion < float(ev.get("segundos", 0.0)):
			continue
		var ds: Array = ev.get("desenlaces", [])
		if ds.size() > 0 and not ds.has(inc.desenlace):
			continue
		_ejecutar_evento(inc, ev)
		if inc.decision_pendiente:
			return true
	return inc.decision_pendiente


func _ejecutar_evento_por_id(inc, id: String) -> void:
	for ev in inc.historia.get("eventos", []):
		if ev["id"] == id and not inc.eventos_hechos.has(id):
			_ejecutar_evento(inc, ev)
			return


func _ejecutar_evento(inc, ev: Dictionary) -> void:
	inc.eventos_hechos.append(ev["id"])
	var mensaje := ""
	if ev.has("radio_por_desenlace"):
		mensaje = ev["radio_por_desenlace"].get(inc.desenlace, ev["radio_por_desenlace"].get("_", ""))
	elif ev.has("radio"):
		mensaje = ev["radio"]
	if mensaje != "":
		mensaje = mensaje.format(inc.variables)
		var quien = null
		for v in inc.en_lugar:
			if is_instance_valid(v) and (ev.get("servicio", "") == "" or v.servicio == ev.get("servicio", "")):
				quien = v
		if quien == null and inc.en_lugar.size() > 0:
			quien = inc.en_lugar[inc.en_lugar.size() - 1]
		if quien != null and is_instance_valid(quien):
			_radio(quien, mensaje)
		else:
			hud.notificar("%s: %s" % [inc.id_incidente, mensaje], Color("9ff3ff"))
		inc.registrar(_hora(segundos_sim), mensaje)
	_aplicar_efectos_historia(inc, ev.get("efectos", {}))
	if ev.has("efectos_por_desenlace"):
		var e = ev["efectos_por_desenlace"].get(inc.desenlace, ev["efectos_por_desenlace"].get("_", {}))
		_aplicar_efectos_historia(inc, e)
	if ev.has("llamada"):
		cola_relacionadas.append([inc, ev["llamada"]])
		_sonar_llamada()
	if ev.has("decision"):
		_mostrar_decision(inc, ev["decision"])


func _aplicar_efectos_historia(inc, e: Dictionary) -> void:
	if e.is_empty():
		return
	if e.has("requiere"):
		for sv in e["requiere"]:
			inc.requeridas[sv] = maxi(int(inc.requeridas.get(sv, 0)), int(e["requiere"][sv]))
			if not inc.servicios.has(sv):
				inc.servicios.append(sv)
	if e.has("quitar"):
		inc.requeridas.erase(e["quitar"])
	if e.has("principal"):
		inc.servicio_necesario = e["principal"]
		if not inc.requeridas.has(e["principal"]):
			inc.requeridas[e["principal"]] = 1
	if e.has("categoria"):
		inc.categoria = e["categoria"]
	if e.has("traslado"):
		inc.traslado = e["traslado"]
	if e.has("duracion"):
		inc.tiempo_intervencion = maxf(3.0, inc.tiempo_intervencion + float(e["duracion"]))
		inc.duracion = maxf(3.0, inc.duracion + float(e["duracion"]))
	if e.has("intensidad"):
		inc.intensidad = maxi(inc.intensidad, int(e["intensidad"]))
	if e.has("urgencia") and inc.tiempo_llegada < 0.0:
		inc.urgencia_total = minf(inc.urgencia_total, float(e["urgencia"]))
		inc.urgencia_restante = minf(inc.urgencia_restante, float(e["urgencia"]))
	if e.has("confirmado"):
		var c := String(e["confirmado"]).format(inc.variables)
		if not inc.confirmados.has(c):
			inc.confirmados.append(c)
	if e.has("info"):
		var i := String(e["info"]).format(inc.variables)
		if not inc.informacion.has(i):
			inc.informacion.append(i)
	if e.has("marca"):
		inc.marcas.append(e["marca"])


func _mostrar_decision(inc, dec: Dictionary) -> void:
	inc.decision_pendiente = true
	var opciones := []
	for o in dec["opciones"]:
		opciones.append({"texto": o["texto"], "accion": _decision_historia.bind(inc, o)})
	_sonido("alerta")
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, dec["titulo"]], "La unidad espera tus órdenes.\n" + inc.titulo, opciones)
	_consejo("decision", "A veces las unidades te piden órdenes en el lugar. Lo que decidas cambia cómo termina la historia.")


func _decision_historia(inc, opcion: Dictionary) -> void:
	hud.cerrar_panel()
	if not is_instance_valid(inc):
		return
	inc.decision_pendiente = false
	inc.registrar(_hora(segundos_sim), "Orden de la central: %s" % opcion["texto"])
	_aplicar_efectos_historia(inc, opcion.get("efectos", {}))
	if opcion.has("siguiente"):
		_ejecutar_evento_por_id(inc, opcion["siguiente"])
	_continuar_tras_decision(inc)


func _continuar_tras_decision(inc) -> void:
	if inc.decision_pendiente or not inc.activo():
		return
	if inc.evento == "decision" or inc.evento == "":
		inc.evento = ""
		if int(inc.presentes.get(inc.servicio_necesario, 0)) > 0:
			var quien = inc.en_lugar[0] if inc.en_lugar.size() > 0 else null
			for v in inc.en_lugar:
				if is_instance_valid(v) and v.servicio == inc.servicio_necesario:
					quien = v
			if inc.tiempo_llegada < 0.0:
				inc.tiempo_llegada = tiempo_juego
			_iniciar_evento(inc, quien)
		elif not inc.requeridas_cumplidas():
			_pedir_refuerzos(inc)
	elif inc.evento == "en_curso" and not inc.requeridas_cumplidas():
		_pedir_refuerzos(inc)


func _vigilar_historias() -> void:
	for inc in incidentes:
		if inc.historia != null and inc.activo():
			_procesar_historia(inc, "tiempo")


## Elige el final de la historia según lo que ha pasado y lo que se ha decidido.
func _final_historia(inc) -> void:
	for regla in inc.historia.get("finales", []):
		if regla.has("desenlace") and regla["desenlace"] != inc.desenlace:
			continue
		if regla.has("marca") and not inc.marcas.has(regla["marca"]):
			continue
		if regla.has("sin_marca") and inc.marcas.has(regla["sin_marca"]):
			continue
		if regla.has("empeorado") and bool(regla["empeorado"]) != inc.empeorado:
			continue
		if regla.get("sin_empeorar", false) and inc.empeorado:
			continue
		if regla.has("exito") and bool(regla["exito"]) != inc.exito:
			continue
		inc.resultado = String(regla["texto"]).format(inc.variables)
		inc.ajuste_estrellas = int(regla.get("estrellas", 0))
		if regla.has("exito_final"):
			inc.exito = bool(regla["exito_final"])
		if inc.exito:
			stats["historias_buenas"] += 1
		return


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
			v.estado = "Disponible" if v.efectivos() > 0 else "Sin personal"
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
	if not inc.activo() or inc.evento == "terminado":
		_radio(v, "En el lugar. La situación ya está controlada, volvemos.")
		_programar(4.0, _regresar.bind(v))
		return
	if not inc.requeridas.has(v.servicio):
		if inc.historia != null:
			_procesar_historia(inc, "llegada", v.servicio)
		# Unidad de apoyo: ayuda un rato y se va
		match v.servicio:
			"policia":
				_radio(v, "En el lugar. Zona asegurada y tráfico cortado.")
			"ambulancia":
				_radio(v, "En el lugar. Atendemos a los afectados leves.")
			_:
				_radio(v, "En el lugar. Asegurando la zona.")
		_programar(8.0, _regresar.bind(v))
		return
	inc.en_lugar.append(v)
	inc.presentes[v.servicio] = int(inc.presentes.get(v.servicio, 0)) + 1
	if v.servicio == inc.servicio_necesario and inc.tiempo_llegada < 0.0:
		inc.tiempo_llegada = tiempo_juego
	hud.mostrar_lugar(inc)
	_consejo("lugar", "Abajo a la izquierda ves lo que pasa en el lugar. Más personal y mejor equipo hacen que vaya más rápido.")
	# Historia: al llegar puede descubrirse algo o pedirse una decisión
	if inc.historia != null:
		inc.registrar(_hora(segundos_sim), "%s llega al lugar" % v.id_unidad)
		if _procesar_historia(inc, "llegada", v.servicio):
			if inc.evento == "":
				inc.evento = "decision"
			return
		if inc.evento == "" or inc.evento == "decision":
			_continuar_tras_decision(inc)
			return
	match inc.evento:
		"":
			if v.servicio == inc.servicio_necesario:
				_iniciar_evento(inc, v)
			else:
				_radio(v, "En el lugar. Esperamos al resto de unidades.")
		"refuerzos":
			if inc.requeridas_cumplidas():
				inc.evento = "en_curso"
				_radio(v, "¡Refuerzos en el lugar! Continuamos.")
			else:
				_radio(v, "Llegamos de refuerzo. Todavía falta: %s." % inc.texto_requeridas())
		_:
			_radio(v, "Nos unimos a la intervención.")


func _iniciar_evento(inc, v) -> void:
	inc.estado = "En intervención"
	inc.progreso = 0.0
	inc.duracion = inc.tiempo_intervencion + (inc.intensidad * 5.0 if inc.categoria == "fuego" else 0.0)
	match inc.categoria:
		"fuego":
			_radio(v, "En el lugar. Comenzamos la extinción.")
		"pelea":
			_radio(v, "En el lugar. Intentamos separar a los implicados.")
		"robo":
			_radio(v, "En el lugar. Entramos en la vivienda.")
		"busqueda":
			_radio(v, "En el lugar. Empezamos a buscar por la zona.")
		"atrapado":
			_radio(v, "En el lugar. Hay una persona atrapada en el vehículo.")
		_:
			_radio(v, "En el lugar. Atendiendo al paciente.")
	if inc.requeridas_cumplidas():
		inc.evento = "en_curso"
	else:
		_pedir_refuerzos(inc)


func _pedir_refuerzos(inc) -> void:
	inc.evento = "refuerzos"
	inc.t_refuerzos = 40.0
	for sv in inc.requeridas:
		if not inc.servicios.has(sv):
			inc.servicios.append(sv)
	var quien = inc.en_lugar[0] if inc.en_lugar.size() > 0 else null
	var mensaje := "¡Necesitamos refuerzos! Falta: %s." % inc.texto_requeridas()
	if quien != null:
		_radio(quien, mensaje)
	else:
		hud.notificar("%s: %s" % [inc.id_incidente, mensaje], Color("ffd166"))
	_sonido("alerta")
	hud.mostrar_lugar(inc)


## Avanza los mini eventos "En el lugar" que estén en marcha.
func _actualizar_eventos(delta: float) -> void:
	for inc in incidentes:
		if inc.evento == "en_curso":
			inc.progreso += delta / maxf(inc.duracion, 1.0) * _ritmo(inc)
			if not inc.refuerzo_pedido and inc.progreso >= 0.4:
				inc.refuerzo_pedido = true
				_quizas_mas_refuerzos(inc)
			if inc.evento == "en_curso" and inc.progreso >= 1.0:
				_finalizar_evento(inc, true)
		elif inc.evento == "refuerzos":
			inc.t_refuerzos -= delta
			if inc.t_refuerzos <= 0.0:
				_finalizar_evento(inc, false)


## Más personal y mejor equipo = la intervención va más rápida.
func _ritmo(inc) -> float:
	var personas := 0
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.servicio == inc.servicio_necesario:
			personas += v.efectivos()
	var r := clampf(0.6 + personas * 0.15, 0.6, 1.6)
	match inc.categoria:
		"fuego":
			if _alguno_tiene(inc, "extincion"):
				r += 0.3
		"medico":
			if _alguno_tiene(inc, "botiquin"):
				r += 0.2
			if _alguno_tiene(inc, "desfibrilador"):
				r += 0.2
			if _alguno_con_bono(inc, "medico"):
				r += 0.3
		"atrapado":
			if not (_alguno_tiene(inc, "tecnico") or _alguno_con_bono(inc, "rescate")):
				r *= 0.4
	return r


func _alguno_tiene(inc, cosa: String) -> bool:
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.tiene(cosa):
			return true
	return false


func _alguno_con_bono(inc, bono: String) -> bool:
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.bono == bono:
			return true
	return false


## A mitad de la intervención la situación puede complicarse.
func _quizas_mas_refuerzos(inc) -> void:
	var servicio := ""
	var prob := 0.0
	match inc.categoria:
		"pelea", "robo":
			servicio = "policia"
			prob = 0.5 if turno == "noche" else 0.3
			if _alguno_tiene(inc, "antidisturbios"):
				prob -= 0.15
			var agentes := 0
			for v in inc.en_lugar:
				if is_instance_valid(v) and v.servicio == "policia":
					agentes += v.efectivos()
			if agentes >= 4:
				prob = 0.0
		"fuego":
			servicio = "bomberos"
			prob = 0.35 if inc.intensidad >= 2 else 0.1
		"medico":
			servicio = "ambulancia"
			prob = 0.15
	if servicio == "" or randf() >= prob:
		return
	inc.requeridas[servicio] = int(inc.requeridas.get(servicio, 0)) + 1
	_pedir_refuerzos(inc)


func _finalizar_evento(inc, exito: bool) -> void:
	inc.evento = "terminado"
	inc.exito = exito
	inc.estado = "Resuelta"
	inc.resultado = _texto_resultado(inc, exito)
	if inc.historia != null:
		_final_historia(inc)
		inc.registrar(_hora(segundos_sim), "Final: %s" % inc.resultado)
	# Riesgo de que algún agente resulte herido
	if inc.categoria in ["pelea", "robo"]:
		var riesgo := 0.6 if not exito else 0.1
		if _alguno_tiene(inc, "chaleco"):
			riesgo *= 0.4
		if randf() < riesgo:
			for v in inc.en_lugar:
				if is_instance_valid(v) and v.servicio == "policia" and v.efectivos() > 0:
					v.heridos.append(Catalogo.TURNOS_BAJA)
					stats["heridos"] += 1
					inc.resultado += " Un agente de %s ha resultado herido." % v.id_unidad
					break
	var quien = inc.en_lugar[0] if inc.en_lugar.size() > 0 else null
	if quien != null and is_instance_valid(quien):
		_radio(quien, inc.resultado)
	if inc.tipo == "aviso_trafico" and sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.queue_free()
		sospechoso = null
	_informe_incidente(inc)
	for v in inc.en_lugar.duplicate():
		if is_instance_valid(v) and v.incidente == inc:
			if v.servicio == "ambulancia" and inc.traslado:
				_trasladar(v)
			else:
				_regresar(v)
	_programar(5.0, _ocultar_lugar.bind(inc))


func _ocultar_lugar(inc) -> void:
	hud.ocultar_lugar(inc)


func _texto_resultado(inc, exito: bool) -> String:
	match inc.categoria:
		"pelea":
			return "Implicados detenidos y heridos atendidos." if exito else "Los implicados han huido antes de que llegaran los refuerzos."
		"robo":
			return "Ladrones detenidos dentro de la vivienda." if exito else "Los ladrones han escapado."
		"busqueda":
			return "¡Encontrado sano y salvo!" if exito else "La búsqueda se ha complicado demasiado."
		"fuego":
			return "Incendio extinguido." if exito else "El fuego ha causado daños graves."
		"atrapado":
			return "Herido excarcelado y estabilizado." if exito else "La excarcelación se complicó: el herido está grave."
		"control":
			if not exito:
				return "El conductor se ha dado a la fuga."
			if turno == "noche" and randf() < 0.5:
				if _alguno_tiene(inc, "alcoholimetro"):
					return "Positivo en alcoholemia: conductor detenido."
				inc.marcas.append("sin_equipo")
				return "Sin alcoholímetro no se ha podido hacer la prueba de alcoholemia."
			return "Conductor multado por exceso de velocidad."
	return "Paciente estabilizado." if exito else "El paciente está grave por la espera."


func _trasladar(v) -> void:
	v.fase = "traslado"
	v.estado = "Traslado al hospital"
	v.en_emergencia = true
	_radio(v, "Trasladamos al paciente al Hospital General de Ciudad Real.")
	v.ir_a(nodo_salida)


func _regresar(v) -> void:
	v.en_emergencia = false
	v.incidente = null
	if v.efectivos() == 0:
		v.fase = "regreso"
		v.estado = "Sin personal"
		v.ir_a(v.nodo_base)
		return
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
	estrellas += inc.ajuste_estrellas
	if not inc.exito:
		estrellas -= 2
		consecuencias.append(inc.resultado)
	if inc.marcas.has("sin_equipo"):
		estrellas -= 1
		consecuencias.append("Faltaba el equipo adecuado.")
	if inc.categoria == "atrapado" and not (_alguno_tiene(inc, "tecnico") or _alguno_con_bono(inc, "rescate")):
		consecuencias.append("Los bomberos no llevaban equipo técnico de excarcelación.")
	if inc.categoria == "fuego" and inc.intensidad > 1:
		estrellas -= inc.intensidad - 1
		consecuencias.append("El fuego se extendió antes de que llegaran los bomberos (nivel %d)." % inc.intensidad)
	estrellas = clampi(estrellas, 1, 5)
	_sumar_estadisticas(estrellas, t_llegada)
	var pago := 600 + estrellas * 400
	_cambiar_dinero(pago)
	var precision_envio: int = inc.precision_al_enviar if inc.precision_al_enviar >= 0 else inc.precision
	var texto := "Resultado: %s\nTiempo de llegada: %s\nLocalización al enviar: %s\nUnidades: %s\n\nValoración: %d de 5 · Cobrado: +%s" % [
		inc.resultado, _texto_segundos(t_llegada), Incidente.NOMBRES_PRECISION[clampi(precision_envio, 0, 3)], inc.texto_requeridas(), estrellas, Hud.formato_euros(pago)]
	if consecuencias.size() > 0:
		texto += "\n\nConsecuencias:"
		for c in consecuencias:
			texto += "\n· " + c
	else:
		texto += "\n\n¡Intervención impecable!"
	if inc.llamadas_relacionadas > 0:
		texto += "\nLlamadas relacionadas: %d" % inc.llamadas_relacionadas
	hud.mostrar_panel("INFORME · %s · %s" % [inc.id_incidente, inc.titulo], texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])
	_consejo("informe", "Cada emergencia resuelta te da dinero según la nota. Con él podrás comprar vehículos y equipo antes del siguiente turno.")


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
		["Vehículo averiado cortando la calzada", ["policia"], "policia", 90.0, "control"],
		["Accidente leve sin heridos", ["policia"], "policia", 80.0, "control"],
		["Persona mayor desorientada", ["policia", "ambulancia"], "policia", 80.0, "busqueda"],
	]
	var opciones_noche := [
		["Pelea entre dos personas", ["policia"], "policia", 70.0, "pelea"],
		["Persona dormida en un portal, muy bebida", ["policia", "ambulancia"], "ambulancia", 85.0, "medico"],
		["Coche sospechoso merodeando", ["policia"], "policia", 90.0, "robo"],
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
	inc.categoria = o[4]
	inc.requeridas = {o[2]: 1}
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
	inc.categoria = "fuego"
	inc.requeridas = {"bomberos": 1}
	inc.tiempo_intervencion = 12.0
	if randf() < 0.5:
		inc.servicios = ["bomberos", "ambulancia"]
		inc.requeridas["ambulancia"] = 1
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
	if inc == null or not is_instance_valid(inc) or not inc.activo():
		_programar(4.0, _retirar_sospechoso.bind(patrulla, objetivo))
		return
	_radio(patrulla, "Vehículo detenido. Procedemos al control.")
	inc.tiempo_llegada = tiempo_juego
	inc.precision_al_enviar = 3
	inc.categoria = "control"
	inc.requeridas = {"policia": 1}
	inc.presentes = {"policia": 1}
	inc.en_lugar = [patrulla]
	inc.estado = "En intervención"
	inc.duracion = 8.0
	inc.progreso = 0.0
	inc.refuerzo_pedido = true
	inc.evento = "en_curso"
	inc.vehiculo_seguido = null
	inc.pos_exacta = objetivo.position
	inc.position = objetivo.position
	hud.mostrar_lugar(inc)


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
	texto += "\n\nObjetivos del turno:" + _texto_objetivos(false)
	hud.mostrar_panel("PAUSA", texto, [
		{"texto": "Continuar", "accion": _alternar_pausa},
		{"texto": "Abandonar el turno y volver a la portada (no se guarda)", "accion": _confirmar_abandonar},
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
	var m := event as InputEventJoypadMotion
	# Pasos 3 y 4: la cruceta puede llegar como botón o como eje
	if paso_calibracion >= 3:
		var dato := {}
		if b != null and b.pressed and b.button_index != boton_x and b.button_index != boton_circulo:
			dato = {"tipo": "boton", "indice": b.button_index}
		elif m != null and absf(m.axis_value) > 0.7 and m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
			dato = {"tipo": "eje", "indice": m.axis, "valor": signf(m.axis_value)}
		elif tecla != null and tecla.pressed and not tecla.echo:
			dato = {"tipo": "tecla", "indice": tecla.keycode}
		if dato.is_empty():
			return
		if paso_calibracion == 3:
			nav_abajo = dato
			paso_calibracion = 4
			hud.mostrar_calibracion("Abajo guardado\n\nAhora pulsa ARRIBA en la cruceta")
		elif dato != nav_abajo:
			Controles.guardar_navegacion(nav_abajo, dato)
			paso_calibracion = 0
			hud.ocultar_calibracion()
			hud.notificar("Mando configurado. Ya puedes moverte por los menús con la cruceta.", Color("8fd3a0"))
		return
	if b == null or not b.pressed:
		return
	if paso_calibracion == 1:
		boton_x = b.button_index
		paso_calibracion = 2
		hud.mostrar_calibracion("X guardado (botón %d)\n\nAhora pulsa el botón CÍRCULO" % boton_x)
	elif paso_calibracion == 2 and b.button_index != boton_x:
		boton_circulo = b.button_index
		Controles.guardar_configuracion(boton_x, boton_circulo)
		paso_calibracion = 3
		hud.mostrar_calibracion("Círculo guardado (botón %d)\n\nAhora pulsa ABAJO en la cruceta" % boton_circulo)


func _salir() -> void:
	get_tree().quit()


# ================================================================ PORTADA Y MENÚ PRINCIPAL

func _preparar_decoracion() -> void:
	# Rutas de luz entre puntos al azar del centro del pueblo
	var centro := _pos_lugar("Plaza de España", tamano_mapa / 2.0)
	rutas_decor.clear()
	for i in 6:
		var a := red.nodo_mas_cercano(centro + Vector2(randf_range(-900, 900), randf_range(-700, 700)))
		var b := red.nodo_mas_cercano(centro + Vector2(randf_range(-900, 900), randf_range(-700, 700)))
		var camino := red.ruta(a, b)
		if camino.size() < 3:
			continue
		var pts := PackedVector2Array()
		for n in camino:
			pts.append(red.pos(n))
		rutas_decor.append({"puntos": pts, "largo": red.longitud_ruta(camino), "fase": randf()})


func _mostrar_portada() -> void:
	en_portada = true
	en_menu = true
	get_tree().paused = true
	Engine.time_scale = 1.0
	hud.cerrar_panel()
	if hud.llamada_abierta():
		hud.cerrar_llamada()
	hud.ocultar_aviso_llamada()
	hud.mostrar_portada(true)
	decoracion.visible = true
	modulador.color = Color(0.55, 0.62, 0.95)
	camara.zoom = Vector2(0.55, 0.55)
	_sonido("radio")
	_menu_principal()


func _menu_principal() -> void:
	var hay_partida := FileAccess.file_exists(RUTA_PARTIDA)
	var txt_continuar := "Continuar partida"
	if hay_partida:
		txt_continuar = "Continuar partida · Día %d · %s" % [partida["dia"], Hud.formato_euros(partida["dinero"])]
	hud.mostrar_panel("", "", [
		{"texto": txt_continuar, "accion": _mostrar_menu_turno, "activo": hay_partida},
		{"texto": "Nueva partida", "accion": _confirmar_nueva},
		{"texto": "Cómo se juega (tutorial)", "accion": _mostrar_tutorial.bind(0)},
		{"texto": "Opciones", "accion": _mostrar_opciones},
		{"texto": "Créditos", "accion": _mostrar_creditos},
		{"texto": "Salir", "accion": _salir},
	], true, 340.0, 520.0)


func _animar_portada(delta: float) -> void:
	_t_portada += delta
	var centro := _pos_lugar("Plaza de España", tamano_mapa / 2.0)
	camara.position = centro + Vector2(cos(_t_portada * 0.05) * 450.0, sin(_t_portada * 0.07) * 300.0)
	decoracion.queue_redraw()


func _dibujar_decoracion() -> void:
	if not en_portada:
		return
	for r in rutas_decor:
		var pts: PackedVector2Array = r["puntos"]
		decoracion.draw_polyline(pts, Color(0.7, 0.9, 1.0, 0.25), 6.0)
		# Luz que recorre la ruta
		var avance := fmod(_t_portada * 0.12 + float(r["fase"]), 1.0) * float(r["largo"])
		for k in range(1, pts.size()):
			var tramo := pts[k - 1].distance_to(pts[k])
			if avance <= tramo:
				var p := pts[k - 1].lerp(pts[k], avance / maxf(tramo, 0.01))
				decoracion.draw_circle(p, 26.0, Color(0.6, 0.85, 1.0, 0.25))
				decoracion.draw_circle(p, 10.0, Color.WHITE)
				break
			avance -= tramo
	# Hexágonos de emergencias que aparecen y desaparecen
	var colores := [Color("f2f6fc"), Color("3b8eea"), Color("d64545")]
	for i in rutas_decor.size():
		var pts: PackedVector2Array = rutas_decor[i]["puntos"]
		var p := pts[pts.size() - 1]
		var brillo := 0.5 + 0.5 * sin(_t_portada * 1.5 + i * 1.3)
		var hex := PackedVector2Array()
		for j in 6:
			var a := deg_to_rad(60.0 * j - 90.0)
			hex.append(p + Vector2(0, -50) + Vector2(cos(a), sin(a)) * 30.0)
		decoracion.draw_colored_polygon(hex, Color(colores[i % 3], brillo))
		decoracion.draw_arc(p, 14.0 + brillo * 20.0, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 1.0 - brillo), 3.0)


func _confirmar_nueva() -> void:
	if not FileAccess.file_exists(RUTA_PARTIDA):
		_nueva_partida()
		return
	hud.mostrar_panel("NUEVA PARTIDA", "Se borrará la partida guardada (día %d, %s). ¿Seguro?" % [partida["dia"], Hud.formato_euros(partida["dinero"])], [
		{"texto": "No, volver", "accion": _menu_principal},
		{"texto": "Sí, empezar de cero", "accion": _nueva_partida},
	], true, 340.0, 560.0)


func _nueva_partida() -> void:
	partida = _partida_nueva()
	hud.set_dinero(partida["dinero"])
	_guardar_partida()
	_mostrar_menu_turno()


func _confirmar_abandonar() -> void:
	hud.mostrar_panel("ABANDONAR EL TURNO", "Se perderá todo lo que ha pasado en este turno. La partida volverá a como estaba al empezarlo.", [
		{"texto": "No, seguir jugando", "accion": _mostrar_menu_pausa},
		{"texto": "Sí, volver a la portada", "accion": _abandonar_turno},
	])


func _abandonar_turno() -> void:
	turno_id += 1
	pausa_tactica = false
	hud.pausa_tactica = false
	hud.set_pausa(false)
	for inc in incidentes:
		inc.queue_free()
	incidentes.clear()
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.queue_free()
	sospechoso = null
	llamada = null
	llamada_sonando = false
	tutorial_activo = false
	_cargar_partida()   # recupera la partida guardada antes del turno
	_mostrar_portada()


# ================================================================ OPCIONES

func _cargar_opciones() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_OPCIONES) == OK:
		for k in opciones:
			opciones[k] = cfg.get_value("opciones", k, opciones[k])
	_aplicar_opciones()


func _guardar_opciones() -> void:
	var cfg := ConfigFile.new()
	for k in opciones:
		cfg.set_value("opciones", k, opciones[k])
	cfg.save(RUTA_OPCIONES)


func _aplicar_opciones() -> void:
	var vol: float = opciones["volumen"]
	AudioServer.set_bus_mute(0, vol <= 0.01)
	if vol > 0.01:
		AudioServer.set_bus_volume_db(0, linear_to_db(vol))
	hud.set_texto_grande(opciones["texto_grande"])


func _mostrar_opciones() -> void:
	var nombres_dif := {"tranquila": "Tranquila (menos emergencias)", "normal": "Normal", "caotica": "Caótica (más y a la vez)"}
	hud.mostrar_panel("OPCIONES", "", [
		{"texto": "Volumen: %d %%" % int(round(float(opciones["volumen"]) * 100.0)), "accion": _cambiar_volumen},
		{"texto": "Tamaño del texto: %s" % ("Grande" if opciones["texto_grande"] else "Normal"), "accion": _cambiar_texto},
		{"texto": "Dificultad: %s" % nombres_dif.get(opciones["dificultad"], "Normal"), "accion": _cambiar_dificultad},
		{"texto": "Configurar botones del mando", "accion": _calibrar_desde_portada},
		{"texto": "Volver", "accion": _menu_principal},
	], true, 340.0, 560.0)


func _cambiar_volumen() -> void:
	var pasos := [1.0, 0.7, 0.4, 0.0]
	var i := pasos.find(opciones["volumen"])
	opciones["volumen"] = pasos[(i + 1) % pasos.size()]
	_aplicar_opciones()
	_guardar_opciones()
	_sonido("click")
	_mostrar_opciones()


func _cambiar_texto() -> void:
	opciones["texto_grande"] = not opciones["texto_grande"]
	_aplicar_opciones()
	_guardar_opciones()
	_mostrar_opciones()


func _cambiar_dificultad() -> void:
	var orden := ["tranquila", "normal", "caotica"]
	opciones["dificultad"] = orden[(orden.find(opciones["dificultad"]) + 1) % orden.size()]
	_guardar_opciones()
	_mostrar_opciones()


func _calibrar_desde_portada() -> void:
	hud.cerrar_panel()
	_empezar_calibracion()
	_programar_menu_tras_calibrar()


func _programar_menu_tras_calibrar() -> void:
	# Cuando termine la configuración, vuelve a las opciones
	var t := get_tree().create_timer(0.5, true)
	t.timeout.connect(_esperar_calibracion)


func _esperar_calibracion() -> void:
	if hud.calibrando():
		_programar_menu_tras_calibrar()
	elif en_portada:
		_mostrar_opciones()


func _mostrar_creditos() -> void:
	hud.mostrar_panel("CRÉDITOS", "CENTRAL 112 · MIGUELTURRA\nJuego hecho en casa para jugar en el Fire TV.\n\nDiseño y programación: con la ayuda de Claude (Anthropic)\nMapa: © colaboradores de OpenStreetMap (licencia ODbL)\nMotor: Godot Engine\n\nTodas las personas, unidades y bases del juego son inventadas.", [
		{"texto": "Volver", "accion": _menu_principal},
	], true, 300.0, 640.0)


# ================================================================ TUTORIAL

const PAGINAS_TUTORIAL := [
	["1 · TU PAPEL", "Eres operadora de la central 112 de Miguelturra. Atiendes llamadas, vigilas el mapa y envías ambulancias, policía y bomberos.\n\nCada turno dura 15 minutos reales. Al final verás un resumen con tu nota y el dinero ganado."],
	["2 · EL MAPA", "Joystick izquierdo: mover el mapa. L2/R2: zoom.\nLos hexágonos son emergencias: blanco = ambulancia, azul = policía, rojo = bomberos (si necesita varios servicios, sale con varios colores).\nEl anillo que se vacía es el tiempo antes de que empeore."],
	["3 · LAS LLAMADAS", "Cuando suene, pulsa X para contestar. Mientras hablas, el tiempo va más lento.\nTranquiliza a la persona, averigua qué pasa y dónde está, y dale buenas instrucciones. Lo que preguntes cambia cómo acaba la historia."],
	["4 · ENVIAR UNIDADES", "Abre una emergencia (mira + X o Triángulo) y elige qué unidad enviar. También puedes elegir primero la unidad con X y luego la emergencia.\nCuadrado: lista de unidades. L1/R1: velocidad del tiempo. L1 en x1: pausa táctica."],
	["5 · EN EL LUGAR", "Al llegar, abajo a la izquierda ves lo que pasa. A veces las unidades piden refuerzos (+1 en el hexágono) o te piden órdenes.\nAntes de cada turno, en EQUIPOS puedes comprar vehículos, equipo y contratar personal."],
]


func _mostrar_tutorial(pagina: int) -> void:
	var p: Array = PAGINAS_TUTORIAL[pagina]
	var botones := []
	if pagina < PAGINAS_TUTORIAL.size() - 1:
		botones.append({"texto": "Siguiente", "accion": _mostrar_tutorial.bind(pagina + 1)})
	else:
		botones.append({"texto": "Empezar un turno de práctica con consejos", "accion": _empezar_tutorial})
	if pagina > 0:
		botones.append({"texto": "Anterior", "accion": _mostrar_tutorial.bind(pagina - 1)})
	botones.append({"texto": "Volver al menú", "accion": _menu_principal})
	hud.mostrar_panel("CÓMO SE JUEGA · " + p[0], p[1], botones, true, 300.0, 700.0)


func _empezar_tutorial() -> void:
	tutorial_activo = true
	consejos_vistos.clear()
	en_portada = false
	hud.mostrar_portada(false)
	decoracion.visible = false
	turno_elegido = "dia"
	_empezar_turno("dia")
	_consejo("inicio", "Mueve el mapa con el joystick izquierdo y acerca o aleja con L2/R2. Enseguida entrará tu primera llamada.")


## Muestra un consejo una sola vez durante el turno de práctica.
func _consejo(clave: String, texto: String) -> void:
	if not tutorial_activo or consejos_vistos.has(clave):
		return
	consejos_vistos.append(clave)
	hud.mostrar_consejo(texto)


# ================================================================ OBJETIVOS DEL TURNO

const OBJETIVOS := [
	{"id": "sin_perdidas", "texto": "No perder ninguna llamada", "premio": 1500},
	{"id": "resolver4", "texto": "Resolver 4 emergencias o más", "premio": 1000},
	{"id": "media4", "texto": "Nota media de 4 o más", "premio": 2000},
	{"id": "sin_empeorar", "texto": "Que ninguna emergencia empeore", "premio": 1500},
	{"id": "sin_heridos", "texto": "Ningún agente herido", "premio": 1000},
	{"id": "relacionadas", "texto": "Atender 1 llamada relacionada", "premio": 800},
	{"id": "historia_buena", "texto": "Terminar una historia con buen final", "premio": 1500},
]


func _elegir_objetivos() -> void:
	var lista: Array = OBJETIVOS.duplicate()
	lista.shuffle()
	objetivos = lista.slice(0, 3)
	var nombres := []
	for o in objetivos:
		nombres.append(o["texto"])
	hud.notificar("Objetivos del turno: " + " · ".join(PackedStringArray(nombres)), Color("ffd166"))


func _objetivo_cumplido(id: String) -> bool:
	match id:
		"sin_perdidas":
			return stats["perdidas"] == 0
		"resolver4":
			return stats["resueltas"] >= 4
		"media4":
			return stats["valoradas"] > 0 and float(stats["estrellas"]) / stats["valoradas"] >= 4.0
		"sin_empeorar":
			return stats["empeoradas"] == 0 and stats["resueltas"] > 0
		"sin_heridos":
			return stats["heridos"] == 0 and stats["resueltas"] > 0
		"relacionadas":
			return stats["relacionadas"] >= 1
		"historia_buena":
			return stats["historias_buenas"] >= 1
	return false


## final = true: cobra los premios de los objetivos cumplidos.
func _texto_objetivos(final: bool) -> String:
	var texto := ""
	for o in objetivos:
		var ok := _objetivo_cumplido(o["id"])
		var marca := "[CUMPLIDO]" if ok else "[pendiente]"
		if final:
			marca = "[CUMPLIDO +%s]" % Hud.formato_euros(o["premio"]) if ok else "[no cumplido]"
			if ok:
				partida["dinero"] = int(partida["dinero"]) + int(o["premio"])
				hud.set_dinero(partida["dinero"])
		texto += "\n· %s %s" % [o["texto"], marca]
	return texto
