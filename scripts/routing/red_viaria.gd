extends RefCounted
## Red de calles real (OpenStreetMap).
## Los cruces y puntos de cada calle son "nodos" y los trozos de calle
## son "tramos". Las rutas se calculan con A* para que los vehículos
## SIEMPRE circulen por las calles y nunca atraviesen edificios.

var tramos: Array = []            # [nodo_a, nodo_b, indice_calle, es_principal]
var calles: Array = []            # nombres de las calles
var vecinos: Dictionary = {}      # nodo -> Array de nodos vecinos
var calle_nodo: Dictionary = {}   # nodo -> nombre de una calle que pasa por él
var astar := AStar2D.new()


func cargar(datos: Dictionary) -> void:
	var nodos: Array = datos["nodos"]
	calles = datos["calles"]
	astar.reserve_space(nodos.size())
	for i in nodos.size():
		astar.add_point(i, Vector2(float(nodos[i][0]), float(nodos[i][1])))
		vecinos[i] = []
	for t in datos["tramos"]:
		var a := int(t[0])
		var b := int(t[1])
		astar.connect_points(a, b, true)
		vecinos[a].append(b)
		vecinos[b].append(a)
		tramos.append(t)
		var nombre: String = calles[int(t[2])]
		if nombre != "":
			if not calle_nodo.has(a):
				calle_nodo[a] = nombre
			if not calle_nodo.has(b):
				calle_nodo[b] = nombre


func pos(id: int) -> Vector2:
	return astar.get_point_position(id)


func ruta(desde: int, hasta: int) -> PackedInt64Array:
	return astar.get_id_path(desde, hasta)


func nodo_mas_cercano(p: Vector2) -> int:
	return astar.get_closest_point(p)


func calle_de_nodo(id: int) -> String:
	return calle_nodo.get(id, "una calle sin nombre")


## Nodo más al oeste del mapa (salida hacia Ciudad Real).
func nodo_mas_al_oeste() -> int:
	var mejor := 0
	for i in astar.get_point_count():
		if pos(i).x < pos(mejor).x:
			mejor = i
	return mejor


func longitud_ruta(r: PackedInt64Array) -> float:
	var total := 0.0
	for k in range(1, r.size()):
		total += pos(r[k - 1]).distance_to(pos(r[k]))
	return total
