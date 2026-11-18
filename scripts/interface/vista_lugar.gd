extends Control
## Vista "EN EL LUGAR": plano esquemático de lo que pasa cuando llegan
## las unidades. Puntos = nuestro personal (blanco sanitarios, azul policía,
## rojo bomberos). Triángulos = sospechosos. Casillas naranjas = fuego.
## Solo dibuja: la lógica (progreso, refuerzos, resultado) la lleva main.gd.

const ANCHO := 430.0
const ALTO := 300.0
const COL_SERV := {"ambulancia": Color("f2f6fc"), "policia": Color("3b8eea"), "bomberos": Color("e05555")}

var inc = null
var _t := 0.0
var fuente: Font


func _ready() -> void:
	fuente = ThemeDB.fallback_font
	size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.19, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), Color("3fb6d8"), false, 2.0)
	if inc == null or not is_instance_valid(inc):
		return
	draw_string(fuente, Vector2(12, 24), "EN EL LUGAR · %s" % inc.id_incidente, HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 24, 18, Color("9ff3ff"))
	draw_string(fuente, Vector2(12, 46), inc.titulo, HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 24, 16, Color("e2f0ff"))
	var zona := Rect2(12, 58, ANCHO - 24, 190)
	# Cuadrícula de fondo
	for x in range(int(zona.position.x), int(zona.end.x), 24):
		draw_line(Vector2(x, zona.position.y), Vector2(x, zona.end.y), Color(0.3, 0.5, 0.8, 0.12), 1.0)
	for y in range(int(zona.position.y), int(zona.end.y), 24):
		draw_line(Vector2(zona.position.x, y), Vector2(zona.end.x, y), Color(0.3, 0.5, 0.8, 0.12), 1.0)
	match inc.categoria:
		"fuego":
			_dibujar_fuego(zona)
		"medico", "atrapado":
			_dibujar_medico(zona)
		_:
			_dibujar_policial(zona)
	_dibujar_estado()


func _personal() -> Array:
	# Lista de colores, uno por persona trabajando en el lugar
	var lista := []
	for v in inc.en_lugar:
		if is_instance_valid(v):
			for i in mini(v.efectivos(), 4):
				lista.append(v.servicio)
	return lista


func _punto(p: Vector2, servicio: String) -> void:
	draw_circle(p, 8.0, Color(0, 0, 0, 0.5))
	draw_circle(p, 6.5, COL_SERV.get(servicio, Color.WHITE))


func _triangulo(p: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(8, 6), p + Vector2(-8, 6)]), color)


func _dibujar_policial(zona: Rect2) -> void:
	var p: float = inc.progreso
	var gente := _personal()
	var n_sosp := 1
	match inc.categoria:
		"pelea":
			n_sosp = 3
		"robo":
			n_sosp = 2
	var esperando: bool = inc.evento == "refuerzos"
	var terminado: bool = inc.evento == "terminado"
	# Vehículo de policía
	draw_rect(Rect2(zona.position + Vector2(14, zona.size.y - 40), Vector2(42, 26)), Color("1d4ed8"))
	draw_rect(Rect2(zona.position + Vector2(14, zona.size.y - 40), Vector2(42, 26)), Color.WHITE, false, 1.5)
	if inc.categoria == "robo":
		# Casa con habitaciones
		var casa := Rect2(zona.position + Vector2(zona.size.x * 0.55, 14), Vector2(zona.size.x * 0.4, zona.size.y - 28))
		draw_rect(casa, Color("14305e"))
		draw_rect(casa, Color("7fb2ff"), false, 2.0)
		draw_line(casa.position + Vector2(casa.size.x / 2.0, 0), casa.position + Vector2(casa.size.x / 2.0, casa.size.y * 0.6), Color("7fb2ff"), 2.0)
		draw_line(casa.position + Vector2(0, casa.size.y * 0.5), casa.position + Vector2(casa.size.x * 0.4, casa.size.y * 0.5), Color("7fb2ff"), 2.0)
	var destino_sosp := zona.position + Vector2(zona.size.x * 0.75, zona.size.y * 0.45)
	var avance := clampf(p * 1.8, 0.0, 1.0)
	if esperando:
		avance = 0.45
	for i in n_sosp:
		var sp := destino_sosp + Vector2(cos(i * 2.1) * 28.0, sin(i * 2.1) * 22.0)
		if esperando:
			sp += Vector2(sin(_t * 9.0 + i), cos(_t * 7.0 + i)) * 4.0
		var col := Color("ff4d6d")
		if terminado and inc.exito:
			col = Color("808a99")
		elif terminado and not inc.exito:
			sp += Vector2(fmod(_t, 3.0) * 60.0, 0)
		elif inc.categoria == "busqueda":
			col = Color("ffd166")   # el niño perdido
		_triangulo(sp, col)
	var origen := zona.position + Vector2(36, zona.size.y - 56)
	for i in gente.size():
		var meta := destino_sosp + Vector2(-46 + (i % 3) * 18.0, -30 + (i / 3) * 26.0)
		if inc.categoria == "busqueda" and not terminado:
			meta = zona.position + Vector2(40 + fmod(i * 97.0 + _t * 40.0, zona.size.x - 80), 30 + fmod(i * 53.0 + _t * 25.0, zona.size.y - 60))
		var pp := origen.lerp(meta, avance) + Vector2(i * 4.0, 0)
		_punto(pp, gente[i])
		# Forcejeo
		if inc.categoria == "pelea" and p > 0.35 and p < 0.8 and not terminado and int(_t * 8.0 + i) % 3 == 0:
			draw_line(pp, destino_sosp, Color("ffb347"), 2.0)


func _dibujar_fuego(zona: Rect2) -> void:
	var edificio := Rect2(zona.position + Vector2(zona.size.x * 0.35, 10), Vector2(zona.size.x * 0.6, zona.size.y - 20))
	draw_rect(edificio, Color("1b2a4a"))
	draw_rect(edificio, Color("7fb2ff"), false, 2.0)
	var cols := 8
	var filas := 6
	var celda := Vector2(edificio.size.x / cols, edificio.size.y / filas)
	var p: float = inc.progreso
	var fuego: float = (1.0 - p) * (0.35 + 0.15 * inc.intensidad)
	if inc.evento == "refuerzos":
		fuego = 0.55 + 0.1 * sin(_t * 2.0)
	if inc.evento == "terminado" and not inc.exito:
		fuego = 0.5
	var ardiendo := []
	for c in cols:
		for r in filas:
			var valor := fmod(sin(c * 12.9898 + r * 78.233) * 43758.5453, 1.0)
			if absf(valor) < fuego:
				var rect := Rect2(edificio.position + Vector2(c, r) * celda, celda).grow(-2.0)
				var parp := 0.7 + 0.3 * sin(_t * 8.0 + c + r)
				draw_rect(rect, Color(1.0, 0.45 * parp + 0.2, 0.1, 0.85))
				ardiendo.append(rect.get_center())
	var gente := _personal()
	for i in gente.size():
		var pp := zona.position + Vector2(30 + (i % 2) * 26.0, 30 + i * 22.0)
		_punto(pp, gente[i])
		if gente[i] == "bomberos" and not ardiendo.is_empty():
			var objetivo: Vector2 = ardiendo[(i + int(_t * 2.0)) % ardiendo.size()]
			draw_line(pp, objetivo, Color(0.4, 0.75, 1.0, 0.8), 3.0)


func _dibujar_medico(zona: Rect2) -> void:
	var centro := zona.get_center() + Vector2(20, 0)
	if inc.categoria == "atrapado":
		draw_rect(Rect2(centro - Vector2(55, 28), Vector2(110, 56)), Color("4a5d80"))
		draw_rect(Rect2(centro - Vector2(55, 28), Vector2(110, 56)), Color.WHITE, false, 1.5)
	# Paciente
	draw_rect(Rect2(centro - Vector2(14, 4), Vector2(28, 8)), Color("ff6b6b"))
	draw_rect(Rect2(centro - Vector2(4, 14), Vector2(8, 28)), Color("ff6b6b"))
	var gente := _personal()
	for i in gente.size():
		var ang := TAU * i / maxf(gente.size(), 1) + _t * 0.3
		var pp := centro + Vector2(cos(ang), sin(ang)) * 52.0
		_punto(pp, gente[i])
		if gente[i] == "bomberos" and inc.categoria == "atrapado" and int(_t * 10.0 + i) % 2 == 0:
			draw_line(pp, centro + (pp - centro) * 0.5, Color("ffe066"), 2.0)
	# Barra de estabilización
	var barra := Rect2(zona.position + Vector2(20, zona.size.y - 22), Vector2(zona.size.x - 40, 12))
	draw_rect(barra, Color("13283a"))
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * inc.progreso, barra.size.y)), Color("2ecc71"))


func _dibujar_estado() -> void:
	var texto := ""
	var color := Color("e2f0ff")
	match inc.evento:
		"en_curso":
			texto = "Interviniendo... %d%%" % int(inc.progreso * 100.0)
		"refuerzos":
			texto = "¡PIDEN REFUERZOS! %s · %d s" % [inc.texto_requeridas(), int(ceil(inc.t_refuerzos))]
			color = Color("ffd166") if int(_t * 3.0) % 2 == 0 else Color("ff6b6b")
		"decision":
			texto = "Esperando órdenes de la central..."
			color = Color("9ff3ff")
		"terminado":
			texto = inc.resultado
			color = Color("8fd3a0") if inc.exito else Color("ff8a65")
		_:
			texto = "Esperando unidades: %s" % inc.texto_requeridas()
	draw_string(fuente, Vector2(12, ALTO - 22), texto, HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 24, 16, color)
