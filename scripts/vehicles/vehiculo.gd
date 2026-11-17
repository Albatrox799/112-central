extends Node2D
## Vehículo que circula SIEMPRE por las calles siguiendo rutas A*.
## Sirve para ambulancias, patrullas y vehículos sospechosos.

signal ha_llegado(vehiculo)
signal interceptado(patrulla, objetivo)

const RedViaria = preload("res://scripts/routing/red_viaria.gd")

const NOMBRES_SERVICIO := {
	"ambulancia": "Ambulancia (soporte vital)",
	"policia": "Policía Local",
	"bomberos": "Bomberos (autobomba)",
	"sospechoso": "Vehículo sospechoso",
}

var id_unidad := ""
var servicio := ""
var estado := "Disponible"   # Disponible, En desplazamiento, Buscando el lugar, En intervención, Regresando, Persecución
var fase := ""               # uso interno de la central
var velocidad := 120.0       # píxeles por segundo
var color := Color.WHITE
var letra := "?"
var red: RedViaria
var nodo_base := 0
var siguiente_nodo := 0      # cruce hacia el que se dirige (o en el que está parado)
var nodo_anterior := -1
var ruta: Array[int] = []
var en_movimiento := false
var deambular := false       # circula por su cuenta (vehículos sospechosos)
var perseguir = null         # objetivo de una persecución (otro vehículo)
var incidente = null
var seleccionado := false
var direccion := 0.0         # hacia dónde mira el vehículo (radianes)
var color_cuerpo := Color.WHITE
var _t := 0.0
var _replanificar := 0.0


func configurar(p_id: String, p_servicio: String, p_color: Color, p_letra: String, p_velocidad: float, p_red: RedViaria) -> void:
	id_unidad = p_id
	servicio = p_servicio
	color = p_color
	letra = p_letra
	velocidad = p_velocidad
	red = p_red
	match servicio:
		"ambulancia":
			color_cuerpo = Color("fff3c4")
		"policia":
			color_cuerpo = Color("e8eef6")
		"bomberos":
			color_cuerpo = Color("c0392b")
		_:
			color_cuerpo = Color("d62839")


func nombre_servicio() -> String:
	return NOMBRES_SERVICIO.get(servicio, servicio)


func colocar_en(nodo: int) -> void:
	siguiente_nodo = nodo
	position = red.pos(nodo)
	ruta.clear()
	en_movimiento = false


## Calcula la ruta por las calles hasta el cruce indicado y empieza a moverse.
func ir_a(destino: int) -> void:
	var camino := red.ruta(siguiente_nodo, destino)
	ruta.clear()
	for n in camino:
		ruta.append(int(n))
	en_movimiento = not ruta.is_empty()


func detener() -> void:
	ruta.clear()
	en_movimiento = false
	deambular = false


func empezar_deambular() -> void:
	deambular = true
	_elegir_siguiente_deambulando()


## Segundos (de juego) que tardaría en llegar a un cruce.
func tiempo_estimado(destino: int) -> float:
	var camino := red.ruta(siguiente_nodo, destino)
	return (position.distance_to(red.pos(siguiente_nodo)) + red.longitud_ruta(camino)) / velocidad


## Segundos que le quedan para terminar la ruta actual.
func tiempo_restante() -> float:
	if ruta.is_empty():
		return 0.0
	var total := position.distance_to(red.pos(ruta[0]))
	for k in range(1, ruta.size()):
		total += red.pos(ruta[k - 1]).distance_to(red.pos(ruta[k]))
	return total / velocidad


func _elegir_siguiente_deambulando() -> void:
	var opciones: Array = []
	for v in red.vecinos[siguiente_nodo]:
		# No entra en calles sin salida (como la salida hacia Ciudad Real)
		if red.vecinos[v].size() > 1:
			opciones.append(v)
	if opciones.size() > 1:
		opciones.erase(nodo_anterior)
	if opciones.is_empty():
		return
	var destino: int = opciones[randi() % opciones.size()]
	nodo_anterior = siguiente_nodo
	ruta.clear()
	ruta.append(destino)
	en_movimiento = true


func _process(delta: float) -> void:
	_t += delta
	if perseguir != null:
		if not is_instance_valid(perseguir):
			perseguir = null
		else:
			_replanificar -= delta
			if _replanificar <= 0.0 or not en_movimiento:
				_replanificar = 0.5
				ir_a(perseguir.siguiente_nodo)
			if position.distance_to(perseguir.position) < 40.0:
				var objetivo = perseguir
				perseguir = null
				detener()
				interceptado.emit(self, objetivo)
	if en_movimiento:
		_avanzar(delta)
	queue_redraw()


func _avanzar(delta: float) -> void:
	var restante := velocidad * delta
	while restante > 0.0 and not ruta.is_empty():
		var nodo_objetivo: int = ruta[0]
		siguiente_nodo = nodo_objetivo
		var objetivo := red.pos(nodo_objetivo)
		var d := position.distance_to(objetivo)
		if d > 0.5:
			direccion = lerp_angle(direccion, (objetivo - position).angle(), 0.35)
		if d <= restante:
			position = objetivo
			restante -= d
			ruta.remove_at(0)
		else:
			position = position.move_toward(objetivo, restante)
			restante = 0.0
	if ruta.is_empty():
		en_movimiento = false
		if deambular:
			_elegir_siguiente_deambulando()
		elif perseguir == null:
			ha_llegado.emit(self)


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var radio := 22.0
	var parpadeo := int(_t * 6.0) % 2 == 0
	var emergencia: bool = estado in ["En desplazamiento", "Persecución", "Buscando el lugar"]
	# Halo de color del servicio (se ve bien aunque el mapa esté alejado)
	if seleccionado:
		draw_circle(Vector2.ZERO, radio + 10.0, Color(1, 1, 1, 0.30))
	draw_circle(Vector2.ZERO, radio, Color(color, 0.28))
	if servicio == "sospechoso":
		if parpadeo:
			draw_arc(Vector2.ZERO, radio, 0.0, TAU, 28, Color("ff4d6d"), 3.0)
	elif emergencia:
		var destello := Color("ff3030") if parpadeo else Color("3080ff")
		draw_arc(Vector2.ZERO, radio, 0.0, TAU, 28, destello, 3.0)
	else:
		draw_arc(Vector2.ZERO, radio, 0.0, TAU, 28, Color(color, 0.8), 2.0)
	# Vehículo visto desde arriba, girado hacia donde circula
	draw_set_transform(Vector2.ZERO, direccion, Vector2.ONE)
	var cuerpo := Rect2(-14, -7, 28, 14)
	if servicio == "bomberos":
		cuerpo = Rect2(-19, -8, 38, 16)
	draw_rect(Rect2(cuerpo.position + Vector2(1, 1), cuerpo.size), Color(0, 0, 0, 0.45))  # sombra
	draw_rect(cuerpo, color_cuerpo)
	draw_rect(Rect2(cuerpo.end.x - 10, -5.5, 5, 11), Color("17212c"))   # parabrisas
	if servicio != "bomberos":
		draw_rect(Rect2(-12, -5.5, 3, 11), Color("17212c"))           # luna trasera
	match servicio:
		"bomberos":
			draw_rect(Rect2(-16, -3, 22, 6), Color("bdc3c7"))         # escalera
			draw_line(Vector2(-16, 0), Vector2(6, 0), Color("7f8c8d"), 1.0)
		"ambulancia":
			draw_rect(Rect2(-7, -7, 3, 14), Color("e63946"))
			draw_rect(Rect2(-14, -1.5, 28, 3), Color("f4d35e"))
		"policia":
			draw_rect(Rect2(-14, -2, 28, 4), Color("1d4ed8"))
	if emergencia:
		draw_rect(Rect2(-3, -6, 4, 6), Color("ff3030") if parpadeo else Color("5a1010"))
		draw_rect(Rect2(-3, 0, 4, 6), Color("2f6bff") if not parpadeo else Color("10205a"))
	draw_rect(cuerpo, Color(0, 0, 0, 0.85), false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if id_unidad != "":
		draw_string_outline(f, Vector2(-70, -radio - 6.0), id_unidad, HORIZONTAL_ALIGNMENT_CENTER, 140, 17, 4, Color("0f151c"))
		draw_string(f, Vector2(-70, -radio - 6.0), id_unidad, HORIZONTAL_ALIGNMENT_CENTER, 140, 17, Color.WHITE)
