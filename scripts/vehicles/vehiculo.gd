extends Node2D
## Vehículo que circula SIEMPRE por las calles siguiendo rutas A*.
## Sirve para ambulancias, patrullas, bomberos y vehículos sospechosos.
##
## Velocidad:
##   - Sin emergencia: circula despacio (las patrullas recorren su zona).
##   - En emergencia: sirenas encendidas y mucha más velocidad.
##   - Las calles principales son más rápidas que las estrechas del centro.
##   - El tráfico de la hora (factor_trafico) también influye.

signal ha_llegado(vehiculo)
signal interceptado(patrulla, objetivo)

const RedViaria = preload("res://scripts/routing/red_viaria.gd")

const NOMBRES_SERVICIO := {
	"ambulancia": "Ambulancia (soporte vital)",
	"policia": "Policía Local",
	"bomberos": "Bomberos (autobomba)",
	"sospechoso": "Vehículo sospechoso",
}
const FACTOR_SIN_EMERGENCIA := 0.45
const FACTOR_PATRULLA := 0.35

var id_unidad := ""
var servicio := ""
# Datos de gestión (tienda y personal)
var tipo := ""               # clave del catálogo (patrulla, ambulancia_b...)
var nombre_tipo := ""
var personal := 2
var heridos: Array = []      # turnos de baja que le quedan a cada herido
var equipo: Array = []       # equipo comprado para este vehículo
var bono := ""
var indice_flota := -1
var estado := "Disponible"   # Disponible, Patrullando, En desplazamiento, Buscando el lugar, En intervención, Traslado al hospital, Regresando, Persecución
var fase := ""               # uso interno de la central
var velocidad := 60.0        # velocidad máxima EN EMERGENCIA (metros por segundo real)
var en_emergencia := false   # sirenas encendidas
var factor_trafico := 1.0
var color := Color.WHITE
var letra := "?"
var red: RedViaria
var nodo_base := 0
var siguiente_nodo := 0      # cruce hacia el que se dirige (o en el que está parado)
var ultimo_nodo := 0         # último cruce por el que ha pasado
var nodo_anterior := -1
var ruta: Array[int] = []
var en_movimiento := false
var deambular := false       # circula por su cuenta (patrullas y sospechosos)
var zona_centro := Vector2.ZERO
var zona_radio := 0.0        # 0 = sin límite de zona
var perseguir = null         # objetivo de una persecución (otro vehículo)
var incidente = null
var seleccionado := false
var direccion := 0.0         # hacia dónde mira el vehículo (radianes)
var _t := 0.0
var _replanificar := 0.0


func configurar(p_id: String, p_servicio: String, p_color: Color, p_letra: String, p_velocidad: float, p_red: RedViaria) -> void:
	id_unidad = p_id
	servicio = p_servicio
	color = p_color
	letra = p_letra
	velocidad = p_velocidad
	red = p_red


func nombre_servicio() -> String:
	if nombre_tipo != "":
		return nombre_tipo
	return NOMBRES_SERVICIO.get(servicio, servicio)


## Personas que pueden trabajar (sin contar a los heridos de baja).
func efectivos() -> int:
	return maxi(personal - heridos.size(), 0)


func tiene(cosa: String) -> bool:
	return equipo.has(cosa)


## ¿Se le puede enviar a una emergencia?
func disponible() -> bool:
	return (estado == "Disponible" or estado == "Patrullando") and efectivos() > 0


func colocar_en(nodo: int) -> void:
	siguiente_nodo = nodo
	ultimo_nodo = nodo
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


## Empieza a patrullar despacio por su zona.
func patrullar() -> void:
	en_emergencia = false
	estado = "Patrullando"
	fase = "patrulla"
	incidente = null
	empezar_deambular()


func velocidad_actual() -> float:
	var v := velocidad
	if not en_emergencia:
		v *= FACTOR_PATRULLA if estado == "Patrullando" else FACTOR_SIN_EMERGENCIA
	return v * factor_trafico


## Segundos reales que tardaría en llegar a un cruce yendo en emergencia.
func tiempo_estimado(destino: int) -> float:
	var camino := red.ruta(siguiente_nodo, destino)
	var dist := position.distance_to(red.pos(siguiente_nodo)) + red.longitud_ruta(camino)
	return dist / (velocidad * factor_trafico * 0.95)


## Segundos que le quedan para terminar la ruta actual.
func tiempo_restante() -> float:
	if ruta.is_empty():
		return 0.0
	var total := position.distance_to(red.pos(ruta[0]))
	for k in range(1, ruta.size()):
		total += red.pos(ruta[k - 1]).distance_to(red.pos(ruta[k]))
	return total / maxf(velocidad_actual() * 0.95, 1.0)


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
	# Si se ha salido de su zona, vuelve hacia el centro de la zona
	if zona_radio > 0.0 and position.distance_to(zona_centro) > zona_radio:
		var mejor_d := INF
		for o in opciones:
			var d := red.pos(o).distance_to(zona_centro)
			if d < mejor_d:
				mejor_d = d
				destino = o
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
	var base := velocidad_actual()
	var restante := delta
	while restante > 0.0 and not ruta.is_empty():
		var nodo_objetivo: int = ruta[0]
		siguiente_nodo = nodo_objetivo
		var objetivo := red.pos(nodo_objetivo)
		var vel := base * red.factor_tramo(ultimo_nodo, nodo_objetivo)
		var d := position.distance_to(objetivo)
		if d > 0.5:
			direccion = lerp_angle(direccion, (objetivo - position).angle(), 0.35)
		var tiempo_necesario := d / maxf(vel, 1.0)
		if tiempo_necesario <= restante:
			position = objetivo
			restante -= tiempo_necesario
			ultimo_nodo = nodo_objetivo
			ruta.remove_at(0)
		else:
			position = position.move_toward(objetivo, vel * restante)
			restante = 0.0
	if ruta.is_empty():
		en_movimiento = false
		if deambular:
			_elegir_siguiente_deambulando()
		elif perseguir == null:
			ha_llegado.emit(self)


const COLORES_PLACA := {
	"ambulancia": [Color("f2f6fc"), Color("d63031")],   # placa blanca, icono rojo
	"policia": [Color("3b8eea"), Color("ffffff")],      # placa azul
	"bomberos": [Color("d64545"), Color("ffffff")],     # placa roja
	"sospechoso": [Color("ff4d6d"), Color("1a0a10")],
}
const COLORES_ESTADO := {
	"Disponible": Color("2ecc71"), "En desplazamiento": Color("f39c12"),
	"Buscando el lugar": Color("e67e22"), "En intervención": Color("e74c3c"),
	"Persecución": Color("a569bd"), "Regresando": Color("5dade2"),
	"Patrullando": Color("27ae60"), "Traslado al hospital": Color("9b59b6"),
}


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var parpadeo := int(_t * 6.0) % 2 == 0
	var emergencia: bool = en_emergencia and servicio != "sospechoso"
	var colores: Array = COLORES_PLACA.get(servicio, [Color.WHITE, Color.BLACK])
	var placa_color: Color = colores[0]
	var icono_color: Color = colores[1]
	# Punto en la calle con resplandor (rosado si va en emergencia)
	var brillo := Color("ff5c8a") if emergencia or servicio == "sospechoso" else Color(placa_color, 0.8)
	draw_circle(Vector2.ZERO, 12.0 + (3.0 if parpadeo and emergencia else 0.0), Color(brillo, 0.25))
	draw_circle(Vector2.ZERO, 4.0, brillo)
	draw_line(Vector2(0, -4), Vector2(0, -12), Color(placa_color, 0.9), 2.0)
	# Placa con el vehículo
	var placa := Rect2(-20, -40, 40, 27)
	if seleccionado:
		draw_rect(placa.grow(5.0), Color(1, 1, 1, 0.9), false, 3.0)
	draw_rect(Rect2(placa.position + Vector2(2, 2), placa.size), Color(0, 0, 0, 0.45))
	draw_rect(placa, placa_color)
	draw_rect(placa, Color(1, 1, 1, 0.85), false, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -13), Vector2(6, -13), Vector2(0, -6)]), placa_color)
	_dibujar_silueta(Vector2(0, -26), icono_color)
	# Barra de estado encima de la placa
	if servicio != "sospechoso":
		var col_estado: Color = COLORES_ESTADO.get(estado, Color.GRAY)
		draw_rect(Rect2(-14, -47, 28, 4), col_estado)
		if emergencia and parpadeo:
			draw_rect(Rect2(-14, -47, 14, 4), Color("ff3030"))
			draw_rect(Rect2(0, -47, 14, 4), Color("2f6bff"))
	elif parpadeo:
		draw_rect(placa.grow(3.0), Color("ff4d6d"), false, 2.0)
	if id_unidad != "":
		draw_string_outline(f, Vector2(-60, -52), id_unidad, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 4, Color("0a1430"))
		draw_string(f, Vector2(-60, -52), id_unidad, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color.WHITE)


## Silueta lateral del vehículo dentro de la placa (mira hacia donde circula).
func _dibujar_silueta(c: Vector2, col: Color) -> void:
	var esp := -1.0 if cos(direccion) < -0.2 else 1.0   # se da la vuelta si va hacia la izquierda
	var sx := Vector2(esp, 1.0)
	draw_set_transform(c, 0.0, sx)
	match servicio:
		"bomberos":
			draw_rect(Rect2(-14, -6, 28, 10), col)
			draw_rect(Rect2(7, -5, 5, 4), Color(0, 0, 0, 0.35))
			draw_line(Vector2(-13, -8), Vector2(6, -8), col, 2.0)
			for x in [-9.0, 0.0, 9.0]:
				draw_circle(Vector2(x, 5), 2.6, col)
		"ambulancia":
			draw_rect(Rect2(-13, -7, 26, 11), col)
			draw_rect(Rect2(6, -5, 5, 4), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-6, -5, 6, 2), Color.WHITE)
			draw_rect(Rect2(-4, -7, 2, 6), Color.WHITE)
			draw_circle(Vector2(-7, 5), 2.6, col)
			draw_circle(Vector2(7, 5), 2.6, col)
		_:
			draw_rect(Rect2(-13, -2, 26, 6), col)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -2), Vector2(-3, -7), Vector2(5, -7), Vector2(9, -2)]), col)
			draw_circle(Vector2(-7, 4.5), 2.6, col)
			draw_circle(Vector2(7, 4.5), 2.6, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
