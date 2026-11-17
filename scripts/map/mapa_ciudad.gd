extends Node2D
## Dibuja el mapa 2D visto desde arriba: campo, manzanas, calles,
## rotonda, nombres de calles y lugares de referencia.
## Se dibuja una sola vez (no consume rendimiento en cada fotograma).

const MapaPrueba = preload("res://data/map/mapa_prueba.gd")
const RedViaria = preload("res://scripts/routing/red_viaria.gd")

const COLOR_CAMPO := Color("27321f")
const COLOR_FONDO := Color("1b2430")
const COLOR_EDIFICIO := Color("2c3a4d")
const COLOR_BORDE_CALLE := Color("3f4b5c")
const COLOR_CALLE := Color("66758a")
const COLOR_TEXTO_CALLE := Color("e8eef6")

var red: RedViaria
var fuente: Font


func _ready() -> void:
	fuente = ThemeDB.fallback_font
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MapaPrueba.TAMANO), COLOR_CAMPO)
	# Casco urbano
	draw_rect(Rect2(Vector2(220, 220), Vector2(1660, 1060)), COLOR_FONDO)
	_dibujar_manzanas()
	_dibujar_calles()
	_dibujar_nombres_calles()
	_dibujar_lugares()


func _dibujar_manzanas() -> void:
	var cols: Array = MapaPrueba.COLUMNAS
	var filas: Array = MapaPrueba.FILAS
	for i in range(cols.size() - 1):
		for j in range(filas.size() - 1):
			var x0: float = cols[i]
			var x1: float = cols[i + 1]
			var y0: float = filas[j]
			var y1: float = filas[j + 1]
			var r := Rect2(x0 + 28, y0 + 28, x1 - x0 - 56, y1 - y0 - 56)
			var clave := "%d,%d" % [i, j]
			var tipo: String = MapaPrueba.MANZANAS_ESPECIALES.get(clave, "viviendas")
			match tipo:
				"plaza":
					draw_rect(r, Color("3b4a3c"))
					draw_circle(r.get_center(), 34, Color("4f6a52"))
				"parque":
					draw_rect(r, Color("244a2c"))
					for k in 9:
						var p := r.position + Vector2(40 + (k % 3) * 85, 40 + (k / 3) * 70)
						draw_circle(p, 16, Color("2f6b3a"))
				"industrial":
					draw_rect(r, Color("2a2d38"))
					draw_rect(Rect2(r.position + Vector2(14, 14), Vector2(r.size.x * 0.55, r.size.y * 0.45)), Color("3d4152"))
					draw_rect(Rect2(r.position + Vector2(14, r.size.y * 0.55), Vector2(r.size.x - 28, r.size.y * 0.38)), Color("3d4152"))
				_:
					var mitad := r.size / 2.0
					for dx in 2:
						for dy in 2:
							var pos_edificio := r.position + Vector2(dx * mitad.x, dy * mitad.y) + Vector2(6, 6)
							draw_rect(Rect2(pos_edificio, mitad - Vector2(12, 12)), COLOR_EDIFICIO)


func _dibujar_calles() -> void:
	for t in red.tramos:
		var a: Vector2 = red.posiciones[t[0]]
		var b: Vector2 = red.posiciones[t[1]]
		draw_line(a, b, COLOR_BORDE_CALLE, 44.0)
	for nombre in red.posiciones:
		draw_circle(red.posiciones[nombre], 22.0, COLOR_BORDE_CALLE)
	for t in red.tramos:
		var a: Vector2 = red.posiciones[t[0]]
		var b: Vector2 = red.posiciones[t[1]]
		draw_line(a, b, COLOR_CALLE, 36.0)
	for nombre in red.posiciones:
		draw_circle(red.posiciones[nombre], 18.0, COLOR_CALLE)
	# Rotonda
	var rotonda: Vector2 = red.posiciones["R"]
	draw_circle(rotonda, 56.0, COLOR_CALLE)
	draw_circle(rotonda, 24.0, Color("2f5a37"))


func _dibujar_nombres_calles() -> void:
	# Un rótulo por calle, en el tramo central de cada una
	var por_calle := {}
	for t in red.tramos:
		var calle: String = t[2]
		if not por_calle.has(calle):
			por_calle[calle] = []
		por_calle[calle].append(t)
	for calle in por_calle:
		var lista: Array = por_calle[calle]
		var t: Array = lista[lista.size() / 2]
		var a: Vector2 = red.posiciones[t[0]]
		var b: Vector2 = red.posiciones[t[1]]
		var medio := (a + b) / 2.0
		var angulo := (b - a).angle()
		if angulo > PI / 2.0 or angulo < -PI / 2.0:
			angulo += PI
		draw_set_transform(medio, angulo, Vector2.ONE)
		draw_string(fuente, Vector2(-160, 7), calle, HORIZONTAL_ALIGNMENT_CENTER, 320, 19, COLOR_TEXTO_CALLE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dibujar_lugares() -> void:
	for l in MapaPrueba.LUGARES:
		var p: Vector2 = l["pos"]
		var letra: String = l["letra"]
		var color: Color = l["color"]
		if letra == "":
			draw_string(fuente, p + Vector2(-150, 0), l["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 300, 22, color)
			continue
		draw_circle(p, 18.0, color)
		draw_arc(p, 18.0, 0.0, TAU, 24, Color(0, 0, 0, 0.7), 2.0)
		draw_string(fuente, p + Vector2(-18, 7), letra, HORIZONTAL_ALIGNMENT_CENTER, 36, 18, Color.BLACK)
		draw_string(fuente, p + Vector2(-110, 40), l["nombre"], HORIZONTAL_ALIGNMENT_CENTER, 220, 16, Color("cfd9e6"))
