extends RefCounted
## Motor de conversación de una llamada al 112.
## Sirve para las llamadas sencillas y para las HISTORIAS (con desenlace
## oculto, variantes de texto, sorpresas y efectos que pasan al incidente).
##
## Lleva la cuenta de:
##   - la calma del llamante (0 = pánico, 100 = tranquilo)
##   - la precisión de la localización (0 a 3)
##   - la información conseguida (sin confirmar) y la confirmada
## Si el operador repite una pregunta, el llamante se pone más nervioso.

var datos: Dictionary = {}
var variables: Dictionary = {}   # {lugar}, {calle}, {nombre}
var desenlace := ""              # lo que pasa de verdad (solo historias)
var nodo_actual := ""
var calma := 30
var precision := 0
var informacion: Array = []
var confirmados: Array = []
var marcas: Array = []
var visitados: Array = []
var terminada := false
var texto_actual := ""
var opciones_actuales: Array = []
## Cambios para el incidente: requiere, urgencia, traslado, categoria
var efectos_incidente: Dictionary = {}
# 0.97: más variedad en las conversaciones
var extras: Array = []           # preguntas extra que se pueden añadir (banco)
var extras_usadas: Array = []
var coletillas: Array = []       # frases típicas de la personalidad del llamante
var cortada := false             # la llamada se ha cortado (se sigue rastreando)
var _ofrecidas: Dictionary = {}  # nodo -> preguntas extra que se ofrecieron allí
var forma_hablar := "normal"      # 2.3: mayor, joven, borracho, extranjero, normal
var categoria := "medico"
var _fondo_usado := false


func iniciar(d: Dictionary, vars: Dictionary = {}, p_desenlace: String = "", calma_inicial: int = -1, apertura: String = "") -> void:
	datos = d
	variables = vars
	desenlace = p_desenlace
	calma = calma_inicial if calma_inicial >= 0 else int(d.get("calma_inicial", d.get("calma", 30)))
	_entrar(d["inicio"])
	if apertura != "" and not texto_actual.begins_with("("):
		texto_actual = apertura + texto_actual


## Preguntas extra que tienen sentido para esta llamada.
func preparar_extras(banco: Array, categoria_inc: String) -> void:
	extras.clear()
	if datos.get("falsa", false) or datos.get("relacionada", false):
		return
	categoria = categoria_inc if categoria_inc != "" else categoria
	for p in banco:
		var cats: Array = p["cat"]
		if cats.has("todas") or cats.has(categoria_inc):
			extras.append(p)
	extras.shuffle()
	# Vuelve a montar las opciones de la primera pantalla con las extra
	if not terminada and datos["nodos"].has(nodo_actual):
		_montar_opciones(datos["nodos"][nodo_actual])


## Localización automática (AML del móvil o dirección de la línea fija).
func localizar(nivel: int) -> void:
	precision = maxi(precision, nivel)


func _por_desenlace(dic: Dictionary):
	if dic.has(desenlace):
		return dic[desenlace]
	return dic.get("_", null)


func _entrar(id: String) -> void:
	var n: Dictionary = datos["nodos"][id]
	# Desvío según lo que pasa de verdad
	if n.has("si_desenlace") and n["si_desenlace"].has(desenlace):
		_entrar(n["si_desenlace"][desenlace])
		return
	# Desvío según el estado emocional (p. ej. si está en pánico)
	if n.has("si_calma_menor"):
		var cond: Dictionary = n["si_calma_menor"]
		if calma < int(cond["valor"]):
			_entrar(cond["ir_a"])
			return
	# Imprevisto durante la llamada
	if n.has("sorpresa"):
		var s: Dictionary = n["sorpresa"]
		var vale: bool = not s.has("desenlaces") or s["desenlaces"].has(desenlace)
		if vale and not visitados.has(s["ir_a"]) and randf() < float(s.get("prob", 0.5)):
			_entrar(s["ir_a"])
			return
	var es_fin: bool = n.get("fin", false)
	nodo_actual = id
	texto_actual = _formato(_elegir_texto(n))
	if visitados.has(id) and not es_fin:
		calma = clampi(calma - 5, 0, 100)
		texto_actual = "¡Ya se lo he dicho! " + texto_actual
	else:
		visitados.append(id)
		_aplicar(n.get("efectos", {}))
		if n.has("efectos_por_desenlace"):
			var e = _por_desenlace(n["efectos_por_desenlace"])
			if e != null:
				_aplicar(e)
	# Coletilla de la personalidad (a veces)
	if not es_fin and not coletillas.is_empty() and randf() < 0.3 and not texto_actual.begins_with("("):
		texto_actual += String(coletillas[randi() % coletillas.size()])
	texto_actual = _humanizar(texto_actual)
	opciones_actuales = []
	if n.get("cuelga", false):
		cortada = true
		var t_corte := "[Colgar]" if datos.get("falsa", false) or datos.get("relacionada", false) else "[Colgar y crear el incidente]"
		opciones_actuales.append({"texto": t_corte, "terminar": true})
		return
	if es_fin:
		var texto_colgar := "[Colgar]" if datos.get("falsa", false) or datos.get("relacionada", false) else "[Colgar y crear el incidente]"
		opciones_actuales.append({"texto": texto_colgar, "terminar": true})
		return
	_montar_opciones(n)


## Opciones de la pantalla: las del guion, más alguna pregunta extra para que
## haya 3 o 4, desordenadas para que no sea siempre la primera la buena.
func _montar_opciones(n: Dictionary) -> void:
	opciones_actuales = []
	var normales: Array = []
	for o in n.get("opciones", []):
		var copia: Dictionary = o.duplicate()
		copia["texto"] = _formato(o["texto"])
		normales.append(copia)
	if not extras.is_empty():
		var ofrecidas: Array = _ofrecidas.get(nodo_actual, [])
		var quiero := 0
		if normales.size() < 3:
			quiero = 3 - normales.size()
		if normales.size() + quiero < 4 and randf() < 0.35:
			quiero += 1
		# Primero las que ya se ofrecieron aquí (para que no cambien al volver)
		for p in ofrecidas:
			if quiero <= 0:
				break
			if not extras_usadas.has(p):
				normales.append({"texto": p["texto"], "extra": p})
				quiero -= 1
		for p in extras:
			if quiero <= 0:
				break
			if extras_usadas.has(p) or ofrecidas.has(p):
				continue
			normales.append({"texto": p["texto"], "extra": p})
			ofrecidas.append(p)
			quiero -= 1
		_ofrecidas[nodo_actual] = ofrecidas
	if not datos.get("relacionada", false):
		normales.shuffle()
	opciones_actuales = normales
	if precision >= 1 and not datos.get("falsa", false) and not datos.get("relacionada", false):
		opciones_actuales.append({"texto": "[Terminar ya la llamada y crear el incidente]", "terminar": true})


func _elegir_texto(n: Dictionary) -> String:
	if n.has("texto_por_desenlace"):
		var t = _por_desenlace(n["texto_por_desenlace"])
		if t != null:
			return t
	if n.has("textos"):
		var lista: Array = n["textos"]
		return lista[randi() % lista.size()]
	return n.get("texto", "...")


func _aplicar(e: Dictionary) -> void:
	if e.has("calma"):
		calma = clampi(calma + int(e["calma"]), 0, 100)
	if e.has("precision"):
		precision = maxi(precision, int(e["precision"]))
	if e.has("info"):
		var txt := _formato(e["info"])
		if not informacion.has(txt):
			informacion.append(txt)
	if e.has("confirmado"):
		var c := _formato(e["confirmado"])
		if not confirmados.has(c):
			confirmados.append(c)
	if e.has("marca"):
		marcas.append(e["marca"])
	if e.has("requiere"):
		var req: Dictionary = efectos_incidente.get("requiere", {})
		for sv in e["requiere"]:
			req[sv] = maxi(int(req.get(sv, 0)), int(e["requiere"][sv]))
		efectos_incidente["requiere"] = req
	for clave in ["urgencia", "traslado", "categoria", "heridos", "principal", "intensidad", "quitar", "duracion"]:
		if e.has(clave):
			efectos_incidente[clave] = e[clave]


func _formato(texto: String) -> String:
	return texto.format(variables)


func elegir(indice: int) -> void:
	if indice < 0 or indice >= opciones_actuales.size():
		return
	var o: Dictionary = opciones_actuales[indice]
	if o.get("terminar", false):
		terminada = true
		return
	if o.has("extra"):
		_responder_extra(o["extra"])
		return
	_aplicar(o.get("efectos", {}))
	if o.has("efectos_por_desenlace"):
		var e = _por_desenlace(o["efectos_por_desenlace"])
		if e != null:
			_aplicar(e)
	_entrar(o["ir_a"])


## Pregunta extra: responde según lo nervioso que esté y se queda en la misma pantalla.
func _responder_extra(p: Dictionary) -> void:
	extras_usadas.append(p)
	var lista: Array = p["nervioso"] if calma < 40 else p["calmo"]
	texto_actual = _humanizar(_formato(String(lista[randi() % lista.size()])))
	_aplicar(p.get("efectos", {}))
	var n: Dictionary = datos["nodos"][nodo_actual]
	_montar_opciones(n)


## 2.3: la gente no habla como un libro. Según los nervios y la forma de
## ser, se traba, repite, deja frases a medias y se oyen cosas de fondo.
const RELLENOS := ["eh... ", "a ver... ", "o sea... ", "es que... ", "bueno... ", "mire... "]
const FONDOS := {
	"medico": ["(se oye a alguien llorando cerca)", "(una mujer grita un nombre de fondo)", "(se oye una respiración ronca)"],
	"fuego": ["(se oye crepitar el fuego y una alarma)", "(gritos de vecinos y cristales que estallan)", "(tos fuerte)"],
	"pelea": ["(gritos y golpes de fondo)", "(alguien grita «¡déjalo ya!»)", "(se oyen cristales rotos)"],
	"robo": ["(susurrando)", "(se oye una alarma sonando)", "(un perro ladra sin parar)"],
	"atrapado": ["(se oye un claxon que no para)", "(ruido de tráfico y gente gritando)", "(huele a gasolina, dice alguien de fondo)"],
	"busqueda": ["(se oye a gente llamando a alguien a voces)", "(viento y ruido de coches)"],
	"control": ["(música muy alta de fondo)", "(motores acelerando)"],
}


func _humanizar(t: String) -> String:
	if t == "" or t.begins_with("(") or datos.get("relacionada", false):
		return t
	var r := t
	# Muy nervioso: se traba al empezar y repite
	if calma < 20 and r.length() > 3:
		var i := 1 if r.begins_with("¡") or r.begins_with("¿") else 0
		var letra := r.substr(i, 1)
		if letra.to_lower() != letra.to_upper() and randf() < 0.55:
			r = r.substr(0, i) + letra + "-" + letra.to_lower() + r.substr(i + 1)
		if randf() < 0.35:
			r = r.replace(", ", "... ")
		if randf() < 0.3:
			r += [" ¡Por favor, por favor!", " ¡Ay, Dios mío!", " ¡Rápido!"][randi() % 3]
	elif calma < 45 and randf() < 0.4:
		r = RELLENOS[randi() % RELLENOS.size()] + r.substr(0, 1).to_lower() + r.substr(1) if not (r.begins_with("¡") or r.begins_with("¿")) else r
	# Formas de hablar
	match forma_hablar:
		"mayor":
			if randf() < 0.4:
				r += [" Ay, hijo...", " Perdone, que una ya no está para estos sustos.", " ¿Me oye bien?"][randi() % 3]
		"joven":
			if randf() < 0.35:
				r = r.replace("muy ", "súper ")
				r += [" En plan, ¡que es muy fuerte!", " Te lo juro.", " ¿Sabes?"][randi() % 3]
		"borracho":
			r = r.replace("s ", "sh ").replace("ce", "she")
			if randf() < 0.5:
				r += [" (hipo)", " ...que no estoy borracho, ¿eh?", " Escuche... escuche..."][randi() % 3]
		"extranjero":
			if randf() < 0.5:
				r += [" Perdón, mi español no muy bien.", " ¿Usted entiende? Por favor.", ""][randi() % 3]
	# Algo que se oye de fondo (una vez por llamada)
	if not _fondo_usado and calma < 60 and randf() < 0.35 and FONDOS.has(categoria):
		_fondo_usado = true
		var f: Array = FONDOS[categoria]
		r += " " + String(f[randi() % f.size()])
	return r


func estado_emocional() -> String:
	var estados: Array = datos.get("estados", ["En pánico", "Muy asustado", "Nervioso", "Tranquilo"])
	if calma < 20:
		return estados[0]
	elif calma < 40:
		return estados[1]
	elif calma < 60:
		return estados[2]
	return estados[3]
