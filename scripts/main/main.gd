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
const LlamadasExtra = preload("res://data/dialogues/llamadas_extra.gd")
const Preguntas = preload("res://data/dialogues/preguntas.gd")
const Catalogo = preload("res://data/gestion/catalogo.gd")
const DatosHistorias = preload("res://data/historias/historias.gd")
const HistoriasExtra = preload("res://data/historias/historias_extra.gd")
const HistoriasCrisis = preload("res://data/historias/historias_crisis.gd")
const Efectos = preload("res://scripts/effects/efectos.gd")
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
const DURACION_TRAMITES := 34.0
const TOPE_PRIMERA_RESPUESTA := 0.3   # la primera respuesta avanza como mucho hasta aquí
## Vehículos sanitarios que atienden pero no trasladan al hospital
const NO_TRASLADAN := ["vir", "moto_sanitaria", "pma"]
const COLOR_RADIO_AMBULANCIA := Color("f4d35e")
const COLOR_RADIO_POLICIA := Color("6fb1ff")
const COLOR_RADIO_BOMBEROS := Color("ff8a65")
const COLOR_SISTEMA := Color("ffa630")
const COLOR_LLAMADA := Color("ff6b6b")
const NOMBRES_SERVICIO := {"ambulancia": "Ambulancia", "policia": "Policía", "bomberos": "Bomberos", "proteccion_civil": "Protección Civil",
	"geo": "GEO", "ume": "UME", "judicial": "Policía Judicial"}
const COLOR_RADIO_PC := Color("ffb15c")
## Lo que hace especial a cada vehículo (se ve en la tienda)
const DESC_BONO := {
	"rapida": "Muy rápida, pero no puede llevar detenidos.",
	"detenidos": "Lleva hasta 4 detenidos al calabozo.",
	"medico": "Con médico: estabiliza antes a los pacientes graves y lleva 2 heridos a la vez.",
	"altura": "Escalera para rescates en altura.",
	"rescate": "Excarcelación y rescates complicados.",
	"apoyo": "Se queda ayudando en cualquier emergencia: todo va más rápido.",
	"camuflado": "Sin colores ni sirenas: los sospechosos no huyen; caza excesos de velocidad patrullando y ayuda en las investigaciones.",
	"canino": "Perro detector: encuentra droga en los controles y busca más rápido a personas perdidas.",
	"vir": "Coche médico, el más rápido: estabiliza y evita que empeoren, pero no traslada al hospital.",
	"moto_sanitaria": "Llega antes que nadie entre la gente de las fiestas; solo primeros auxilios, no traslada.",
	"pma": "Carpa con camillas: atiende a varios heridos a la vez en grandes emergencias; no traslada.",
	"blindado": "Blindado con 6 agentes: personas armadas, atrincherados y rehenes.",
	"antidisturbios_geo": "8 agentes con escudos: disuelven peleas multitudinarias y bandas.",
	"mando": "Se queda en la zona y coordina: todas las unidades del aviso trabajan más rápido.",
	"tedax": "Artificieros con robot: imprescindibles ante paquetes sospechosos y bombas.",
	"nrbq": "Fugas químicas, nubes tóxicas y mercancías peligrosas.",
	"forestal": "Autobomba pesada para incendios forestales.",
	"derrumbes": "Perros y cámaras para buscar víctimas entre escombros.",
	"anfibio": "Rescate en riadas e inundaciones, con bombas de achique.",
	"detectives": "Investigan las denuncias paso a paso hasta detener al culpable.",
	"heli_sanitario": "Vuela en línea recta: ideal para avisos en el campo, el monte o la pedanía. Traslada al hospital en un momento. 350 € de combustible por salida.",
	"heli_policia": "Vuela en línea recta: busca personas y sospechosos desde el aire y guía a las patrullas (no detiene). 350 € de combustible por salida.",
}
const Pueblo = preload("res://data/pueblo/pueblo.gd")
const Casos = preload("res://data/pueblo/casos.gd")
## Meteorología: nombre, color en la barra y velocidad de las unidades.
const CLIMAS := {
	"despejado": {"nombre": "Despejado", "color": Color("9fd3ff"), "velocidad": 1.0},
	"lluvia": {"nombre": "Lluvia", "color": Color("7fb2ff"), "velocidad": 0.85},
	"niebla": {"nombre": "Niebla", "color": Color("c8d0dc"), "velocidad": 0.8},
	"tormenta": {"nombre": "Tormenta", "color": Color("b48cff"), "velocidad": 0.75},
	"calor": {"nombre": "Ola de calor", "color": Color("ffb347"), "velocidad": 1.0},
}

var red := RedViaria.new()
var datos_mapa: Dictionary = {}
var tamano_mapa := Vector2(3000, 3000)
var nodo_salida := 0
var mundo: Node2D
var mapa
var camara: Camera2D
var capa_rutas: Node2D
var modulador: CanvasModulate
var efectos = null
var clima := "despejado"
var tween_camara: Tween
var _t_fps_bajo := 0.0
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
var todas_llamadas: Array = []       # las de siempre y las nuevas (0.97)
var todas_historias: Array = []
var llamadas_turno: Array = []       # ids que ya han sonado este turno (no se repiten)
var subidas_nivel: Array = []        # ascensos del personal en este turno (1.1)
var llamada_linea := "movil"         # movil (AML, zona) o fijo (dirección del abonado)
var llamada_desvio := Vector2.ZERO   # dónde cae el centro de la zona aproximada
var llamada_coletillas: Array = []
var _t_pitido := 0.0
var localizando := false
var cola_relacionadas: Array = []   # [incidente, clave de llamada]

# Portada, opciones, tutorial y objetivos
var en_portada := false
var decoracion: Node2D
var rutas_decor: Array = []
var _t_portada := 0.0
const RIESGO_MUERTE := {"tranquila": 0.12, "normal": 0.3, "caotica": 0.45}
const PENALIZA_SIN_REFUERZO := {"tranquila": 0.8, "normal": 0.65, "caotica": 0.5}
const ESPERA_AMBULANCIA := {"tranquila": 140.0, "normal": 95.0, "caotica": 70.0}
var opciones := {"volumen": 1.0, "texto_grande": false, "dificultad": "normal", "texto_animado": true, "calidad": "alta", "vibracion": true, "meteo": true}
var tutorial_activo := false
var consejos_vistos: Array = []
var objetivos: Array = []
var _t_historias := 0.0

# Mando
var paso_calibracion := 0
var boton_x := -1
var boton_circulo := -1
var cruceta_temp: Dictionary = {}
var debug_activo := false
var ultimo_evento := "(pulsa cualquier botón)"
var _t_barra := 0.0
var unidad_a_enviar = null   # unidad elegida con X que espera destino en el mapa
var _t_trafico := 0.0
# --- Vida del pueblo (0.9) y sucesos (0.95)
var evento_hoy := ""          # fiesta o día especial activo en este turno
var pos_evento := Vector2.ZERO
var obras: Array = []         # [nodo_a, nodo_b, nombre de la calle]
var denuncias: Array = []          # denuncias pendientes en la comisaría
var pausa_comisaria := false
var externos_usados := {"guardia_civil": 0, "ume": 0}
var contador_externos := 0
var capa_mapa := ""           # "", "calor", "historial"
var etapas_programadas: Array = []


# ================================================================ INICIO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	datos_mapa = _cargar_mapa()
	red.cargar(datos_mapa)
	tamano_mapa = Vector2(float(datos_mapa["tamano"][0]), float(datos_mapa["tamano"][1]))
	nodo_salida = int(datos_mapa.get("salida", red.nodo_mas_al_oeste()))
	_anadir_lugares_virtuales()
	todas_llamadas = DatosLlamadas.LLAMADAS.duplicate()
	todas_llamadas.append_array(LlamadasExtra.construir())
	todas_historias = DatosHistorias.HISTORIAS.duplicate()
	todas_historias.append_array(HistoriasExtra.HISTORIAS)
	todas_historias.append_array(HistoriasCrisis.HISTORIAS)

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
	var n_comisaria := _nodo_calle("Calle Lentejuela", n_pol1)
	var n_pc := _nodo_lugar("Pabellón Municipal")
	bases = {"ambulancia1": n_amb1, "ambulancia2": n_amb2, "policia": n_comisaria, "policia_zona1": n_pol1,
		"policia_zona2": n_pol2, "bomberos": n_bom, "proteccion_civil": n_pc}
	mapa.anadir_base("Base ambulancias 1", red.pos(n_amb1) + Vector2(0, -40), COLOR_RADIO_AMBULANCIA, "A")
	mapa.anadir_base("Base ambulancias 2", red.pos(n_amb2) + Vector2(0, -40), COLOR_RADIO_AMBULANCIA, "A")
	mapa.anadir_base("Comisaría Policía Local (C/ Lentejuela, 7)", red.pos(n_comisaria) + Vector2(-40, 30), Color("4d96ff"), "P")
	mapa.anadir_base("Protección Civil", red.pos(n_pc) + Vector2(40, 30), Color("ff8c1a"), "C")
	mapa.anadir_base("Parque de bomberos", red.pos(n_bom) + Vector2(40, -40), Color("e74c3c"), "B")
	# Bases del GEO y de la UME: a las afueras del pueblo (no patrullan)
	var n_geo := _nodo_extremo(Vector2(0.7, 0.7))
	var n_ume := _nodo_extremo(Vector2(-0.4, 0.9))
	if n_ume == n_geo:
		n_ume = _nodo_extremo(Vector2(0.0, 1.0))
	# Helipuerto (0.99), a las afueras junto a la carretera de Ciudad Real
	var n_heli := n_geo
	for l in datos_mapa.get("lugares", []):
		if l.get("tipo", "") == "helipuerto":
			n_heli = int(l["nodo"])
	bases["helipuerto"] = n_heli
	bases["geo"] = n_geo
	bases["ume"] = n_ume
	mapa.anadir_base("Base de la Unidad de Intervención Especial (GEO)", red.pos(n_geo) + Vector2(40, 30), COLOR_SERVICIO["geo"], "E")
	mapa.anadir_base("Base de la UME", red.pos(n_ume) + Vector2(-40, 30), COLOR_SERVICIO["ume"], "U")

	_crear_sonidos()
	efectos = Efectos.new()
	add_child(efectos)
	efectos.configurar(datos_mapa)
	efectos.vehiculos = vehiculos
	efectos.incidentes = incidentes
	hud = Hud.new()
	add_child(hud)
	hud.llamada_contestada.connect(_contestar_llamada)
	hud.opcion_llamada.connect(_elegir_opcion)

	_cargar_partida()
	_cargar_opciones()
	_preparar_decoracion()
	_mostrar_portada()
	hud.mostrar_carga(Pueblo.CURIOSIDADES[randi() % Pueblo.CURIOSIDADES.size()])
	get_tree().create_timer(3.5, true).timeout.connect(_fin_carga)


func _fin_carga() -> void:
	hud.ocultar_carga()
	if not Controles.cargar_configuracion() and Input.get_connected_joypads().size() > 0:
		_empezar_calibracion()


func _cargar_mapa() -> Dictionary:
	var texto := FileAccess.get_file_as_string(RUTA_MAPA)
	var d = JSON.parse_string(texto)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("No se ha podido leer el mapa: " + RUTA_MAPA)
		return {}
	return d


## El polígono industrial y el Monte de San Isidro no son "lugares" de OpenStreetMap:
## se añaden aquí para que las historias y las fiestas puedan ocurrir allí.
## Nodo de calle más alejado en una dirección (para las bases de fuera del pueblo).
func _nodo_extremo(dir: Vector2) -> int:
	var mejor := 0
	var valor := -INF
	for i in int(datos_mapa.get("nodos_pueblo", red.astar.get_point_count())):
		if red.grado(i) < 2:
			continue
		var v := red.pos(i).dot(dir.normalized())
		if v > valor:
			valor = v
			mejor = i
	return mejor


func _anadir_lugares_virtuales() -> void:
	var n := 0
	var zonas_pueblo := int(datos_mapa.get("zonas_pueblo", 99999))
	var iz := -1
	for z in datos_mapa.get("zonas", []):
		iz += 1
		if z.get("tipo", "") != "industrial" or iz >= zonas_pueblo:
			continue
		var pts: Array = z["puntos"]
		var c := Vector2.ZERO
		for i in pts.size() / 2:
			c += Vector2(float(pts[i * 2]), float(pts[i * 2 + 1]))
		c /= maxf(1.0, pts.size() / 2.0)
		var nodo := red.nodo_mas_cercano(c)
		n += 1
		datos_mapa["lugares"].append({"nombre": "el polígono industrial" if n == 1 else "el polígono industrial (zona %d)" % n,
			"tipo": "industrial", "x": c.x, "y": c.y, "calle": red.calle_de_nodo(nodo), "nodo": nodo})
	# Monte de San Isidro: ya viene en el mapa ampliado (0.99)
	for l in datos_mapa["lugares"]:
		if l.get("tipo", "") == "monte":
			return
	var mejor := 0
	var puntos := -INF
	for i in red.astar.get_point_count():
		var q := red.pos(i)
		var valor := q.x - q.y * 1.1
		if valor > puntos:
			puntos = valor
			mejor = i
	var pm := red.pos(mejor)
	datos_mapa["lugares"].append({"nombre": "el Monte de San Isidro", "tipo": "monte", "x": pm.x, "y": pm.y,
		"calle": red.calle_de_nodo(mejor), "nodo": mejor})


## Nodo en mitad de una calle por su nombre (para la comisaría de la C/ Lentejuela).
func _nodo_calle(nombre: String, por_defecto: int) -> int:
	var lista := []
	for k in red.calle_nodo:
		if red.calle_nodo[k] == nombre:
			lista.append(int(k))
	if lista.is_empty():
		return por_defecto
	lista.sort()
	return lista[lista.size() / 2]


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


const COLOR_SERVICIO := {"ambulancia": Color("f4d35e"), "policia": Color("4d96ff"), "bomberos": Color("e74c3c"), "proteccion_civil": Color("ff8c1a"),
	"geo": Color("b8c2d6"), "ume": Color("d4a017"), "judicial": Color("c39bd3")}
const LETRA_SERVICIO := {"ambulancia": "A", "policia": "P", "bomberos": "B", "proteccion_civil": "C", "geo": "E", "ume": "U", "judicial": "J"}


## Nombres de las unidades por su tipo («Coche patrulla 1», «Moto 2»...),
## en el orden de la flota. Si solo hay uno de un tipo, también lleva el 1.
func _ids_flota() -> Array:
	var cuenta := {}
	var ids := []
	for u in partida["flota"]:
		var t: String = u["tipo"]
		cuenta[t] = int(cuenta.get(t, 0)) + 1
		ids.append("%s %d" % [String(Catalogo.NOMBRE_CORTO.get(t, Catalogo.VEHICULOS[t]["nombre"])), int(cuenta[t])])
	return ids


func _sueldo_de(u: Dictionary) -> int:
	var sv: String = Catalogo.VEHICULOS[u["tipo"]]["servicio"]
	return int(u["personal"]) * int(Catalogo.SUELDO_ESPECIAL.get(sv, Catalogo.SUELDO_POR_TURNO))


func _equipo_para(e: Dictionary, sv: String) -> bool:
	var s_eq = e["servicio"]
	if s_eq is Array:
		return (s_eq as Array).has(sv)
	return String(s_eq) == sv


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
		v.formacion = int(u.get("formacion", 0))
		_completar_tripulacion(u)
		v.tripulacion = u["nombres"].duplicate()
		_datos_tripulacion(v, i)
		v.factor_taller = 1.05 if _tiene_mejora("taller") else 1.0
		v.indice_flota = i
		v.aereo = bool(datos.get("aereo", false))
		v.camillas = int(datos.get("camillas", 0))
		var nodo: int = bases.get(u["base"], bases["policia"])
		v.nodo_base = nodo
		v.zona_radio = 0.0
		if sv == "policia" and not v.aereo:
			# Las patrullas se reparten entre dos zonas de Miguelturra
			var zona_nodo: int = bases["policia_zona1"] if n_policia % 2 == 0 else bases["policia_zona2"]
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


## Da nombre a cada persona del vehículo (se guarda en la partida).
func _completar_tripulacion(u: Dictionary) -> void:
	if not u.has("nombres"):
		u["nombres"] = []
	var nombres: Array = u["nombres"]
	while nombres.size() < int(u["personal"]):
		nombres.append(Pueblo.NOMBRES_PERSONAL[randi() % Pueblo.NOMBRES_PERSONAL.size()])
	while nombres.size() > int(u["personal"]):
		nombres.pop_back()


## Guarda en la flota los cambios de personal (heridos) de los vehículos.
func _sincronizar_flota() -> void:
	for v in vehiculos:
		if v.indice_flota >= 0 and v.indice_flota < partida["flota"].size():
			partida["flota"][v.indice_flota]["heridos"] = v.heridos.duplicate()
			# Las bajas nuevas del turno pasan a personas concretas
			var de_baja := 0
			var sanos: Array = []
			for p in _plantilla():
				if int(p["vehiculo"]) == v.indice_flota:
					if int(p["baja"]) > 0:
						de_baja += 1
					else:
						sanos.append(p)
			var nuevas: int = v.heridos.size() - de_baja
			sanos.shuffle()
			for k in mini(nuevas, sanos.size()):
				sanos[k]["baja"] = Catalogo.TURNOS_BAJA
				sanos[k]["moral"] = maxi(int(sanos[k]["moral"]) - 10, 0)
			# Experiencia del turno
			for p in _plantilla():
				if int(p["vehiculo"]) == v.indice_flota and int(p["baja"]) == 0 and v.xp_turno > 0:
					_ganar_xp(p, v.xp_turno)
			v.xp_turno = 0


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
		"dinero": Catalogo.DINERO_INICIAL, "flota": Catalogo.FLOTA_INICIAL.duplicate(true),
		"vistas": [], "reputacion": 50.0, "puntos": 0, "logros": [], "historial": [], "arcos": {},
		"evento_dia": {}, "eventos_vistos": [], "denuncias_tramitadas": 0, "pc_regalado": false, "detenidos_total": 0,
		"casos": [], "contador_casos": 0, "mapa_ampliado": true, "calabozo": 0, "plantilla": [], "mejoras": [], "psicologo": false}


func _cargar_partida() -> void:
	partida = _partida_nueva()
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_PARTIDA) == OK:
		for k in partida:
			partida[k] = cfg.get_value("partida", k, partida[k])
		# Partidas de antes de la 0.99: el pueblo se ha movido dentro del mapa ampliado
		if not cfg.has_section_key("partida", "mapa_ampliado"):
			var desp: Array = datos_mapa.get("desplazamiento", [0.0, 0.0])
			for h in partida["historial"]:
				h[0] = float(h[0]) + float(desp[0])
				h[1] = float(h[1]) + float(desp[1])
			partida["mapa_ampliado"] = true
	_migrar_plantilla()
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
	hud.ocultar_periodico()
	en_portada = false
	hud.mostrar_portada(false)
	decoracion.visible = false
	en_menu = true
	get_tree().paused = true
	hud.set_pausa(false)
	_clima_de_menu()
	var media := 0.0
	if partida["valoradas"] > 0:
		media = float(partida["estrellas"]) / partida["valoradas"]
	var regalo := _quizas_regalar_pc()
	var ev_id := _evento_del_dia()
	var texto := "Día %d de servicio · %s · Dinero: %s\nTurnos completados: %d · Resueltas: %d · Valoración media: %.1f · Reputación: %d/100" % [
		partida["dia"], _rango_actual(), Hud.formato_euros(partida["dinero"]), partida["turnos"], partida["resueltas"], media, int(partida["reputacion"])]
	if regalo != "":
		texto += "\n\n" + regalo
	if ev_id != "":
		var ev: Dictionary = Pueblo.EVENTOS[ev_id]
		var cuando: String = {"dia": " (solo en el turno de día)", "noche": " (solo en el turno de noche)"}.get(ev["turno"], "")
		texto += "\n\nHOY EN MIGUELTURRA: %s%s\n%s" % [ev["nombre"], cuando, ev["desc"]]
	var pistas := _texto_investigaciones(true)
	if pistas != "":
		texto += "\n\n" + pistas
	texto += "\n\n¿Sabías que...? " + Pueblo.CURIOSIDADES[randi() % Pueblo.CURIOSIDADES.size()]
	texto += "\n\nElige tu turno:"
	hud.mostrar_panel("CENTRAL 112 · MIGUELTURRA", texto, [
		{"texto": "Turno de día (08:00 - 20:00): más llamadas, accidentes y caídas", "accion": _elegir_turno.bind("dia")},
		{"texto": "Turno de noche (20:00 - 08:00): peleas, robos y persecuciones", "accion": _elegir_turno.bind("noche")},
		{"texto": "Mi carrera: rango, logros, investigaciones e historial", "accion": _mostrar_carrera.bind(_mostrar_menu_turno)},
		{"texto": "Volver a la portada", "accion": _mostrar_portada},
	], true, 60.0, 700.0)


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
	hud.dejar_de_mirar()
	red.restaurar_cortes()
	obras.clear()
	_construir_flota()
	_cancelar_envio()
	stats = {"llamadas": 0, "falsas": 0, "perdidas": 0, "resueltas": 0, "estrellas": 0,
		"valoradas": 0, "tiempo_total": 0.0, "con_tiempo": 0, "empeoradas": 0, "ingresos": 0, "heridos": 0,
		"historias": 0, "historias_buenas": 0, "relacionadas": 0, "fallecidos": 0, "sucesos": [],
		"titular_especial": "", "logros_nuevos": [], "detenidos_huida": 0, "detenidos": 0, "multas": 0, "comision": 0}
	cola_relacionadas.clear()
	llamadas_turno.clear()
	var presos := int(partida.get("calabozo", 0))
	if presos > 0:
		var salen := int(ceil(presos / 2.0))
		partida["calabozo"] = presos - salen
		hud.notificar("El juzgado se ha llevado a %d presos del calabozo (quedan %d de %d plazas)." % [salen, int(partida["calabozo"]), _plazas_calabozo()], Color("9fc7e8"))
	hud.set_calabozo(int(partida.get("calabozo", 0)), _plazas_calabozo())
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
	efectos.activo = true
	_elegir_clima()
	_preparar_vida_del_pueblo()
	_programar(5.0, _sonar_llamada)
	_programar(35.0, _evento_aleatorio)
	var p_natural: float = {"tranquila": 0.45, "normal": 0.85, "caotica": 1.0}.get(opciones["dificultad"], 0.85)
	if randf() < p_natural:
		_programar(randf_range(150.0, 620.0), _aviso_muerte_natural)


# ================================================================ EQUIPOS Y TIENDA

func _sueldos_turno() -> int:
	var total := 0
	for u in partida["flota"]:
		total += _sueldo_de(u)
	for p in _plantilla():
		if int(p["vehiculo"]) < 0:
			total += _sueldo_persona(p)
	if partida.get("psicologo", false):
		total += Catalogo.PRECIO_PSICOLOGO
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
	var reserva := 0
	var bajas := 0
	for p in _plantilla():
		if int(p["vehiculo"]) < 0:
			reserva += 1
		if int(p["baja"]) > 0:
			bajas += 1
	opciones.append({"texto": "Plantilla: %d personas · reserva %d · de baja %d" % [_plantilla().size(), reserva, bajas], "accion": _mostrar_plantilla})
	opciones.append({"texto": "Mejoras de las bases (%d de %d)" % [(partida.get("mejoras", []) as Array).size(), Catalogo.MEJORAS.size()], "accion": _mostrar_mejoras})
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
	_completar_tripulacion(u)
	var formacion := int(u.get("formacion", 0))
	var tripu := []
	for p in _plantilla():
		if int(p["vehiculo"]) == i:
			tripu.append(_texto_persona_corto(p))
	var texto := "%s · Velocidad %d · Plazas %d\nPersonal: %d (de baja: %d)\n· %s\nFormación: nivel %d de 2 (trabajan un %d%% más rápido)\nEquipo: %s\nDinero: %s" % [
		datos["nombre"], int(datos["velocidad"]), int(datos["plazas"]), int(u["personal"]), u["heridos"].size(),
		"\n· ".join(PackedStringArray(tripu)), formacion, formacion * 10, equipo_txt, Hud.formato_euros(partida["dinero"])]
	var dinero: int = partida["dinero"]
	var opciones := []
	if int(u["personal"]) < int(datos["plazas"]):
		opciones.append({"texto": "Contratar a una persona (%s + %s/turno)" % [Hud.formato_euros(Catalogo.PRECIO_CONTRATAR), Hud.formato_euros(int(Catalogo.SUELDO_ESPECIAL.get(sv, Catalogo.SUELDO_POR_TURNO)))],
			"accion": _contratar.bind(i), "activo": dinero >= Catalogo.PRECIO_CONTRATAR})
	if int(u["personal"]) < int(datos["plazas"]) or u["heridos"].size() > 0:
		for p in _plantilla():
			if int(p["vehiculo"]) < 0 and p["servicio"] == sv and int(p["baja"]) == 0:
				opciones.append({"texto": "Traer de la reserva a %s" % _texto_persona_corto(p), "accion": _asignar_persona.bind(_plantilla().find(p), i, true)})
	if int(u["personal"]) > 1:
		opciones.append({"texto": "Pasar a la reserva a la persona menos experta (ahorra sueldo)", "accion": _despedir.bind(i)})
	if formacion < 2:
		opciones.append({"texto": "Curso de formación para la tripulación (%s): trabajan más rápido" % Hud.formato_euros(Catalogo.PRECIO_FORMACION),
			"accion": _formar.bind(i), "activo": dinero >= Catalogo.PRECIO_FORMACION})
	for clave in Catalogo.EQUIPO:
		var e: Dictionary = Catalogo.EQUIPO[clave]
		if _equipo_para(e, sv) and not u["equipo"].has(clave):
			opciones.append({"texto": "Comprar %s (%s): %s" % [e["nombre"], Hud.formato_euros(e["precio"]), e["ayuda"]],
				"accion": _comprar_equipo.bind(i, clave), "activo": dinero >= int(e["precio"])})
	var mismos := 0
	for otro in partida["flota"]:
		if Catalogo.VEHICULOS[otro["tipo"]]["servicio"] == sv:
			mismos += 1
	if mismos > 1 or sv in ["geo", "ume", "judicial"]:
		opciones.append({"texto": "Vender este vehículo (+%s)" % Hud.formato_euros(int(datos["precio"]) / 2), "accion": _vender.bind(i)})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	hud.mostrar_panel("%s · %s" % [id, datos["nombre"]], texto, opciones, true)


func _formar(i: int) -> void:
	partida["flota"][i]["formacion"] = int(partida["flota"][i].get("formacion", 0)) + 1
	_cambiar_dinero(-Catalogo.PRECIO_FORMACION)
	_guardar_partida()
	_sonido("envio")
	hud.notificar("La tripulación ha terminado el curso de formación.", Color("8fd3a0"))
	_mostrar_ficha(i)


func _contratar(i: int) -> void:
	var sv: String = Catalogo.VEHICULOS[partida["flota"][i]["tipo"]]["servicio"]
	var p := _nueva_persona(sv)
	p["vehiculo"] = i
	_plantilla().append(p)
	_recalcular_flota()
	_cambiar_dinero(-Catalogo.PRECIO_CONTRATAR)
	_guardar_partida()
	_sonido("envio")
	_mostrar_ficha(i)


func _despedir(i: int) -> void:
	# Pasa a la reserva a la persona con menos experiencia del vehículo
	var peor = null
	for p in _plantilla():
		if int(p["vehiculo"]) == i and (peor == null or int(p["xp"]) < int(peor["xp"])):
			peor = p
	if peor != null:
		peor["vehiculo"] = -1
		hud.notificar("%s pasa a la reserva." % peor["nombre"], Color("9fc7e8"))
	_recalcular_flota()
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
	# Su tripulación pasa a la reserva y se corrigen los números de los demás
	for p in _plantilla():
		var vi := int(p["vehiculo"])
		if vi == i:
			p["vehiculo"] = -1
		elif vi > i:
			p["vehiculo"] = vi - 1
	partida["flota"].remove_at(i)
	_cambiar_dinero(int(datos["precio"]) / 2)
	_guardar_partida()
	_mostrar_equipos()


func _mostrar_tienda_vehiculos() -> void:
	var dinero: int = partida["dinero"]
	var opciones := []
	var nombres := {"ambulancia": "Sanitario", "policia": "Policía", "bomberos": "Bomberos", "proteccion_civil": "Protección Civil",
		"geo": "GEO", "ume": "UME", "judicial": "Policía Judicial"}
	var mi_rango := _rango_indice(int(partida["puntos"]))
	for clave in Catalogo.VEHICULOS:
		var d: Dictionary = Catalogo.VEHICULOS[clave]
		var extra: String = DESC_BONO.get(d["bono"], "")
		var rango_min := int(d.get("rango", 0))
		if d["servicio"] in ["geo", "ume", "judicial"]:
			extra += (" " if extra != "" else "") + "Mantenimiento barato (%s por persona y turno)." % Hud.formato_euros(int(Catalogo.SUELDO_ESPECIAL[d["servicio"]]))
		if rango_min > mi_rango:
			opciones.append({"texto": "%s · %s · BLOQUEADO: necesitas el rango «%s»" % [nombres[d["servicio"]], d["nombre"], Pueblo.RANGOS[rango_min][1]], "accion": _mostrar_tienda_vehiculos, "activo": false})
			continue
		opciones.append({"texto": "%s · %s · Vel. %d · %d plazas · %s%s" % [nombres[d["servicio"]], d["nombre"], int(d["velocidad"]), int(d["plazas"]), Hud.formato_euros(d["precio"]), "" if extra == "" else "\n     " + extra],
			"accion": _comprar_vehiculo.bind(clave), "activo": dinero >= int(d["precio"])})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	hud.mostrar_panel("TIENDA DE VEHÍCULOS", "Dinero: %s\nCada vehículo nuevo viene con su personal mínimo." % Hud.formato_euros(dinero), opciones, true)


func _comprar_vehiculo(clave: String) -> void:
	var d: Dictionary = Catalogo.VEHICULOS[clave]
	partida["flota"].append({"tipo": clave, "base": String(d.get("base", Catalogo.BASE_SERVICIO[d["servicio"]])),
		"personal": 0, "heridos": [], "equipo": [], "nombres": []})
	var indice: int = partida["flota"].size() - 1
	# Primero se usa gente de la reserva del mismo servicio; si no, se contrata
	var faltan := mini(int(d.get("inicial", 2)), int(d["plazas"]))
	for p in _plantilla():
		if faltan > 0 and int(p["vehiculo"]) < 0 and p["servicio"] == d["servicio"] and int(p["baja"]) == 0:
			p["vehiculo"] = indice
			faltan -= 1
	for k in faltan:
		var np := _nueva_persona(String(d["servicio"]))
		np["vehiculo"] = indice
		_plantilla().append(np)
	_recalcular_flota()
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
		_aplazar_pasos_caso()
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
		sueldos += _sueldo_de(u)
		var quedan := []
		for t in u["heridos"]:
			if int(t) > 1:
				quedan.append(int(t) - 1)
		u["heridos"] = quedan
	for p in _plantilla():
		if int(p["baja"]) > 0:
			p["baja"] = int(p["baja"]) - 1
		var sube := 5 + (5 if _tiene_mejora("gimnasio") else 0) + (15 if partida.get("psicologo", false) else 0)
		p["moral"] = mini(int(p["moral"]) + sube, 100)
	for p in _plantilla():
		if int(p["vehiculo"]) < 0:
			sueldos += _sueldo_persona(p)
	if partida.get("psicologo", false):
		sueldos += Catalogo.PRECIO_PSICOLOGO
	_recalcular_flota()
	if not subidas_nivel.is_empty():
		texto += "\n\nAscensos del personal:\n· " + "\n· ".join(PackedStringArray(subidas_nivel))
		subidas_nivel.clear()
	partida["dinero"] = int(partida["dinero"]) - sueldos
	hud.set_dinero(partida["dinero"])
	texto += "\n\nIngresos del turno: %s\nSueldos del personal: -%s\nDinero total: %s" % [
		Hud.formato_euros(stats["ingresos"]), Hud.formato_euros(sueldos), Hud.formato_euros(partida["dinero"])]
	if stats["heridos"] > 0:
		texto += "\nPersonal herido este turno: %d" % stats["heridos"]
	texto += "\nPolicía: %d detenidos al calabozo y %d multas" % [stats["detenidos"], stats["multas"]]
	if stats["comision"] > 0:
		texto += "\nComisión por multas (%d %%): +%s" % [int(round(_comision() * 100.0)), Hud.formato_euros(stats["comision"])]
	partida["dia"] += 1
	partida["turnos"] += 1
	partida["resueltas"] += stats["resueltas"]
	partida["estrellas"] += stats["estrellas"]
	partida["valoradas"] += stats["valoradas"]
	texto += _cierre_de_carrera()
	_guardar_partida()
	texto += "\n\nObjetivos del turno:" + _texto_objetivos(true)
	if stats["historias"] > 0:
		texto += "\nHistorias: %d (con buen final: %d) · Llamadas relacionadas: %d" % [stats["historias"], stats["historias_buenas"], stats["relacionadas"]]
	tutorial_activo = false
	_guardar_partida()
	texto += "\n\nPartida guardada."
	_sonido("envio")
	_texto_resumen = texto
	hud.mostrar_periodico(_datos_periodico(media))
	hud.mostrar_panel("", "", [{"texto": "Ver el resumen del turno", "accion": _ver_resumen}], true, 574.0, 420.0)


var _texto_resumen := ""


func _ver_resumen() -> void:
	hud.ocultar_periodico()
	hud.mostrar_panel("RESUMEN DEL TURNO", _texto_resumen, [
		{"texto": "Elegir el siguiente turno", "accion": _mostrar_menu_turno},
		{"texto": "Salir del juego", "accion": _salir},
	], true)


## Portada del periódico local con el caso más destacado del turno.
func _datos_periodico(media: float) -> Dictionary:
	var sucesos: Array = stats["sucesos"]
	var mejor = null
	var peor = null
	var muerte = null
	for su in sucesos:
		if su["fallecido"] and muerte == null:
			muerte = su
		if mejor == null or int(su["estrellas"]) > int(mejor["estrellas"]) or (int(su["estrellas"]) == int(mejor["estrellas"]) and su["historia"]):
			mejor = su
		if peor == null or int(su["estrellas"]) < int(peor["estrellas"]):
			peor = su
	var titular := "Turno tranquilo en la central del 112 de Miguelturra"
	var sub := "Los operadores apenas han tenido avisos durante la jornada."
	if muerte != null:
		var sitio: String = muerte["calle"] if muerte["calle"] != "" else "Miguelturra"
		var muertes := 0
		for su in sucesos:
			if su["fallecido"]:
				muertes += 1
		var t_muerte: String = String(muerte["titulo"]).to_lower()
		var opciones_tit := [
			"Jornada trágica: fallece una persona en %s" % sitio,
			"Muere un vecino en %s tras %s" % [sitio, t_muerte],
			"Luto en Miguelturra: una víctima mortal en %s" % sitio,
		]
		if t_muerte.contains("arma") or t_muerte.contains("navaja") or t_muerte.contains("banda") or t_muerte.contains("asalto"):
			opciones_tit = ["Sangre en las calles de Miguelturra: un muerto en %s" % sitio, "Crimen en %s: la Guardia Civil investiga una muerte violenta" % sitio]
		titular = opciones_tit[randi() % opciones_tit.size()]
		if muertes >= 2:
			titular = "Turno negro en el 112: %d fallecidos en una sola jornada" % muertes
		sub = String(muerte["resultado"])
	elif stats["perdidas"] >= 3:
		titular = "Críticas al 112: varias llamadas se quedan sin respuesta"
		sub = "%d vecinos colgaron antes de ser atendidos durante el turno." % stats["perdidas"]
	elif mejor != null and int(mejor["estrellas"]) >= 4:
		titular = "Actuación ejemplar del 112: %s" % String(mejor["titulo"]).to_lower()
		sub = String(mejor["resultado"])
	elif peor != null and int(peor["estrellas"]) <= 2:
		titular = "Polémica por la tardanza del 112: %s" % String(peor["titulo"]).to_lower()
		sub = String(peor["resultado"])
	elif evento_hoy != "":
		titular = Pueblo.EVENTOS[evento_hoy]["noticia"]
		sub = "La central del 112 atendió %d emergencias durante la jornada." % sucesos.size()
	elif sucesos.size() > 0:
		titular = "La central del 112 atiende %d emergencias en un solo turno" % sucesos.size()
		sub = "Policía Local, sanitarios y bomberos han trabajado sin descanso."
	if String(stats.get("titular_especial", "")) != "":
		if titular != "" and muerte == null:
			sub = titular + "."
		titular = stats["titular_especial"]
	var breves: Array = []
	for su in sucesos:
		if su != mejor and su != muerte and breves.size() < 4:
			breves.append("%s: %s" % [su["titulo"], su["resultado"]])
	breves.append("El tiempo: %s." % String(CLIMAS[clima]["nombre"]).to_lower())
	if evento_hoy != "" and not titular.begins_with(Pueblo.EVENTOS[evento_hoy]["noticia"]):
		breves.push_front("Fiestas: %s." % Pueblo.EVENTOS[evento_hoy]["noticia"])
	for o in obras:
		if o[3] == "obras":
			breves.append("Tráfico: obras en %s." % o[2])
			break
	if stats["heridos"] > 0:
		breves.append("%d agentes heridos durante el servicio." % stats["heridos"])
	if stats["detenidos"] > 0 or stats["multas"] > 0:
		breves.append("La Policía Local detuvo a %d personas y puso %d multas." % [stats["detenidos"], stats["multas"]])
	var nota := "sin valorar" if stats["valoradas"] == 0 else "%.1f de 5" % media
	return {"fecha": "Día %d de servicio · %s" % [partida["dia"] - 1, TURNOS[turno]["nombre"]],
		"titular": titular, "subtitulo": sub, "breves": breves,
		"pie": "Valoración de los vecinos: %s · Llamadas atendidas: %d · Emergencias resueltas: %d" % [nota, stats["llamadas"], stats["resueltas"]]}


## Genera llamadas y avisos al azar, con ratos de calma entre medias.
func _evento_aleatorio() -> void:
	if en_menu or turno_terminando:
		return
	var dificultad := maxf(0.6, 1.0 - (partida["dia"] - 1) * 0.05)
	var espera := randf_range(40.0, 70.0) if turno == "dia" else randf_range(50.0, 80.0)
	if evento_hoy != "":
		espera *= 0.85   # en fiestas hay más jaleo
	var factor: float = {"tranquila": 1.4, "normal": 1.0, "caotica": 0.7}.get(opciones["dificultad"], 1.0)
	_programar(espera * dificultad * factor, _evento_aleatorio)
	var activos := 0
	for inc in incidentes:
		if inc.activo():
			activos += 1
	var extra_max: int = {"tranquila": -1, "normal": 0, "caotica": 2}.get(opciones["dificultad"], 0)
	if activos >= 3 + mini(partida["dia"] - 1, 3) + extra_max:
		return
	# Día de fiestas: muchas emergencias ocurren allí
	if evento_hoy != "" and randf() < 0.45:
		_aviso_pueblo()
		return
	if turno == "noche" and randf() < 0.06:
		_iniciar_cadena(-1)
		return
	# El tiempo también trae sus propias emergencias
	if clima == "tormenta" and randf() < 0.18:
		_crear_incendio("Incendio por la caída de un rayo")
		return
	if clima == "calor" and randf() < 0.22:
		_aviso_directo("caida_mayor", "Golpe de calor: persona mayor desmayada en la calle")
		return
	var r := randf()
	if r < 0.35:
		# Llamada que hay que atender
		if not llamada_sonando and llamada == null:
			_sonar_llamada()
		else:
			_aviso_directo()
	elif r < 0.65:
		# Emergencia menor: solo un aviso y aparece sola en el mapa
		if (clima == "lluvia" or clima == "tormenta" or clima == "niebla") and randf() < 0.4:
			_aviso_directo("accidente_trafico", "Accidente por la calzada mojada" if clima != "niebla" else "Accidente por la niebla")
		else:
			_aviso_directo()
	elif r < 0.77 and sospechoso == null:
		_crear_aviso_trafico()
	elif r < 0.9:
		_crear_incendio()
	else:
		_aviso_patrulla()


# ================================================================ VIDA DEL PUEBLO (0.9)

## El segundo día el ayuntamiento cede un vehículo de Protección Civil.
func _quizas_regalar_pc() -> String:
	if bool(partida.get("pc_regalado", false)) or int(partida["dia"]) < 2:
		return ""
	partida["pc_regalado"] = true
	for u in partida["flota"]:
		if Catalogo.VEHICULOS[u["tipo"]]["servicio"] == "proteccion_civil":
			return ""
	partida["flota"].append({"tipo": "pc_vehiculo", "base": "proteccion_civil", "personal": 3, "heridos": [], "equipo": []})
	_guardar_partida()
	return "¡NOVEDAD! El ayuntamiento os cede un vehículo de PROTECCIÓN CIVIL (naranja). Ayuda en cualquier emergencia: acordona, atiende y hace que todo vaya más rápido."


## ¿Hay fiesta o algo especial hoy? Se decide una vez por día y se guarda.
func _evento_del_dia() -> String:
	var d: Dictionary = partida.get("evento_dia", {})
	if int(d.get("dia", -1)) == int(partida["dia"]):
		return String(d.get("id", ""))
	var id := ""
	var dia := int(partida["dia"])
	if dia >= 2 and (dia % 3 == 0 or randf() < 0.2):
		var vistos: Array = partida.get("eventos_vistos", [])
		var posibles := []
		for k in Pueblo.EVENTOS:
			if not vistos.has(k):
				posibles.append(k)
		if posibles.is_empty():
			vistos.clear()
			posibles = Pueblo.EVENTOS.keys()
		id = posibles[randi() % posibles.size()]
		vistos.append(id)
		while vistos.size() > 5:
			vistos.pop_front()
		partida["eventos_vistos"] = vistos
	partida["evento_dia"] = {"dia": dia, "id": id}
	return id


func _preparar_vida_del_pueblo() -> void:
	externos_usados = {"guardia_civil": 0, "ume": 0}
	denuncias.clear()
	hud.set_comisaria(0)
	etapas_programadas.clear()
	stats["rango_inicio"] = _rango_indice(int(partida["puntos"]))
	stats["reputacion_inicio"] = float(partida["reputacion"])
	# Fiesta o día especial
	evento_hoy = ""
	var ev_id := _evento_del_dia()
	if ev_id != "":
		var ev: Dictionary = Pueblo.EVENTOS[ev_id]
		if ev["turno"] == "ambos" or ev["turno"] == turno:
			evento_hoy = ev_id
			var l := _lugar(ev["lugar"])
			pos_evento = Vector2(float(l.get("x", tamano_mapa.x / 2.0)), float(l.get("y", tamano_mapa.y / 2.0)))
			_cortar_alrededor(pos_evento, 140.0, 3, "")
			_programar(4.0, _anunciar_evento)
			if ev.has("historia"):
				_programar(randf_range(90.0, 200.0), _sonar_historia.bind(ev["historia"]))
	efectos.zona_evento = {} if evento_hoy == "" else {"pos": pos_evento, "nombre": Pueblo.EVENTOS[evento_hoy]["nombre"]}
	# Obras en alguna calle
	_poner_obras(1 + randi() % 2)
	# Comisaría: denuncias de los vecinos
	_programar(randf_range(120.0, 260.0), _llega_denuncia)
	# Investigaciones en marcha
	_programar_arcos()
	# Cadena: coche sospechoso que acaba en robo (de noche)
	if turno == "noche" and randf() < 0.4:
		_programar(randf_range(200.0, 500.0), _iniciar_cadena.bind(-1))


func _anunciar_evento() -> void:
	if evento_hoy == "":
		return
	var ev: Dictionary = Pueblo.EVENTOS[evento_hoy]
	hud.notificar("HOY: %s. Habrá más avisos cerca de %s y algunas calles están cortadas." % [ev["nombre"], ev["lugar"]], Color("ffd166"))
	_sonido("alerta")
	_viaje_camara(pos_evento)


## Corta unos cuantos tramos de calle cerca de un punto (fiestas) o al azar (obras).
func _cortar_alrededor(centro: Vector2, radio: float, cuantos: int, motivo: String) -> void:
	var candidatos := []
	for t in red.tramos:
		var a := int(t[0])
		var b := int(t[1])
		if int(t[3]) == 1 or red.grado(a) < 3 or red.grado(b) < 3:
			continue
		var m := (red.pos(a) + red.pos(b)) / 2.0
		if m.distance_to(centro) > radio:
			continue
		var cerca_base := false
		for k in bases:
			if red.pos(bases[k]).distance_to(m) < 120.0:
				cerca_base = true
		if not cerca_base:
			candidatos.append([a, b])
	candidatos.shuffle()
	for i in mini(cuantos, candidatos.size()):
		var c: Array = candidatos[i]
		red.cortar(c[0], c[1])
		obras.append([c[0], c[1], red.calle_de_nodo(c[0]), motivo])


func _poner_obras(cuantas: int) -> void:
	var centro := _pos_lugar("Plaza de España", tamano_mapa / 2.0)
	for i in cuantas:
		var punto := centro + Vector2(randf_range(-700, 700), randf_range(-600, 600))
		var antes := obras.size()
		_cortar_alrededor(punto, 250.0, 1, "obras")
		if obras.size() > antes:
			var o: Array = obras[obras.size() - 1]
			_programar(8.0 + i * 4.0, hud.notificar.bind("Tráfico: obras en %s. Las unidades darán un rodeo." % o[2], Color("ffb347")))


## Emergencia propia del día especial, cerca del lugar de la fiesta.
func _aviso_pueblo() -> void:
	var ev: Dictionary = Pueblo.EVENTOS[evento_hoy]
	var avisos: Array = ev["avisos"]
	var d: Dictionary = avisos[randi() % avisos.size()]
	var nodo := _nodo_cerca(pos_evento, 260.0)
	var inc = _nuevo_aviso(d, nodo, ev["lugar"], "Aviso desde %s (%s)" % [ev["lugar"], ev["nombre"]])
	inc.evento_pueblo = evento_hoy


func _nodo_cerca(centro: Vector2, radio: float) -> int:
	for intento in 12:
		var q := centro + Vector2(randf_range(-radio, radio), randf_range(-radio, radio))
		var n := red.nodo_mas_cercano(q)
		if red.pos(n).distance_to(centro) <= radio * 1.5:
			return n
	return red.nodo_mas_cercano(centro)


## Crea una emergencia menor a partir de una definición (ver data/pueblo/pueblo.gd).
func _nuevo_aviso(d: Dictionary, nodo: int, lugar_nombre: String, fuente: String, avisar: bool = true):
	var calle := red.calle_de_nodo(nodo)
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.categoria = d.get("categoria", "medico")
	inc.tipo = "incendio" if inc.categoria == "fuego" else "aviso_directo"
	inc.fuente = fuente
	inc.titulo = d["titulo"]
	inc.clima = clima
	inc.servicios = d["servicios"].duplicate()
	inc.servicio_necesario = d["principal"]
	inc.requeridas = d.get("requeridas", {d["principal"]: 1}).duplicate()
	for sv in inc.requeridas:
		if not inc.servicios.has(sv):
			inc.servicios.append(sv)
	inc.urgencia_total = float(d.get("urgencia", 90.0))
	inc.urgencia_restante = inc.urgencia_total
	inc.traslado = d.get("traslado", false)
	inc.tiempo_intervencion = float(d.get("intervencion", 10.0))
	inc.heridos = int(d.get("heridos", 1))
	if d.get("fallecido", false):
		inc.fallecidos = 1
	inc.resultado_bien = d.get("resultado_bien", "")
	inc.resultado_mal = d.get("resultado_mal", "")
	inc.informacion = ["En %s" % calle]
	if lugar_nombre != "":
		inc.informacion.append("Cerca de %s" % lugar_nombre)
	for i in d.get("info", []):
		inc.informacion.append(i)
	inc.precision = 3
	inc.precision_al_enviar = -1
	inc.nodo_real = nodo
	inc.nodo_aproximado = nodo
	inc.pos_exacta = red.pos(nodo)
	inc.calma_final = 60
	inc.tiempo_creacion = tiempo_juego
	inc.registrar(_hora(segundos_sim), "Aviso recibido: %s" % inc.titulo)
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	if avisar:
		hud.notificar("NUEVO AVISO %s: %s en %s. Pulsa Triángulo para verlo." % [inc.id_incidente, inc.titulo, calle], Color("9ff3ff"))
		_sonido("alerta")
	return inc


## Llamada de una historia concreta (por ejemplo, la de la fiesta ilegal).
func _sonar_historia(id: String) -> void:
	if en_menu or turno_terminando:
		return
	if llamada_sonando or llamada != null or hud.llamada_abierta():
		_programar(20.0, _sonar_historia.bind(id))
		return
	for h in todas_historias:
		if h["id"] == id:
			llamada_rel_inc = null
			llamada_historia = {}
			llamada_desenlace = ""
			_preparar_historia(h)
			_hacer_sonar()
			return


# ================================================================ CARRERA DEL OPERADOR (0.9)

func _rango_indice(puntos: int) -> int:
	var idx := 0
	for i in Pueblo.RANGOS.size():
		if puntos >= int(Pueblo.RANGOS[i][0]):
			idx = i
	return idx


func _rango_actual() -> String:
	return Pueblo.RANGOS[_rango_indice(int(partida["puntos"]))][1]


func _sumar_reputacion(cuanto: float) -> void:
	partida["reputacion"] = clampf(float(partida["reputacion"]) + cuanto, 0.0, 100.0)


func _dar_logro(id: String) -> void:
	var logros: Array = partida["logros"]
	if logros.has(id) or not Pueblo.LOGROS.has(id):
		return
	logros.append(id)
	if stats.has("logros_nuevos"):
		stats["logros_nuevos"].append(id)
	hud.notificar("¡LOGRO CONSEGUIDO! %s: %s" % [Pueblo.LOGROS[id]["nombre"], Pueblo.LOGROS[id]["desc"]], Color("ffd700"))
	_sonido("envio")
	_vibrar(0.4, 0.2, 0.3)


## Se llama al cerrar cada emergencia: reputación, puntos, historial, logros e investigaciones.
func _al_cerrar_incidente(inc, estrellas: int) -> void:
	if inc.fallecidos > 0:
		var baja := 8 if partida.get("psicologo", false) else 15
		for v in inc.en_escena:
			if is_instance_valid(v) and v.indice_flota >= 0:
				for p in _plantilla():
					if int(p["vehiculo"]) == v.indice_flota:
						p["moral"] = maxi(int(p["moral"]) - baja, 0)
	_sumar_reputacion((estrellas - 3) * 1.2 - (2.0 if inc.fallecidos > 0 else 0.0))
	partida["puntos"] = int(partida["puntos"]) + estrellas
	var historial: Array = partida["historial"]
	historial.append([inc.position.x, inc.position.y, estrellas, inc.titulo, int(partida["dia"]), turno])
	while historial.size() > 80:
		historial.pop_front()
	if estrellas >= 5:
		_dar_logro("cinco_estrellas")
	if inc.exito and inc.marcas.has("rcp"):
		_dar_logro("rcp")
	if inc.exito and inc.categoria == "fuego" and inc.marcas.has("atrapado_bien"):
		_dar_logro("rescate_altura")
	if inc.exito and inc.cadena == "huida":
		_dar_logro("persecucion")
	if inc.arco != "":
		var etapa: Dictionary = Pueblo.ARCOS[inc.arco]["etapas"][inc.etapa_arco]
		if inc.exito or etapa.get("siempre_avanza", false):
			_avanzar_arco(inc.arco, inc.etapa_arco)
		else:
			hud.notificar("%s: esta vez no ha salido bien. La investigación seguirá en otro turno." % Pueblo.ARCOS[inc.arco]["nombre"], Color("ff8a65"))


## Al terminar el turno: presupuesto, rango y logros. Devuelve el texto para el resumen.
func _cierre_de_carrera() -> String:
	var texto := ""
	var sub := Catalogo.SUBVENCION_BASE + int(float(partida["reputacion"]) * 20.0)
	partida["dinero"] = int(partida["dinero"]) + sub
	hud.set_dinero(partida["dinero"])
	var cambio := float(partida["reputacion"]) - float(stats.get("reputacion_inicio", partida["reputacion"]))
	texto += "\nReputación en el pueblo: %d/100 (%s%d)" % [int(partida["reputacion"]), "+" if cambio >= 0.0 else "", int(round(cambio))]
	texto += "\nPresupuesto del ayuntamiento: +%s" % Hud.formato_euros(sub)
	var antes := int(stats.get("rango_inicio", 0))
	var ahora := _rango_indice(int(partida["puntos"]))
	if ahora > antes:
		texto += "\n\n¡ASCENSO! Ahora eres %s." % Pueblo.RANGOS[ahora][1]
	else:
		texto += "\nRango: %s (%d puntos)" % [Pueblo.RANGOS[ahora][1], int(partida["puntos"])]
	if ahora >= 3:
		_dar_logro("jefe")
	_dar_logro("primer_turno")
	if stats["perdidas"] == 0 and stats["llamadas"] > 0:
		_dar_logro("sin_perdidas")
	if clima == "tormenta":
		_dar_logro("tormenta")
	if evento_hoy != "":
		_dar_logro("fiestas")
	if int(partida["turnos"]) >= 10:
		_dar_logro("diez_turnos")
	if int(partida["resueltas"]) >= 100:
		_dar_logro("cien")
	if partida["flota"].size() >= 10:
		_dar_logro("flota")
	var nuevos: Array = stats.get("logros_nuevos", [])
	if nuevos.size() > 0:
		var nombres := []
		for id in nuevos:
			nombres.append(Pueblo.LOGROS[id]["nombre"])
		texto += "\nLogros nuevos: " + ", ".join(PackedStringArray(nombres))
	return texto


func _mostrar_carrera(volver: Callable) -> void:
	var idx := _rango_indice(int(partida["puntos"]))
	var texto := "Rango: %s · %d puntos" % [Pueblo.RANGOS[idx][1], int(partida["puntos"])]
	if idx + 1 < Pueblo.RANGOS.size():
		texto += "\nSiguiente rango: %s (faltan %d puntos)" % [Pueblo.RANGOS[idx + 1][1], int(Pueblo.RANGOS[idx + 1][0]) - int(partida["puntos"])]
	texto += "\nReputación en el pueblo: %d/100 · Presupuesto por turno: %s" % [int(partida["reputacion"]),
		Hud.formato_euros(Catalogo.SUBVENCION_BASE + int(float(partida["reputacion"]) * 20.0))]
	texto += "\nLogros: %d de %d · Denuncias tramitadas: %d" % [partida["logros"].size(), Pueblo.LOGROS.size(), int(partida["denuncias_tramitadas"])]
	var inv := _texto_investigaciones(false)
	texto += "\n\n" + (inv if inv != "" else "Investigaciones: todavía no hay ninguna abierta (empiezan a partir del día 3).")
	hud.mostrar_panel("MI CARRERA", texto, [
		{"texto": "Ver los logros", "accion": _mostrar_logros.bind(volver)},
		{"texto": "Historial de emergencias", "accion": _mostrar_historial.bind(volver)},
		{"texto": "Volver", "accion": volver},
	], true)


func _mostrar_logros(volver: Callable) -> void:
	var texto := ""
	for id in Pueblo.LOGROS:
		var hecho: bool = partida["logros"].has(id)
		texto += "%s %s: %s\n" % ["[X]" if hecho else "[  ]", Pueblo.LOGROS[id]["nombre"], Pueblo.LOGROS[id]["desc"]]
	hud.mostrar_panel("LOGROS", texto.strip_edges(), [{"texto": "Volver", "accion": _mostrar_carrera.bind(volver)}], true)


func _mostrar_historial(volver: Callable) -> void:
	var historial: Array = partida["historial"]
	var texto := ""
	var desde := maxi(0, historial.size() - 15)
	for k in range(historial.size() - 1, desde - 1, -1):
		var h: Array = historial[k]
		texto += "Día %d (%s) · %s · %d de 5\n" % [int(h[4]), "día" if h[5] == "dia" else "noche", h[3], int(h[2])]
	if texto == "":
		texto = "Todavía no hay emergencias en el historial."
	texto += "\nConsejo: en el menú de pausa puedes ver el mapa de calor con dónde ocurren más emergencias."
	hud.mostrar_panel("HISTORIAL DE EMERGENCIAS", texto.strip_edges(), [{"texto": "Volver", "accion": _mostrar_carrera.bind(volver)}], true)


func _cambiar_capa_mapa() -> void:
	var orden := ["", "calor", "historial"]
	capa_mapa = orden[(orden.find(capa_mapa) + 1) % orden.size()]
	efectos.capa = capa_mapa
	efectos.historial = partida["historial"]
	_mostrar_menu_pausa()


# ================================================================ COMISARÍA: DENUNCIAS (0.95-0.96)
## Las denuncias se acumulan en la comisaría (C/ Lentejuela, 7). Arriba se ve
## cuántas hay; con la cruceta izquierda se abre la comisaría y el juego se pausa.

const MAX_DENUNCIAS := 4
const ESPERA_DENUNCIA := 300.0   # segundos de juego que espera el vecino


func _llega_denuncia() -> void:
	if en_menu or turno_terminando:
		return
	if turno == "dia" and randf() < 0.65:
		_programar(randf_range(220.0, 380.0), _llega_denuncia)
	if denuncias.size() >= MAX_DENUNCIAS:
		return
	var d: Dictionary = {}
	# Las investigaciones pueden necesitar una denuncia
	for id in etapas_programadas:
		var etapa := _etapa_actual(id)
		if not etapa.is_empty() and etapa["tipo"] == "denuncia":
			d = {"tipo": "arco", "arco": id, "quien": etapa["quien"], "texto": etapa["texto"]}
			etapas_programadas.erase(id)
			break
	if d.is_empty():
		d = Pueblo.DENUNCIAS[randi() % Pueblo.DENUNCIAS.size()].duplicate()
	d["llegada"] = tiempo_juego
	denuncias.append(d)
	hud.set_comisaria(denuncias.size())
	hud.notificar("COMISARÍA: ha llegado una denuncia nueva. Pulsa la cruceta IZQUIERDA para atenderla.", COLOR_RADIO_POLICIA)
	_sonido("radio")
	_consejo("denuncia", "En la comisaría de la calle Lentejuela los vecinos ponen denuncias. Ábrela con la cruceta izquierda (el juego se pausa). Tramitarlas da reputación, y algunas abren investigaciones o evitan delitos.")


## Cada segundo: los vecinos que llevan mucho rato esperando se van.
func _vigilar_denuncias() -> void:
	var quedan: Array = []
	for d in denuncias:
		if tiempo_juego - float(d["llegada"]) > ESPERA_DENUNCIA:
			if d["tipo"] == "arco":
				etapas_programadas.append(d["arco"])
			_sumar_reputacion(-1.0)
			hud.notificar("COMISARÍA: un vecino se ha cansado de esperar y se ha ido.", COLOR_RADIO_POLICIA)
		else:
			quedan.append(d)
	if quedan.size() != denuncias.size():
		denuncias = quedan
		hud.set_comisaria(denuncias.size())


func _mostrar_comisaria() -> void:
	if not get_tree().paused:
		get_tree().paused = true
		pausa_comisaria = true
	var opciones := []
	for i in denuncias.size():
		var d: Dictionary = denuncias[i]
		var espera := int(maxf(0.0, ESPERA_DENUNCIA - (tiempo_juego - float(d["llegada"]))))
		var resumen := String(d["texto"])
		if resumen.length() > 60:
			resumen = resumen.left(58) + "…"
		opciones.append({"texto": "%s · «%s» (espera %d s)" % [d["quien"], resumen, espera], "accion": _mostrar_denuncia.bind(i)})
	var abiertos := 0
	for c in _casos():
		if c["estado"] == "abierto":
			abiertos += 1
	var en_calabozo := int(partida.get("calabozo", 0))
	opciones.append({"texto": "Calabozo: %d de %d plazas ocupadas · Llevar presos a la cárcel" % [en_calabozo, _plazas_calabozo()],
		"accion": _trasladar_presos, "activo": en_calabozo > 0})
	if _flota_tiene("judicial") or not _casos().is_empty():
		opciones.append({"texto": "Casos de la Policía Judicial (%d abiertos)" % abiertos, "accion": _mostrar_casos})
	opciones.append({"texto": "Volver al mapa (el juego sigue)", "accion": _cerrar_comisaria})
	var texto := "Comisaría de la Policía Local · C/ Lentejuela, 7\nEl juego está en pausa mientras decides."
	if denuncias.is_empty():
		texto += "\n\nNo hay ninguna denuncia pendiente."
	else:
		texto += "\n\nDenuncias pendientes: %d. Elige una para atenderla." % denuncias.size()
	texto += "\nDenuncias tramitadas en total: %d" % int(partida["denuncias_tramitadas"])
	hud.mostrar_panel("COMISARÍA", texto, opciones, true, 120.0, 720.0)


func _cerrar_comisaria() -> void:
	hud.cerrar_panel()
	if pausa_comisaria:
		pausa_comisaria = false
		get_tree().paused = false


func _mostrar_denuncia(i: int) -> void:
	if i < 0 or i >= denuncias.size():
		_mostrar_comisaria()
		return
	var d: Dictionary = denuncias[i]
	var texto := "%s:\n\n«%s»" % [d["quien"], d["texto"]]
	var ops := []
	if _denuncia_investigable(d):
		if _flota_tiene("judicial"):
			ops.append({"texto": "Pasarla a la Policía Judicial: los detectives abren un caso", "accion": _resolver_denuncia.bind(i, "judicial")})
		else:
			texto += "\n\n(Con un equipo de Policía Judicial podrías investigarla hasta dar con el culpable: se compra en la tienda.)"
	hud.mostrar_panel("DENUNCIA EN LA COMISARÍA", texto, ops + [
		{"texto": "Tramitar la denuncia y abrir una investigación", "accion": _resolver_denuncia.bind(i, "tramitar")},
		{"texto": "Tomar nota y pasarla al turno siguiente", "accion": _resolver_denuncia.bind(i, "nota")},
		{"texto": "Archivarla", "accion": _resolver_denuncia.bind(i, "archivar")},
		{"texto": "Volver a la lista de denuncias", "accion": _mostrar_comisaria},
	], true, 160.0, 720.0)


func _resolver_denuncia(i: int, accion: String) -> void:
	if i < 0 or i >= denuncias.size():
		_mostrar_comisaria()
		return
	var d: Dictionary = denuncias[i]
	denuncias.remove_at(i)
	hud.set_comisaria(denuncias.size())
	var tipo: String = d["tipo"]
	match accion:
		"judicial":
			partida["denuncias_tramitadas"] = int(partida["denuncias_tramitadas"]) + 1
			_sumar_reputacion(1.0)
			var caso := _abrir_caso(d)
			hud.notificar("Caso %s abierto. Míralo en «Casos de la Policía Judicial» y manda a los detectives." % caso["id"], Color("c39bd3"))
			_mostrar_caso(_casos().size() - 1)
			return
		"tramitar":
			partida["denuncias_tramitadas"] = int(partida["denuncias_tramitadas"]) + 1
			_sumar_reputacion(1.0)
			if int(partida["denuncias_tramitadas"]) >= 5:
				_dar_logro("denuncias")
			if tipo == "arco":
				_avanzar_arco(d["arco"], int(partida["arcos"][d["arco"]]["etapa"]))
			elif tipo == "sospechoso":
				hud.notificar("Denuncia tramitada: una patrulla irá a identificar el coche sospechoso.", COLOR_RADIO_POLICIA)
				_iniciar_cadena(-1)
			else:
				hud.notificar("Denuncia tramitada. El vecino se va satisfecho.", COLOR_RADIO_POLICIA)
		"nota":
			if tipo == "arco":
				etapas_programadas.append(d["arco"])
			hud.notificar("Has tomado nota de la denuncia.", COLOR_RADIO_POLICIA)
			if tipo == "sospechoso":
				_programar(randf_range(120.0, 200.0), _cadena_robo.bind(-1))
		"archivar":
			_sumar_reputacion(-1.5)
			hud.notificar("Denuncia archivada. El vecino se va muy enfadado.", COLOR_RADIO_POLICIA)
			if tipo == "sospechoso":
				_programar(randf_range(90.0, 160.0), _cadena_robo.bind(-1))
	_mostrar_comisaria()


# ================================================================ POLICÍA JUDICIAL: CASOS (0.98)

func _casos() -> Array:
	if not partida.has("casos"):
		partida["casos"] = []
	return partida["casos"]


func _denuncia_investigable(d: Dictionary) -> bool:
	if String(d.get("tipo", "")) != "normal":
		return false
	var t := String(d["texto"]).to_lower()
	for k in Casos.INVESTIGABLES:
		if t.contains(k):
			return true
	return false


## Crea el caso: tres sospechosos, uno culpable. Cada sospechoso inocente se
## diferencia del culpable al menos en un rasgo, así que hacen falta las pistas.
func _abrir_caso(d: Dictionary) -> Dictionary:
	var cats: Array = Casos.RASGOS.keys()
	cats.shuffle()
	cats = cats.slice(0, 3)
	var culpable := {}
	for c in cats:
		var lista: Array = Casos.RASGOS[c]
		culpable[c] = lista[randi() % lista.size()]
	var nombres: Array = Casos.NOMBRES.duplicate()
	nombres.shuffle()
	var sospechosos := []
	for k in 3:
		var r := {}
		for c in cats:
			r[c] = culpable[c]
		sospechosos.append({"nombre": nombres[k], "rasgos": r})
	var pos_culpable := randi() % 3
	var otro := 0
	for k in 3:
		if k == pos_culpable:
			continue
		# Diferente en una categoría distinta para cada inocente (y quizá en otra más)
		var c_dif: String = cats[otro % cats.size()]
		otro += 1
		var opciones_r: Array = (Casos.RASGOS[c_dif] as Array).duplicate()
		opciones_r.erase(culpable[c_dif])
		sospechosos[k]["rasgos"][c_dif] = opciones_r[randi() % opciones_r.size()]
		if randf() < 0.4:
			var c2: String = cats[randi() % cats.size()]
			if c2 != c_dif:
				var o2: Array = (Casos.RASGOS[c2] as Array).duplicate()
				o2.erase(culpable[c2])
				sospechosos[k]["rasgos"][c2] = o2[randi() % o2.size()]
	var pasos: Array = []
	var pool: Array = range(Casos.PASOS.size())
	pool.shuffle()
	for k in 3:
		pasos.append({"paso": pool[k], "categoria": cats[k]})
	partida["contador_casos"] = int(partida.get("contador_casos", 0)) + 1
	var caso := {"id": "CASO-%d" % int(partida["contador_casos"]), "denuncia": d["texto"], "quien": d["quien"],
		"pasos": pasos, "hechos": 0, "pistas": [], "sospechosos": sospechosos, "culpable": pos_culpable,
		"estado": "abierto", "en_curso": false, "banda": randf() < 0.3 and String(d["texto"]).to_lower().contains("rob")}
	_casos().append(caso)
	_guardar_partida()
	return caso


func _mostrar_casos() -> void:
	var opciones := []
	var casos := _casos()
	for i in casos.size():
		var c: Dictionary = casos[i]
		var estado: String = {"abierto": "ABIERTO · %d de %d pistas" % [int(c["hechos"]), (c["pasos"] as Array).size()], "resuelto": "RESUELTO", "archivado": "ARCHIVADO"}.get(c["estado"], "")
		var resumen := String(c["denuncia"])
		if resumen.length() > 50:
			resumen = resumen.left(48) + "…"
		opciones.append({"texto": "%s · %s · «%s»" % [c["id"], estado, resumen], "accion": _mostrar_caso.bind(i)})
	opciones.append({"texto": "Volver a la comisaría", "accion": _mostrar_comisaria})
	var texto := "Casos de los detectives. Cada paso es un aviso al que mandas el coche de la Policía Judicial; cada paso da una pista. Con todas, acusa al culpable."
	if casos.is_empty():
		texto += "\n\nTodavía no hay casos. Pasa una denuncia de robo, estafa o agresión a la Policía Judicial."
	hud.mostrar_panel("POLICÍA JUDICIAL", texto, opciones, true, 120.0, 720.0)


func _texto_rasgos(r: Dictionary) -> String:
	var partes := []
	for c in r:
		partes.append(String(r[c]))
	return ", ".join(PackedStringArray(partes))


func _mostrar_caso(i: int) -> void:
	var casos := _casos()
	if i < 0 or i >= casos.size():
		_mostrar_casos()
		return
	var c: Dictionary = casos[i]
	var pasos: Array = c["pasos"]
	var texto := "%s · denuncia de %s:\n«%s»\n\nPistas:" % [c["id"], String(c["quien"]).to_lower(), c["denuncia"]]
	if (c["pistas"] as Array).is_empty():
		texto += "\n· ninguna todavía"
	for p in c["pistas"]:
		texto += "\n· " + String(p)
	texto += "\n\nSospechosos:"
	for s_ in c["sospechosos"]:
		texto += "\n· %s: %s" % [s_["nombre"], _texto_rasgos(s_["rasgos"])]
	if c.get("banda", false) and int(c["hechos"]) >= 2:
		texto += "\n\n¡Las huellas coinciden con otros robos del barrio: es una banda!"
	var opciones := []
	if c["estado"] == "abierto":
		if bool(c["en_curso"]):
			texto += "\n\nLos detectives tienen un paso en marcha (mira el aviso en el mapa)."
		elif int(c["hechos"]) < pasos.size():
			var paso: Dictionary = Casos.PASOS[int(pasos[int(c["hechos"])]["paso"])]
			opciones.append({"texto": "Mandar a los detectives: %s" % paso["titulo"], "accion": _lanzar_paso_caso.bind(i), "activo": not en_menu})
		for k in (c["sospechosos"] as Array).size():
			var sospe: Dictionary = c["sospechosos"][k]
			opciones.append({"texto": "Acusar a %s y detenerlo" % sospe["nombre"], "accion": _acusar.bind(i, k), "activo": not bool(c["en_curso"]) and not en_menu})
		opciones.append({"texto": "Archivar el caso", "accion": _archivar_caso.bind(i)})
	opciones.append({"texto": "Volver a los casos", "accion": _mostrar_casos})
	hud.mostrar_panel("CASO %s" % c["id"], texto, opciones, true, 120.0, 720.0)


func _lanzar_paso_caso(i: int) -> void:
	var c: Dictionary = _casos()[i]
	var paso: Dictionary = Casos.PASOS[int(c["pasos"][int(c["hechos"])]["paso"])]
	var l := _elegir_lugar(paso["lugar"])
	var nodo := int(l.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var d := {"titulo": "%s: %s" % [c["id"], paso["titulo"].to_lower()], "servicios": ["judicial"], "principal": "judicial",
		"urgencia": 9999.0, "intervencion": 9.0, "categoria": "control", "requeridas": {"judicial": 1},
		"info": ["Investigación de la denuncia: %s" % c["denuncia"]]}
	var inc = _nuevo_aviso(d, nodo, String(l.get("nombre", "")), "Policía Judicial")
	if inc == null:
		return
	inc.caso_id = String(c["id"])
	c["en_curso"] = true
	hud.notificar("%s: manda el coche de los detectives a %s." % [inc.id_incidente, l.get("nombre", "la zona")], Color("c39bd3"))
	_cerrar_comisaria()


func _indice_caso(id: String) -> int:
	var casos := _casos()
	for i in casos.size():
		if casos[i]["id"] == id:
			return i
	return -1


## Un paso terminado: pista nueva (o detención si era el paso final).
func _paso_caso_hecho(inc) -> void:
	var i := _indice_caso(inc.caso_id)
	if i < 0:
		return
	var c: Dictionary = _casos()[i]
	c["en_curso"] = false
	if inc.marcas.has("detencion_caso"):
		_cerrar_caso_detencion(c, inc)
		return
	var pasos: Array = c["pasos"]
	var k := int(c["hechos"])
	if k >= pasos.size():
		return
	var cat: String = pasos[k]["categoria"]
	var culpable: Dictionary = c["sospechosos"][int(c["culpable"])]["rasgos"]
	var pista: String = Casos.FRASE_PISTA[cat] % String(culpable[cat])
	(c["pistas"] as Array).append(pista)
	c["hechos"] = k + 1
	var paso: Dictionary = Casos.PASOS[int(pasos[k]["paso"])]
	inc.resultado = "%s %s" % [paso["radio"], pista]
	inc.resultado_bien = inc.resultado
	inc.resultado_mal = inc.resultado
	hud.notificar("%s · PISTA: %s" % [c["id"], pista], Color("c39bd3"))
	if int(c["hechos"]) >= pasos.size():
		hud.notificar("%s: ya tienes todas las pistas. Ve a la comisaría y acusa al culpable." % c["id"], Color("ffd700"))
	_guardar_partida()


func _acusar(i: int, k: int) -> void:
	var c: Dictionary = _casos()[i]
	var sospe: Dictionary = c["sospechosos"][k]
	if k != int(c["culpable"]):
		c["estado"] = "archivado"
		_sumar_reputacion(-1.0)
		hud.notificar("%s: %s tenía coartada. El caso se enfría y se archiva." % [c["id"], sospe["nombre"]], Color("ff8a65"))
		if randf() < 0.5:
			denuncias.append({"tipo": "normal", "quien": c["quien"], "texto": "Me han vuelto a robar. Seguro que es el mismo de la otra vez.", "llegada": tiempo_juego})
			hud.set_comisaria(denuncias.size())
		_guardar_partida()
		_mostrar_casos()
		return
	# Acertado: la policía va a detenerlo
	var l := _elegir_lugar(["edificio", "bar", "industrial", "plaza"])
	var nodo := int(l.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var banda: bool = c.get("banda", false)
	var d := {"titulo": "%s: %s de %s" % [c["id"], "redada contra la banda" if banda else "detención", sospe["nombre"]], "servicios": ["policia", "judicial"],
		"principal": "policia", "urgencia": 240.0, "intervencion": 12.0 if not banda else 16.0, "categoria": "robo",
		"requeridas": {"policia": 2 if banda else 1, "judicial": 1}, "info": ["Orden de detención contra %s (%s)" % [sospe["nombre"], _texto_rasgos(sospe["rasgos"])]]}
	var inc = _nuevo_aviso(d, nodo, String(l.get("nombre", "")), "Policía Judicial")
	if inc == null:
		return
	inc.caso_id = String(c["id"])
	inc.marcas.append("detencion_caso")
	c["en_curso"] = true
	hud.notificar("%s: ¡orden de detención! Manda a la policía y a los detectives a %s." % [c["id"], l.get("nombre", "la zona")], Color("ffd700"))
	_guardar_partida()
	_cerrar_comisaria()


func _cerrar_caso_detencion(c: Dictionary, inc) -> void:
	c["estado"] = "resuelto"
	var banda: bool = c.get("banda", false)
	var premio := 3000 if banda else 1500
	_cambiar_dinero(premio)
	_sumar_reputacion(4.0 if banda else 2.5)
	var nombre: String = c["sospechosos"][int(c["culpable"])]["nombre"]
	inc.resultado = ("Banda desarticulada: %s y tres cómplices detenidos. Recuperado lo robado." if banda else "%s detenido. Ha confesado y se ha recuperado lo robado.") % nombre
	inc.resultado_bien = inc.resultado
	inc.resultado_mal = inc.resultado
	inc.detenidos = maxi(inc.detenidos, 4 if banda else 1)
	stats["titular_especial"] = "La Policía Judicial de Miguelturra desarticula una banda de ladrones" if banda else "Resuelto el %s: detenido el autor de la denuncia" % c["id"]
	hud.notificar("¡%s RESUELTO! %s +%s" % [c["id"], inc.resultado, Hud.formato_euros(premio)], Color("ffd700"))
	_dar_logro("detective")
	_guardar_partida()


func _archivar_caso(i: int) -> void:
	_casos()[i]["estado"] = "archivado"
	_guardar_partida()
	_mostrar_casos()


## Al acabar el turno, los pasos que nadie ha empezado se aplazan.
func _aplazar_pasos_caso() -> void:
	for inc in incidentes:
		if inc.caso_id != "" and inc.activo() and inc.evento == "" and inc.tiempo_llegada < 0.0:
			var en_camino := false
			for v in inc.unidades:
				if is_instance_valid(v) and v.incidente == inc:
					en_camino = true
			if en_camino:
				continue
			inc.estado = "Resuelta"
			inc.evento = "terminado"
			inc.resultado = "Aplazado al siguiente turno."
			var i := _indice_caso(inc.caso_id)
			if i >= 0:
				_casos()[i]["en_curso"] = false


# ================================================================ INVESTIGACIONES (0.95)

func _estado_arco(id: String) -> Dictionary:
	var arcos: Dictionary = partida["arcos"]
	if not arcos.has(id):
		arcos[id] = {"etapa": 0, "dia_ult": 0, "cerrado": false}
	return arcos[id]


func _etapa_actual(id: String) -> Dictionary:
	var e := _estado_arco(id)
	var etapas: Array = Pueblo.ARCOS[id]["etapas"]
	if bool(e["cerrado"]) or int(e["etapa"]) >= etapas.size():
		return {}
	return etapas[int(e["etapa"])]


func _programar_arcos() -> void:
	for id in Pueblo.ARCOS:
		var arco: Dictionary = Pueblo.ARCOS[id]
		var e := _estado_arco(id)
		if bool(e["cerrado"]) or int(partida["dia"]) < int(arco["dia_min"]) or int(e["dia_ult"]) >= int(partida["dia"]):
			continue
		var etapa := _etapa_actual(id)
		if etapa.is_empty():
			continue
		if etapa["turno"] != "ambos" and etapa["turno"] != turno:
			hud.notificar("%s: la próxima pista llegará en un turno de %s." % [arco["nombre"], "NOCHE" if etapa["turno"] == "noche" else "DÍA"], Color("ffd166"))
			continue
		hud.notificar("Investigación en marcha: %s. Hoy puede haber novedades." % arco["nombre"], Color("ffd700"))
		if etapa["tipo"] == "denuncia":
			etapas_programadas.append(id)
			_programar(randf_range(60.0, 150.0), _llega_denuncia)
		else:
			_programar(randf_range(60.0, 180.0), _lanzar_etapa.bind(id))


func _lanzar_etapa(id: String) -> void:
	if en_menu or turno_terminando:
		return
	var etapa := _etapa_actual(id)
	if etapa.is_empty():
		return
	var lugar := _lugar_de_etapa(String(etapa.get("lugar", "")))
	var nodo := int(lugar.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var inc = _nuevo_aviso(etapa["def"], nodo, String(lugar.get("nombre", "")), "Investigación: %s" % Pueblo.ARCOS[id]["nombre"])
	inc.arco = id
	inc.etapa_arco = int(_estado_arco(id)["etapa"])
	if etapa["tipo"] == "gran":
		hud.notificar("¡%s! Es la gran operación de la investigación. Prepara a tus mejores unidades." % etapa["def"]["titulo"], Color("ffd700"))
	else:
		hud.notificar("INVESTIGACIÓN · %s: %s (%s)" % [Pueblo.ARCOS[id]["nombre"], etapa["def"]["titulo"], inc.id_incidente], Color("ffd700"))
	_sonido("alerta")
	_vibrar(0.7, 0.7, 0.8)
	_viaje_camara(inc.position)


func _lugar_de_etapa(lugar: String) -> Dictionary:
	if lugar == "":
		return _elegir_lugar(["plaza", "parque"])
	var exacto := _lugar(lugar) if not lugar in ["industrial", "parque", "monte"] else {}
	if not exacto.is_empty():
		return exacto
	return _elegir_lugar([lugar])


func _avanzar_arco(id: String, etapa_hecha: int) -> void:
	var e := _estado_arco(id)
	if int(e["etapa"]) != etapa_hecha or bool(e["cerrado"]):
		return
	var etapa: Dictionary = Pueblo.ARCOS[id]["etapas"][etapa_hecha]
	e["etapa"] = etapa_hecha + 1
	e["dia_ult"] = int(partida["dia"])
	if etapa.has("titular"):
		stats["titular_especial"] = etapa["titular"]
	if etapa.get("final", false):
		e["cerrado"] = true
		var premio := int(etapa.get("recompensa", 0))
		_cambiar_dinero(premio)
		_sumar_reputacion(float(etapa.get("reputacion", 0)))
		_dar_logro(String(etapa.get("logro", "")))
		hud.notificar("¡%s RESUELTA! Recompensa: +%s y mucha reputación." % [Pueblo.ARCOS[id]["nombre"].to_upper(), Hud.formato_euros(premio)], Color("ffd700"))
	elif etapa.has("avance"):
		hud.notificar(etapa["avance"], Color("ffd166"))
	_sonido("envio")
	_guardar_partida()


func _texto_investigaciones(corto: bool) -> String:
	var lineas := []
	for id in Pueblo.ARCOS:
		if int(partida["dia"]) < int(Pueblo.ARCOS[id]["dia_min"]) and not partida["arcos"].has(id):
			continue
		var e := _estado_arco(id)
		var total: int = Pueblo.ARCOS[id]["etapas"].size()
		if bool(e["cerrado"]):
			if not corto:
				lineas.append("· %s: RESUELTA" % Pueblo.ARCOS[id]["nombre"])
		else:
			var linea := "· %s: %d de %d pasos" % [Pueblo.ARCOS[id]["nombre"], int(e["etapa"]), total]
			var sig := _etapa_actual(id)
			if not sig.is_empty():
				if int(e["dia_ult"]) >= int(partida["dia"]):
					linea += " · seguirá mañana"
				else:
					linea += " · próxima pista: turno de %s" % {"dia": "DÍA", "noche": "NOCHE"}.get(String(sig["turno"]), "día o noche")
			lineas.append(linea)
	if lineas.is_empty():
		return ""
	return "Investigaciones:\n" + "\n".join(PackedStringArray(lineas))


# ================================================================ APOYO EXTERNO: GUARDIA CIVIL Y UME (0.95)

func _gran_emergencia(inc) -> bool:
	return (inc.categoria == "fuego" and inc.intensidad >= 3) or int(inc.requeridas.get("bomberos", 0)) >= 2 \
		or inc.heridos >= 3 or inc.arco != ""


func _pedir_externo(tipo: String, inc) -> void:
	_cerrar_panel()
	if not is_instance_valid(inc) or not inc.activo():
		return
	externos_usados[tipo] = int(externos_usados.get(tipo, 0)) + 1
	contador_externos += 1
	var v = Vehiculo.new()
	if tipo == "guardia_civil":
		v.configurar("Guardia Civil %d" % contador_externos, "policia", Color("2e7d4f"), "G", 62.0, red)
		v.nombre_tipo = "Guardia Civil"
		v.personal = 2
		v.equipo = ["chaleco", "antidisturbios", "alcoholimetro"]
		v.bono = "detenidos"
	else:
		v.configurar("Consorcio %d" % contador_externos, "bomberos", Color("d4a017"), "U", 48.0, red)
		v.nombre_tipo = "Bomberos del Consorcio Provincial (refuerzo de fuera)"
		v.personal = 6
		v.equipo = ["extincion", "tecnico", "busqueda"]
		v.bono = "rescate"
	v.tipo = tipo
	v.externo = true
	v.heridos = []
	v.indice_flota = -1
	v.nodo_base = nodo_salida
	v.colocar_en(nodo_salida)
	v.ha_llegado.connect(_on_unidad_llega)
	v.interceptado.connect(_on_interceptado)
	mundo.add_child(v)
	vehiculos.append(v)
	var quien := "La Guardia Civil manda una patrulla desde fuera del pueblo" if tipo == "guardia_civil" else "El Consorcio Provincial manda una dotación de refuerzo: tardará, pero llega con mucho personal y equipo"
	hud.notificar("%s (%s) para %s." % [quien, v.id_unidad, inc.id_incidente], Color("8fd3a0"))
	_enviar_unidad(v, inc)


# ================================================================ CADENA: COCHE SOSPECHOSO -> ROBO -> HUIDA (0.95)

func _iniciar_cadena(nodo: int) -> void:
	if en_menu or turno_terminando:
		return
	if nodo < 0:
		var l := _elegir_lugar(["comercio", "supermercado", "bar", "plaza"])
		nodo = _nodo_cerca(Vector2(float(l.get("x", 2600)), float(l.get("y", 2400))), 200.0)
	var d := {"titulo": "Coche sospechoso merodeando entre los comercios", "servicios": ["policia"], "principal": "policia",
		"urgencia": 100.0, "intervencion": 8.0, "categoria": "control", "info": ["Dos hombres en un coche gris que da vueltas despacio"],
		"resultado_bien": "Coche identificado: llevaban herramientas para forzar puertas. Denunciados y vigilados."}
	var inc = _nuevo_aviso(d, nodo, "", "Aviso de un vecino")
	inc.cadena = "sospechoso"
	_programar(110.0, _comprobar_sospechoso.bind(inc))


## Si nadie identifica al coche sospechoso, se va... y vuelve para robar.
func _comprobar_sospechoso(inc) -> void:
	if not is_instance_valid(inc) or not inc.activo() or inc.tiempo_llegada >= 0.0:
		return
	for v in vehiculos:
		if v.incidente == inc:
			return
	inc.estado = "Resuelta"
	inc.evento = "terminado"
	inc.resultado = "El coche sospechoso se ha ido sin que nadie lo identificara."
	hud.notificar("%s: el coche sospechoso se ha ido sin que nadie lo identificara..." % inc.id_incidente, COLOR_SISTEMA)
	_programar(randf_range(40.0, 80.0), _cadena_robo.bind(inc.nodo_real))


func _cadena_robo(nodo: int) -> void:
	if en_menu or turno_terminando:
		return
	var l := _elegir_lugar(["comercio", "supermercado", "gasolinera"])
	if nodo < 0:
		nodo = int(l.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var d := {"titulo": "Robo en %s: los ladrones siguen dentro" % l.get("nombre", "un comercio"), "servicios": ["policia"], "principal": "policia",
		"urgencia": 80.0, "intervencion": 10.0, "categoria": "robo", "info": ["Salta la alarma y se ve a dos personas dentro"],
		"resultado_bien": "Ladrones detenidos dentro del comercio."}
	var inc = _nuevo_aviso(d, nodo, String(l.get("nombre", "")), "Alarma conectada a la central")
	inc.cadena = "robo"
	_vibrar(0.5, 0.5, 0.5)


## Al llegar la policía al robo, los ladrones huyen en coche: empieza la persecución.
func _robo_huida(inc, v) -> bool:
	if sospechoso != null and is_instance_valid(sospechoso):
		return false
	var av = _crear_aviso_trafico(inc.nodo_real, "Ladrones huyendo en un coche", ["Acaban de robar en %s" % inc.titulo.trim_prefix("Robo en ").split(":")[0]])
	av.cadena = "huida"
	av.resultado_bien = "Ladrones detenidos tras la persecución."
	inc.en_lugar.erase(v)
	inc.en_escena.erase(v)
	inc.presentes["policia"] = maxi(0, int(inc.presentes.get("policia", 1)) - 1)
	inc.evento = "terminado"
	inc.estado = "Resuelta"
	inc.exito = true
	inc.resultado = "Los ladrones huyen en un coche: persecución en curso (%s)." % av.id_incidente
	v.estado = "Disponible"
	_retirar_en_camino(inc)
	_iniciar_persecucion(v, av)
	_radio(v, "¡Los ladrones salen corriendo y huyen en un coche! Vamos tras ellos.")
	return true


func _choque_huida(lugar: Vector2) -> void:
	var atrapado := randf() < 0.35
	var d := {"titulo": "Choque del coche de los ladrones", "servicios": ["ambulancia"], "principal": "ambulancia",
		"urgencia": 70.0, "intervencion": 12.0, "categoria": "atrapado" if atrapado else "medico", "traslado": true, "heridos": 2,
		"info": ["El coche de la huida se ha estrellado", "Dos heridos"], "requeridas": {"ambulancia": 1}}
	if atrapado:
		d["requeridas"]["bomberos"] = 1
		d["info"].append("Uno de ellos está atrapado en el coche")
	_nuevo_aviso(d, red.nodo_mas_cercano(lugar), "", "Aviso de la patrulla")


# ================================================================ METEOROLOGÍA

func _clima_de_menu() -> void:
	clima = "despejado"
	efectos.zona_evento = {}
	efectos.activo = false
	efectos.set_clima("despejado")


func _elegir_clima() -> void:
	if not bool(opciones["meteo"]):
		_poner_clima("despejado", false)
		return
	var pesos := {"despejado": 50.0, "lluvia": 18.0, "niebla": 8.0 if turno == "dia" else 16.0,
		"tormenta": 8.0, "calor": 14.0 if turno == "dia" else 0.0}
	_poner_clima(_sortear(pesos), false)
	hud.notificar("Parte meteorológico: %s." % String(CLIMAS[clima]["nombre"]).to_lower(), CLIMAS[clima]["color"])
	_programar(randf_range(280.0, 520.0), _cambio_clima)


func _sortear(pesos: Dictionary) -> String:
	var total := 0.0
	for k in pesos:
		total += float(pesos[k])
	var tirada := randf() * total
	for k in pesos:
		tirada -= float(pesos[k])
		if tirada <= 0.0 and float(pesos[k]) > 0.0:
			return k
	return pesos.keys()[0]


## A mitad del turno el tiempo puede cambiar.
func _cambio_clima() -> void:
	if en_menu or turno_terminando or not bool(opciones["meteo"]) or randf() > 0.45:
		return
	var nuevo := "despejado"
	if clima == "despejado":
		nuevo = _sortear({"lluvia": 3.0, "niebla": 2.0 if turno == "noche" else 1.0, "tormenta": 2.0, "calor": 2.0 if turno == "dia" else 0.0})
	elif clima == "lluvia" and randf() < 0.4:
		nuevo = "tormenta"
	_poner_clima(nuevo, true)


func _poner_clima(nuevo: String, avisar: bool) -> void:
	clima = nuevo
	efectos.set_clima(nuevo)
	hud.set_clima(CLIMAS[nuevo]["nombre"], CLIMAS[nuevo]["color"])
	_actualizar_trafico()
	if not avisar:
		return
	var textos := {
		"despejado": "Parte meteorológico: el tiempo mejora y el cielo se despeja.",
		"lluvia": "Parte meteorológico: empieza a llover. Las unidades irán más despacio y habrá más accidentes.",
		"niebla": "Parte meteorológico: banco de niebla. Las unidades irán más despacio.",
		"tormenta": "Parte meteorológico: ¡tormenta eléctrica! Cuidado con los rayos y la calzada mojada.",
		"calor": "Parte meteorológico: ola de calor. Atentos a los golpes de calor y los incendios.",
	}
	hud.notificar(textos.get(nuevo, ""), CLIMAS[nuevo]["color"])
	_sonido("alerta")


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
	_pitidos_localizacion(delta)
	if not pausa_tactica:
		_actualizar_eventos(delta)
		_vigilar_ambulancias(delta)
		_vigilar_recogidas(delta)
		_t_historias -= delta
		if _t_historias <= 0.0:
			_t_historias = 1.0
			_vigilar_historias()
	_ajustar_iconos()
	_vigilar_fluidez(delta)
	var hora := fmod(segundos_sim / 3600.0, 24.0)
	modulador.color = _color_hora(hora) * _tinte_clima()
	efectos.noche = _factor_noche(hora)
	efectos.zoom = camara.zoom.x
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
		_vigilar_denuncias()
		_radar_camuflado()
		for v in vehiculos:
			if v.estado == "Disponible":
				v.cansancio = maxf(0.0, v.cansancio - (4.0 if _tiene_mejora("gimnasio") else 2.0))
			elif v.estado == "Patrullando":
				v.cansancio = maxf(0.0, v.cansancio - 0.5)
	_comprobar_fin_turno()


## Más atascos en las horas punta del día; calles vacías de madrugada.
func _actualizar_trafico() -> void:
	var h := fmod(segundos_sim / 3600.0, 24.0)
	var f := 1.0
	if (h >= 8.0 and h < 9.5) or (h >= 13.5 and h < 15.0) or (h >= 18.0 and h < 20.0):
		f = 0.8
	elif h >= 23.0 or h < 6.0:
		f = 1.15
	f *= float(CLIMAS[clima]["velocidad"])
	for v in vehiculos:
		v.factor_trafico = f
	if sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.factor_trafico = f


## Los iconos se mantienen legibles aunque se aleje el mapa.
func _ajustar_iconos() -> void:
	var s := clampf(0.85 / camara.zoom.x, 0.8, 6.0)
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
	if tween_camara != null and tween_camara.is_valid():
		if v.length() < 0.2:
			return
		tween_camara.kill()
	camara.position += v * 650.0 * d / camara.zoom.x
	var z := Input.get_action_strength("zoom_mas") - Input.get_action_strength("zoom_menos")
	if absf(z) > 0.05:
		var nz := clampf(camara.zoom.x * (1.0 + z * 1.6 * d), 0.09, 2.2)
		camara.zoom = Vector2(nz, nz)
	camara.position = camara.position.clamp(Vector2.ZERO, tamano_mapa)


## Si el juego va muy lento varios segundos, baja la calidad gráfica solo.
func _vigilar_fluidez(delta: float) -> void:
	if opciones["calidad"] != "alta":
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	if Engine.get_frames_per_second() < 15:
		_t_fps_bajo += real
	else:
		_t_fps_bajo = 0.0
	if _t_fps_bajo > 6.0:
		_t_fps_bajo = 0.0
		opciones["calidad"] = "normal"
		_aplicar_opciones()
		_guardar_opciones()
		hud.notificar("El juego iba lento: he puesto la calidad gráfica en Normal (puedes cambiarla en Opciones).", Color("ffd166"))


## 0 de día, 1 de noche cerrada (para las farolas y los faros).
func _factor_noche(h: float) -> float:
	if h >= 21.0 or h < 6.0:
		return 1.0
	if h >= 19.0:
		return (h - 19.0) / 2.0
	if h < 8.0:
		return 1.0 - (h - 6.0) / 2.0
	return 0.0


func _tinte_clima() -> Color:
	match clima:
		"lluvia":
			return Color(0.82, 0.86, 0.95)
		"tormenta":
			return Color(0.68, 0.72, 0.85)
		"niebla":
			return Color(0.9, 0.92, 0.96)
		"calor":
			return Color(1.0, 0.96, 0.88)
	return Color.WHITE


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


## Ruta de cada unidad en emergencia: línea brillante con pulsos que avanzan
## hacia el destino y, al final, el tiempo que le falta para llegar.
func _dibujar_rutas() -> void:
	var ancho := 5.0 / camara.zoom.x
	var esc := clampf(1.0 / camara.zoom.x, 0.6, 3.5)
	var f := ThemeDB.fallback_font
	# Calles cortadas por obras o por las fiestas: rayas naranjas y blancas
	for o in obras:
		var a := red.pos(int(o[0]))
		var b := red.pos(int(o[1]))
		var largo := a.distance_to(b)
		var pasos := maxi(2, int(largo / 12.0))
		for k in pasos:
			var p1 := a.lerp(b, float(k) / pasos)
			var p2 := a.lerp(b, float(k + 1) / pasos)
			capa_rutas.draw_line(p1, p2, Color("ff8c1a") if k % 2 == 0 else Color.WHITE, ancho * 1.6)
		var m := (a + b) / 2.0
		capa_rutas.draw_set_transform(m + Vector2(0, -16) * esc, 0.0, Vector2(esc, esc))
		capa_rutas.draw_colored_polygon(PackedVector2Array([Vector2(-9, 6), Vector2(9, 6), Vector2(0, -10)]), Color("ff8c1a"))
		capa_rutas.draw_string(f, Vector2(-30, -14), "CORTADA" if o[3] == "" else "OBRAS", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("ffd166"))
		capa_rutas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for v in vehiculos:
		if v.ruta.is_empty() or not v.en_emergencia:
			continue
		var pts := PackedVector2Array([v.position])
		for n in v.ruta:
			pts.append(red.pos(n))
		if pts.size() < 2:
			continue
		var col: Color = COLOR_SERVICIO.get(v.servicio, Color.WHITE)
		capa_rutas.draw_polyline(pts, Color(col, 0.16), ancho * 3.0)
		capa_rutas.draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.4), ancho * 1.4)
		# Pulsos que avanzan por la ruta
		var largo := 0.0
		for k in range(1, pts.size()):
			largo += pts[k - 1].distance_to(pts[k])
		var separacion := 90.0
		var desfase := fmod(tiempo_juego * 160.0, separacion)
		var recorrido := 0.0
		var marca := desfase
		for k in range(1, pts.size()):
			var tramo := pts[k - 1].distance_to(pts[k])
			while marca <= recorrido + tramo:
				var punto := pts[k - 1].lerp(pts[k], (marca - recorrido) / maxf(tramo, 0.01))
				capa_rutas.draw_circle(punto, ancho * 0.9, Color(1, 1, 1, 0.95))
				marca += separacion
			recorrido += tramo
		var fin_ruta := pts[pts.size() - 1]
		capa_rutas.draw_circle(fin_ruta, ancho * 1.6, col)
		capa_rutas.draw_arc(fin_ruta, ancho * 2.4 + fmod(tiempo_juego, 1.0) * ancho * 3.0, 0.0, TAU, 24, Color(col, 1.0 - fmod(tiempo_juego, 1.0)), ancho * 0.5)
		# Etiqueta con el tiempo que falta
		if v.fase in ["ida", "buscando2", "traslado"]:
			var texto := "%s · %s" % [v.id_unidad, _texto_segundos(v.tiempo_restante())]
			capa_rutas.draw_set_transform(fin_ruta + Vector2(0, -34) * esc, 0.0, Vector2(esc, esc))
			var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0
			capa_rutas.draw_rect(Rect2(-w / 2.0, -20, w, 24), Color(0.02, 0.06, 0.15, 0.85))
			capa_rutas.draw_rect(Rect2(-w / 2.0, -20, w, 24), col, false, 2.0)
			capa_rutas.draw_string(f, Vector2(-w / 2.0 + 7, -2), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			capa_rutas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pequeño viaje de cámara hasta una emergencia grave y vuelta a donde estabas.
## Si mueves el joystick, se cancela.
func _viaje_camara(destino: Vector2) -> void:
	if en_menu or hud.ventana_abierta() or unidad_a_enviar != null:
		return
	if tween_camara != null and tween_camara.is_valid():
		return
	var origen := camara.position
	tween_camara = create_tween()
	if tween_camara.has_method("set_ignore_time_scale"):
		tween_camara.call("set_ignore_time_scale", true)
	tween_camara.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_camara.tween_property(camara, "position", destino, 0.9)
	tween_camara.tween_interval(1.6)
	tween_camara.tween_property(camara, "position", origen, 0.9)


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
	if pausa_comisaria:
		if event.is_action_pressed("cancelar") or event.is_action_pressed("abrir_comisaria") or event.is_action_pressed("pausa"):
			_cerrar_comisaria()
			get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed("abrir_comisaria"):
		_mostrar_comisaria()


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
	elif _puede_reasignar(v):
		texto += "\nEstá apoyando en %s: puedes sacarla y mandarla a otro aviso." % v.incidente.id_incidente
		var otros := []
		for inc in incidentes:
			if inc.activo() and inc.evento != "terminado" and inc != v.incidente and inc.tipo != "aviso_trafico":
				otros.append([v.tiempo_estimado(_destino_de(inc)), inc])
		otros.sort_custom(func(a, b): return a[0] < b[0])
		for par in otros:
			var inc = par[1]
			opciones.append({"texto": "Dejar %s e ir a %s · %s · llega en %s" % [v.incidente.id_incidente, inc.id_incidente, inc.titulo, _texto_segundos(par[0])],
				"accion": _reasignar.bind(v, inc)})
		opciones.append({"texto": "Dejar %s y volver a la base" % v.incidente.id_incidente, "accion": _retirar_apoyo.bind(v)})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel(v.id_unidad, texto, opciones)


## ¿Se puede sacar esta unidad del aviso en el que está? Sí, si solo está
## apoyando (tráfico, Protección Civil, primera respuesta), si va de camino,
## si es un VIR o moto sanitaria y ya hay ambulancia de traslado, o si sobra.
func _puede_reasignar(v) -> bool:
	if v.externo or v.efectivos() <= 0:
		return false
	var inc = v.incidente
	if inc == null or not is_instance_valid(inc) or not inc.activo():
		return false
	if String(inc.evento).begins_with("tramites") or inc.tipo == "aviso_trafico":
		return false
	if v.fase in ["ida", "buscando", "buscando2"]:
		return true
	if v.estado != "En intervención":
		return false
	if v.fase in ["apoyo", "primera_respuesta"] or inc.apoyos.has(v):
		return true
	if not inc.en_lugar.has(v):
		return false
	if v.bono in ["vir", "moto_sanitaria", "pma"]:
		for o in inc.en_lugar:
			if o != v and is_instance_valid(o) and o.servicio == "ambulancia" and not NO_TRASLADAN.has(o.bono):
				return true
	# Sobra: hay más unidades de su servicio de las que hacen falta
	return int(inc.presentes.get(v.servicio, 0)) > maxi(int(inc.requeridas.get(v.servicio, 0)), 1)


## Quita la unidad de su aviso actual (sin enviarla aún a ningún sitio).
func _soltar_de_aviso(v) -> void:
	var inc = v.incidente
	if inc == null or not is_instance_valid(inc):
		return
	inc.apoyos.erase(v)
	inc.en_escena.erase(v)
	inc.unidades.erase(v)
	if inc.en_lugar.has(v):
		inc.en_lugar.erase(v)
		inc.presentes[v.servicio] = maxi(0, int(inc.presentes.get(v.servicio, 1)) - 1)
	inc.registrar(_hora(segundos_sim), "%s deja el aviso por orden de la central" % v.id_unidad)
	v.incidente = null
	if inc.estado == "Unidad en camino":
		var queda := false
		for o in inc.unidades:
			if is_instance_valid(o) and o.incidente == inc and o.servicio == inc.servicio_necesario:
				queda = true
		if not queda:
			inc.estado = "Pendiente"


func _reasignar(v, nuevo) -> void:
	if not _puede_reasignar(v) or not nuevo.activo():
		hud.notificar("No es posible sacar %s ahora mismo." % v.id_unidad)
		return
	var viejo = v.incidente
	_soltar_de_aviso(v)
	v.estado = "Disponible"
	v.fase = ""
	_radio(v, "Recibido, central. Dejamos %s y vamos a %s." % [viejo.id_incidente, nuevo.id_incidente])
	if nuevo.tipo == "aviso_trafico":
		_enviar_desde_unidad(v, nuevo)
	else:
		_enviar_unidad(v, nuevo)


func _retirar_apoyo(v) -> void:
	if not _puede_reasignar(v):
		return
	var viejo = v.incidente
	_soltar_de_aviso(v)
	_radio(v, "Recibido. Dejamos %s y volvemos." % viejo.id_incidente)
	_regresar(v)
	_cerrar_panel()


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
			var aviso := " · ¡ESPERAN TUS ÓRDENES!" if inc.decision_pendiente else ""
			opciones.append({"texto": "%s · %s · %s%s" % [inc.id_incidente, inc.titulo, inc.estado, aviso], "accion": _mostrar_incidente.bind(inc)})
	var texto := "Elige una emergencia para ver los detalles."
	if obras.size() > 0:
		var cortadas := []
		for o in obras:
			if not cortadas.has(o[2]):
				cortadas.append(o[2])
		texto += "\nCalles cortadas: " + ", ".join(PackedStringArray(cortadas))
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
	if inc.t_ambulancia >= 0.0:
		texto += "\n¡HERIDO ESPERANDO AMBULANCIA! Aguanta: %s" % _texto_segundos(inc.t_ambulancia)
	elif inc.evento == "en_curso" and inc.faltan_apoyo() > 0:
		texto += "\nPiden refuerzos (no es obligatorio): sin ellos van más lentos"
	for c in inc.confirmados:
		texto += "\nCONFIRMADO: %s" % c
	for k in range(maxi(0, inc.informacion.size() - 3), inc.informacion.size()):
		texto += "\n· %s" % inc.informacion[k]
	if inc.cronologia.size() > 0:
		texto += "\nÚltimos hechos:"
		for k in range(maxi(0, inc.cronologia.size() - 2), inc.cronologia.size()):
			texto += "\n  %s  %s" % [inc.cronologia[k][0], inc.cronologia[k][1]]
	var opciones := []
	if inc.decision_pendiente and not inc.decision_actual.is_empty():
		opciones.append({"texto": ">> DAR ÓRDENES: %s" % inc.decision_actual["titulo"], "accion": _mostrar_decision.bind(inc, inc.decision_actual)})
	if inc.activo() and not String(inc.evento).begins_with("tramites") and inc.evento != "terminado":
		var usados_gc := int(externos_usados.get("guardia_civil", 0))
		if inc.servicios.has("policia") and usados_gc < 2:
			opciones.append({"texto": "Pedir apoyo a la Guardia Civil (viene desde fuera del pueblo) · quedan %d" % (2 - usados_gc),
				"accion": _pedir_externo.bind("guardia_civil", inc)})
		if _gran_emergencia(inc) and int(externos_usados.get("ume", 0)) < 1:
			opciones.append({"texto": "Pedir refuerzo de bomberos del Consorcio Provincial: tarda, pero es muy potente",
				"accion": _pedir_externo.bind("ume", inc)})
	if inc.activo():
		var destino: int = inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado
		var lista := []
		for v in vehiculos:
			var libre: bool = v.disponible()
			var util: bool = inc.requeridas.has(v.servicio) or inc.servicios.has(v.servicio)
			var t: float = v.tiempo_estimado(destino)
			# Orden: útiles y libres primero, luego otras libres, luego ocupadas
			var orden := t + (0.0 if util else 10000.0) + (0.0 if libre else 100000.0)
			lista.append([orden, v, libre, util, t])
		lista.sort_custom(func(a, b): return a[0] < b[0])
		for item in lista:
			var v = item[1]
			var etiqueta := "Enviar %s (%s) · llega en %s" % [v.id_unidad, v.nombre_servicio(), _texto_segundos(item[4])]
			if v.estado == "Regresando":
				etiqueta += " · desde la vuelta (%d/%d servicios)" % [v.servicios_seguidos, v.limite_seguidos()]
			if v.estado == "Reponiendo material":
				etiqueta = "%s sin material: volviendo a la base a reponer" % v.id_unidad
			if not item[3]:
				etiqueta += " · como apoyo"
			if v.cansancio >= 50.0:
				etiqueta += " · cansados (%d%%)" % int(v.cansancio)
			if not item[2] and _puede_reasignar(v) and v.incidente != inc:
				etiqueta = "Sacar %s de %s y enviarla aquí · llega en %s" % [v.id_unidad, v.incidente.id_incidente, _texto_segundos(item[4])]
				opciones.append({"texto": etiqueta, "accion": _reasignar.bind(v, inc)})
				continue
			if not item[2]:
				etiqueta = "%s no disponible (%s)" % [v.id_unidad, v.estado]
			opciones.append({"texto": etiqueta, "accion": _enviar_unidad.bind(v, inc), "activo": item[2]})
	opciones.append({"texto": "Volver al mapa", "accion": _cerrar_panel})
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, inc.titulo], texto, opciones)
	hud.mirar_lugar(inc)


# ================================================================ LLAMADAS

## solo_relacionadas = true: solo suena si hay una llamada relacionada en cola
## (así no se encadenan llamadas nuevas nada más colgar).
func _sonar_llamada(solo_relacionadas: bool = false) -> void:
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
	if turno_terminando or solo_relacionadas:
		return
	llamada_rel_inc = null
	llamada_historia = {}
	llamada_desenlace = ""
	llamada_coletillas = []
	# Historias (menos frecuentes que las llamadas sencillas)
	var historias := []
	for h in todas_historias:
		var solo: String = h.get("solo_evento", "")
		var puede := true
		for sv in h.get("necesita", []):
			if not _flota_tiene(sv):
				puede = false
		if h.has("rara") and randf() > float(h["rara"]):
			puede = false
		if puede and (h["turno"] == turno or h["turno"] == "ambos") and (solo == "" or solo == evento_hoy):
			historias.append(h)
	if not historias.is_empty() and randf() < 0.45:
		_preparar_historia(_elegir_historia(historias))
	else:
		var posibles := []
		for d in todas_llamadas:
			if (d["turno"] == turno or d["turno"] == "ambos") and d["id"] != ultima_llamada_id and not llamadas_turno.has(d["id"]):
				posibles.append(d)
		if posibles.is_empty():
			# Ya han salido todas este turno: se empieza de nuevo
			llamadas_turno.clear()
			for d in todas_llamadas:
				if (d["turno"] == turno or d["turno"] == "ambos") and d["id"] != ultima_llamada_id:
					posibles.append(d)
		if posibles.is_empty():
			return
		llamada_datos = posibles[randi() % posibles.size()]
		ultima_llamada_id = llamada_datos["id"]
		llamadas_turno.append(llamada_datos["id"])
		llamada_lugar = _elegir_lugar(llamada_datos["referencias"])
		var pers: Dictionary = Preguntas.PERSONALIDADES[randi() % Preguntas.PERSONALIDADES.size()]
		llamada_perfil = String(llamada_datos["llamante"])
		if pers["nombre"] != "normal" and not llamada_datos.get("falsa", false):
			llamada_perfil += " · " + String(pers["nombre"])
			llamada_coletillas = pers["coletillas"]
		llamada_calma = clampi(int(llamada_datos.get("calma_inicial", 30)) + int(pers["calma"]), 5, 95)
		llamada_vars = {"lugar": llamada_lugar.get("nombre", "la plaza"), "calle": llamada_lugar.get("calle", "una calle del centro")}
	_hacer_sonar()


func _hacer_sonar() -> void:
	llamada_sonando = true
	hora_llamada = _hora(segundos_sim)
	contador_llamadas += 1
	var extra := " · posible relación con %s" % llamada_rel_inc.id_incidente if llamada_rel_inc != null else ""
	hud.mostrar_aviso_llamada("Localidad: Miguelturra · %s%s" % [hora_llamada, extra], SEGUNDOS_PARA_COLGAR)
	hud.notificar("Llamada entrante al 112", COLOR_LLAMADA)
	_sonido("llamada")
	_vibrar(0.6, 0.4, 0.7)
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
		_sumar_reputacion(-1.5)
		hud.notificar("La persona ha colgado: llamada perdida (-300 €).", COLOR_LLAMADA)
		_programar(3.0, _sonar_llamada.bind(true))


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
	llamada.coletillas = llamada_coletillas
	var apertura := ""
	if llamada_rel_inc == null and randf() < 0.45:
		apertura = String(Preguntas.APERTURAS[randi() % Preguntas.APERTURAS.size()])
	llamada.iniciar(llamada_datos, llamada_vars, llamada_desenlace, llamada_calma, apertura)
	var cat := "medico"
	if llamada_datos.has("incidente"):
		cat = String(llamada_datos["incidente"].get("categoria", "medico"))
	llamada.preparar_extras(Preguntas.PREGUNTAS, cat)
	hud.abrir_llamada()
	_aplicar_escala()
	_refrescar_llamada()
	_empezar_localizacion()
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
		Incidente.NOMBRES_PRECISION[llamada.precision], datos_vistos, textos, llamada.precision)


# ================================================================ LOCALIZACIÓN DE LA LLAMADA (0.97)
## Al coger la llamada, el sistema localiza el teléfono: un fijo da la calle
## del abonado en pocos segundos; un móvil, solo una zona (AML). Si se corta
## la llamada, se sigue rastreando el origen durante un rato.

func _empezar_localizacion() -> void:
	llamada_desvio = Vector2.from_angle(randf() * TAU) * 200.0
	if llamada_rel_inc != null or llamada_datos.get("falsa", false) and randf() < 0.5:
		hud.set_localizando("", 0.0)
		localizando = false
		return
	llamada_linea = String(llamada_datos.get("linea", "fijo" if randf() < 0.3 else "movil"))
	var dur := 4.0 if llamada_linea == "fijo" else randf_range(7.0, 11.0)
	localizando = true
	_t_pitido = 0.0
	var centro := _pos_llamada()
	var etiqueta := "LOCALIZANDO… LÍNEA FIJA" if llamada_linea == "fijo" else "LOCALIZANDO… MÓVIL (AML)"
	hud.set_localizando(etiqueta, dur)
	efectos.rastreo("llamada", centro + llamada_desvio * (0.0 if llamada_linea == "fijo" else 1.0), 1100.0, 140.0 if llamada_linea == "fijo" else 380.0, dur, etiqueta)
	_programar(dur, _fin_localizacion.bind(contador_llamadas))


func _pos_llamada() -> Vector2:
	var nodo := int(llamada_lugar.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	if llamada_linea == "fijo":
		return Vector2(float(llamada_lugar.get("x", red.pos(nodo).x)), float(llamada_lugar.get("y", red.pos(nodo).y)))
	return red.pos(nodo)


func _fin_localizacion(numero: int) -> void:
	localizando = false
	if llamada == null or numero != contador_llamadas:
		return
	if llamada_datos.get("falsa", false):
		hud.set_localizando("Localizada: %s" % ("línea fija" if llamada_linea == "fijo" else "zona del móvil"), -1.0)
		efectos.rastreo("llamada", _pos_llamada(), 380.0, 380.0, 0.1, "LOCALIZADA", 2.5)
		return
	if llamada_linea == "fijo":
		llamada.localizar(2)
		var dato := "Línea fija: el abonado vive en %s" % llamada_vars.get("calle", "el centro")
		if not llamada.informacion.has(dato):
			llamada.informacion.append(dato)
		hud.set_localizando("LÍNEA FIJA · %s" % llamada_vars.get("calle", ""), -1.0)
		efectos.rastreo("llamada", _pos_llamada(), 140.0, 140.0, 0.1, "LÍNEA FIJA LOCALIZADA", 3.0)
	else:
		llamada.localizar(1)
		if not llamada.informacion.has("Móvil localizado por AML: zona aproximada"):
			llamada.informacion.append("Móvil localizado por AML: zona aproximada")
		hud.set_localizando("MÓVIL · zona aproximada (radio 400 m)", -1.0)
		efectos.rastreo("llamada", _pos_llamada() + llamada_desvio, 380.0, 380.0, 0.1, "ZONA DEL MÓVIL", 3.0)
	_sonido("radio")
	hud.actualizar_localizacion(Incidente.NOMBRES_PRECISION[llamada.precision], llamada.precision)
	var datos_vistos: Array = llamada.informacion.duplicate()
	for c in llamada.confirmados:
		datos_vistos.append("CONFIRMADO: " + c)
	hud.actualizar_datos(datos_vistos)


## Tras cortarse la llamada, se sigue rastreando el teléfono.
func _rastrear_incidente(inc, linea: String) -> void:
	var objetivo := 3 if linea == "fijo" else 2
	if inc.precision >= objetivo:
		return
	var dur := randf_range(20.0, 40.0)
	var r0: float = inc.radio_visible() if inc.radio_visible() > 0.0 else 900.0
	inc.informacion.append("Llamada cortada: rastreando el origen del %s" % ("teléfono fijo" if linea == "fijo" else "móvil"))
	inc.registrar(_hora(segundos_sim), "Se corta la llamada: empieza el rastreo")
	efectos.rastreo(inc.id_incidente, inc.pos_exacta if objetivo == 3 else inc.pos_calle, r0, 30.0 if objetivo == 3 else 140.0, dur, "RASTREANDO %s…" % inc.id_incidente)
	_consejo("rastreo", "Si se corta la llamada, la central sigue rastreando el teléfono: en unos segundos la localización mejora sola. Puedes mandar ya una unidad a la zona.")
	_programar(dur, _fin_rastreo.bind(inc, objetivo))


func _fin_rastreo(inc, objetivo: int) -> void:
	if not is_instance_valid(inc) or not inc.activo():
		return
	if inc.precision < objetivo:
		inc.precision = objetivo
		inc.actualizar_posicion()
		inc.nodo_aproximado = red.nodo_mas_cercano(inc.posicion_aproximada())
	inc.registrar(_hora(segundos_sim), "Rastreo completado: %s" % inc.texto_precision())
	hud.notificar("%s: rastreo completado · %s" % [inc.id_incidente, inc.texto_precision()], Color("3ddc84"))
	_sonido("radio")
	efectos.rastreo(inc.id_incidente, inc.posicion_aproximada(), inc.radio_visible() + 30.0, inc.radio_visible() + 30.0, 0.1, "LOCALIZADO", 3.0)
	# Las unidades que iban a la zona aproximada corrigen el rumbo
	for v in inc.unidades:
		if is_instance_valid(v) and v.incidente == inc and v.fase == "ida":
			v.ir_a(inc.nodo_real if inc.precision >= 3 else inc.nodo_aproximado)


func _pitidos_localizacion(delta: float) -> void:
	if not localizando or llamada == null:
		return
	_t_pitido -= delta / maxf(Engine.time_scale, 0.01)
	if _t_pitido <= 0.0:
		_t_pitido = 0.55
		_sonido("pitido")


func _elegir_opcion(indice: int) -> void:
	if llamada == null:
		return
	_sonido("click")
	llamada.elegir(indice)
	# Si la persona está al borde del pánico, puede colgar o cortarse
	if not llamada.terminada and llamada.calma <= 8 and llamada_rel_inc == null and not llamada_datos.get("falsa", false) and randf() < 0.3:
		llamada.cortada = true
		llamada.terminada = true
		hud.notificar("La persona ha colgado de los nervios... Se rastrea el teléfono.", COLOR_LLAMADA)
	if llamada.terminada:
		_terminar_llamada()
	else:
		_refrescar_llamada()


func _terminar_llamada() -> void:
	hud.cerrar_llamada()
	_aplicar_escala()
	localizando = false
	efectos.quitar_rastreo("llamada")
	var cortada: bool = llamada != null and llamada.cortada
	# Llamada relacionada: se une al incidente que ya existe
	if llamada_rel_inc != null:
		var inc_rel = llamada_rel_inc
		llamada_rel_inc = null
		if is_instance_valid(inc_rel):
			_unir_llamada(inc_rel, llamada)
		llamada = null
		_programar(2.0, _sonar_llamada.bind(true))
		return
	if llamada_datos.get("falsa", false):
		stats["falsas"] += 1
		_cambiar_dinero(200)
		hud.notificar("Llamada sin emergencia real: no se crea ningún incidente (+200 €).", Color("9fb3c8"))
		llamada = null
		_programar(2.0, _sonar_llamada.bind(true))
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
	inc.heridos = int(d.get("heridos", 1))
	inc.intensidad = int(d.get("intensidad", 1))
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
	for m in d.get("marcas", []):
		if not inc.marcas.has(m):
			inc.marcas.append(m)
	inc.precision = llamada.precision
	inc.calma_final = llamada.calma
	inc.nodo_real = nodo
	inc.pos_exacta = red.pos(nodo)
	inc.pos_calle = Vector2(float(llamada_lugar.get("x", inc.pos_exacta.x)), float(llamada_lugar.get("y", inc.pos_exacta.y)))
	inc.radio_calle = 140.0
	inc.pos_zona = inc.pos_exacta + llamada_desvio
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
	if cortada:
		_rastrear_incidente(inc, llamada_linea)
	_quitar_servicios_sin_flota(inc)
	_mostrar_incidente(inc)
	_consejo("incidente", "Elige en la lista qué unidad enviar y pulsa X. Fíjate en los colores del hexágono: blanco ambulancia, azul policía, rojo bomberos.")
	_programar(2.0, _sonar_llamada.bind(true))


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
	if inc.historia != null:
		_procesar_historia(inc, "marca")
		if not inc.decision_pendiente and inc.evento == "decision":
			_continuar_tras_decision(inc)
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
		if cuando == "llegada_bono" and ev.get("bono", "") != servicio:
			continue
		if cuando == "tiempo" and tiempo_juego - inc.tiempo_creacion < float(ev.get("segundos", 0.0)):
			continue
		var ds: Array = ev.get("desenlaces", [])
		if ds.size() > 0 and not ds.has(inc.desenlace):
			continue
		if ev.has("si_marca") and not inc.marcas.has(ev["si_marca"]):
			continue
		if ev.has("sin_marca") and inc.marcas.has(ev["sin_marca"]):
			continue
		if ev.get("solo_si_decision", false) and not inc.decision_pendiente:
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
	for otro in ev.get("excluye", []):
		inc.eventos_hechos.append(otro)
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
		_sonar_llamada(true)
	if ev.get("resuelve_decision", false) and inc.decision_pendiente:
		# Lo que ha pasado responde a la pregunta que esperaba la unidad
		inc.decision_pendiente = false
		inc.decision_actual = {}
		if hud.panel_abierto() and hud.panel_titulo.text.begins_with(inc.id_incidente):
			hud.cerrar_panel()
	if ev.has("siguiente"):
		_ejecutar_evento_por_id(inc, ev["siguiente"])
	if ev.has("decision"):
		_mostrar_decision(inc, ev["decision"])


## Si no tienes GEO, UME o detectives, el aviso no los pide (lo resuelven
## los demás, aunque peor).
func _quitar_servicios_sin_flota(inc) -> void:
	for sv in ["geo", "ume", "judicial"]:
		if inc.requeridas.has(sv) and not _flota_tiene(sv):
			inc.requeridas.erase(sv)
			inc.servicios.erase(sv)
			inc.marcas.append("sin_" + sv)
			if inc.servicio_necesario == sv:
				inc.servicio_necesario = "bomberos" if sv == "ume" else "policia"
				inc.requeridas[inc.servicio_necesario] = maxi(int(inc.requeridas.get(inc.servicio_necesario, 0)), 1)
				if not inc.servicios.has(inc.servicio_necesario):
					inc.servicios.append(inc.servicio_necesario)
	if inc.requeridas.is_empty():
		inc.requeridas[inc.servicio_necesario] = 1


func _flota_tiene(sv: String) -> bool:
	for v in vehiculos:
		if is_instance_valid(v) and v.servicio == sv and not v.externo:
			return true
	return false


func _aplicar_efectos_historia(inc, e: Dictionary) -> void:
	if e.is_empty():
		return
	if e.has("requiere"):
		for sv in e["requiere"]:
			inc.requeridas[sv] = maxi(int(inc.requeridas.get(sv, 0)), int(e["requiere"][sv]))
			if not inc.servicios.has(sv):
				inc.servicios.append(sv)
	if e.has("requiere"):
		_quitar_servicios_sin_flota(inc)
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
	if e.has("heridos"):
		inc.heridos = maxi(inc.heridos, int(e["heridos"]))


func _mostrar_decision(inc, dec: Dictionary) -> void:
	inc.decision_pendiente = true
	inc.decision_actual = dec
	inc.t_recordar_decision = 0.0
	var opciones := []
	for o in dec["opciones"]:
		opciones.append({"texto": o["texto"], "accion": _decision_historia.bind(inc, o)})
	_sonido("alerta")
	hud.mostrar_panel("%s · %s" % [inc.id_incidente, dec["titulo"]], "La unidad espera tus órdenes.\n" + inc.titulo, opciones)
	hud.mirar_lugar(inc)
	_consejo("decision", "A veces las unidades te piden órdenes en el lugar. Lo que decidas cambia cómo termina la historia.")


func _decision_historia(inc, opcion: Dictionary) -> void:
	hud.cerrar_panel()
	if not is_instance_valid(inc):
		return
	inc.decision_pendiente = false
	inc.decision_actual = {}
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
		if inc.decision_pendiente and inc.activo():
			inc.t_recordar_decision += 1.0
			if inc.t_recordar_decision >= 20.0 and not hud.ventana_abierta():
				inc.t_recordar_decision = 0.0
				hud.notificar("%s: la unidad sigue esperando tus órdenes. Pulsa Triángulo y elige «Dar órdenes»." % inc.id_incidente, Color("ffd166"))
				_sonido("alerta")


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
		if regla.get("fallecido", false):
			inc.fallecidos = maxi(inc.fallecidos, 1)
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
	elif v.servicio == "proteccion_civil":
		color = COLOR_RADIO_PC
	hud.notificar("%s: «%s»" % [v.id_unidad, mensaje], color)
	efectos.burbuja(v, mensaje, color)
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
	if v.aereo:
		if not v.en_movimiento and v.position.distance_to(red.pos(v.nodo_base)) < 60.0:
			v.espera_despegue = Vehiculo.DESPEGUE
		_cambiar_dinero(-Catalogo.COSTE_VUELO)
		v.ir_a(destino)
		_radio(v, "Recibido, central. Despegamos hacia %s (combustible: %s)." % [inc.id_incidente, Hud.formato_euros(Catalogo.COSTE_VUELO)])
		_consejo("helicoptero", "Los helicópteros vuelan en línea recta y no les afecta el tráfico, pero tardan 10 segundos en despegar y cada salida cuesta combustible. Compensan en avisos lejos del pueblo.")
		_cerrar_panel()
		return
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
				_programar(TIEMPO_BUSQUEDA[inc.precision] * (0.35 if v.aereo else 1.0), _fin_busqueda.bind(v))
				if v.aereo:
					_radio(v, "Sobrevolamos la zona buscando el lugar desde el aire.")
			else:
				_comenzar_intervencion(v)
		"buscando2":
			_comenzar_intervencion(v)
		"calabozo":
			_detenidos_en_calabozo(v)
		"recoger_presos":
			var lleva := mini(_plazas_detenidos(v), int(partida.get("calabozo", 0)))
			partida["calabozo"] = int(partida.get("calabozo", 0)) - lleva
			hud.set_calabozo(int(partida["calabozo"]), _plazas_calabozo())
			if lleva <= 0:
				_regresar(v)
			else:
				v.detenidos_a_bordo = lleva
				v.fase = "carcel"
				v.estado = "Trasladando a prisión"
				_radio(v, "Llevamos %d presos al centro penitenciario." % lleva)
				v.ir_a(nodo_salida)
		"carcel":
			_radio(v, "%d presos entregados en el centro penitenciario. Volvemos." % v.detenidos_a_bordo)
			v.detenidos_a_bordo = 0
			_regresar(v)
		"traslado":
			v.fase = "hospital"
			_radio(v, "%s en el Hospital General de Ciudad Real." % ("Paciente entregado" if v.pacientes_a_bordo <= 1 else "%d pacientes entregados" % v.pacientes_a_bordo))
			v.pacientes_a_bordo = 0
			_programar(6.0, _regresar.bind(v))
		"regreso":
			if v.externo:
				hud.notificar("%s vuelve a su base. ¡Gracias por el apoyo!" % v.id_unidad, Color("8fd3a0"))
				vehiculos.erase(v)
				if seleccion == v:
					seleccion = null
				if unidad_a_enviar == v:
					_cancelar_envio()
				v.queue_free()
				return
			var reponia: bool = v.estado == "Reponiendo material"
			v.servicios_seguidos = 0
			v.estado = "Disponible" if v.efectivos() > 0 else "Sin personal"
			v.fase = ""
			v.incidente = null
			_radio(v, "Material repuesto. En base y disponibles." if reponia else "En base y disponibles.")


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
	if inc.recogida != "" and inc.activo():
		_cargar_recogida(v, inc)
		return
	if not inc.activo() or inc.evento == "terminado":
		_radio(v, "En el lugar. La situación ya está controlada, volvemos.")
		_programar(4.0, _regresar.bind(v))
		return
	if not inc.en_escena.has(v):
		inc.en_escena.append(v)
	inc.llegadas[v.id_unidad] = tiempo_juego
	if String(inc.evento).begins_with("tramites"):
		if v.servicio == "policia" and inc.evento == "tramites_espera":
			inc.en_lugar.append(v)
			inc.presentes["policia"] = 1
			_iniciar_tramites(inc, v)
		else:
			_radio(v, "En el lugar. La policía se encarga de los trámites; nos retiramos.")
			_programar(4.0, _regresar.bind(v))
		return
	if inc.cadena == "robo" and v.servicio == "policia" and not v.aereo and _robo_huida(inc, v):
		return
	if v.bono == "heli_policia" and inc.categoria in ["pelea", "robo", "control"] and inc.historia == null:
		# El helicóptero no puede detener: vigila desde el aire y guía a las patrullas
		if not inc.apoyos.has(v):
			inc.apoyos.append(v)
		v.fase = "apoyo"
		_radio(v, "Helicóptero sobre la zona: los tenemos localizados desde el aire. Hace falta una patrulla en tierra para actuar.")
		if int(inc.presentes.get("policia", 0)) == 0 and not inc.refuerzos_avisados.has("policia_tierra"):
			inc.refuerzos_avisados["policia_tierra"] = 1
			hud.notificar("%s: el helicóptero vigila, pero necesitas una patrulla en tierra." % inc.id_incidente, Color("ffd166"))
		return
	if v.servicio == "proteccion_civil" and not inc.requeridas.has(v.servicio):
		# Protección Civil se queda hasta el final: acordona, atiende y acelera el trabajo
		if not inc.apoyos.has(v) and int(inc.presentes.get(inc.servicio_necesario, 0)) == 0:
			inc.apoyos.append(v)
			_radio(v, "Protección Civil en el lugar. Atendemos a los afectados hasta que llegue %s." % NOMBRES_SERVICIO.get(inc.servicio_necesario, "el servicio adecuado").to_lower())
		else:
			_radio(v, "Protección Civil en el lugar: acordonamos la zona y ayudamos en lo que haga falta.")
		_consejo("proteccion_civil", "Protección Civil no sustituye a nadie, pero se queda hasta el final ayudando: todo va más rápido y la situación empeora más despacio.")
		return
	if inc.historia != null and v.bono != "":
		_procesar_historia(inc, "llegada_bono", v.bono)
	if v.servicio == "geo" and not inc.requeridas.has("geo") and inc.historia == null and inc.arco == "" and not inc.marcas.has("geo_avisado"):
		inc.marcas.append("geo_avisado")
		_sumar_reputacion(-0.5)
		hud.notificar("Los vecinos critican el despliegue: un blindado del GEO para %s parece exagerado." % inc.titulo.to_lower(), Color("ffb347"))
	if not inc.requeridas.has(v.servicio):
		if inc.historia != null:
			_procesar_historia(inc, "llegada", v.servicio)
		# Primera respuesta: si aún no ha llegado el servicio principal, se queda
		# atendiendo (la situación empeora más despacio) hasta que llegue.
		if int(inc.presentes.get(inc.servicio_necesario, 0)) == 0:
			v.fase = "primera_respuesta"
			inc.apoyos.append(v)
			_radio(v, "Somos los primeros en llegar. Atendemos y tranquilizamos a los afectados hasta que llegue %s." % NOMBRES_SERVICIO.get(inc.servicio_necesario, "el servicio adecuado").to_lower())
			inc.registrar(_hora(segundos_sim), "%s atiende como primera respuesta" % v.id_unidad)
			_consejo("primera_respuesta", "Si no tienes la unidad adecuada libre, puedes mandar otra (por ejemplo, la policía) para que atienda mientras tanto: la situación empeora más despacio.")
			return
		# Unidad de apoyo: se queda hasta el final ayudando (tráfico, zona, heridos leves)
		v.fase = "apoyo"
		if not inc.apoyos.has(v):
			inc.apoyos.append(v)
		match v.servicio:
			"policia":
				_radio(v, "En el lugar. Cortamos el tráfico y despejamos el paso para que trabajen más rápido.")
			"ambulancia":
				_radio(v, "En el lugar. Atendemos a los afectados leves.")
			_:
				_radio(v, "En el lugar. Asegurando la zona.")
		_consejo("apoyo", "Las unidades de apoyo se quedan hasta el final: la policía organiza el tráfico y todo va más rápido. Al terminar, se van todas.")
		return
	inc.en_lugar.append(v)
	inc.presentes[v.servicio] = int(inc.presentes.get(v.servicio, 0)) + 1
	if v.servicio == inc.servicio_necesario:
		_liberar_apoyos(inc, v)
	if v.servicio == inc.servicio_necesario and inc.tiempo_llegada < 0.0:
		inc.tiempo_llegada = tiempo_juego
	_consejo("lugar", "Ya hay unidades en el lugar: abre la emergencia (Triángulo o con la mira) y a la izquierda verás lo que está pasando. Más personal y mejor equipo hacen que vaya más rápido.")
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
			if v.servicio == "ambulancia" and inc.t_ambulancia >= 0.0:
				_radio(v, "Ambulancia en el lugar. Nos hacemos cargo del herido.")
			elif v.servicio == "ambulancia" and not NO_TRASLADAN.has(v.bono) and _vir_en(inc) != null:
				var vir = _vir_en(inc)
				_radio(v, "Ambulancia de traslado en el lugar. Nos hacemos cargo del paciente.")
				_radio(vir, "Ha llegado la ambulancia. Seguimos apoyando; si nos necesitas en otro aviso, mándanos (Cuadrado en la unidad).")
				_consejo("vir_libre", "Cuando llega la ambulancia de traslado, el VIR o la moto sanitaria quedan de apoyo: puedes sacarlos y mandarlos a otro aviso desde la unidad o desde la otra emergencia.")
			elif inc.refuerzos_avisados.has(v.servicio):
				_radio(v, "¡Refuerzos en el lugar! Ahora irá más rápido.")
			else:
				_radio(v, "Nos unimos a la intervención.")


## Cuando llega el servicio principal, las unidades de primera respuesta se van.
func _liberar_apoyos(inc, llega) -> void:
	for a in inc.apoyos:
		if is_instance_valid(a) and a.servicio == "proteccion_civil":
			continue
		if is_instance_valid(a) and a.incidente == inc and a.fase == "primera_respuesta":
			a.fase = "apoyo"
			if a.servicio == "policia":
				_radio(a, "Ya ha llegado %s. Les dejamos al paciente y nos quedamos organizando el tráfico." % llega.id_unidad)
			else:
				_radio(a, "Ya ha llegado %s. Seguimos ayudando hasta que terminen." % llega.id_unidad)


func _iniciar_evento(inc, v) -> void:
	inc.estado = "En intervención"
	inc.progreso = minf(inc.progreso, TOPE_PRIMERA_RESPUESTA)   # lo avanzado por la primera respuesta
	inc.duracion = inc.tiempo_intervencion + (inc.intensidad * 5.0 if inc.categoria == "fuego" else 0.0)
	if inc.categoria == "busqueda":
		inc.duracion *= 2.4   # buscar a alguien lleva tiempo (más patrullas y el perro lo acortan)
	# A veces aparecen más heridos de los que se esperaban
	if inc.historia == null and inc.recogida == "" and inc.categoria in ["medico", "atrapado", "fuego", "pelea"] and inc.traslado:
		var p_mas: float = {"tranquila": 0.08, "normal": 0.15, "caotica": 0.25}.get(opciones["dificultad"], 0.15)
		if randf() < p_mas:
			var extra := 1 if randf() < 0.7 else 2
			inc.heridos += extra
			inc.requeridas["ambulancia"] = int(inc.requeridas.get("ambulancia", 0)) + 1
			_radio(v, "¡Central, hay %s! Necesitamos más ambulancias para el traslado." % ("otro herido más" if extra == 1 else "dos heridos más"))
			_pedir_refuerzos(inc)
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
	# Empiezan a trabajar siempre: los refuerzos los decides tú
	inc.evento = "en_curso"
	if inc.faltan_de("ambulancia") > 0 and inc.t_ambulancia < 0.0 and inc.refuerzos_avisados.has("ambulancia"):
		# Ya la habían pedido antes de empezar: ahora corre el tiempo
		inc.t_ambulancia = float(ESPERA_AMBULANCIA.get(opciones["dificultad"], 95.0))
	if not inc.requeridas_cumplidas():
		_pedir_refuerzos(inc)


## Las unidades piden por radio lo que les vendría bien. No es obligatorio
## mandarlo: sin refuerzos tardan más y hay más riesgo. Los heridos, en cambio,
## necesitan una ambulancia: si no llega a tiempo, pueden morir.
func _pedir_refuerzos(inc) -> void:
	if inc.evento == "refuerzos":
		inc.evento = "en_curso"
	for sv in inc.requeridas:
		if not inc.servicios.has(sv):
			inc.servicios.append(sv)
	var quien = null
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.incidente == inc:
			quien = v
			break
	var hubo := false
	for sv in inc.requeridas:
		var f: int = inc.faltan_de(sv)
		if f <= 0 or int(inc.refuerzos_avisados.get(sv, 0)) >= int(inc.requeridas[sv]):
			continue
		inc.refuerzos_avisados[sv] = int(inc.requeridas[sv])
		var mensaje := ""
		match sv:
			"ambulancia":
				mensaje = "¡Central, necesitamos una ambulancia aquí, hay heridos!" if f == 1 else "¡Central, necesitamos %d ambulancias, hay varios heridos!" % f
				if inc.t_ambulancia < 0.0 and inc.evento == "en_curso":
					inc.t_ambulancia = float(ESPERA_AMBULANCIA.get(opciones["dificultad"], 95.0))
			"policia":
				mensaje = "Central, nos vendría bien otra patrulla." if f == 1 else "Central, nos vendrían bien %d patrullas más." % f
			"bomberos":
				mensaje = "Central, nos vendría bien otra dotación de bomberos." if f == 1 else "Central, nos vendrían bien %d dotaciones más." % f
			_:
				mensaje = "Central, nos vendría bien apoyo de %s." % NOMBRES_SERVICIO.get(sv, sv).to_lower()
		hubo = true
		if quien != null:
			_radio(quien, mensaje)
		else:
			hud.notificar("%s: %s" % [inc.id_incidente, mensaje], Color("ffd166"))
		inc.registrar(_hora(segundos_sim), "Piden por radio: %s" % NOMBRES_SERVICIO.get(sv, sv))
	if not hubo:
		return
	_sonido("alerta")
	_vibrar(0.3, 0.6, 0.4)
	if inc.t_ambulancia >= 0.0:
		_consejo("ambulancia_heridos", "Cuando hay heridos, la ambulancia es urgente: el anillo rojo y blanco marca el tiempo que aguantan. Si no llega, pueden morir.")
	else:
		_consejo("refuerzos_libres", "Los refuerzos no son obligatorios: si no los mandas, la unidad sigue sola pero tarda más, y en peleas o robos hay más riesgo de heridos y de que alguien escape.")


## Se acabó el tiempo esperando la ambulancia.
func _sin_ambulancia(inc) -> void:
	inc.t_ambulancia = -1.0
	var hay: int = int(inc.presentes.get("ambulancia", 0))
	if hay > 0:
		inc.requeridas["ambulancia"] = hay
	else:
		inc.requeridas.erase("ambulancia")
		inc.servicios.erase("ambulancia")
		inc.traslado = false
	var prob: float = {"tranquila": 0.25, "normal": 0.6, "caotica": 0.8}.get(opciones["dificultad"], 0.6)
	if _alguno_con_bono(inc, "pma"):
		prob *= 0.3
	elif _alguno_con_bono(inc, "vir") or _alguno_con_bono(inc, "moto_sanitaria"):
		prob *= 0.5
	var quien = null
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.incidente == inc:
			quien = v
			break
	var texto := ""
	if randf() < prob:
		inc.fallecidos = maxi(inc.fallecidos, 1)
		texto = "Central... la ambulancia no ha llegado a tiempo. No hemos podido hacer nada por el herido."
		inc.resultado_mal = "El herido ha fallecido esperando una ambulancia."
	else:
		inc.ajuste_estrellas -= 1
		inc.marcas.append("herido_grave")
		texto = "La ambulancia no llega: el herido está muy grave, se lo lleva una ambulancia de Ciudad Real."
	if quien != null:
		_radio(quien, texto)
	else:
		hud.notificar("%s: %s" % [inc.id_incidente, texto], Color("ff8a65"))
	inc.registrar(_hora(segundos_sim), texto)
	_sonido("alerta")
	_vibrar(0.6, 0.9, 0.6)
	if inc.evento == "en_curso" and inc.progreso >= 0.99:
		_finalizar_evento(inc, inc.fallecidos == 0)
	elif inc.fallecidos > 0 and inc.evento == "en_curso":
		_finalizar_evento(inc, false)


## Avanza los mini eventos "En el lugar" que estén en marcha.
func _actualizar_eventos(delta: float) -> void:
	for inc in incidentes:
		if inc.evento == "" and inc.activo() and inc.apoyos.size() > 0 and int(inc.presentes.get(inc.servicio_necesario, 0)) == 0:
			# Primera respuesta: atienden muy despacio hasta que llega quien corresponde
			inc.progreso = minf(inc.progreso + delta / maxf(inc.tiempo_intervencion * 6.0, 1.0), TOPE_PRIMERA_RESPUESTA)
		if inc.evento == "en_curso":
			inc.progreso += delta / maxf(inc.duracion, 1.0) * _ritmo(inc)
			if not inc.refuerzo_pedido and inc.progreso >= 0.4:
				inc.refuerzo_pedido = true
				_quizas_mas_refuerzos(inc)
			if inc.evento == "en_curso" and inc.progreso >= 1.0:
				if inc.faltan_de("ambulancia") > 0:
					# Ya han terminado, pero el herido necesita una ambulancia
					inc.progreso = 0.99
					if not inc.esperando_ambulancia:
						inc.esperando_ambulancia = true
						var q = inc.en_lugar[0] if inc.en_lugar.size() > 0 else null
						if q != null and is_instance_valid(q):
							_radio(q, "Aquí ya está todo controlado, pero el herido necesita una ambulancia. ¿Cuánto le falta?")
				else:
					_finalizar_evento(inc, true)
		elif inc.evento == "refuerzos":
			inc.evento = "en_curso"
		elif inc.evento == "tramites":
			inc.progreso = minf(inc.progreso + delta / DURACION_TRAMITES, 0.99)


## Heridos esperando ambulancia: cuenta atrás.
func _vigilar_ambulancias(delta: float) -> void:
	for inc in incidentes.duplicate():
		if inc.t_ambulancia < 0.0 or not inc.activo() or inc.recogida != "":
			continue
		if inc.faltan_de("ambulancia") == 0:
			inc.t_ambulancia = -1.0
			inc.esperando_ambulancia = false
			continue
		var factor := 1.0
		if _alguno_con_bono(inc, "pma"):
			factor = 0.4
		elif _alguno_con_bono(inc, "vir") or _alguno_con_bono(inc, "moto_sanitaria"):
			factor = 0.6
		elif inc.unidades_en_escena().size() > 0:
			factor = 0.85   # alguien le hace los primeros auxilios
		var antes: float = inc.t_ambulancia
		inc.t_ambulancia -= delta * factor
		if antes > 30.0 and inc.t_ambulancia <= 30.0:
			hud.notificar("%s: ¡el herido empeora! Hace falta una ambulancia YA." % inc.id_incidente, Color("ff6b6b"))
			_sonido("alerta")
		if inc.t_ambulancia <= 0.0:
			_sin_ambulancia(inc)


## Más personal y mejor equipo = la intervención va más rápida.
func _ritmo(inc) -> float:
	var personas := 0
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.servicio == inc.servicio_necesario:
			personas += v.efectivos()
	var r := clampf(0.6 + personas * 0.15, 0.6, 1.6)
	var cansancio := 0.0
	var n := 0
	var formacion := 0
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.servicio == inc.servicio_necesario:
			cansancio += v.cansancio
			n += 1
			formacion = maxi(formacion, v.formacion)
		if is_instance_valid(v) and v.tipo == "ume":
			r *= 1.4
	if n > 0:
		r *= 1.0 - (cansancio / n) / 300.0
	r *= 1.0 + 0.1 * formacion
	var trafico := false
	for v in inc.unidades_en_escena():
		if v.servicio == "proteccion_civil":
			r *= 1.2
			break
	for a in inc.apoyos:
		if is_instance_valid(a) and a.incidente == inc and a.fase == "apoyo" and a.servicio == "policia":
			trafico = true
	if trafico:
		r *= 1.15   # la policía organiza el tráfico y despeja el paso
	# Vehículos especiales
	if _alguno_con_bono(inc, "camuflado") and (inc.arco != "" or inc.categoria == "control"):
		r *= 1.3
	if _alguno_con_bono(inc, "canino") and inc.categoria in ["busqueda", "control"]:
		r *= 1.5
	if inc.categoria == "busqueda":
		var patrullas := 0
		for v in inc.unidades_en_escena():
			if v.servicio in ["policia", "proteccion_civil"]:
				patrullas += 1
		r *= 1.0 + 0.35 * maxi(patrullas - 1, 0)
	if _alguno_con_bono(inc, "vir") and inc.categoria in ["medico", "atrapado"]:
		r *= 1.2
	if _alguno_con_bono(inc, "moto_sanitaria") and inc.evento_pueblo != "":
		r *= 1.5
	if _alguno_con_bono(inc, "pma") and inc.heridos >= 2:
		r *= 1.0 + 0.3 * mini(inc.heridos, 3)
	# Plantilla (1.1): experiencia, habilidades y moral de quienes están allí
	var bonus := 1.0
	for v in inc.unidades_en_escena():
		bonus += 0.05 * v.nivel_medio
		if v.moral_media < 40.0:
			bonus -= 0.1
		var h: Array = v.habilidades
		if h.has("triaje") and inc.heridos >= 2:
			bonus += 0.2
		if h.has("negociador") and (inc.categoria == "pelea" or inc.marcas.has("armado")):
			bonus += 0.2
		if h.has("interrogador") and (inc.categoria == "control" or inc.caso_id != ""):
			bonus += 0.2
		if h.has("altura") and inc.categoria == "atrapado":
			bonus += 0.25
		if h.has("forestal") and inc.categoria == "fuego" and inc.intensidad >= 2:
			bonus += 0.2
		if h.has("trafico"):
			bonus += 0.1
		if h.has("rescate") and (inc.marcas.has("derrumbe") or inc.marcas.has("inundacion")):
			bonus += 0.25
		if h.has("nrbq") and inc.marcas.has("quimico"):
			bonus += 0.25
		if (h.has("olfato") or h.has("paciencia")) and inc.caso_id != "":
			bonus += 0.25
	r *= clampf(bonus, 0.7, 2.0)
	# GEO, UME y detectives (0.98)
	if _bono_en_escena(inc, "mando"):
		r *= 1.25
	if _bono_en_escena(inc, "blindado") and (inc.categoria in ["pelea", "robo"] or inc.marcas.has("armado")):
		r *= 1.3
	if _bono_en_escena(inc, "antidisturbios_geo") and inc.categoria == "pelea":
		r *= 1.6
		if _equipo_en_escena(inc, "escudos_humo"):
			r *= 1.2
	if _bono_en_escena(inc, "tedax") and inc.marcas.has("explosivo"):
		r *= 1.4
		if _equipo_en_escena(inc, "perro_explosivos"):
			r *= 1.2
	if _bono_en_escena(inc, "nrbq") and inc.marcas.has("quimico"):
		r *= 1.5
		if _equipo_en_escena(inc, "trajes_nrbq"):
			r *= 1.2
	if _bono_en_escena(inc, "forestal") and inc.categoria == "fuego":
		r *= 1.5
	if _bono_en_escena(inc, "derrumbes") and (inc.categoria == "atrapado" or inc.marcas.has("derrumbe")):
		r *= 1.5
		if _equipo_en_escena(inc, "geofono"):
			r *= 1.2
	if _bono_en_escena(inc, "anfibio") and inc.marcas.has("inundacion"):
		r *= 1.6
		if _equipo_en_escena(inc, "bombas_achique"):
			r *= 1.2
	if _equipo_en_escena(inc, "dron") and inc.categoria == "busqueda":
		r *= 1.3
	if _bono_en_escena(inc, "heli_policia"):
		r *= 2.2 if inc.categoria == "busqueda" else 1.25
	if _bono_en_escena(inc, "detectives") and inc.caso_id != "":
		r *= 1.0 + (0.2 if _equipo_en_escena(inc, "kit_forense") else 0.0)
	# Sin los refuerzos que piden, trabajan más despacio (según la dificultad)
	var faltan: int = inc.faltan_apoyo()
	if faltan > 0:
		r *= pow(float(PENALIZA_SIN_REFUERZO.get(opciones["dificultad"], 0.65)), faltan)
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


func _bono_en_escena(inc, bono: String) -> bool:
	for v in inc.unidades_en_escena():
		if v.bono == bono:
			return true
	return _alguno_con_bono(inc, bono)


func _equipo_en_escena(inc, cosa: String) -> bool:
	for v in inc.unidades_en_escena():
		if v.tiene(cosa):
			return true
	return _alguno_tiene(inc, cosa)


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
	var cambia := false
	if servicio != "" and randf() < prob:
		inc.requeridas[servicio] = int(inc.requeridas.get(servicio, 0)) + 1
		cambia = true
	# En peleas y robos puede haber heridos (navajas, golpes) que necesitan ambulancia
	if inc.categoria in ["pelea", "robo"] and not inc.requeridas.has("ambulancia"):
		var p_herido := 0.4 if turno == "noche" else 0.25
		if randf() < p_herido:
			inc.requeridas["ambulancia"] = 1
			inc.traslado = true
			inc.heridos = maxi(inc.heridos, 1)
			inc.informacion.append("Hay un herido en el lugar")
			cambia = true
	if cambia:
		_pedir_refuerzos(inc)


func _finalizar_evento(inc, exito: bool) -> void:
	if inc.caso_id != "":
		_paso_caso_hecho(inc)
	if exito and inc.historia == null and inc.empeorado and inc.categoria in ["pelea", "robo"] and randf() < 0.45:
		exito = false   # se llegó tarde: los implicados se han ido
	inc.evento = "terminado"
	inc.exito = exito
	inc.estado = "Resuelta"
	inc.resultado = _texto_resultado(inc, exito)
	if exito and inc.resultado_bien != "":
		inc.resultado = inc.resultado_bien
	elif not exito and inc.resultado_mal != "":
		inc.resultado = inc.resultado_mal
	_liberar_pc(inc)
	if inc.historia != null:
		_final_historia(inc)
		inc.registrar(_hora(segundos_sim), "Final: %s" % inc.resultado)
	# Riesgo de que algún agente resulte herido
	var pocos: bool = inc.faltan_apoyo() > 0
	if inc.categoria in ["pelea", "robo"]:
		var riesgo := 0.6 if not exito else 0.1
		if pocos:
			riesgo += 0.25   # pocos agentes: más riesgo
		if _alguno_tiene(inc, "chaleco"):
			riesgo *= 0.4
		if randf() < riesgo:
			for v in inc.en_lugar:
				if is_instance_valid(v) and v.servicio == "policia" and v.efectivos() > 0:
					v.heridos.append(Catalogo.TURNOS_BAJA)
					stats["heridos"] += 1
					inc.resultado += " Un agente de %s ha resultado herido." % v.id_unidad
					break
	if inc.historia == null and inc.fallecidos == 0:
		# Sin historia: si se llegó tarde o se dieron malas instrucciones por
		# teléfono, alguien puede morir (según la dificultad).
		var riesgo := 0.0
		if inc.categoria in ["medico", "atrapado"]:
			if inc.empeorado:
				riesgo = float(RIESGO_MUERTE.get(opciones["dificultad"], 0.3))
			if inc.marcas.has("consejo_malo"):
				riesgo += 0.08 if not inc.empeorado else 0.15
			if inc.marcas.has("herido_grave"):
				riesgo += 0.2
			if inc.marcas.has("consejo_bueno") or inc.marcas.has("rcp"):
				riesgo *= 0.6
			for v in inc.unidades_en_escena():
				if v.habilidades.has("reanimacion"):
					riesgo *= 0.6
					break
			if _alguno_con_bono(inc, "pma"):
				riesgo *= 0.3
			elif _alguno_con_bono(inc, "vir") or _alguno_con_bono(inc, "medico") or _alguno_con_bono(inc, "heli_sanitario"):
				riesgo *= 0.6
		elif inc.categoria == "fuego" and inc.intensidad >= 3 and inc.empeorado:
			riesgo = 0.3
		elif inc.categoria == "pelea" and inc.requeridas.has("ambulancia") and inc.empeorado:
			riesgo = 0.15
		if riesgo > 0.0 and randf() < riesgo:
			inc.fallecidos = 1
			inc.resultado = "A pesar de los esfuerzos, el paciente ha fallecido." if inc.empeorado else "El paciente ha empeorado de golpe y ha fallecido."
	if inc.fallecidos > 0:
		_abrir_tramites(inc)
		return
	var quien = inc.en_lugar[0] if inc.en_lugar.size() > 0 else null
	if quien != null and is_instance_valid(quien):
		_radio(quien, inc.resultado)
	if inc.tipo == "aviso_trafico" and sospechoso != null and is_instance_valid(sospechoso):
		sospechoso.queue_free()
		sospechoso = null
	_calcular_detenidos(inc, exito)
	if pocos and inc.detenidos >= 1 and inc.categoria in ["pelea", "robo", "control"] and randf() < 0.45:
		inc.detenidos -= 1
		inc.escapado = true
		inc.resultado += " Con tan pocos agentes, uno de los implicados ha conseguido escapar."
	_informe_incidente(inc)
	_retirar_en_camino(inc)
	for a in inc.apoyos:
		if is_instance_valid(a) and a.incidente == inc:
			a.servicios_seguidos += 1
			a.xp_turno += 1
			_regresar(a)
	inc.apoyos.clear()
	for v in inc.en_lugar:
		if is_instance_valid(v):
			v.servicios_seguidos += 1
			v.xp_turno += 1
	_repartir_al_terminar(inc)


# ================================================================ PLANTILLA (1.1)
## Cada persona tiene nombre, servicio, experiencia, nivel, habilidades, moral
## y puede estar en un vehículo, en la reserva o de baja. Los datos de cada
## vehículo (personal, heridos, nombres) se calculan a partir de la plantilla.

func _plantilla() -> Array:
	if not partida.has("plantilla"):
		partida["plantilla"] = []
	return partida["plantilla"]


func _nueva_persona(sv: String) -> Dictionary:
	var usados := []
	for p in _plantilla():
		usados.append(p["nombre"])
	var nombre := ""
	for intento in 20:
		nombre = "%s %s." % [Pueblo.NOMBRES_PERSONAL[randi() % Pueblo.NOMBRES_PERSONAL.size()], "ABCDEFGHIJLMNOPRSTV"[randi() % 19]]
		if not usados.has(nombre):
			break
	return {"nombre": nombre, "servicio": sv, "xp": 0, "nivel": 0, "habilidades": [], "vehiculo": -1, "baja": 0, "moral": 75}


## Partidas antiguas: crea la plantilla a partir de las tripulaciones.
func _migrar_plantilla() -> void:
	if not _plantilla().is_empty():
		_recalcular_flota()
		return
	for i in partida["flota"].size():
		var u: Dictionary = partida["flota"][i]
		_completar_tripulacion(u)
		var sv: String = Catalogo.VEHICULOS[u["tipo"]]["servicio"]
		var bajas: Array = u["heridos"]
		for k in (u["nombres"] as Array).size():
			var p := _nueva_persona(sv)
			p["nombre"] = "%s %s." % [u["nombres"][k], "ABCDEFGHIJLMNOPRSTV"[randi() % 19]]
			p["vehiculo"] = i
			if k < bajas.size():
				p["baja"] = int(bajas[k])
			_plantilla().append(p)
	_recalcular_flota()


## Rehace personal, bajas y nombres de cada vehículo desde la plantilla.
func _recalcular_flota() -> void:
	for i in partida["flota"].size():
		var u: Dictionary = partida["flota"][i]
		var nombres := []
		var bajas := []
		for p in _plantilla():
			if int(p["vehiculo"]) == i:
				nombres.append(String(p["nombre"]))
				if int(p["baja"]) > 0:
					bajas.append(int(p["baja"]))
		u["nombres"] = nombres
		u["personal"] = nombres.size()
		u["heridos"] = bajas


func _datos_tripulacion(v, i: int) -> void:
	var habs := []
	var nivel := 0.0
	var moral := 0.0
	var n := 0
	for p in _plantilla():
		if int(p["vehiculo"]) == i and int(p["baja"]) == 0:
			n += 1
			nivel += float(p["nivel"])
			moral += float(p["moral"])
			for h in p["habilidades"]:
				if not habs.has(h):
					habs.append(h)
	v.habilidades = habs
	v.nivel_medio = nivel / n if n > 0 else 0.0
	v.moral_media = moral / n if n > 0 else 70.0


func _sueldo_persona(p: Dictionary) -> int:
	var base := int(Catalogo.SUELDO_ESPECIAL.get(p["servicio"], Catalogo.SUELDO_POR_TURNO))
	if int(p["vehiculo"]) < 0:
		return int(round(base * Catalogo.FACTOR_SUELDO_RESERVA))
	return base


func _ganar_xp(p: Dictionary, cuanto: int) -> void:
	p["xp"] = int(p["xp"]) + cuanto
	var nivel := 0
	for k in Catalogo.XP_NIVEL.size():
		if int(p["xp"]) >= int(Catalogo.XP_NIVEL[k]):
			nivel = k
	if nivel > int(p["nivel"]):
		p["nivel"] = nivel
		var nueva := _habilidad_al_azar(p)
		var t := "%s asciende a %s" % [p["nombre"], Catalogo.NOMBRES_NIVEL[nivel]]
		if nueva != "":
			t += " y aprende: %s" % String(Catalogo.HABILIDADES[p["servicio"]][nueva]).split(":")[0]
		subidas_nivel.append(t)


func _habilidad_al_azar(p: Dictionary) -> String:
	var posibles: Array = (Catalogo.HABILIDADES.get(p["servicio"], {}) as Dictionary).keys()
	posibles.shuffle()
	for h in posibles:
		if not (p["habilidades"] as Array).has(h):
			(p["habilidades"] as Array).append(h)
			return h
	return ""


func _texto_persona_corto(p: Dictionary) -> String:
	var t := "%s (%s, %d serv.)" % [p["nombre"], Catalogo.NOMBRES_NIVEL[int(p["nivel"])], int(p["xp"])]
	if int(p["baja"]) > 0:
		t += " · DE BAJA %d turno%s" % [int(p["baja"]), "" if int(p["baja"]) == 1 else "s"]
	if int(p["moral"]) < 40:
		t += " · moral baja"
	return t


func _plazas_calabozo() -> int:
	return Catalogo.PLAZAS_CALABOZO * (2 if _tiene_mejora("calabozo") else 1)


func _tiene_mejora(clave: String) -> bool:
	return (partida.get("mejoras", []) as Array).has(clave)


func _mostrar_plantilla() -> void:
	var ids := _ids_flota()
	var opciones := []
	var lista: Array = _plantilla()
	var orden: Array = range(lista.size())
	orden.sort_custom(func(a, b): return String(lista[a]["servicio"]) + String(lista[a]["nombre"]) < String(lista[b]["servicio"]) + String(lista[b]["nombre"]))
	for k in orden:
		var p: Dictionary = lista[k]
		var donde: String = "reserva" if int(p["vehiculo"]) < 0 else (String(ids[int(p["vehiculo"])]) if int(p["vehiculo"]) < ids.size() else "?")
		opciones.append({"texto": "%s · %s · %s" % [NOMBRES_SERVICIO.get(p["servicio"], p["servicio"]), _texto_persona_corto(p), donde], "accion": _mostrar_persona.bind(k)})
	for sv in ["ambulancia", "policia", "bomberos"]:
		opciones.append({"texto": "Contratar para la reserva: %s (%s + %s/turno)" % [NOMBRES_SERVICIO[sv], Hud.formato_euros(Catalogo.PRECIO_CONTRATAR),
			Hud.formato_euros(int(round(Catalogo.SUELDO_POR_TURNO * Catalogo.FACTOR_SUELDO_RESERVA)))], "accion": _contratar_reserva.bind(sv), "activo": int(partida["dinero"]) >= Catalogo.PRECIO_CONTRATAR})
	var psi: bool = partida.get("psicologo", false)
	opciones.append({"texto": ("Despedir al psicólogo de emergencias" if psi else "Contratar un psicólogo de emergencias (%s/turno): la moral se recupera mucho antes") % Hud.formato_euros(Catalogo.PRECIO_PSICOLOGO), "accion": _cambiar_psicologo})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	var texto := "Tu personal. La reserva cobra el 60 %% y sirve para cubrir bajas sin dejar vehículos parados. Con la experiencia suben a Experto/a (8 servicios) y Veterano/a (20) y aprenden habilidades.\nDinero: %s" % Hud.formato_euros(partida["dinero"])
	hud.mostrar_panel("PLANTILLA", texto, opciones, true, 120.0, 720.0)


func _mostrar_persona(k: int) -> void:
	var p: Dictionary = _plantilla()[k]
	var ids := _ids_flota()
	var habs := []
	for h in p["habilidades"]:
		habs.append(String(Catalogo.HABILIDADES.get(p["servicio"], {}).get(h, h)))
	var texto := "%s · %s\n%s · %d servicios · moral %d/100\n%s\nHabilidades:\n· %s" % [p["nombre"], NOMBRES_SERVICIO.get(p["servicio"], p["servicio"]),
		Catalogo.NOMBRES_NIVEL[int(p["nivel"])], int(p["xp"]), int(p["moral"]),
		"En la reserva" if int(p["vehiculo"]) < 0 else "Destino: %s" % ids[int(p["vehiculo"])],
		"ninguna todavía" if habs.is_empty() else "\n· ".join(PackedStringArray(habs))]
	if int(p["baja"]) > 0:
		texto += "\n\nDe baja: %d turno%s más." % [int(p["baja"]), "" if int(p["baja"]) == 1 else "s"]
	var opciones := []
	for i in partida["flota"].size():
		var u: Dictionary = partida["flota"][i]
		var d: Dictionary = Catalogo.VEHICULOS[u["tipo"]]
		if d["servicio"] == p["servicio"] and i != int(p["vehiculo"]) and int(u["personal"]) < int(d["plazas"]):
			opciones.append({"texto": "Destinar a %s (%d/%d)" % [ids[i], int(u["personal"]), int(d["plazas"])], "accion": _asignar_persona.bind(k, i, false)})
	if int(p["vehiculo"]) >= 0:
		opciones.append({"texto": "Pasar a la reserva", "accion": _asignar_persona.bind(k, -1, false)})
	var posibles: Array = (Catalogo.HABILIDADES.get(p["servicio"], {}) as Dictionary).keys()
	var precio := Catalogo.PRECIO_CURSO / (2 if _tiene_mejora("aula") else 1)
	for h in posibles:
		if not (p["habilidades"] as Array).has(h):
			opciones.append({"texto": "Curso: %s (%s)" % [Catalogo.HABILIDADES[p["servicio"]][h], Hud.formato_euros(precio)], "accion": _dar_curso.bind(k, h), "activo": int(partida["dinero"]) >= precio})
	opciones.append({"texto": "Despedir (se va de la plantilla)", "accion": _despedir_persona.bind(k)})
	opciones.append({"texto": "Volver a la plantilla", "accion": _mostrar_plantilla})
	hud.mostrar_panel("PERSONAL", texto, opciones, true, 120.0, 720.0)


func _asignar_persona(k: int, vehiculo: int, volver_ficha: bool) -> void:
	var p: Dictionary = _plantilla()[k]
	if vehiculo >= 0:
		# Si el vehículo está lleno, el de baja con más turnos pasa a la reserva para dejarle sitio
		var u: Dictionary = partida["flota"][vehiculo]
		var d: Dictionary = Catalogo.VEHICULOS[u["tipo"]]
		if int(u["personal"]) >= int(d["plazas"]):
			for otro in _plantilla():
				if int(otro["vehiculo"]) == vehiculo and int(otro["baja"]) > 0:
					otro["vehiculo"] = -1
					break
	p["vehiculo"] = vehiculo
	_recalcular_flota()
	_guardar_partida()
	_sonido("envio")
	if volver_ficha and vehiculo >= 0:
		_mostrar_ficha(vehiculo)
	else:
		_mostrar_persona(k)


func _contratar_reserva(sv: String) -> void:
	_plantilla().append(_nueva_persona(sv))
	_cambiar_dinero(-Catalogo.PRECIO_CONTRATAR)
	_guardar_partida()
	_sonido("envio")
	_mostrar_plantilla()


func _despedir_persona(k: int) -> void:
	var p: Dictionary = _plantilla()[k]
	_plantilla().remove_at(k)
	_recalcular_flota()
	_guardar_partida()
	hud.notificar("%s deja el servicio." % p["nombre"])
	_mostrar_plantilla()


func _dar_curso(k: int, h: String) -> void:
	var p: Dictionary = _plantilla()[k]
	var precio := Catalogo.PRECIO_CURSO / (2 if _tiene_mejora("aula") else 1)
	(p["habilidades"] as Array).append(h)
	_cambiar_dinero(-precio)
	_guardar_partida()
	_sonido("envio")
	hud.notificar("%s ha terminado el curso." % p["nombre"], Color("8fd3a0"))
	_mostrar_persona(k)


func _cambiar_psicologo() -> void:
	partida["psicologo"] = not bool(partida.get("psicologo", false))
	_guardar_partida()
	_mostrar_plantilla()


func _mostrar_mejoras() -> void:
	var opciones := []
	for clave in Catalogo.MEJORAS:
		var m: Dictionary = Catalogo.MEJORAS[clave]
		if _tiene_mejora(clave):
			opciones.append({"texto": "✔ %s: %s" % [m["nombre"], m["ayuda"]], "accion": _mostrar_mejoras, "activo": false})
		else:
			opciones.append({"texto": "Construir %s (%s): %s" % [m["nombre"], Hud.formato_euros(m["precio"]), m["ayuda"]],
				"accion": _comprar_mejora.bind(clave), "activo": int(partida["dinero"]) >= int(m["precio"])})
	opciones.append({"texto": "Volver a equipos", "accion": _mostrar_equipos})
	hud.mostrar_panel("MEJORAS DE LAS BASES", "Dinero: %s" % Hud.formato_euros(partida["dinero"]), opciones, true)


func _comprar_mejora(clave: String) -> void:
	(partida["mejoras"] as Array).append(clave)
	_cambiar_dinero(-int(Catalogo.MEJORAS[clave]["precio"]))
	_guardar_partida()
	_sonido("envio")
	hud.notificar("Mejora construida: %s." % Catalogo.MEJORAS[clave]["nombre"], Color("8fd3a0"))
	_mostrar_mejoras()


# ================================================================ HERIDOS Y DETENIDOS (1.0)
## Al terminar un aviso: cada ambulancia lleva los heridos que caben (básica 1,
## SVA 2, helicóptero 1) y cada coche de policía los detenidos que caben. Lo que
## no cabe se queda esperando con una unidad, como un aviso nuevo de «recogida»
## al que mandas más ambulancias o furgones (o los mismos cuando vuelvan).

func _repartir_al_terminar(inc) -> void:
	var unidades: Array = []
	for v in inc.en_lugar:
		if is_instance_valid(v) and v.incidente == inc and not unidades.has(v):
			unidades.append(v)
	var heridos := 0
	if inc.traslado and inc.exito:
		heridos = maxi(inc.heridos - inc.fallecidos, 0)
		if heridos == 0 and inc.fallecidos == 0:
			heridos = 1
	var detenidos: int = inc.detenidos
	var libres: Array = unidades.duplicate()
	# 1) Quién se queda con los que no quepan
	var cap_amb := 0
	var cap_pol := 0
	for v in unidades:
		cap_amb += v.camillas
		cap_pol += _plazas_detenidos(v)
	var cuidador_h = null
	var cuidador_d = null
	if heridos > cap_amb:
		# Se queda un sanitario que no traslada (VIR, moto, PMA) o, si no, cualquiera que no traslade
		for v in libres:
			if v.servicio == "ambulancia" and v.camillas == 0:
				cuidador_h = v
				break
		if cuidador_h == null:
			for v in libres:
				if v.camillas == 0 and _plazas_detenidos(v) == 0:
					cuidador_h = v
					break
		if cuidador_h == null:
			for v in libres:
				if v.camillas == 0:
					cuidador_h = v
					break
		if cuidador_h != null:
			libres.erase(cuidador_h)
	var policias: Array = []
	for v in libres:
		if v.servicio in ["policia", "geo", "judicial"] and not v.aereo:
			policias.append(v)
	var cap_libre := 0
	for v in policias:
		cap_libre += _plazas_detenidos(v)
	if detenidos > cap_libre and not policias.is_empty():
		# Se queda vigilando la unidad que menos detenidos puede llevar
		policias.sort_custom(func(a, b): return _plazas_detenidos(a) < _plazas_detenidos(b))
		cuidador_d = policias[0]
		policias.remove_at(0)
		libres.erase(cuidador_d)
	# 2) Ambulancias con heridos al hospital
	for v in libres.duplicate():
		if heridos > 0 and v.camillas > 0:
			var lleva := mini(heridos, v.camillas)
			heridos -= lleva
			v.pacientes_a_bordo = lleva
			libres.erase(v)
			_trasladar(v)
	# 3) Policías con detenidos al calabozo
	for v in policias:
		if detenidos > 0 and _plazas_detenidos(v) > 0 and libres.has(v):
			var lleva := mini(detenidos, _plazas_detenidos(v))
			detenidos -= lleva
			libres.erase(v)
			_llevar_al_calabozo(v, lleva)
	# 4) Lo que queda: aviso de recogida con la unidad que se queda
	if heridos > 0:
		_crear_recogida(inc, "heridos", heridos, cuidador_h)
	if detenidos > 0:
		if cuidador_d != null:
			_crear_recogida(inc, "detenidos", detenidos, cuidador_d)
		else:
			inc.resultado += " Sin agentes para custodiarlos, %d implicados se han ido." % detenidos
	for v in libres:
		_regresar(v)


func _crear_recogida(inc, tipo: String, n: int, cuidador) -> void:
	var heridos := tipo == "heridos"
	var titulo := ("Traslado pendiente: %d herido%s de %s" % [n, "" if n == 1 else "s", inc.id_incidente]) if heridos else ("Recogida de %d detenido%s de %s" % [n, "" if n == 1 else "s", inc.id_incidente])
	var d := {"titulo": titulo, "servicios": ["ambulancia"] if heridos else ["policia"], "principal": "ambulancia" if heridos else "policia",
		"urgencia": 9999.0, "intervencion": 3.0, "categoria": "medico" if heridos else "control",
		"requeridas": {"ambulancia" if heridos else "policia": 1},
		"info": ["Hacen falta %s" % ("ambulancias: la básica lleva 1 herido y la SVA, 2" if heridos else "coches o furgones: un coche lleva 2 detenidos, el furgón 4 y el antidisturbios 8")]}
	var r = _nuevo_aviso(d, inc.nodo_real, "", "Unidades en el lugar", false)
	if r == null:
		return
	r.recogida = tipo
	r.pendientes = n
	r.origen = inc.id_incidente
	r.evento = "recogida"
	r.estado = "En intervención"
	r.tiempo_llegada = 0.0
	if heridos:
		r.t_ambulancia = float(ESPERA_AMBULANCIA.get(opciones["dificultad"], 95.0)) * 1.3
	if cuidador != null and is_instance_valid(cuidador):
		r.cuidador = cuidador
		cuidador.incidente = r
		cuidador.fase = "custodia"
		cuidador.estado = "Atendiendo heridos" if heridos else "Custodiando detenidos"
		r.en_escena.append(cuidador)
		r.unidades.append(cuidador)
		_radio(cuidador, ("Nos quedamos con %d herido%s: necesitamos más ambulancias para llevarlos al hospital." % [n, "" if n == 1 else "s"]) if heridos
			else ("Nos quedamos custodiando a %d detenidos: necesitamos un furgón o más coches para llevarlos al calabozo." % n))
	hud.notificar("%s: %s. Manda %s." % [r.id_incidente, titulo, "ambulancias" if heridos else "furgones o patrullas"], Color("ffd166"))
	_sonido("alerta")
	_consejo("recogida", "Cuando no caben todos, una unidad se queda con los heridos o detenidos y aparece un aviso de recogida. Manda más ambulancias o furgones, o los mismos cuando vuelvan del hospital o del calabozo.")


## Una unidad llega a un aviso de recogida y se lleva a los que le caben.
func _cargar_recogida(v, r) -> void:
	var heridos: bool = r.recogida == "heridos"
	var cabe: int = v.camillas if heridos else _plazas_detenidos(v)
	if cabe <= 0:
		_radio(v, "No podemos llevar %s en este vehículo. Volvemos." % ("heridos" if heridos else "detenidos"))
		_regresar(v)
		return
	var lleva := mini(cabe, r.pendientes)
	r.pendientes -= lleva
	r.unidades.erase(v)
	if heridos:
		v.pacientes_a_bordo = lleva
		v.incidente = null
		_radio(v, "Recogemos %d herido%s." % [lleva, "" if lleva == 1 else "s"])
		_trasladar(v)
	else:
		_llevar_al_calabozo(v, lleva)
	if r.pendientes > 0:
		r.titulo = ("Traslado pendiente: %d herido%s de %s" if heridos else "Recogida de %d detenido%s de %s") % [r.pendientes, "" if r.pendientes == 1 else "s", r.origen]
		hud.notificar("%s: quedan %d por llevar." % [r.id_incidente, r.pendientes], Color("ffd166"))
		return
	_cerrar_recogida(r, "Todos trasladados.")


func _cerrar_recogida(r, texto: String) -> void:
	r.estado = "Resuelta"
	r.evento = "terminado"
	r.resultado = texto
	r.t_ambulancia = -1.0
	r.registrar(_hora(segundos_sim), texto)
	if r.cuidador != null and is_instance_valid(r.cuidador) and r.cuidador.incidente == r:
		_radio(r.cuidador, "Recogida completada. Quedamos libres.")
		_regresar(r.cuidador)
	r.cuidador = null


## Los heridos que esperan pueden empeorar; los detenidos, escaparse.
func _vigilar_recogidas(delta: float) -> void:
	for r in incidentes.duplicate():
		if r.recogida == "" or not r.activo():
			continue
		if r.recogida == "heridos":
			var factor := 0.6 if r.cuidador != null and is_instance_valid(r.cuidador) else 1.0
			r.t_ambulancia -= delta * factor
			if r.t_ambulancia <= 0.0:
				var prob: float = {"tranquila": 0.2, "normal": 0.45, "caotica": 0.65}.get(opciones["dificultad"], 0.45)
				var texto := ""
				if randf() < prob:
					stats["fallecidos"] += 1
					stats["sucesos"].append({"titulo": "Herido sin traslado (%s)" % r.origen, "resultado": "Un herido ha muerto esperando una ambulancia.", "estrellas": 1, "fallecido": true, "historia": false, "calle": red.calle_de_nodo(r.nodo_real)})
					texto = "Un herido ha muerto esperando una ambulancia."
					_sumar_reputacion(-3.0)
				else:
					texto = "Los heridos se los ha llevado una ambulancia de fuera, tarde y graves."
					_sumar_reputacion(-1.5)
				hud.notificar("%s: %s" % [r.id_incidente, texto], Color("ff6b6b"))
				_sonido("alerta")
				_cerrar_recogida(r, texto)
		else:
			r.t_custodia += delta
			if r.t_custodia >= 60.0:
				r.t_custodia = 0.0
				var p_escape := 0.2 if r.pendientes <= 3 else 0.4
				if randf() < p_escape:
					r.pendientes -= 1
					hud.notificar("%s: ¡un detenido se ha escapado mientras esperaban el furgón!" % r.id_incidente, Color("ff8a65"))
					if r.cuidador != null and is_instance_valid(r.cuidador):
						_radio(r.cuidador, "¡Se nos ha escapado uno! Somos pocos para vigilarlos a todos.")
					if r.pendientes <= 0:
						_cerrar_recogida(r, "Todos los detenidos se han escapado.")


# ================================================================ MULTAS Y DETENIDOS (0.96)

## El coche camuflado caza excesos de velocidad mientras patrulla.
func _radar_camuflado() -> void:
	if turno_terminando:
		return
	for v in vehiculos:
		if v.bono != "camuflado" or v.estado != "Patrullando":
			continue
		v.t_radar += 1.0
		if v.t_radar < 70.0:
			continue
		v.t_radar = randf_range(-20.0, 10.0)
		if randf() < 0.55:
			var km := randi_range(72, 115)
			var importe := _multa_velocidad(km)
			var parte := int(round(importe * _comision()))
			stats["multas"] += 1
			stats["comision"] += parte
			_cambiar_dinero(parte)
			_radio(v, "Radar del coche camuflado: un turismo a %d km/h en %s. Multa de %d €: tu comisión, +%d €." % [km, red.calle_de_nodo(v.siguiente_nodo), importe, parte])




## Según el delito: multa en el sitio o detenido al calabozo.
func _calcular_detenidos(inc, exito: bool) -> void:
	inc.detenidos = 0
	inc.multas = 0
	if not exito or inc.fallecidos > 0:
		return
	var texto: String = String(inc.resultado).to_lower()
	match inc.categoria:
		"pelea", "robo":
			inc.detenidos = 2 if inc.cadena == "huida" or randf() < 0.35 else 1
			var t_low := String(inc.titulo).to_lower()
			if t_low.contains("multitud") or t_low.contains("campal") or t_low.contains("bandas") or int(inc.requeridas.get("policia", 0)) >= 3:
				inc.detenidos = randi_range(5, 10)
			elif int(inc.requeridas.get("policia", 0)) == 2 and inc.categoria == "pelea":
				inc.detenidos = randi_range(2, 4)
		"control":
			if texto.contains("detenid") or texto.contains("positivo") and randf() < 0.5:
				inc.detenidos = 2 if inc.cadena == "huida" else 1
			else:
				inc.multas = 1
	if texto.contains("multad") or texto.contains("multa"):
		inc.multas = maxi(inc.multas, 1)
	if texto.contains("detenid") and inc.detenidos == 0:
		inc.detenidos = 1
	# Con la unidad canina, en los controles de noche a veces aparece droga
	if inc.categoria == "control" and turno == "noche" and _alguno_con_bono(inc, "canino") and randf() < 0.35:
		inc.detenidos = maxi(inc.detenidos, 1)
		inc.multas = 0
		inc.resultado += " El perro ha detectado droga escondida: el conductor queda detenido."
	if inc.multas > 0:
		inc.importe_multas = _importe_multa(texto + " " + String(inc.titulo).to_lower()) * inc.multas
		inc.comision = int(round(inc.importe_multas * _comision()))
		stats["multas"] += inc.multas
		stats["comision"] += inc.comision
		_cambiar_dinero(inc.comision)


## Importe de la multa según la infracción (aproximado a los reales).
func _importe_multa(texto: String) -> int:
	if texto.contains("aparca") or texto.contains("grúa") or texto.contains("cortan la calle"):
		return 90
	if texto.contains("ruido") or texto.contains("música"):
		return 300
	if texto.contains("alcohol") or texto.contains("bebido"):
		return 500
	var km := _km_en(texto)
	if km > 0:
		return _multa_velocidad(km)
	if texto.contains("velocidad"):
		return 300
	return 200


## Exceso de velocidad (límite 50 km/h en el pueblo): de 100 a 600 €.
func _multa_velocidad(km: int) -> int:
	var exceso := km - 50
	if exceso <= 20:
		return 100
	if exceso <= 30:
		return 300
	if exceso <= 50:
		return 400
	return 600


func _km_en(texto: String) -> int:
	var i := texto.find(" km/h")
	if i < 0:
		return 0
	var j := i - 1
	while j >= 0 and texto[j] >= "0" and texto[j] <= "9":
		j -= 1
	return texto.substr(j + 1, i - j - 1).to_int()


## Comisión de la central: 30 % en prácticas, hasta 50 % como Coordinador/a del 112.
func _comision() -> float:
	return 0.30 + 0.05 * _rango_indice(int(partida["puntos"]))


func _plazas_detenidos(v) -> int:
	if v.tipo == "moto" or v.aereo or not (v.servicio in ["policia", "geo", "judicial"]):
		return 0
	match v.bono:
		"detenidos":
			return 4
		"antidisturbios_geo":
			return 8
		"blindado":
			return 4
		"tedax", "mando":
			return 0
	return 2


func _llevar_al_calabozo(v, cuantos: int) -> void:
	v.incidente = null
	v.en_emergencia = false
	v.detenidos_a_bordo = cuantos
	v.fase = "calabozo"
	v.estado = "Trasladando detenido"
	v.cansancio = minf(100.0, v.cansancio + 8.0)
	_radio(v, "Llevamos %s al calabozo de la comisaría." % ("al detenido" if cuantos == 1 else "a los %d detenidos" % cuantos))
	v.ir_a(bases["policia"])


func _detenidos_en_calabozo(v) -> void:
	var n: int = v.detenidos_a_bordo
	var hueco := maxi(_plazas_calabozo() - int(partida.get("calabozo", 0)), 0)
	var entran := mini(n, hueco)
	partida["calabozo"] = int(partida.get("calabozo", 0)) + entran
	stats["detenidos"] += n
	partida["detenidos_total"] = int(partida["detenidos_total"]) + n
	if int(partida["detenidos_total"]) >= 10:
		_dar_logro("detenciones")
	var resto := n - entran
	if resto > 0:
		# Calabozo lleno: los que no caben van directos a la cárcel
		v.detenidos_a_bordo = resto
		v.fase = "carcel"
		v.estado = "Trasladando a prisión"
		v.en_emergencia = false
		_radio(v, "Calabozo lleno (%d/%d). Llevamos a %d al centro penitenciario." % [int(partida["calabozo"]), _plazas_calabozo(), resto])
		v.ir_a(nodo_salida)
		return
	v.detenidos_a_bordo = 0
	_radio(v, "%s en el calabozo de la C/ Lentejuela (%d/%d plazas)." % ["Detenido ingresado" if n == 1 else "%d detenidos ingresados" % n, int(partida["calabozo"]), _plazas_calabozo()])
	hud.set_calabozo(int(partida["calabozo"]), _plazas_calabozo())
	_regresar(v)


## Traslado de presos del calabozo a la cárcel (desde la comisaría).
func _trasladar_presos() -> void:
	var mejor = null
	for v in vehiculos:
		if v.disponible() and v.servicio == "policia" and _plazas_detenidos(v) > 0 and not v.externo:
			if mejor == null or _plazas_detenidos(v) > _plazas_detenidos(mejor):
				mejor = v
	if mejor == null:
		hud.notificar("No hay ningún coche o furgón de policía libre para llevar presos a la cárcel.")
		return
	mejor.deambular = false
	mejor.fase = "recoger_presos"
	mejor.estado = "A por presos"
	mejor.incidente = null
	mejor.ir_a(bases["policia"])
	_radio(mejor, "Vamos a la comisaría a recoger presos para llevarlos al centro penitenciario.")
	_cerrar_comisaria()


# ================================================================ FALLECIMIENTOS Y TRÁMITES
## Si alguien fallece, la ambulancia no lo traslada: el sanitario certifica la
## muerte, la policía custodia el lugar y toma declaración, después llegan el
## juzgado de guardia y el forense, y la funeraria hace el levantamiento.

func _liberar_pc(inc) -> void:
	for v in inc.en_escena.duplicate():
		if is_instance_valid(v) and v.servicio == "proteccion_civil" and v.incidente == inc and v.estado == "En intervención":
			inc.apoyos.erase(v)
			v.servicios_seguidos += 1
			v.xp_turno += 1
			_radio(v, "Terminado. Protección Civil queda disponible.")
			_regresar(v)


func _abrir_tramites(inc) -> void:
	_liberar_pc(inc)
	stats["fallecidos"] = int(stats.get("fallecidos", 0)) + 1
	inc.traslado = false
	inc.estado = "Trámites por fallecimiento"
	inc.evento = "tramites_espera"
	inc.progreso = 0.0
	inc.tramites_paso = 0
	inc.urgencia_total = 0.0
	inc.registrar(_hora(segundos_sim), "Fallecimiento confirmado: %s" % inc.resultado)
	var sanitario = null
	var policia = null
	for v in inc.en_lugar + inc.apoyos:
		if not is_instance_valid(v) or v.incidente != inc:
			continue
		if v.servicio == "ambulancia" and sanitario == null:
			sanitario = v
		if v.servicio == "policia" and policia == null:
			policia = v
	if sanitario != null:
		_radio(sanitario, "Lo sentimos, central: el médico certifica el fallecimiento. Hay que avisar al juzgado de guardia.")
	else:
		hud.notificar("%s: ha fallecido una persona. Hay que avisar al juzgado de guardia." % inc.id_incidente, Color("cfd9e6"))
	# La policía se queda; el resto de unidades se retiran
	for v in (inc.en_lugar + inc.apoyos).duplicate():
		if is_instance_valid(v) and v.incidente == inc and v != policia:
			v.servicios_seguidos += 1
			v.xp_turno += 1
			_regresar(v)
	inc.apoyos.clear()
	_retirar_en_camino(inc, policia == null)
	inc.en_lugar = [policia] if policia != null else []
	inc.servicios = ["policia"]
	inc.servicio_necesario = "policia"
	inc.requeridas = {"policia": 1}
	inc.presentes = {"policia": 1 if policia != null else 0}
	_sonido("alerta")
	if policia != null:
		_iniciar_tramites(inc, policia)
	else:
		hud.notificar("%s: hace falta una patrulla para custodiar el lugar y tomar declaración. Pulsa Triángulo." % inc.id_incidente, COLOR_RADIO_POLICIA)
	_consejo("tramites", "Cuando alguien fallece, manda una patrulla: custodia el lugar y toma declaración. Después llegan el juzgado y el forense, y la funeraria se encarga del levantamiento.")


func _iniciar_tramites(inc, v) -> void:
	inc.evento = "tramites"
	inc.progreso = 0.0
	inc.tramites_paso = 0
	inc.estado = "Trámites por fallecimiento"
	_radio(v, "Lugar acordonado. Tomamos declaración a los testigos y esperamos al juzgado.")
	inc.registrar(_hora(segundos_sim), "%s custodia el lugar y toma declaración" % v.id_unidad)
	_programar(DURACION_TRAMITES * 0.35, _paso_tramites.bind(inc, 1))
	_programar(DURACION_TRAMITES * 0.7, _paso_tramites.bind(inc, 2))
	_programar(DURACION_TRAMITES, _fin_tramites.bind(inc))


func _paso_tramites(inc, paso: int) -> void:
	if not is_instance_valid(inc) or inc.evento != "tramites":
		return
	inc.tramites_paso = paso
	var texto := "el juzgado de guardia y el médico forense llegan al lugar." if paso == 1 else "la funeraria realiza el levantamiento del cuerpo."
	hud.notificar("%s: %s" % [inc.id_incidente, texto], Color("cfd9e6"))
	inc.registrar(_hora(segundos_sim), texto)


func _fin_tramites(inc) -> void:
	if not is_instance_valid(inc) or inc.evento != "tramites":
		return
	inc.evento = "terminado"
	inc.estado = "Resuelta"
	inc.progreso = 1.0
	inc.resultado += " Trámites completados: declaración, juzgado y levantamiento."
	_retirar_en_camino(inc)
	for v in inc.en_lugar.duplicate():
		if is_instance_valid(v) and v.incidente == inc:
			_radio(v, "Trámites terminados. Quedamos disponibles.")
			v.servicios_seguidos += 1
			v.xp_turno += 1
			_regresar(v)
	_informe_incidente(inc)


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


func _vir_en(inc):
	for o in inc.en_lugar:
		if is_instance_valid(o) and o.incidente == inc and o.bono in ["vir", "moto_sanitaria"]:
			return o
	return null


## Las unidades que aún iban de camino a un aviso ya terminado dan la vuelta.
func _retirar_en_camino(inc, salvo_policia := false) -> void:
	for v in inc.unidades.duplicate():
		if not is_instance_valid(v) or v.incidente != inc:
			continue
		if not (v.fase in ["ida", "buscando", "buscando2"]):
			continue
		if salvo_policia and v.servicio == "policia":
			continue
		_radio(v, "Recibido: el aviso ya está resuelto. Damos la vuelta y volvemos a base.")
		_regresar(v)


func _trasladar(v) -> void:
	v.fase = "traslado"
	v.estado = "Traslado al hospital"
	v.en_emergencia = true
	_radio(v, "Trasladamos al paciente al Hospital General de Ciudad Real.")
	v.ir_a(nodo_salida)


func _regresar(v) -> void:
	if v.incidente != null:
		v.cansancio = minf(100.0, v.cansancio + 14.0)
	v.en_emergencia = false
	v.incidente = null
	if v.externo:
		v.fase = "regreso"
		v.estado = "Regresando"
		v.ir_a(v.nodo_base)
		return
	if v.efectivos() == 0:
		v.fase = "regreso"
		v.estado = "Sin personal"
		v.ir_a(v.nodo_base)
		return
	if v.servicio == "policia" and not v.aereo:
		v.patrullar()
		return
	v.fase = "regreso"
	v.estado = "Regresando"
	# Ambulancia sin material (ya ha hecho todos sus servicios seguidos):
	# vuelve más rápido a la base para reponer y no se le pueden dar más avisos.
	if v.servicio == "ambulancia" and v.servicios_seguidos >= v.limite_seguidos():
		v.estado = "Reponiendo material"
		_radio(v, "Nos hemos quedado sin material. Volvemos rápido a la base a reponer.")
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
	if inc.fallecidos > 0:
		estrellas -= 1
		consecuencias.append("Ha fallecido una persona. Se han hecho los trámites judiciales.")
	if inc.categoria == "atrapado" and not (_alguno_tiene(inc, "tecnico") or _alguno_con_bono(inc, "rescate")):
		consecuencias.append("Los bomberos no llevaban equipo técnico de excarcelación.")
	if inc.categoria == "fuego" and inc.intensidad > 1:
		estrellas -= inc.intensidad - 1
		consecuencias.append("El fuego se extendió antes de que llegaran los bomberos (nivel %d)." % inc.intensidad)
	estrellas = clampi(estrellas, 1, 5)
	_sumar_estadisticas(estrellas, t_llegada)
	_al_cerrar_incidente(inc, estrellas)
	stats["sucesos"].append({"titulo": inc.titulo, "resultado": inc.resultado, "estrellas": estrellas,
		"fallecido": inc.fallecidos > 0, "historia": inc.historia != null, "calle": red.calle_de_nodo(inc.nodo_real) if inc.nodo_real >= 0 else ""})
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
	if inc.detenidos > 0:
		texto += "\nDetenidos: %d (los llevan al calabozo de la C/ Lentejuela)" % inc.detenidos
	if inc.multas > 0:
		texto += "\nMultas: %d por %s · Tu comisión (%d %%): +%s" % [inc.multas, Hud.formato_euros(inc.importe_multas),
			int(round(_comision() * 100.0)), Hud.formato_euros(inc.comision)]
	hud.mostrar_panel("INFORME · %s · %s" % [inc.id_incidente, inc.titulo], texto, [{"texto": "Aceptar", "accion": _cerrar_panel}])
	hud.mirar_lugar(inc, true)
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


# ================================================================ AVISOS DIRECTOS (emergencias menores)

## Emergencia menor que no necesita conversación: llega como aviso a la
## izquierda de la pantalla y aparece directamente en el mapa.
func _aviso_directo(forzar_id: String = "", titulo: String = "") -> void:
	var posibles := []
	for d in todas_llamadas:
		if forzar_id != "":
			if d["id"] == forzar_id:
				posibles.append(d)
		elif not d.get("falsa", false) and not d.has("linea") and (d["turno"] == turno or d["turno"] == "ambos"):
			posibles.append(d)
	if posibles.is_empty():
		return
	var datos: Dictionary = posibles[randi() % posibles.size()]
	var d: Dictionary = datos["incidente"]
	var lugar := _elegir_lugar(datos["referencias"])
	var nodo := int(lugar.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	var calle: String = lugar.get("calle", red.calle_de_nodo(nodo))
	var inc = Incidente.new()
	contador_incidentes += 1
	inc.id_incidente = "INC-%03d" % contador_incidentes
	inc.categoria = d.get("categoria", "medico")
	inc.tipo = "incendio" if inc.categoria == "fuego" else "aviso_directo"
	inc.fuente = "Aviso recibido por la centralita"
	inc.titulo = d["titulo"] if titulo == "" else titulo
	inc.clima = clima
	inc.servicios = d["servicios"].duplicate()
	inc.servicio_necesario = d["principal"]
	inc.requeridas = d.get("requeridas", {d["principal"]: 1}).duplicate()
	inc.urgencia_total = float(d["urgencia"]) + 15.0
	inc.urgencia_restante = inc.urgencia_total
	inc.traslado = d.get("traslado", false)
	inc.tiempo_intervencion = d.get("intervencion", 10.0)
	inc.informacion = ["Aviso de un vecino en %s" % calle, "Cerca de %s" % lugar.get("nombre", "")]
	inc.precision = 3
	inc.precision_al_enviar = -1
	inc.nodo_real = nodo
	inc.nodo_aproximado = nodo
	inc.pos_exacta = red.pos(nodo)
	inc.calma_final = 60
	inc.tiempo_creacion = tiempo_juego
	inc.registrar(_hora(segundos_sim), "Aviso recibido: %s" % inc.titulo)
	inc.actualizar_posicion()
	mundo.add_child(inc)
	incidentes.append(inc)
	hud.notificar("NUEVO AVISO %s: %s en %s. Pulsa Triángulo para verlo." % [inc.id_incidente, inc.titulo, calle], Color("9ff3ff"))
	_sonido("alerta")
	_consejo("aviso_directo", "Las emergencias menores llegan como aviso y aparecen solas en el mapa, sin llamada. Ábrelas con Triángulo y manda la unidad.")


## Fallecimiento natural en un domicilio: el sanitario certifica y empiezan
## los trámites (juzgado, forense y funeraria).
func _aviso_muerte_natural() -> void:
	if en_menu or turno_terminando:
		return
	var casos := [
		["Persona mayor encontrada sin vida en su casa", "La vecina no la veía desde ayer y no abre la puerta"],
		["Hombre que no despierta en su cama", "Su mujer dice que está frío y no respira"],
		["Anciano desplomado en el huerto", "Lo ha encontrado su nieto, no responde"],
		["Mujer sin pulso en una residencia", "La auxiliar de noche pide una ambulancia"],
	]
	var c: Array = casos[randi() % casos.size()]
	var d := {"titulo": c[0], "servicios": ["ambulancia", "policia"], "principal": "ambulancia",
		"urgencia": 90.0, "intervencion": 7.0, "categoria": "medico", "info": [c[1]], "requeridas": {"ambulancia": 1}}
	var l := _elegir_lugar(["edificio", "plaza", "iglesia", "parque"])
	var nodo := int(l.get("nodo", red.nodo_mas_cercano(tamano_mapa / 2.0)))
	d["fallecido"] = true
	var inc = _nuevo_aviso(d, nodo, String(l.get("nombre", "")), "Aviso de un familiar")
	inc.resultado_bien = "El médico certifica el fallecimiento por causas naturales."
	inc.resultado_mal = "El médico certifica el fallecimiento por causas naturales."


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

func _crear_incendio(titulo: String = "") -> void:
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
	inc.titulo = "Incendio en edificio" if titulo == "" else titulo
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
	_viaje_camara(inc.position)


# ================================================================ AVISO DE TRÁFICO + PERSECUCIÓN

func _crear_aviso_trafico(nodo_forzado: int = -1, titulo: String = "", info: Array = []):
	# Aparece en una calle al azar, lejos del borde del mapa
	var nodo_inicio := red.nodo_mas_cercano(_pos_lugar("Plaza de España", tamano_mapa / 2.0) + Vector2(randf_range(-600, 600), randf_range(-500, 500)))
	if nodo_forzado >= 0:
		nodo_inicio = nodo_forzado
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
	inc.titulo = "Vehículo a %d km/h (límite %d)" % [medida, limite] if titulo == "" else titulo
	inc.informacion = ["Detectado por radar en %s" % calle_inicio, "Turismo de color rojo"] if info.is_empty() else info.duplicate()
	if turno == "noche":
		inc.informacion.append("Posible conductor bebido")
	inc.precision = 3
	inc.vehiculo_seguido = sospechoso
	inc.tiempo_creacion = tiempo_juego
	inc.position = sospechoso.position
	mundo.add_child(inc)
	incidentes.append(inc)
	if titulo == "":
		hud.notificar("AVISO AUTOMÁTICO: vehículo a %d km/h en %s. Pulsa Triángulo para verlo." % [medida, calle_inicio], COLOR_SISTEMA)
	else:
		inc.fuente = "Huida tras un robo"
		sospechoso.velocidad = 66.0
		sospechoso_acelero = true
	_sonido("alerta")
	_programar(60.0, _aviso_caduca.bind(inc))
	return inc


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
	hud.mirar_lugar(inc)


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
		if v.perseguir == sospechoso and v.bono != "camuflado" and v.position.distance_to(sospechoso.position) < 300.0:
			sospechoso_acelero = true
			sospechoso.velocidad = 66.0
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
	if not inc.en_escena.has(patrulla):
		inc.en_escena.append(patrulla)
	inc.llegadas[patrulla.id_unidad] = tiempo_juego
	if inc.cadena == "huida":
		if randf() < 0.55:
			_radio(patrulla, "¡El coche de los ladrones se ha estrellado! Los detenemos. Hay heridos: pedimos una ambulancia.")
			_choque_huida(objetivo.position)
		else:
			_radio(patrulla, "¡Los tenemos! Ladrones detenidos.")


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
	for nombre in ["llamada", "radio", "alerta", "envio", "click", "sirena", "pitido"]:
		var reproductor := AudioStreamPlayer.new()
		var ruta := "res://assets/audio/%s.wav" % nombre
		if ResourceLoader.exists(ruta):
			reproductor.stream = load(ruta)
		reproductor.volume_db = -4.0 if nombre != "sirena" else -8.0
		if nombre == "pitido":
			reproductor.volume_db = -12.0
		add_child(reproductor)
		sonidos[nombre] = reproductor
	sonidos["llamada"].finished.connect(_repetir_tono)


func _repetir_tono() -> void:
	if llamada_sonando:
		sonidos["llamada"].play()


func _vibrar(debil: float, fuerte: float, segundos: float) -> void:
	if not bool(opciones.get("vibracion", true)):
		return
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, debil, fuerte, segundos)


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
		{"texto": "Capa del mapa: %s" % {"": "Normal", "calor": "Mapa de calor (dónde hay más emergencias)", "historial": "Historial de emergencias"}[capa_mapa], "accion": _cambiar_capa_mapa},
		{"texto": "Mi carrera: rango, logros e investigaciones", "accion": _mostrar_carrera.bind(_mostrar_menu_pausa)},
		{"texto": "Prueba de mando: %s" % ("activada" if debug_activo else "desactivada"), "accion": _alternar_debug_menu},
		{"texto": "Configurar botones del mando", "accion": _calibrar_desde_menu},
		{"texto": "Configurar solo la cruceta", "accion": _cruceta_desde_menu},
		{"texto": "Restablecer la cruceta (arriba 11, abajo 12, izquierda 13)", "accion": _restablecer_cruceta},
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


## Configurar solo la cruceta (sin repetir X y Círculo).
func _empezar_cruceta() -> void:
	_cerrar_panel()
	cruceta_temp = {}
	paso_calibracion = 3
	hud.mostrar_calibracion("CONFIGURAR LA CRUCETA\n\nPulsa ARRIBA en la cruceta\n(una sola vez y sin tocar nada más)")


func _cruceta_desde_menu() -> void:
	_alternar_pausa()
	_empezar_cruceta()


func _cruceta_desde_portada() -> void:
	_empezar_cruceta()
	_programar_menu_tras_calibrar()


func _restablecer_cruceta() -> void:
	Controles.restablecer_cruceta()
	hud.notificar("Cruceta restablecida: arriba (botón 11), abajo (botón 12) e izquierda (botón 13).", Color("8fd3a0"))
	_sonido("click")


func _calibrar(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla != null and tecla.pressed and tecla.keycode == KEY_ENTER:
		hud.ocultar_calibracion()
		return
	var b := event as InputEventJoypadButton
	var m := event as InputEventJoypadMotion
	# Pasos 3, 4 y 5: la cruceta (arriba, abajo, izquierda). Paso 6: confirmar.
	if paso_calibracion == 6:
		if b != null and b.pressed and (b.button_index == Controles.boton_sel or b.button_index == boton_x):
			Controles.guardar_cruceta(cruceta_temp["arriba"], cruceta_temp["abajo"], cruceta_temp["izquierda"])
			paso_calibracion = 0
			hud.ocultar_calibracion()
			hud.notificar("Cruceta configurada: arriba sube, abajo baja e izquierda abre la comisaría.", Color("8fd3a0"))
		elif b != null and b.pressed and (b.button_index == Controles.boton_can or b.button_index == boton_circulo):
			_empezar_cruceta()
		elif tecla != null and tecla.pressed and tecla.keycode == KEY_ESCAPE:
			_empezar_cruceta()
		return
	if paso_calibracion >= 3:
		var dato := {}
		if b != null and b.pressed and b.button_index != boton_x and b.button_index != boton_circulo \
				and b.button_index != Controles.boton_sel and b.button_index != Controles.boton_can:
			dato = {"tipo": "boton", "indice": b.button_index}
		elif m != null and absf(m.axis_value) > 0.8 and m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
			dato = {"tipo": "eje", "indice": m.axis, "valor": signf(m.axis_value)}
		elif tecla != null and tecla.pressed and not tecla.echo:
			dato = {"tipo": "tecla", "indice": tecla.keycode}
		if dato.is_empty():
			return
		for ya in cruceta_temp:
			if cruceta_temp[ya] == dato:
				hud.mostrar_calibracion("Esa flecha ya es %s (%s).\n\nPulsa otra distinta." % [ya.to_upper(), Controles.describir(dato)])
				return
		var orden := ["arriba", "abajo", "izquierda"]
		var actual: String = orden[paso_calibracion - 3]
		cruceta_temp[actual] = dato
		paso_calibracion += 1
		if paso_calibracion <= 5:
			hud.mostrar_calibracion("%s guardado (%s)\n\nAhora pulsa %s en la cruceta" % [actual.to_upper(), Controles.describir(dato), orden[paso_calibracion - 3].to_upper()])
		else:
			hud.mostrar_calibracion("COMPRUEBA LA CRUCETA\n\nArriba: %s\nAbajo: %s\nIzquierda (comisaría): %s\n\nX: guardar   ·   Círculo: repetir" % [
				Controles.describir(cruceta_temp["arriba"]), Controles.describir(cruceta_temp["abajo"]), Controles.describir(cruceta_temp["izquierda"])])
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
		cruceta_temp = {}
		paso_calibracion = 3
		hud.mostrar_calibracion("Círculo guardado (botón %d)\n\nAhora pulsa ARRIBA en la cruceta" % boton_circulo)


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
	_clima_de_menu()
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
		{"texto": "Mi carrera", "accion": _mostrar_carrera.bind(_menu_principal), "activo": hay_partida},
		{"texto": "Opciones", "accion": _mostrar_opciones},
		{"texto": "Créditos", "accion": _mostrar_creditos},
		{"texto": "Salir", "accion": _salir},
	], true, 320.0, 520.0)


func _animar_portada(delta: float) -> void:
	_t_portada += delta
	efectos.noche = 1.0
	efectos.zoom = camara.zoom.x
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
				# Coche con las sirenas encendidas: destellos rojo y azul
				var rojo := int(_t_portada * 5.0 + k) % 2 == 0
				var col := Color(1.0, 0.2, 0.2) if rojo else Color(0.25, 0.45, 1.0)
				decoracion.draw_circle(p, 90.0, Color(col, 0.10))
				decoracion.draw_circle(p, 40.0, Color(col, 0.22))
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
	hud.texto_animado = bool(opciones["texto_animado"])
	var alta: bool = opciones["calidad"] == "alta"
	hud.vista_lugar.calidad_alta = alta
	if efectos != null:
		efectos.calidad_alta = alta
	if mapa != null:
		mapa.calidad_alta = alta


func _mostrar_opciones() -> void:
	var nombres_dif := {"tranquila": "Tranquila (menos emergencias)", "normal": "Normal", "caotica": "Caótica (más y a la vez)"}
	hud.mostrar_panel("OPCIONES", "", [
		{"texto": "Volumen: %d %%" % int(round(float(opciones["volumen"]) * 100.0)), "accion": _cambiar_volumen},
		{"texto": "Tamaño del texto: %s" % ("Grande" if opciones["texto_grande"] else "Normal"), "accion": _cambiar_texto},
		{"texto": "Dificultad: %s" % nombres_dif.get(opciones["dificultad"], "Normal"), "accion": _cambiar_dificultad},
		{"texto": "Calidad gráfica: %s" % ("Alta" if opciones["calidad"] == "alta" else "Normal (más fluida)"), "accion": _cambiar_opcion.bind("calidad")},
		{"texto": "Texto de las llamadas: %s" % ("Se va escribiendo" if opciones["texto_animado"] else "Aparece de golpe"), "accion": _cambiar_opcion.bind("texto_animado")},
		{"texto": "Meteorología (lluvia, niebla...): %s" % ("Sí" if opciones["meteo"] else "No"), "accion": _cambiar_opcion.bind("meteo")},
		{"texto": "Vibración del mando: %s" % ("Sí" if opciones["vibracion"] else "No"), "accion": _cambiar_opcion.bind("vibracion")},
		{"texto": "Configurar botones del mando", "accion": _calibrar_desde_portada},
		{"texto": "Configurar solo la cruceta", "accion": _cruceta_desde_portada},
		{"texto": "Restablecer la cruceta", "accion": _restablecer_cruceta},
		{"texto": "Volver", "accion": _menu_principal},
	], true, 190.0, 640.0)


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


func _cambiar_opcion(clave: String) -> void:
	if clave == "calidad":
		opciones["calidad"] = "normal" if opciones["calidad"] == "alta" else "alta"
	else:
		opciones[clave] = not bool(opciones[clave])
	_aplicar_opciones()
	_guardar_opciones()
	_sonido("click")
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
	["5 · EN EL LUGAR", "Cuando haya unidades en el lugar, abre la emergencia y a la izquierda verás lo que pasa. A veces las unidades piden refuerzos (+1 en el hexágono) o te piden órdenes.\nAntes de cada turno, en EQUIPOS puedes comprar vehículos, equipo y contratar personal."],
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
