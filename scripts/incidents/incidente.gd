extends Node2D
## Emergencia que aparece en el mapa.
## Tipos: "llamada" (sanitaria), "aviso_trafico" (persecución), "incendio".
## Si la localización no es exacta, se dibuja un círculo de búsqueda.
## Cada emergencia tiene un tiempo de urgencia: si ninguna unidad llega
## antes de que se agote, la situación empeora.

const NOMBRES_PRECISION := ["Ubicación desconocida", "Zona aproximada", "Calle identificada", "Punto exacto"]

var id_incidente := ""
var tipo := "llamada"
var titulo := ""
var fuente := "Llamada al 112"
var servicio_necesario := "ambulancia"
var informacion: Array = []
var marcas: Array = []
var estado := "Pendiente"       # Pendiente, Unidad en camino, En intervención, Persecución en curso, Resuelta
var precision := 0
var precision_al_enviar := -1
var calma_final := 50
var nodo_real := -1
var nodo_aproximado := -1
var pos_exacta := Vector2.ZERO
var pos_calle := Vector2.ZERO
var pos_zona := Vector2.ZERO
var radio_calle := 180.0
var radio_zona := 300.0
var tiempo_creacion := 0.0
var tiempo_llegada := -1.0
var unidades: Array = []
var vehiculo_seguido: Node2D = null
var seleccionado := false
var escala_icono := 1.0
# Urgencia (segundos de juego)
var urgencia_total := 0.0
var urgencia_restante := 0.0
var empeorado := false
# Incendios
var intensidad := 1             # 1 = conato, 2 = declarado, 3 = grave
var _t := 0.0
var _humo: Array = []           # partículas de humo [pos, vida, tamaño]


func posicion_aproximada() -> Vector2:
	match precision:
		3:
			return pos_exacta
		2:
			return pos_calle
		_:
			return pos_zona


func radio_visible() -> float:
	match precision:
		2:
			return radio_calle
		1:
			return radio_zona
	return 0.0


func texto_precision() -> String:
	return NOMBRES_PRECISION[clampi(precision, 0, 3)]


func actualizar_posicion() -> void:
	if vehiculo_seguido == null:
		position = posicion_aproximada()


func activo() -> bool:
	return estado != "Resuelta"


## ¿Sigue corriendo el tiempo de urgencia? (hasta que llega la unidad adecuada)
func esperando_ayuda() -> bool:
	return activo() and tiempo_llegada < 0.0 and urgencia_total > 0.0


func _process(delta: float) -> void:
	_t += delta
	if vehiculo_seguido != null:
		if is_instance_valid(vehiculo_seguido):
			position = vehiculo_seguido.position
		else:
			vehiculo_seguido = null
	if esperando_ayuda():
		urgencia_restante = maxf(urgencia_restante - delta, 0.0)
	if tipo == "incendio" and activo():
		_actualizar_humo(delta)
	queue_redraw()


func _actualizar_humo(delta: float) -> void:
	if randf() < delta * (6.0 + intensidad * 6.0):
		_humo.append([Vector2(randf_range(-12, 12), randf_range(-8, 8)) * intensidad, 0.0, randf_range(10, 18)])
	var vivas: Array = []
	for h in _humo:
		h[1] += delta
		h[0] += Vector2(18.0, -30.0) * delta   # el viento empuja el humo
		h[2] += delta * 14.0
		if h[1] < 3.0:
			vivas.append(h)
	_humo = vivas


func _draw() -> void:
	if not activo():
		return
	var f := ThemeDB.fallback_font
	var r := radio_visible()
	if r > 0.0:
		draw_circle(Vector2.ZERO, r, Color(1, 0.45, 0.2, 0.12))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 0.55, 0.25, 0.6), 3.0)
	var s := escala_icono
	if tipo == "incendio":
		_dibujar_fuego()
	var pulso := 1.0 + 0.25 * sin(_t * 5.0)
	var color := Color("ff4d4d")
	if tipo == "aviso_trafico":
		color = Color("ffa630")
	elif tipo == "incendio":
		color = Color("ff7a1a")
	draw_circle(Vector2.ZERO, 34.0 * s * pulso, Color(color, 0.22))
	if seleccionado:
		draw_arc(Vector2.ZERO, 40.0 * s, 0.0, TAU, 32, Color.WHITE, 3.0 * s)
	# Anillo de urgencia: se vacía con el tiempo (verde -> rojo)
	if esperando_ayuda():
		var fr := urgencia_restante / urgencia_total
		var col_urg := Color("e74c3c").lerp(Color("2ecc71"), fr)
		draw_arc(Vector2.ZERO, 30.0 * s, -PI / 2.0, -PI / 2.0 + TAU * fr, 40, col_urg, 5.0 * s)
	if vehiculo_seguido == null:
		draw_circle(Vector2.ZERO, 21.0 * s, color)
		draw_arc(Vector2.ZERO, 21.0 * s, 0.0, TAU, 28, Color(0, 0, 0, 0.8), 2.0 * s)
		var simbolo := "!"
		if tipo == "incendio":
			simbolo = "F"
		elif servicio_necesario == "ambulancia":
			simbolo = "+"
		draw_string(f, Vector2(-20, 10) * s, simbolo, HORIZONTAL_ALIGNMENT_CENTER, 40 * s, int(28 * s), Color.BLACK)
	draw_string_outline(f, Vector2(-100, -46) * s, id_incidente, HORIZONTAL_ALIGNMENT_CENTER, 200 * s, int(18 * s), int(4 * s), Color("0f151c"))
	draw_string(f, Vector2(-100, -46) * s, id_incidente, HORIZONTAL_ALIGNMENT_CENTER, 200 * s, int(18 * s), Color.WHITE)


func _dibujar_fuego() -> void:
	# Humo
	for h in _humo:
		var a: float = 0.35 * (1.0 - h[1] / 3.0)
		draw_circle(h[0], h[2], Color(0.45, 0.45, 0.48, a))
	# Llamas que parpadean
	var base := 14.0 + intensidad * 12.0
	for i in 6:
		var ang := TAU * i / 6.0 + _t * 0.7
		var rr := base * (0.55 + 0.25 * sin(_t * 9.0 + i * 1.7))
		var p := Vector2(cos(ang), sin(ang)) * rr * 0.6
		draw_circle(p, rr * 0.55, Color(1.0, 0.45 + 0.2 * sin(_t * 7.0 + i), 0.1, 0.55))
	draw_circle(Vector2.ZERO, base * 0.45, Color(1.0, 0.85, 0.3, 0.7))
