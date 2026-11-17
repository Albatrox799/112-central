extends RefCounted
## Red de calles del mapa.
## Los cruces son "nodos" y las calles son "tramos" que los unen.
## Las rutas se calculan con A* para que los vehículos SIEMPRE
## circulen por las calles y nunca atraviesen edificios.

var posiciones: Dictionary = {}   # nombre del nodo -> Vector2
var ids: Dictionary = {}          # nombre del nodo -> número interno
var tramos: Array = []            # [nodo_a, nodo_b, nombre_de_la_calle]
var vecinos: Dictionary = {}      # número interno -> Array de números
var astar := AStar2D.new()


func cargar(nodos: Dictionary, lista_tramos: Array) -> void:
	var i := 0
	for nombre in nodos:
		var p: Vector2 = nodos[nombre]
		posiciones[nombre] = p
		ids[nombre] = i
		astar.add_point(i, p)
		vecinos[i] = []
		i += 1
	for t in lista_tramos:
		var a: int = ids[t[0]]
		var b: int = ids[t[1]]
		astar.connect_points(a, b, true)
		vecinos[a].append(b)
		vecinos[b].append(a)
		tramos.append(t)


func pos(id: int) -> Vector2:
	return astar.get_point_position(id)


func id_de(nombre: String) -> int:
	return ids[nombre]


func ruta(desde: int, hasta: int) -> PackedInt64Array:
	return astar.get_id_path(desde, hasta)


func nodo_mas_cercano(p: Vector2) -> int:
	return astar.get_closest_point(p)


func longitud_ruta(r: PackedInt64Array) -> float:
	var total := 0.0
	for k in range(1, r.size()):
		total += pos(r[k - 1]).distance_to(pos(r[k]))
	return total
