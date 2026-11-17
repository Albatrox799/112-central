extends RefCounted
## Motor de conversación de una llamada al 112.
## Lee una conversación desde un archivo de datos (data/dialogues)
## y lleva la cuenta de:
##   - la calma del llamante (0 = pánico, 100 = tranquilo)
##   - la precisión de la localización (0 a 3)
##   - la información conseguida
## Si el operador repite una pregunta, el llamante se pone más nervioso.

var datos: Dictionary = {}
var nodo_actual := ""
var calma := 30
var precision := 0
var informacion: Array = []
var marcas: Array = []
var visitados: Array = []
var terminada := false
var texto_actual := ""
var opciones_actuales: Array = []


func iniciar(d: Dictionary) -> void:
	datos = d
	calma = int(d.get("calma_inicial", 30))
	_entrar(d["inicio"])


func _entrar(id: String) -> void:
	var n: Dictionary = datos["nodos"][id]
	# Desvío según el estado emocional (p. ej. si está en pánico)
	if n.has("si_calma_menor"):
		var cond: Dictionary = n["si_calma_menor"]
		if calma < int(cond["valor"]):
			_entrar(cond["ir_a"])
			return
	var es_fin: bool = n.get("fin", false)
	nodo_actual = id
	texto_actual = n["texto"]
	if visitados.has(id) and not es_fin:
		calma = clampi(calma - 5, 0, 100)
		texto_actual = "¡Ya se lo he dicho! " + texto_actual
	else:
		visitados.append(id)
		_aplicar(n.get("efectos", {}))
	opciones_actuales = []
	if es_fin:
		opciones_actuales.append({"texto": "[Colgar y crear el incidente]", "terminar": true})
		return
	for o in n.get("opciones", []):
		opciones_actuales.append(o)
	if precision >= 1:
		opciones_actuales.append({"texto": "[Terminar ya la llamada y crear el incidente]", "terminar": true})


func _aplicar(e: Dictionary) -> void:
	if e.has("calma"):
		calma = clampi(calma + int(e["calma"]), 0, 100)
	if e.has("precision"):
		precision = maxi(precision, int(e["precision"]))
	if e.has("info"):
		var txt: String = e["info"]
		if not informacion.has(txt):
			informacion.append(txt)
	if e.has("marca"):
		marcas.append(e["marca"])


func elegir(indice: int) -> void:
	if indice < 0 or indice >= opciones_actuales.size():
		return
	var o: Dictionary = opciones_actuales[indice]
	if o.get("terminar", false):
		terminada = true
		return
	_aplicar(o.get("efectos", {}))
	_entrar(o["ir_a"])


func estado_emocional() -> String:
	var estados: Array = datos.get("estados", ["En pánico", "Muy asustado", "Nervioso", "Tranquilo"])
	if calma < 20:
		return estados[0]
	elif calma < 40:
		return estados[1]
	elif calma < 60:
		return estados[2]
	return estados[3]
