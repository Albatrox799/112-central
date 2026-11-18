extends Node2D
## Mapa real de Miguelturra (datos de OpenStreetMap) con estética de
## central táctica: fondo oscuro, calles iluminadas, edificios y zonas.
## Las calles y edificios se crean una sola vez como nodos estáticos,
## así el Fire TV no tiene que recalcularlos en cada fotograma.

const COLOR_FONDO := Color("0a1430")
const COLOR_TEXTO := Color("9ec4ff")

const ESTILO_ZONAS := {
	# tipo: [color, orden de dibujo]
	"campo": [Color("0c1a35"), 0],
	"residencial": [Color("0f2148"), 1],
	"industrial": [Color("131d47"), 1],
	"comercial": [Color("15214c"), 1],
	"aparcamiento": [Color("13264f"), 2],
	"plaza": [Color("19305f"), 2],
	"deporte": [Color("0f344c"), 2],
	"parque": [Color("0e3848"), 2],
	"agua": [Color("0b3f74"), 3],
}

const ESTILO_VIAS := {
	# tipo: [color, ancho en metros, orden]
	"path": [Color("1b3568"), 2.5, 0], "footway": [Color("1b3568"), 2.5, 0],
	"cycleway": [Color("1b3d68"), 2.5, 0], "track": [Color("1c3659"), 4.0, 0],
	"service": [Color("23437e"), 6.0, 1], "pedestrian": [Color("284a88"), 8.0, 1],
	"living_street": [Color("2c5098"), 10.0, 2], "residential": [Color("2c5098"), 10.0, 2],
	"unclassified": [Color("3560aa"), 11.0, 3],
	"tertiary": [Color("4a80d2"), 14.0, 4], "tertiary_link": [Color("4a80d2"), 12.0, 4],
	"secondary": [Color("5590e0"), 15.0, 4], "secondary_link": [Color("5590e0"), 12.0, 4],
	"primary": [Color("62a0ee"), 16.0, 4], "primary_link": [Color("62a0ee"), 12.0, 4],
	"trunk": [Color("70aef8"), 18.0, 4], "trunk_link": [Color("70aef8"), 12.0, 4],
	"motorway": [Color("70aef8"), 20.0, 4], "motorway_link": [Color("70aef8"), 12.0, 4],
}

const ICONOS := {
	# tipo: [letra, color]
	"sanidad": ["+", Color("2ecc71")], "farmacia": ["F", Color("2ecc71")],
	"ayuntamiento": ["Ay", Color("c9a227")], "policia": ["P", Color("4d96ff")],
	"bomberos": ["B", Color("e74c3c")], "colegio": ["C", Color("9b8cff")],
	"iglesia": ["I", Color("d9c8a9")], "teatro": ["T", Color("e0a96d")],
	"gasolinera": ["G", Color("bdbdbd")], "supermercado": ["S", Color("f2994a")],
	"restaurante": ["R", Color("f2c94c")], "bar": ["b", Color("f2c94c")],
	"deporte": ["D", Color("56cfe1")], "comercio": ["c", Color("f2c94c")],
	"edificio": ["E", Color("aab7c4")],
}

var datos: Dictionary = {}
var tamano := Vector2(3000, 3000)
var fuente: Font
var capa_nombres: Node2D
var capa_iconos: Node2D
var bases: Array = []   # [{nombre, pos, color, letra}]
var relieve: Node2D     # sombras y bordes iluminados de los edificios
var calidad_alta := true:
	set(valor):
		calidad_alta = valor
		if relieve != null:
			relieve.visible = valor


func _ready() -> void:
	fuente = ThemeDB.fallback_font
	tamano = Vector2(float(datos["tamano"][0]), float(datos["tamano"][1]))
	_crear_zonas()
	_crear_tren()
	_crear_vias()
	_crear_edificios()
	capa_iconos = Node2D.new()
	capa_iconos.draw.connect(_dibujar_iconos)
	add_child(capa_iconos)
	capa_nombres = Node2D.new()
	capa_nombres.draw.connect(_dibujar_nombres)
	add_child(capa_nombres)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tamano), COLOR_FONDO)


func mostrar_nombres(si: bool) -> void:
	if capa_nombres.visible != si:
		capa_nombres.visible = si


func anadir_base(nombre: String, pos: Vector2, color: Color, letra: String) -> void:
	bases.append({"nombre": nombre, "pos": pos, "color": color, "letra": letra})
	if capa_iconos:
		capa_iconos.queue_redraw()
		capa_nombres.queue_redraw()


# ------------------------------------------------------------------ CREACIÓN

func _puntos(lista: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.resize(lista.size() / 2)
	for i in p.size():
		p[i] = Vector2(float(lista[i * 2]), float(lista[i * 2 + 1]))
	return p


func _crear_zonas() -> void:
	var zonas: Array = datos["zonas"].duplicate()
	zonas.sort_custom(func(a, b): return ESTILO_ZONAS.get(a["tipo"], [Color.BLACK, 1])[1] < ESTILO_ZONAS.get(b["tipo"], [Color.BLACK, 1])[1])
	for z in zonas:
		var estilo: Array = ESTILO_ZONAS.get(z["tipo"], [Color("1a2430"), 1])
		var poly := Polygon2D.new()
		poly.polygon = _puntos(z["puntos"])
		poly.color = estilo[0]
		add_child(poly)


func _crear_tren() -> void:
	for t in datos["tren"]:
		var l := Line2D.new()
		l.points = _puntos(t)
		l.width = 5.0
		l.default_color = Color("2a3f70")
		add_child(l)


func _crear_vias() -> void:
	var vias: Array = datos["vias"].duplicate()
	vias.sort_custom(func(a, b): return ESTILO_VIAS.get(a["tipo"], [Color.BLACK, 1.0, 2])[2] < ESTILO_VIAS.get(b["tipo"], [Color.BLACK, 1.0, 2])[2])
	for v in vias:
		var estilo: Array = ESTILO_VIAS.get(v["tipo"], [Color("2c5098"), 10.0, 2])
		if estilo[2] >= 4:
			# Resplandor de las calles principales
			var brillo := Line2D.new()
			brillo.points = _puntos(v["puntos"])
			brillo.width = estilo[1] * 2.6
			brillo.default_color = Color(0.35, 0.6, 1.0, 0.10)
			brillo.joint_mode = Line2D.LINE_JOINT_ROUND
			add_child(brillo)
		var l := Line2D.new()
		l.points = _puntos(v["puntos"])
		l.width = estilo[1]
		l.default_color = estilo[0]
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(l)


func _crear_edificios() -> void:
	# Sombra debajo (da sensación de altura); se dibuja una sola vez
	relieve = Node2D.new()
	relieve.draw.connect(_dibujar_sombras)
	relieve.visible = calidad_alta
	add_child(relieve)
	for e in datos["edificios"]:
		var poly := Polygon2D.new()
		poly.polygon = _puntos(e)
		poly.color = Color("1b3772")
		add_child(poly)
	var bordes := Node2D.new()
	bordes.draw.connect(_dibujar_bordes.bind(bordes))
	add_child(bordes)


func _dibujar_sombras() -> void:
	for e in datos["edificios"]:
		var p := _puntos(e)
		var sombra := PackedVector2Array()
		for q in p:
			sombra.append(q + Vector2(6, 8))
		if sombra.size() >= 3:
			relieve.draw_colored_polygon(sombra, Color(0.0, 0.02, 0.08, 0.55))


## Tejados: borde claro y un poco más de luz en el centro.
func _dibujar_bordes(nodo: Node2D) -> void:
	for e in datos["edificios"]:
		var p := _puntos(e)
		if p.size() < 3:
			continue
		var cerrado := p.duplicate()
		cerrado.append(p[0])
		nodo.draw_polyline(cerrado, Color("3e6ccc"), 1.6)
		var centro := Vector2.ZERO
		for q in p:
			centro += q
		centro /= float(p.size())
		var tejado := PackedVector2Array()
		for q in p:
			tejado.append(centro + (q - centro) * 0.6)
		nodo.draw_colored_polygon(tejado, Color(0.25, 0.4, 0.75, 0.25))


# ------------------------------------------------------------------ DIBUJO

func _dibujar_iconos() -> void:
	for l in datos["lugares"]:
		var tipo: String = l["tipo"]
		if not ICONOS.has(tipo):
			continue
		var icono: Array = ICONOS[tipo]
		_icono(Vector2(float(l["x"]), float(l["y"])), icono[0], icono[1], 13.0)
	for b in bases:
		_hexagono_base(b["pos"], b["color"], b["letra"])


func _hexagono_base(p: Vector2, color: Color, letra: String) -> void:
	var hex := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		hex.append(p + Vector2(cos(a), sin(a)) * 22.0)
	capa_iconos.draw_colored_polygon(hex, Color("0d2a5c"))
	var borde := hex.duplicate()
	borde.append(hex[0])
	capa_iconos.draw_polyline(borde, color, 3.0)
	capa_iconos.draw_string(fuente, p + Vector2(-22, 7), letra, HORIZONTAL_ALIGNMENT_CENTER, 44, 20, color)


func _icono(p: Vector2, letra: String, color: Color, radio: float) -> void:
	capa_iconos.draw_circle(p, radio + 3.0, Color(0, 0, 0, 0.6))
	capa_iconos.draw_circle(p, radio, color)
	capa_iconos.draw_string(fuente, p + Vector2(-radio, radio * 0.45), letra, HORIZONTAL_ALIGNMENT_CENTER, radio * 2.0, int(radio * 1.15), Color.BLACK)


func _dibujar_nombres() -> void:
	# Nombre de cada calle sobre su tramo recto más largo
	var mejor := {}
	for v in datos["vias"]:
		var nombre: String = v["nombre"]
		if nombre == "" or v["tipo"] in ["path", "footway", "cycleway", "track"]:
			continue
		var p := _puntos(v["puntos"])
		for i in range(1, p.size()):
			var largo := p[i - 1].distance_to(p[i])
			if not mejor.has(nombre) or largo > mejor[nombre][2]:
				mejor[nombre] = [p[i - 1], p[i], largo]
	for nombre in mejor:
		var a: Vector2 = mejor[nombre][0]
		var b: Vector2 = mejor[nombre][1]
		if mejor[nombre][2] < 45.0:
			continue
		var angulo := (b - a).angle()
		if angulo > PI / 2.0 or angulo < -PI / 2.0:
			angulo += PI
		capa_nombres.draw_set_transform((a + b) / 2.0, angulo, Vector2.ONE)
		capa_nombres.draw_string_outline(fuente, Vector2(-200, 6), nombre, HORIZONTAL_ALIGNMENT_CENTER, 400, 18, 4, Color("0a1430"))
		capa_nombres.draw_string(fuente, Vector2(-200, 6), nombre, HORIZONTAL_ALIGNMENT_CENTER, 400, 18, COLOR_TEXTO)
	capa_nombres.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Nombres de lugares
	for l in datos["lugares"]:
		var p := Vector2(float(l["x"]), float(l["y"]))
		var desplaz := Vector2(-150, 34) if ICONOS.has(l["tipo"]) else Vector2(-150, 6)
		var color := Color("d6e6ff") if ICONOS.has(l["tipo"]) else Color("7fe0d0")
		capa_nombres.draw_string_outline(fuente, p + desplaz, l["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 300, 15, 4, Color("0a1430"))
		capa_nombres.draw_string(fuente, p + desplaz, l["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 300, 15, color)
	for b in bases:
		var p: Vector2 = b["pos"] + Vector2(-150, 40)
		capa_nombres.draw_string_outline(fuente, p, b["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 300, 17, 4, Color("0a1430"))
		capa_nombres.draw_string(fuente, p, b["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 300, 17, b["color"])
