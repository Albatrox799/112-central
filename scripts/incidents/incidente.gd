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
## Servicios que hay que enviar (se dibujan como colores del hexágono)
var servicios: Array = ["ambulancia"]
var traslado := false          # la ambulancia lleva al herido al hospital
# Mini evento "En el lugar"
var categoria := "medico"       # medico, pelea, robo, fuego, busqueda, atrapado, control
var requeridas: Dictionary = {} # servicio -> unidades necesarias
var presentes: Dictionary = {}  # servicio -> unidades en el lugar
var en_lugar: Array = []        # vehículos trabajando en el lugar
var evento := ""                # "", en_curso, refuerzos, terminado
var progreso := 0.0
var duracion := 10.0
var t_refuerzos := 0.0
var refuerzo_pedido := false
var exito := true
var resultado := ""
# Historias
var historia = null             # datos de la historia (o null si es una emergencia normal)
var desenlace := ""             # lo que pasa de verdad
var variables: Dictionary = {}  # {lugar}, {calle}...
var eventos_hechos: Array = []
var cronologia: Array = []      # ["hh:mm", texto]
var confirmados: Array = []
var llamadas_relacionadas := 0
var decision_pendiente := false
var ajuste_estrellas := 0
var apoyos: Array = []          # unidades de primera respuesta esperando al servicio principal


func registrar(hora: String, texto: String) -> void:
	cronologia.append([hora, texto])
var tiempo_intervencion := 10.0 # segundos en el lugar
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


func unidades_que_faltan() -> int:
	var total := 0
	for sv in requeridas:
		total += maxi(int(requeridas[sv]) - int(presentes.get(sv, 0)), 0)
	return total


func requeridas_cumplidas() -> bool:
	return unidades_que_faltan() == 0


func texto_requeridas() -> String:
	var partes := []
	var nombres := {"ambulancia": "Ambulancia", "policia": "Policía", "bomberos": "Bomberos"}
	for sv in requeridas:
		partes.append("%s %d/%d" % [nombres.get(sv, sv), int(presentes.get(sv, 0)), int(requeridas[sv])])
	return ", ".join(PackedStringArray(partes))


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
		var factor := 1.0
		for a in apoyos:
			if is_instance_valid(a):
				factor = 0.5   # alguien ya está atendiendo: empeora más despacio
		urgencia_restante = maxf(urgencia_restante - delta * factor, 0.0)
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


const COLOR_SERVICIO := {
	"ambulancia": [Color("f2f6fc"), Color("d63031")],   # blanco
	"policia": [Color("3b8eea"), Color("ffffff")],      # azul
	"bomberos": [Color("d64545"), Color("ffffff")],     # rojo
}
const ORDEN_SERVICIOS := ["ambulancia", "policia", "bomberos"]


func _draw() -> void:
	if not activo():
		return
	var f := ThemeDB.fallback_font
	var r := radio_visible()
	if r > 0.0:
		draw_circle(Vector2.ZERO, r, Color(0.4, 0.75, 1.0, 0.10))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.55, 0.85, 1.0, 0.6), 3.0)
	var s := escala_icono
	if tipo == "incendio":
		_dibujar_fuego()
	# Ondas en el suelo
	for k in 2:
		var fase := fmod(_t * 0.8 + k * 0.5, 1.0)
		draw_arc(Vector2.ZERO, (8.0 + fase * 26.0) * s, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.8 * (1.0 - fase)), 2.0 * s)
	draw_circle(Vector2.ZERO, 5.0 * s, Color("bfe6ff"))
	# Hexágono flotante con los colores de los servicios necesarios
	var alto := 48.0 if vehiculo_seguido == null else 92.0
	var centro := Vector2(0, -alto) * s
	var radio := 24.0 * s
	draw_line(Vector2.ZERO, centro + Vector2(0, radio), Color(0.75, 0.9, 1.0, 0.9), 2.0 * s)
	var hex := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		hex.append(centro + Vector2(cos(a), sin(a)) * radio)
	var lista: Array = []
	for sv in ORDEN_SERVICIOS:
		if servicios.has(sv):
			lista.append(sv)
	if lista.is_empty():
		lista = ["policia"]
	var ancho_franja := radio * 2.0 / lista.size()
	for k in lista.size():
		var x0 := centro.x - radio + k * ancho_franja
		var franja := PackedVector2Array([
			Vector2(x0, centro.y - radio * 1.2), Vector2(x0 + ancho_franja, centro.y - radio * 1.2),
			Vector2(x0 + ancho_franja, centro.y + radio * 1.2), Vector2(x0, centro.y + radio * 1.2)])
		var colores: Array = COLOR_SERVICIO[lista[k]]
		for trozo in Geometry2D.intersect_polygons(hex, franja):
			draw_colored_polygon(trozo, colores[0])
		_dibujar_simbolo(lista[k], Vector2(x0 + ancho_franja / 2.0, centro.y), colores[1], s * (1.0 if lista.size() == 1 else 0.75))
	var borde := hex.duplicate()
	borde.append(hex[0])
	draw_polyline(borde, Color.WHITE, 2.5 * s)
	# Refuerzos pedidos: "+N" parpadeando junto al hexágono
	var faltan := unidades_que_faltan()
	if faltan > 0 and (evento == "refuerzos" or evento == ""):
		var vis := evento == "" or int(_t * 3.0) % 2 == 0
		if vis:
			var pos_marca := centro + Vector2(radio + 4.0 * s, -radio)
			draw_circle(pos_marca, 13.0 * s, Color("ffd166"))
			draw_string(f, pos_marca + Vector2(-13, 6) * s, "+%d" % faltan, HORIZONTAL_ALIGNMENT_CENTER, 26 * s, int(16 * s), Color("0a1430"))
	if seleccionado:
		var grande := PackedVector2Array()
		for p in borde:
			grande.append(centro + (p - centro) * 1.3)
		draw_polyline(grande, Color("9ff3ff"), 3.0 * s)
	# Anillo de urgencia alrededor del hexágono (verde -> rojo)
	if esperando_ayuda():
		var fr := urgencia_restante / urgencia_total
		var col_urg := Color("e74c3c").lerp(Color("2ecc71"), fr)
		draw_arc(centro, radio + 7.0 * s, -PI / 2.0, -PI / 2.0 + TAU * fr, 40, col_urg, 4.0 * s)
	draw_string_outline(f, centro + Vector2(-100, -radio - 12.0 * s), id_incidente, HORIZONTAL_ALIGNMENT_CENTER, 200, int(16 * s), int(4 * s), Color("0a1430"))
	draw_string(f, centro + Vector2(-100, -radio - 12.0 * s), id_incidente, HORIZONTAL_ALIGNMENT_CENTER, 200, int(16 * s), Color.WHITE)


func _dibujar_simbolo(servicio: String, c: Vector2, col: Color, s: float) -> void:
	match servicio:
		"ambulancia":
			draw_rect(Rect2(c + Vector2(-9, -3) * s, Vector2(18, 6) * s), col)
			draw_rect(Rect2(c + Vector2(-3, -9) * s, Vector2(6, 18) * s), col)
		"policia":
			var escudo := PackedVector2Array([
				c + Vector2(-8, -9) * s, c + Vector2(8, -9) * s, c + Vector2(8, 1) * s,
				c + Vector2(0, 10) * s, c + Vector2(-8, 1) * s])
			draw_colored_polygon(escudo, col)
		"bomberos":
			var llama := PackedVector2Array([
				c + Vector2(0, -11) * s, c + Vector2(6, -2) * s, c + Vector2(7, 4) * s,
				c + Vector2(3, 9) * s, c + Vector2(-3, 9) * s, c + Vector2(-7, 4) * s,
				c + Vector2(-5, -3) * s, c + Vector2(-2, 1) * s])
			draw_colored_polygon(llama, col)


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
