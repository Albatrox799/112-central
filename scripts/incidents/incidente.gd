extends Node2D
## Emergencia que aparece en el mapa.
## Puede venir de una llamada (tipo "llamada") o de un aviso
## automático del sistema (tipo "aviso_trafico").
## Si la localización no es exacta, se dibuja un círculo de búsqueda.

const NOMBRES_PRECISION := ["Ubicación desconocida", "Zona aproximada", "Calle identificada", "Punto exacto"]

var id_incidente := ""
var tipo := "llamada"
var titulo := ""
var fuente := "Llamada al 112"
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
var _t := 0.0


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


func _process(delta: float) -> void:
	_t += delta
	if vehiculo_seguido != null:
		if is_instance_valid(vehiculo_seguido):
			position = vehiculo_seguido.position
		else:
			vehiculo_seguido = null
	queue_redraw()


func _draw() -> void:
	if not activo():
		return
	var f := ThemeDB.fallback_font
	var r := radio_visible()
	if r > 0.0:
		draw_circle(Vector2.ZERO, r, Color(1, 0.45, 0.2, 0.12))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 0.55, 0.25, 0.6), 3.0)
	var pulso := 1.0 + 0.25 * sin(_t * 5.0)
	var color := Color("ff4d4d") if tipo == "llamada" else Color("ffa630")
	draw_circle(Vector2.ZERO, 32.0 * pulso, Color(color, 0.25))
	if seleccionado:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, Color.WHITE, 3.0)
	if vehiculo_seguido == null:
		draw_circle(Vector2.ZERO, 20.0, color)
		draw_string(f, Vector2(-20, 10), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 28, Color.BLACK)
	draw_string(f, Vector2(-100, -42), id_incidente, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color.WHITE)
