extends Control
## Vista "EN EL LUGAR": escena animada con figuritas de lo que pasa cuando
## llegan las unidades (policías deteniendo, sanitarios con la camilla, RCP,
## bomberos con la manguera, rescates por la ventana, excarcelaciones...).
## Solo dibuja: la lógica (progreso, refuerzos, resultado) la lleva main.gd.
## Se abre al mirar una emergencia en la que ya hay alguna unidad trabajando.

const ANCHO := 540.0
const ALTO := 360.0
const ESCENA := Rect2(10, 58, 520, 250)
const Y_ACERA := 256.0
const Y_CALZADA := 270.0
const Y_SUELO := 298.0     # donde apoyan las ruedas y los pies de los que están en la calle

const ROPA := {
	"policia": Color("2f5fb3"), "ambulancia": Color("e3ef5a"), "bomberos": Color("c0392b"),
	"civil": Color("48a9a6"), "sospechoso": Color("ff6b9a"), "herido": Color("9aa5b1"),
	"nino": Color("ffd166"), "forense": Color("ecf0f1"), "funeraria": Color("2d3436"),
	"proteccion_civil": Color("ff8c1a"),
	"geo": Color("2b3038"), "ume": Color("6b7a3a"), "judicial": Color("6a5a4c"),
}
const PIEL := Color("f1c9a5")

var inc = null
var final := false          # se muestra junto al informe (animación de cierre)
var calidad_alta := true
var _t := 0.0
var _t_escena := 0.0        # desde que se abrió esta escena (entrada de las figuras)
var _t_fin := -1.0          # desde que terminó la intervención
var _inc_anterior = null
var _unidades: Array = []   # [{id, servicio, n}] (se recuerda aunque ya se hayan ido)
var _chispas: Array = []    # partículas [pos, vel, vida, color]
var fuente: Font
var _edad_serv := {}        # servicio -> segundos desde que llegó la primera unidad
var _puerta_serv := {}      # puerta del vehículo -> servicio
var _cache_sub := {}        # id del aviso -> [subtipo, ambiente] (2.0)
const T_LLEGADA := 2.0      # el vehículo entra en escena y aparca
const T_BAJAR := 0.7        # abren las puertas y se bajan
const FUERA := Vector2(-5000, -5000)


func _ready() -> void:
	fuente = ThemeDB.fallback_font
	size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_t_escena += delta
	if inc != _inc_anterior:
		_inc_anterior = inc
		_t_escena = 0.0
		_t_fin = -1.0
		_unidades.clear()
		_chispas.clear()
	if inc != null and is_instance_valid(inc):
		_recordar_unidades()
		if inc.evento == "terminado":
			if _t_fin < 0.0:
				_t_fin = 0.0
			else:
				_t_fin += delta
	_actualizar_chispas(delta)
	queue_redraw()


func _recordar_unidades() -> void:
	var lista: Array = inc.unidades_en_escena()
	if lista.is_empty():
		return
	var nuevas: Array = []
	for v in lista:
		nuevas.append({"id": v.id_unidad, "servicio": v.servicio, "tipo": v.tipo, "n": clampi(v.efectivos(), 1, 3),
			"llegada": float(inc.llegadas.get(v.id_unidad, -1000.0))})
	_unidades = nuevas


func _gente(servicio: String) -> int:
	var total := 0
	for u in _unidades:
		if u["servicio"] == servicio:
			total += int(u["n"])
	return total


func _hay(servicio: String) -> bool:
	return _gente(servicio) > 0


# ================================================================ DIBUJO GENERAL

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.06, 0.15, 0.97))
	if inc == null or not is_instance_valid(inc):
		draw_rect(Rect2(Vector2.ZERO, size), Color("3fb6d8"), false, 2.0)
		return
	# Cabecera
	draw_rect(Rect2(0, 0, ANCHO, 50), Color(0.05, 0.13, 0.28, 1.0))
	var punto := Color("ff4d4d") if int(_t * 2.0) % 2 == 0 else Color("4d8dff")
	draw_circle(Vector2(18, 18), 6.0, punto)
	draw_string(fuente, Vector2(32, 25), "EN EL LUGAR · %s" % inc.id_incidente, HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 44, 18, Color("9ff3ff"))
	draw_string(fuente, Vector2(14, 44), String(inc.titulo), HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 28, 15, Color("e2f0ff"))
	# Escena recortada a su recuadro
	_fondo()
	var ev := String(inc.evento)
	if ev.begins_with("tramites") or (ev == "terminado" and int(inc.fallecidos) > 0):
		_escena_tramites()
		_dibujar_chispas()
		_carteles()
		draw_rect(ESCENA, Color("2a6f8f"), false, 1.0)
		_dibujar_estado()
		draw_rect(Rect2(Vector2.ZERO, size), Color("3fb6d8"), false, 2.0)
		return
	match String(inc.categoria):
		"fuego":
			_escena_fuego()
		"atrapado":
			_escena_atrapado()
		"pelea":
			_escena_pelea()
		"robo":
			_escena_robo()
		"busqueda":
			_escena_busqueda()
		"control":
			_escena_control()
		_:
			_escena_medica()
	_escena_proteccion_civil()
	_escena_especiales()
	for u in _unidades:
		if u.get("tipo", "") == "pma":
			_carpa_pma()
			break
	for u in _unidades:
		if u.get("tipo", "") == "canina":
			_perro(Vector2(260 + sin(_t * 0.8) * 60.0, Y_ACERA + 6))
			break
	if _hay("policia") and String(inc.servicio_necesario) != "policia":
		_corte_trafico()
	_dibujar_chispas()
	_clima_escena()
	_carteles()
	draw_rect(ESCENA, Color("2a6f8f"), false, 1.0)
	_dibujar_estado()
	draw_rect(Rect2(Vector2.ZERO, size), Color("3fb6d8"), false, 2.0)


# ================================================================ ESCENAS PROPIAS (2.0)
## Qué es exactamente el aviso (contenedor, coche, campo, banco...) según el
## título y la información, y dónde pasa (pueblo, campo, monte, embalse...).
func _subtipo() -> String:
	return String(_detectar()[0])


func _ambiente() -> String:
	return String(_detectar()[1])


func _detectar() -> Array:
	var id := String(inc.id_incidente)
	if _cache_sub.has(id):
		return _cache_sub[id]
	var partes := [String(inc.titulo)]
	for x in inc.informacion:
		partes.append(String(x))
	var t := " ".join(PackedStringArray(partes)).to_lower()
	var sub := ""
	var amb := "ciudad"
	match String(inc.categoria):
		"fuego":
			if t.contains("contenedor"):
				sub = "contenedor"
			elif t.contains("coche") or t.contains("turismo"):
				sub = "coche"
			elif t.contains("campo") or t.contains("cereal") or t.contains("rastrojo") or t.contains("forestal") or t.contains("monte") or t.contains("pinar"):
				sub = "campo"
			elif t.contains("nave") or t.contains("polígono") or t.contains("industrial") or t.contains("químic") or t.contains("camión"):
				sub = "nave"
			elif t.contains("butano") or t.contains("explosión"):
				sub = "explosion"
			elif t.contains("cocina") or t.contains("sartén"):
				sub = "cocina"
		"atrapado":
			if t.contains("tractor"):
				sub = "tractor"
			elif t.contains("derrumbe") or t.contains("escombro"):
				sub = "derrumbe"
			elif t.contains("riada") or t.contains("inunda"):
				sub = "riada"
			elif t.contains("nieve") or t.contains("nevada"):
				sub = "nieve"
			elif t.contains("cantera") or t.contains("desprendimiento"):
				sub = "cantera"
			elif t.contains("bebé") or t.contains("encerrado"):
				sub = "bebe"
		"medico":
			if t.contains("atropell") or t.contains("ciclista"):
				sub = "atropello"
			elif t.contains("accidente") or t.contains("vuelco") or t.contains("salido de la vía") or t.contains("choque"):
				sub = "accidente"
			elif t.contains("parto"):
				sub = "parto"
			elif t.contains("atentado") or t.contains("explosión"):
				sub = "atentado"
		"pelea":
			if t.contains("campal") or t.contains("multitud") or t.contains("bandas") or t.contains("parque"):
				sub = "masiva"
			elif t.contains("armad") or t.contains("rehén") or t.contains("rehenes") or t.contains("atrincher"):
				sub = "armado"
			else:
				sub = "bar"
		"robo":
			if t.contains("banco") or t.contains("sucursal"):
				sub = "banco"
			elif t.contains("supermercado") or t.contains("tienda") or t.contains("bolso") or t.contains("tirón") or t.contains("comercio"):
				sub = "tienda"
			elif t.contains("finca") or t.contains("gasóleo") or t.contains("cobre"):
				sub = "finca"
		"control":
			if t.contains("fiesta") or t.contains("música") or t.contains("ruido"):
				sub = "fiesta"
			elif t.contains("trompo") or t.contains("carrera") or t.contains("derrap"):
				sub = "trompos"
			elif t.contains("paquete") or t.contains("bomba"):
				sub = "bomba"
		"busqueda":
			if t.contains("embalse") or t.contains("bañista") or t.contains("pantano"):
				sub = "embalse"
	if t.contains("monte") or t.contains("senderista") or t.contains("pinar") or t.contains("forestal"):
		amb = "monte"
	elif t.contains("embalse") or t.contains("pantano") or t.contains("bañista"):
		amb = "agua"
	elif sub in ["campo", "tractor", "finca"] or t.contains("finca") or t.contains("granja") or t.contains("cortijo") or t.contains("carretera"):
		amb = "campo"
	elif sub in ["nave", "cantera"] or t.contains("polígono"):
		amb = "industrial"
	else:
		var raiz = get_tree().current_scene
		if raiz != null and "datos_mapa" in raiz:
			var pr: Array = raiz.datos_mapa.get("pueblo_rect", [])
			if pr.size() == 4 and not Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])).has_point(inc.pos_exacta):
				amb = "campo"
	var r := [sub, amb]
	_cache_sub[id] = r
	return r


func _fondo() -> void:
	match _ambiente():
		"campo":
			_fondo_campo(false)
		"monte":
			_fondo_campo(true)
		"agua":
			_fondo_agua()
		"industrial":
			_fondo_ciudad(true)
		_:
			_fondo_ciudad(false)


func _fondo_campo(monte: bool) -> void:
	var noche := _es_noche()
	var cielo := Color("0b1a3a") if noche else Color("2a5a94")
	draw_rect(Rect2(ESCENA.position, Vector2(ESCENA.size.x, Y_ACERA - ESCENA.position.y)), cielo)
	var colina := Color("16304a") if noche else Color("3e6b4a")
	var pts := PackedVector2Array([Vector2(ESCENA.position.x, Y_ACERA - 40)])
	for k in 9:
		pts.append(Vector2(ESCENA.position.x + k * 65.0, Y_ACERA - 40 - 26.0 * absf(sin(k * 1.7))))
	pts.append(Vector2(ESCENA.end.x, Y_ACERA - 30))
	pts.append(Vector2(ESCENA.end.x, Y_ACERA))
	pts.append(Vector2(ESCENA.position.x, Y_ACERA))
	draw_colored_polygon(pts, colina)
	if monte:
		for k in 12:
			var x := ESCENA.position.x + 20 + k * 43.0
			var y := Y_ACERA - 4 - fmod(k * 13.0, 18.0)
			draw_rect(Rect2(x - 2, y - 10, 4, 12), Color("4a3420"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 12, y - 8), Vector2(x, y - 40), Vector2(x + 12, y - 8)]), Color("123a28") if noche else Color("1f5a3a"))
	else:
		draw_rect(Rect2(ESCENA.position.x, Y_ACERA - 26, ESCENA.size.x, 26), Color("4a4022") if noche else Color("a8903e"))
		for k in 30:
			var x := ESCENA.position.x + k * 18.0
			draw_line(Vector2(x, Y_ACERA - 2), Vector2(x + 3, Y_ACERA - 20), Color("5e5230") if noche else Color("c9ae52"), 1.0)
		draw_rect(Rect2(ESCENA.position.x + 30, Y_ACERA - 62, 46, 30), Color("5c584f") if noche else Color("d8cfc0"))
		draw_colored_polygon(PackedVector2Array([Vector2(ESCENA.position.x + 26, Y_ACERA - 62), Vector2(ESCENA.position.x + 53, Y_ACERA - 80), Vector2(ESCENA.position.x + 80, Y_ACERA - 62)]), Color("8a3b2a"))
	draw_rect(Rect2(ESCENA.position.x, Y_ACERA, ESCENA.size.x, Y_CALZADA - Y_ACERA), Color("3a3224") if noche else Color("6b5a3e"))
	draw_rect(Rect2(ESCENA.position.x, Y_CALZADA, ESCENA.size.x, ESCENA.end.y - Y_CALZADA), Color("2a2a2e"))
	if noche:
		for k in 20:
			draw_circle(Vector2(ESCENA.position.x + fmod(k * 97.0, ESCENA.size.x), ESCENA.position.y + fmod(k * 37.0, 80.0) + 4), 1.0, Color(1, 1, 1, 0.6))


func _fondo_agua() -> void:
	_fondo_campo(false)
	var agua := Rect2(300, Y_ACERA - 70, ESCENA.end.x - 300, 70)
	draw_rect(agua, Color("0e2c48") if _es_noche() else Color("1d5a8c"))
	for k in 6:
		var y := agua.position.y + 10 + k * 10.0
		var x := agua.position.x + fmod(_t * 20.0 + k * 40.0, agua.size.x - 30.0)
		draw_line(Vector2(x, y), Vector2(x + 22, y), Color(1, 1, 1, 0.25), 1.0)


## Lluvia o nieve sobre la escena, según el tiempo que hacía al llegar el aviso.
func _clima_escena() -> void:
	var c := String(inc.clima)
	var nieve := _subtipo() == "nieve" or c == "nieve"
	if c in ["lluvia", "tormenta"]:
		for k in 40:
			var x := ESCENA.position.x + fmod(k * 53.0 + _t * 60.0, ESCENA.size.x)
			var y := ESCENA.position.y + fmod(k * 31.0 + _t * 420.0, ESCENA.size.y)
			draw_line(Vector2(x, y), Vector2(x - 3, y + 10), Color(0.7, 0.8, 1.0, 0.45), 1.0)
		if c == "tormenta" and fmod(_t, 7.0) < 0.12:
			draw_rect(ESCENA, Color(1, 1, 1, 0.25))
	if nieve:
		draw_rect(Rect2(ESCENA.position.x, Y_ACERA - 4, ESCENA.size.x, 8), Color(0.95, 0.97, 1.0, 0.9))
		draw_rect(Rect2(ESCENA.position.x, Y_SUELO + 2, ESCENA.size.x, ESCENA.end.y - Y_SUELO - 2), Color(0.95, 0.97, 1.0, 0.7))
		for k in 45:
			var x := ESCENA.position.x + fmod(k * 41.0 + sin(_t + k) * 10.0, ESCENA.size.x)
			var y := ESCENA.position.y + fmod(k * 29.0 + _t * 40.0, ESCENA.size.y)
			draw_circle(Vector2(x, y), 1.6, Color(1, 1, 1, 0.85))


func _fondo_ciudad(industrial: bool) -> void:
	var noche := _es_noche()
	var cielo := Color("0b1a3a") if noche else Color("1b3a6b")
	draw_rect(Rect2(ESCENA.position, Vector2(ESCENA.size.x, Y_ACERA - ESCENA.position.y)), cielo)
	# Edificios lejanos
	var x := ESCENA.position.x
	var i := 0
	while x < ESCENA.end.x:
		var ancho := 40.0 + fmod(i * 37.0, 30.0)
		var alto := 60.0 + fmod(i * 53.0, 70.0)
		if industrial:
			ancho = 90.0
			alto = 50.0 + fmod(i * 17.0, 20.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, Y_ACERA - alto), Vector2(x + (ancho - 4.0) / 2.0, Y_ACERA - alto - 16), Vector2(x + ancho - 4.0, Y_ACERA - alto)]), Color("3a4658"))
		var col_ed := Color("4a5668") if industrial else (Color("13254a") if noche else Color("274a80"))
		draw_rect(Rect2(x, Y_ACERA - alto, ancho - 4.0, alto), col_ed)
		if noche:
			for k in 3:
				if fmod(i * 7.0 + k * 3.0, 5.0) < 2.0:
					draw_rect(Rect2(x + 6.0 + k * 11.0, Y_ACERA - alto + 10.0, 5, 6), Color(1.0, 0.85, 0.45, 0.6))
		x += ancho
		i += 1
	# Acera y calzada
	draw_rect(Rect2(ESCENA.position.x, Y_ACERA, ESCENA.size.x, Y_CALZADA - Y_ACERA), Color("2b3a5c"))
	draw_rect(Rect2(ESCENA.position.x, Y_CALZADA, ESCENA.size.x, ESCENA.end.y - Y_CALZADA), Color("161e33"))
	var xx := ESCENA.position.x + 10.0
	while xx < ESCENA.end.x:
		draw_line(Vector2(xx, Y_CALZADA + 14), Vector2(xx + 18, Y_CALZADA + 14), Color(1, 1, 1, 0.25), 2.0)
		xx += 40.0
	# Farola
	draw_line(Vector2(ESCENA.end.x - 30, Y_ACERA), Vector2(ESCENA.end.x - 30, Y_ACERA - 70), Color("5a6c8a"), 3.0)
	draw_line(Vector2(ESCENA.end.x - 30, Y_ACERA - 70), Vector2(ESCENA.end.x - 44, Y_ACERA - 70), Color("5a6c8a"), 3.0)
	if noche:
		_elipse(Vector2(ESCENA.end.x - 44, Y_ACERA - 6), 30.0, 7.0, Color(1.0, 0.85, 0.45, 0.10))
		draw_circle(Vector2(ESCENA.end.x - 44, Y_ACERA - 67), 4.0, Color(1.0, 0.9, 0.6))


func _es_noche() -> bool:
	var raiz = get_tree().current_scene
	if raiz != null and "segundos_sim" in raiz:
		var h := fmod(float(raiz.segundos_sim) / 3600.0, 24.0)
		return h < 7.5 or h >= 20.5
	return false


func _ahora() -> float:
	var raiz = get_tree().current_scene
	if raiz != null and "tiempo_juego" in raiz:
		return float(raiz.tiempo_juego)
	return 0.0


## Vehículos en la calle, uno por unidad. Si acaban de llegar, entran
## conduciendo, frenan, abren las puertas y se baja el personal.
func _aparcados(salen: Dictionary = {}) -> Dictionary:
	var puertas := {}
	_edad_serv.clear()
	_puerta_serv.clear()
	var ahora := _ahora()
	var x := ESCENA.position.x + 48.0
	for u in _unidades:
		var sv: String = u["servicio"]
		var edad := ahora - float(u.get("llegada", -1000.0))
		var p := Vector2(x, Y_SUELO)
		var desplazamiento: float = salen.get(sv, 0.0)
		if edad < T_LLEGADA:
			var k := clampf(edad / T_LLEGADA, 0.0, 1.0)
			desplazamiento -= (1.0 - (1.0 - pow(1.0 - k, 3.0))) * 460.0
		_vehiculo(p + Vector2(desplazamiento, 0), sv, 1.0, true, String(u.get("tipo", "")))
		if edad >= T_LLEGADA and edad < T_LLEGADA + T_BAJAR + 1.2:
			# Puerta abierta mientras se bajan
			draw_rect(Rect2(p + Vector2(-2, -26), Vector2(4, 20)), Color("c8ccd4"))
		if desplazamiento == 0.0:
			draw_string(fuente, p + Vector2(-30, 12), String(u["id"]), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 1, 1, 0.75))
		if not puertas.has(sv):
			puertas[sv] = p + Vector2(0, -4)
			_puerta_serv[p + Vector2(0, -4)] = sv
		_edad_serv[sv] = maxf(float(_edad_serv.get(sv, -1.0)), edad)
		x += 88.0
		if x > ESCENA.end.x - 40.0:
			break
	return puertas


## Segundos desde que ese personal se bajó del vehículo (negativo: aún dentro).
func _tiempo_fuera(desde: Vector2, retraso: float) -> float:
	var sv: String = _puerta_serv.get(desde, "")
	var edad: float = _edad_serv.get(sv, 999.0)
	return edad - T_LLEGADA - T_BAJAR - retraso


## Posición de entrada: las figuras salen del vehículo y caminan hasta su sitio.
func _entrar(desde: Vector2, hasta: Vector2, retraso: float = 0.0) -> Vector2:
	var t := _tiempo_fuera(desde, retraso)
	if t < 0.0:
		return FUERA
	return desde.lerp(hasta, clampf(t / 1.6, 0.0, 1.0))


func _andando(desde: Vector2, hasta: Vector2, retraso: float = 0.0) -> bool:
	var t := _tiempo_fuera(desde, retraso)
	return t > 0.0 and t < 1.6


# ================================================================ ESCENAS

func _escena_medica() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var paciente := Vector2(300, Y_ACERA + 6)
	var salida := {}
	var camilla_k := 0.0
	if fin and exito and bool(inc.traslado) and _t_fin >= 0.0:
		camilla_k = clampf((_t_fin - 0.6) / 2.6, 0.0, 1.0)
		if _t_fin > 3.6:
			salida["ambulancia"] = (_t_fin - 3.6) * 160.0
	var puertas := _aparcados(salida)
	var puerta_amb: Vector2 = puertas.get("ambulancia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	_props_medica(_subtipo(), paciente)
	# Curiosos
	_persona(Vector2(446, Y_ACERA + 2), "civil", "pie", 0.0, -1.0)
	_persona(Vector2(470, Y_ACERA + 4), "civil", "pie", 0.0, -1.0)
	var muerto: bool = int(inc.fallecidos) > 0 and fin
	var rcp: bool = (inc.marcas.has("rcp") or String(inc.desenlace) == "infarto") and p < 0.55 and not fin
	# Heridos: el más grave tumbado; los demás sentados en el bordillo
	var n_her := clampi(int(inc.heridos), 1, 3)
	var sitios_heridos := [paciente, Vector2(392, Y_ACERA + 6), Vector2(214, Y_ACERA + 6)]
	for h in range(1, n_her):
		var pose_h := "saluda" if fin and exito else "sentado"
		_persona(sitios_heridos[h], "herido", pose_h, _t * 2.0, -1.0 if h == 1 else 1.0)
		if not fin:
			draw_circle(sitios_heridos[h] + Vector2(2, -24), 2.0, Color("e74c3c"))   # herida en la cabeza
	if camilla_k > 0.0:
		var pc := paciente.lerp(puerta_amb + Vector2(30, 0), camilla_k)
		if camilla_k < 1.0:
			_camilla(pc, true)
			_persona(pc + Vector2(-26, 0), "ambulancia", "andar", _t * 8.0, -1.0)
			_persona(pc + Vector2(26, 0), "ambulancia", "andar", _t * 8.0 + 1.5, -1.0)
	else:
		if muerto:
			_persona(paciente, "herido", "tumbado")
			draw_rect(Rect2(paciente + Vector2(-16, -9), Vector2(34, 9)), Color("e8eef6"))
		elif fin and exito:
			_persona(paciente + Vector2(0, -2), "herido", "saluda", _t)
		else:
			_persona(paciente, "herido", "tumbado")
			if bool(inc.empeorado) and int(_t * 2.0) % 2 == 0:
				draw_circle(paciente + Vector2(14, -18), 4.0, Color("ff4d4d"))
		# Sanitarios: salen de la ambulancia y van a atender a cada herido.
		# Si hay varios heridos, van pasando de uno a otro.
		var n_amb := _gente("ambulancia")
		var lados := [Vector2(-22, 0), Vector2(22, 0), Vector2(0, -2)]
		var ciclo := p * float(n_her) * 1.5
		for i in mini(n_amb, 3):
			var actual := 0
			var anterior := 0
			var tramo := 1.0
			if n_her > 1 and not fin:
				actual = (int(ciclo) + i) % n_her
				anterior = (int(ciclo) - 1 + i + n_her) % n_her
				tramo = clampf(fmod(ciclo, 1.0) / 0.25, 0.0, 1.0) if ciclo >= 1.0 else 1.0
			var lado: Vector2 = lados[i] if n_her == 1 else (Vector2(-22, 0) if i % 2 == 0 else Vector2(22, 0))
			var sitio: Vector2 = sitios_heridos[actual] + lado
			var sitio_antes: Vector2 = sitios_heridos[anterior] + lado
			var pos := _entrar(puerta_amb, sitio_antes.lerp(sitio, tramo), i * 0.35)
			var pose := "agachado"
			if _andando(puerta_amb, sitio, i * 0.35) or tramo < 1.0:
				pose = "andar"
			elif i == 0 and rcp and actual == 0:
				pose = "rcp"
			elif fin:
				pose = "pie"
			_persona(pos, "ambulancia", pose, _t * 8.0, 1.0 if lado.x < 0 else -1.0)
		if n_amb > 0 and not fin and not muerto and _tiempo_fuera(puerta_amb, 0.0) > 1.6:
			_monitor(paciente + Vector2(40, -6))
		_apoyo_alrededor(paciente, puertas, n_amb == 0)


## Lo que rodea al paciente según el aviso: coche accidentado, bici, etc.
func _props_medica(sub: String, paciente: Vector2) -> void:
	match sub:
		"accidente":
			_coche_accidentado(Vector2(440, Y_SUELO), false)
			for k in 8:
				draw_line(Vector2(400 + k * 9.0, Y_SUELO - 2), Vector2(403 + k * 9.0, Y_SUELO - 4), Color(0.8, 0.9, 1.0, 0.8), 1.0)   # cristales
			draw_colored_polygon(PackedVector2Array([Vector2(510, Y_SUELO), Vector2(516, Y_SUELO - 12), Vector2(522, Y_SUELO)]), Color("ff3b30"))   # triángulo
		"atropello":
			# Bici tirada junto al herido y el coche parado
			var b := paciente + Vector2(-30, 4)
			draw_arc(b + Vector2(-10, -6), 7.0, 0.0, TAU, 16, Color("c0c6cf"), 1.5)
			draw_arc(b + Vector2(12, -4), 7.0, 0.0, TAU, 16, Color("c0c6cf"), 1.5)
			draw_line(b + Vector2(-10, -6), b + Vector2(2, -12), Color("e74c3c"), 2.0)
			draw_line(b + Vector2(2, -12), b + Vector2(12, -4), Color("e74c3c"), 2.0)
			_vehiculo(Vector2(450, Y_SUELO), "sospechoso", -1.0, false)
			_persona(Vector2(410, Y_SUELO - 2), "civil", "pie", 0.0, -1.0)   # el conductor
		"parto":
			_vehiculo(Vector2(430, Y_SUELO), "sospechoso", -1.0, false)
			draw_rect(Rect2(Vector2(404, Y_SUELO - 24), Vector2(4, 16)), Color("9aa5b1"))   # puerta abierta
		"atentado":
			for k in 10:
				var x := 160.0 + fmod(k * 47.0, 330.0)
				draw_rect(Rect2(x, Y_ACERA + 2 + fmod(k * 5.0, 8.0), 8 + fmod(k * 3.0, 6.0), 4), Color("5a5a60"))
			for k in 3:
				_persona(Vector2(180 + k * 120.0, Y_ACERA + 10), "herido", "tumbado")
				_sangre(Vector2(184 + k * 120.0, Y_ACERA + 12), 0.8)
			_humo_suave(Vector2(420, Y_ACERA - 20))
			_humo_suave(Vector2(260, Y_ACERA - 30))


func _escena_atrapado() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var coche := Vector2(330, Y_SUELO)
	var salida := {}
	var camilla_k := 0.0
	if fin and exito and _t_fin >= 0.0:
		camilla_k = clampf((_t_fin - 0.6) / 2.6, 0.0, 1.0)
		if _t_fin > 3.6:
			salida["ambulancia"] = (_t_fin - 3.6) * 160.0
	var puertas := _aparcados(salida)
	# Lo que atrapa a la persona: coche, tractor, escombros, agua...
	var sin_techo := p > 0.6 or fin
	var sub := _subtipo()
	match sub:
		"tractor":
			_tractor_volcado(coche)
		"derrumbe", "cantera":
			_escombros(coche, 1.0 - p * 0.6 if not fin else 0.3, sub == "cantera")
		"riada":
			var nivel := (1.0 - p * 0.7) if not fin else 0.2
			draw_rect(Rect2(ESCENA.position.x, Y_SUELO - 30.0 * nivel, ESCENA.size.x, ESCENA.end.y - Y_SUELO + 30.0 * nivel), Color(0.25, 0.4, 0.55, 0.75))
			_coche_accidentado(coche, false)
			draw_rect(Rect2(ESCENA.position.x, Y_SUELO - 22.0 * nivel, ESCENA.size.x, 22.0 * nivel + 4.0), Color(0.3, 0.45, 0.6, 0.6))
		"bebe":
			_vehiculo(coche, "sospechoso", 1.0, false)
			if not fin:
				draw_circle(coche + Vector2(6, -22), 3.0, PIEL)
				if int(_t * 3.0) % 2 == 0:
					_bocadillo(coche + Vector2(8, -40), "¡Buaaa!")
			draw_circle(Vector2(440, ESCENA.position.y + 26), 16.0, Color(1.0, 0.85, 0.3, 0.9))   # sol
		_:
			_coche_accidentado(coche, sin_techo)
	if (not fin or not exito) and not (sub in ["derrumbe", "cantera", "bebe"]):
		draw_circle(coche + Vector2(-4, -26), 4.5, PIEL)   # la persona atrapada dentro
	elif not fin and sub in ["derrumbe", "cantera"] and int(_t * 1.2) % 2 == 0:
		draw_line(coche + Vector2(-6, -18), coche + Vector2(-12, -30), PIEL, 3.0)   # una mano entre los escombros
	if not fin:
		_humo_suave(coche + Vector2(30, -26))
	# Otros heridos del accidente, sentados en la acera esperando a los sanitarios
	for h in range(1, clampi(int(inc.heridos), 1, 3)):
		var ph := Vector2(180 + h * 34.0, Y_ACERA + 6)
		_persona(ph, "herido", "saluda" if fin and exito else "sentado", _t * 2.0, 1.0)
		if not fin:
			draw_circle(ph + Vector2(-2, -24), 2.0, Color("e74c3c"))
	var n_bom := _gente("bomberos")
	var puerta_bom: Vector2 = puertas.get("bomberos", coche)
	for i in mini(n_bom, 3):
		var sitio := coche + Vector2(-44 + i * 44.0, 0)
		var pos := _entrar(puerta_bom, sitio, i * 0.3)
		var pose := "andar" if _andando(puerta_bom, sitio, i * 0.3) else "pie"
		if not fin and pose == "pie" and i < 2:
			pose = "herramienta"
			if inc.evento == "en_curso" and randf() < 0.5:
				_chispa(pos + Vector2(14 * (1.0 if i == 0 else -1.0), -14))
		_persona(pos, "bomberos", pose, _t * 8.0, 1.0 if i == 0 else -1.0)
	var puerta_amb: Vector2 = puertas.get("ambulancia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	if camilla_k > 0.0:
		if camilla_k < 1.0:
			var pc := (coche + Vector2(0, -6)).lerp(puerta_amb + Vector2(30, 0), camilla_k)
			_camilla(pc, true)
			_persona(pc + Vector2(-26, 0), "ambulancia", "andar", _t * 8.0, -1.0)
			_persona(pc + Vector2(26, 0), "ambulancia", "andar", _t * 8.0 + 1.5, -1.0)
	else:
		for i in mini(_gente("ambulancia"), 2):
			var sitio := Vector2(240 + i * 26.0, Y_ACERA + 8)
			var pos := _entrar(puerta_amb, sitio, i * 0.3)
			_persona(pos, "ambulancia", "andar" if _andando(puerta_amb, sitio, i * 0.3) else "pie", _t * 8.0, 1.0)
		if _hay("ambulancia"):
			_camilla(Vector2(220, Y_ACERA + 8), false)
	for i in mini(_gente("policia"), 2):
		var sitio := Vector2(460 + i * 22.0, Y_SUELO - 2)
		var puerta_pol: Vector2 = puertas.get("policia", sitio)
		_persona(_entrar(puerta_pol, sitio, 0.2), "policia", "trafico", _t * 3.0, -1.0)


func _escena_fuego() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var edificio := Rect2(320, 92, 180, Y_ACERA - 92)
	var fuego: float = (1.0 - p) * (0.35 + 0.18 * int(inc.intensidad))
	if inc.evento == "":
		fuego = 0.5 + 0.12 * int(inc.intensidad)
	if fin:
		fuego = 0.0 if exito else 0.55
	var puertas := _aparcados()
	var sub := _subtipo()
	if sub in ["contenedor", "coche", "campo", "nave"]:
		_fuego_especial(sub, fuego, fin, exito, puertas)
		return
	if sub == "cocina":
		fuego = minf(fuego, 0.22)
	# Edificio
	draw_rect(edificio, Color("2c3e66") if not (fin and not exito) else Color("1c1f26"))
	draw_rect(edificio, Color("7fb2ff"), false, 1.5)
	draw_rect(Rect2(edificio.position + Vector2(edificio.size.x / 2.0 - 12, edificio.size.y - 34), Vector2(24, 34)), Color("1b2640"))
	var ventanas: Array = []
	for fila in 3:
		for col in 4:
			var v := Rect2(edificio.position + Vector2(14 + col * 42.0, 14 + fila * 46.0), Vector2(26, 26))
			var valor := absf(fmod(sin(col * 12.9898 + fila * 78.233) * 43758.5453, 1.0))
			var arde := valor < fuego
			draw_rect(v, Color("ffcf6e") if arde else Color("13213d"))
			draw_rect(v, Color("6d8cc4"), false, 1.0)
			if arde:
				_llama(v.get_center() + Vector2(0, -6), 14.0 + 4.0 * sin(_t * 9.0 + col + fila))
				ventanas.append(v.get_center())
	# Humo que sale del tejado
	if fuego > 0.05 or (fin and exito and _t_fin < 6.0):
		var gris := 0.25 if fuego > 0.05 else 0.55
		for k in 5:
			var fase := fmod(_t * 0.4 + k * 0.2, 1.0)
			var c := Vector2(edificio.position.x + 40 + k * 26.0 + fase * 30.0, edificio.position.y - fase * 60.0)
			draw_circle(c, 10.0 + fase * 16.0, Color(gris, gris, gris + 0.03, 0.45 * (1.0 - fase)))
	# Persona en la ventana y rescate con la escalera
	var atrapado: bool = int(inc.intensidad) >= 2 or inc.marcas.has("atrapado_bien") or inc.marcas.has("atrapado_mal")
	var ventana_rescate := edificio.position + Vector2(14 + 3 * 42.0 + 13, 14 + 46.0 + 13)
	var puerta_bom: Vector2 = puertas.get("bomberos", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	if atrapado and _hay("bomberos"):
		var esc_k := clampf((p - 0.35) / 0.2, 0.0, 1.0) if not fin else 1.0
		var base_esc := puerta_bom + Vector2(10, -26)
		var punta := base_esc.lerp(ventana_rescate + Vector2(-6, 14), esc_k)
		if esc_k > 0.0:
			draw_line(base_esc, punta, Color("c8ccd4"), 5.0)
			draw_line(base_esc, punta, Color("6c7380"), 1.0)
		var bajada := clampf((p - 0.6) / 0.25, 0.0, 1.0) if not fin else 1.0
		if bajada <= 0.0:
			_persona(ventana_rescate + Vector2(0, 12), "civil", "saluda", _t * 2.0)
		elif bajada < 1.0:
			var pr := (ventana_rescate + Vector2(-6, 14)).lerp(base_esc, bajada)
			_persona(pr, "bomberos", "pie", 0.0, -1.0)
			_persona(pr + Vector2(8, 0), "civil", "pie")
		else:
			_persona(Vector2(270, Y_ACERA + 6), "civil", "saluda" if exito else "pie", _t * 2.0)
	elif atrapado:
		_persona(ventana_rescate + Vector2(0, 12), "civil", "saluda", _t * 2.0)
	# Bomberos con manguera
	var n_bom := _gente("bomberos")
	for i in mini(n_bom, 4):
		var sitio := Vector2(230 + (i % 2) * 34.0, Y_ACERA + 6 - (i / 2) * 2.0)
		var pos := _entrar(puerta_bom, sitio, i * 0.25)
		var andando := _andando(puerta_bom, sitio, i * 0.25)
		_persona(pos, "bomberos", "andar" if andando else ("manguera" if fuego > 0.0 else "pie"), _t * 8.0, 1.0)
		if not andando and fuego > 0.0 and ventanas.size() > 0:
			var objetivo: Vector2 = ventanas[(i + int(_t * 0.7)) % ventanas.size()]
			_chorro(pos + Vector2(12, -14), objetivo)
	if n_bom > 0 and not fin:
		draw_line(puerta_bom + Vector2(20, -2), Vector2(230, Y_ACERA + 6), Color("e0c060"), 2.0)  # manguera en el suelo
	# Sanitarios y policía, apartados
	for i in mini(_gente("ambulancia"), 2):
		var sitio := Vector2(150 + i * 22.0, Y_ACERA + 6)
		_persona(_entrar(puertas.get("ambulancia", sitio), sitio), "ambulancia", "pie", 0.0, 1.0)
	for i in mini(_gente("policia"), 2):
		var sitio := Vector2(510 - i * 20.0, Y_SUELO - 2)
		_persona(_entrar(puertas.get("policia", sitio), sitio), "policia", "trafico", _t * 3.0, -1.0)


## Incendios que no son de un edificio: contenedor, coche, campo o nave.
func _fuego_especial(sub: String, fuego: float, fin: bool, exito: bool, puertas: Dictionary) -> void:
	var focos: Array = []
	match sub:
		"contenedor":
			for k in 2:
				var c := Vector2(360 + k * 56.0, Y_ACERA + 4)
				var quemado := fuego > 0.05 or (fin and not exito)
				draw_rect(Rect2(c + Vector2(-22, -34), Vector2(44, 34)), Color("1e5a2a") if not quemado or k == 1 else Color("23201c"))
				draw_rect(Rect2(c + Vector2(-24, -38), Vector2(48, 6)), Color("14401e") if not quemado or k == 1 else Color("191612"))
				draw_circle(c + Vector2(-14, 2), 4.0, Color("101418"))
				draw_circle(c + Vector2(14, 2), 4.0, Color("101418"))
				if k == 0 and fuego > 0.02:
					for f in 3:
						_llama(c + Vector2(-12 + f * 12.0, -40), 18.0 + fuego * 30.0 + 5.0 * sin(_t * 9.0 + f))
					focos.append(c + Vector2(0, -40))
			# Bolsas de basura por el suelo
			for k in 4:
				_elipse(Vector2(318 + k * 14.0, Y_ACERA + 8), 6.0, 4.0, Color("2a2a30"))
		"coche":
			var c := Vector2(380, Y_SUELO)
			_coche_accidentado(c, fuego > 0.3 or (fin and not exito))
			if fuego > 0.02:
				for f in 4:
					_llama(c + Vector2(-24 + f * 16.0, -26), 16.0 + fuego * 34.0 + 5.0 * sin(_t * 10.0 + f))
				focos.append(c + Vector2(0, -28))
			elif fin:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-32, -6), c + Vector2(-24, -20), c + Vector2(20, -18), c + Vector2(30, -6)]), Color("1a1a1a"))
		"campo":
			# Frente de fuego que avanza por el campo
			var frente := 300.0 + (1.0 - fuego) * 120.0
			for f in 9:
				var x := 300.0 + f * 24.0
				if fuego > 0.02 and x >= frente - 40.0:
					_llama(Vector2(x, Y_ACERA - 10), 20.0 + fuego * 40.0 + 6.0 * sin(_t * 8.0 + f))
				elif x < frente:
					draw_rect(Rect2(x - 12, Y_ACERA - 26, 24, 26), Color("2a221a"))
			if fuego > 0.02:
				focos.append(Vector2(frente + 20, Y_ACERA - 14))
				focos.append(Vector2(frente + 80, Y_ACERA - 14))
		"nave":
			var nave := Rect2(300, 120, 210, Y_ACERA - 120)
			draw_rect(nave, Color("5a6170") if not (fin and not exito) else Color("26282d"))
			draw_colored_polygon(PackedVector2Array([nave.position, nave.position + Vector2(nave.size.x / 2.0, -26), nave.position + Vector2(nave.size.x, 0)]), Color("454b57"))
			for k in 6:
				draw_line(nave.position + Vector2(10 + k * 34.0, 10), nave.position + Vector2(10 + k * 34.0, nave.size.y), Color("4a505c"), 2.0)
			draw_rect(Rect2(nave.position + Vector2(70, nave.size.y - 60), Vector2(70, 60)), Color("2a2e36"))
			if fuego > 0.02:
				for f in 4:
					_llama(nave.position + Vector2(40 + f * 44.0, -10), 22.0 + fuego * 40.0 + 6.0 * sin(_t * 8.0 + f))
				focos.append(nave.position + Vector2(105, 20))
				focos.append(nave.position + Vector2(160, 0))
	# Humo
	if fuego > 0.05 or (fin and exito and _t_fin < 6.0):
		var gris := 0.2 if fuego > 0.05 else 0.55
		var base: Vector2 = focos[0] if not focos.is_empty() else Vector2(400, Y_ACERA - 40)
		for k in 6:
			var fase := fmod(_t * 0.4 + k * 0.17, 1.0)
			draw_circle(base + Vector2(k * 12.0 + fase * 40.0, -fase * 90.0), 10.0 + fase * 22.0, Color(gris, gris, gris + 0.03, 0.5 * (1.0 - fase)))
	# Bomberos con manguera apuntando a los focos
	var puerta_bom: Vector2 = puertas.get("bomberos", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var n_bom := _gente("bomberos") + _gente("ume")
	for i in mini(n_bom, 4):
		var sitio := Vector2(230 + (i % 2) * 34.0, Y_ACERA + 6 - (i / 2) * 2.0)
		var pos := _entrar(puerta_bom, sitio, i * 0.25)
		var andando := _andando(puerta_bom, sitio, i * 0.25)
		var tipo_p := "bomberos" if i < _gente("bomberos") else "ume"
		_persona(pos, tipo_p, "andar" if andando else ("manguera" if fuego > 0.0 else "pie"), _t * 8.0, 1.0)
		if not andando and fuego > 0.0 and not focos.is_empty():
			_chorro(pos + Vector2(12, -14), focos[(i + int(_t * 0.7)) % focos.size()])
	if n_bom > 0 and not fin:
		draw_line(puerta_bom + Vector2(20, -2), Vector2(230, Y_ACERA + 6), Color("e0c060"), 2.0)
	# Vecinos mirando y policía cortando el paso
	_persona(Vector2(150, Y_ACERA + 4), "civil", "pie", 0.0, 1.0)
	_persona(Vector2(172, Y_ACERA + 6), "civil", "saluda" if fuego > 0.3 else "pie", _t * 2.0, 1.0)
	for i in mini(_gente("policia"), 2):
		var sitio := Vector2(510 - i * 20.0, Y_SUELO - 2)
		_persona(_entrar(puertas.get("policia", sitio), sitio), "policia", "trafico", _t * 3.0, -1.0)
	for i in mini(_gente("ambulancia"), 2):
		var sitio := Vector2(120 + i * 22.0, Y_ACERA + 6)
		_persona(_entrar(puertas.get("ambulancia", sitio), sitio), "ambulancia", "pie", 0.0, 1.0)


func _escena_pelea() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var salida := {}
	if fin and exito and _t_fin > 3.4:
		salida["policia"] = (_t_fin - 3.4) * 150.0
	var puertas := _aparcados(salida)
	var sub := _subtipo()
	if sub == "masiva" or sub == "armado":
		_pelea_especial(sub, p, fin, exito, puertas)
		return
	# Fachada del bar
	var bar := Rect2(300, 120, 200, Y_ACERA - 120)
	draw_rect(bar, Color("3a2a4a"))
	draw_rect(Rect2(bar.position + Vector2(20, -20), Vector2(70, 22)), Color("1a0f24"))
	var neon := Color("ff5fb1") if int(_t * 1.5) % 4 != 0 else Color("6b2a4a")
	draw_string(fuente, bar.position + Vector2(24, -3), "BAR", HORIZONTAL_ALIGNMENT_LEFT, 64, 18, neon)
	draw_rect(Rect2(bar.position + Vector2(110, 40), Vector2(30, bar.size.y - 40)), Color("1b1228"))
	draw_rect(Rect2(bar.position + Vector2(20, 40), Vector2(70, 40)), Color("ffcf6e", 0.5))
	var centro := Vector2(300, Y_ACERA + 6)
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var n_sosp := 3
	var detenidos := p > 0.7 or (fin and exito)
	var lleva_k := clampf((_t_fin - 0.4) / 2.6, 0.0, 1.0) if fin and exito else 0.0
	for i in n_sosp:
		var sp := centro + Vector2(-30 + i * 30.0, 0)
		if not detenidos and not fin:
			sp += Vector2(sin(_t * 7.0 + i * 2.0) * 6.0, 0)
			_persona(sp, "sospechoso", "pelea", _t * 9.0 + i, 1.0 if i % 2 == 0 else -1.0)
		elif fin and not exito:
			_persona(sp + Vector2(fmod(_t_fin, 4.0) * 70.0 + i * 10.0, 0), "sospechoso", "andar", _t * 10.0, 1.0)
		else:
			var hacia_coche := sp.lerp(puerta_pol + Vector2(10 + i * 8.0, 0), lleva_k)
			if lleva_k < 1.0:
				_persona(hacia_coche, "sospechoso", "esposado", _t * 6.0 if lleva_k > 0.0 else 0.0, -1.0)
	# Un herido en el suelo (con sangre si es grave)
	if inc.requeridas.has("ambulancia") or float(inc.t_ambulancia) >= 0.0:
		_sangre(Vector2(254, Y_ACERA + 12), 1.0 + p * 0.4)
	_persona(Vector2(250, Y_ACERA + 10), "herido", "tumbado")
	var n_pol := _gente("policia")
	for i in mini(n_pol, 4):
		var sitio := centro + Vector2(-50 + i * 30.0, -2 + (i % 2) * 2.0)
		if detenidos:
			sitio = centro + Vector2(-44 + i * 30.0, 0)
		var pos := _entrar(puerta_pol, sitio, i * 0.25)
		if lleva_k > 0.0 and i < 3:
			pos = (centro + Vector2(-44 + i * 30.0, 0)).lerp(puerta_pol + Vector2(-10 + i * 8.0, 0), lleva_k)
		var pose := "andar" if _andando(puerta_pol, sitio, i * 0.25) or (lleva_k > 0.0 and lleva_k < 1.0) else "pie"
		if pose == "pie" and not detenidos and inc.evento == "en_curso" and p > 0.25:
			pose = "pelea"
		_persona(pos, "policia", pose, _t * 8.0 + i, -1.0 if pos.x > centro.x else 1.0)
	for i in mini(_gente("ambulancia"), 2):
		var sitio := Vector2(232 + i * 34.0, Y_ACERA + 8)
		var pos := _entrar(puertas.get("ambulancia", sitio), sitio, 0.4)
		_persona(pos, "ambulancia", "agachado", 0.0, 1.0 if i == 0 else -1.0)


## Peleas multitudinarias (muchos implicados) y personas armadas o atrincheradas.
func _pelea_especial(sub: String, p: float, fin: bool, exito: bool, puertas: Dictionary) -> void:
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var n_pol := _gente("policia") + _gente("geo")
	if sub == "masiva":
		var calmados := p > 0.7 or fin
		for i in 10:
			var base := Vector2(220 + (i % 5) * 50.0, Y_ACERA + 2 + (i / 5) * 8.0)
			if not calmados:
				base += Vector2(sin(_t * 6.0 + i * 1.7) * 8.0, 0)
				_persona(base, "sospechoso" if i % 2 == 0 else "civil", "pelea", _t * 9.0 + i, 1.0 if i % 2 == 0 else -1.0)
			elif exito and i < 6:
				_persona(base, "sospechoso", "esposado", 0.0, -1.0)
			elif not exito:
				_persona(base + Vector2(fmod(_t_fin, 4.0) * 60.0, 0), "sospechoso", "andar", _t * 10.0, 1.0)
		if not calmados:
			for k in 3:
				var bx := 250.0 + fmod(_t * 90.0 + k * 70.0, 200.0)
				draw_line(Vector2(bx, Y_ACERA - 30 - k * 6), Vector2(bx + 6, Y_ACERA - 36 - k * 6), Color("7fd07f"), 2.0)   # botellas volando
		# Línea de agentes con escudos que avanza
		var avance := clampf(p, 0.0, 1.0) * 60.0
		for i in mini(n_pol, 5):
			var sitio := Vector2(150 + i * 4.0 + avance, Y_ACERA + 4 + i * 2.0)
			var pos := _entrar(puerta_pol, sitio, i * 0.2)
			_persona(pos, "geo" if i < _gente("geo") else "policia", "pie", 0.0, 1.0)
			draw_rect(Rect2(pos + Vector2(6, -24), Vector2(5, 18)), Color(0.55, 0.65, 0.78, 0.85))
		_sangre(Vector2(300, Y_ACERA + 12), 1.0)
		_persona(Vector2(300, Y_ACERA + 10), "herido", "tumbado")
	else:
		# Persona armada en un portal; agentes parapetados tras sus coches
		var portal := Rect2(380, 130, 120, Y_ACERA - 130)
		draw_rect(portal, Color("3b4a6b"))
		draw_rect(Rect2(portal.position + Vector2(44, portal.size.y - 54), Vector2(32, 54)), Color("141c30"))
		var rendido := p > 0.8 or fin
		var arm := portal.position + Vector2(60, portal.size.y)
		if not rendido:
			_persona(arm, "sospechoso", "pie", 0.0, -1.0)
			draw_line(arm + Vector2(-6, -18), arm + Vector2(-24, -20), Color("2b2b2b"), 3.0)   # arma
			if int(_t * 2.0) % 3 == 0:
				_bocadillo(arm + Vector2(0, -44), "¡Que nadie se acerque!")
		elif exito:
			_persona(arm + Vector2(-40, 0), "sospechoso", "esposado", 0.0, -1.0)
		for i in mini(n_pol, 4):
			var sitio := Vector2(220 + i * 30.0, Y_SUELO - 2)
			var pos := _entrar(puerta_pol, sitio, i * 0.2)
			_persona(pos, "geo" if i < _gente("geo") else "policia", "pie", 0.0, 1.0)
		if n_pol > 0 and not rendido:
			_bocadillo(Vector2(250, Y_SUELO - 50), "Suelta el arma, vamos a hablar")


func _escena_robo() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var salida := {}
	if fin and exito and _t_fin > 3.4:
		salida["policia"] = (_t_fin - 3.4) * 150.0
	var puertas := _aparcados(salida)
	var casa := Rect2(300, 110, 190, Y_ACERA - 110)
	match _subtipo():
		"banco":
			draw_rect(casa, Color("5d6d7e"))
			draw_rect(Rect2(casa.position + Vector2(20, -24), Vector2(150, 24)), Color("1f3a5f"))
			draw_string(fuente, casa.position + Vector2(52, -6), "BANCO", HORIZONTAL_ALIGNMENT_LEFT, 100, 18, Color("f1c40f"))
			for k in 4:
				draw_line(casa.position + Vector2(10 + k * 56.0, 0), casa.position + Vector2(10 + k * 56.0, casa.size.y), Color("8a9aab"), 4.0)   # columnas
			if not fin and int(_t * 3.0) % 2 == 0:
				draw_circle(casa.position + Vector2(casa.size.x - 14, 14), 6.0, Color("ff3b30"))   # alarma
		"tienda":
			draw_rect(casa, Color("3d5a4a"))
			draw_rect(Rect2(casa.position + Vector2(0, 0), Vector2(casa.size.x, 20)), Color("e67e22"))
			draw_string(fuente, casa.position + Vector2(50, 15), "SUPERMERCADO", HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color.WHITE)
			for k in 6:
				draw_line(casa.position + Vector2(k * 32.0, 20), casa.position + Vector2(k * 32.0 + 16, 20 + 10), Color("f5f5f5"), 2.0)   # toldo
		"finca":
			draw_rect(casa, Color("8a7a62"))
			draw_colored_polygon(PackedVector2Array([casa.position + Vector2(-10, 0), casa.position + Vector2(casa.size.x / 2.0, -30), casa.position + Vector2(casa.size.x + 10, 0)]), Color("6b5a44"))
			draw_rect(Rect2(casa.position + Vector2(-60, casa.size.y - 34), Vector2(40, 34)), Color("b0392b"))   # depósito de gasóleo
			draw_string(fuente, casa.position + Vector2(-58, casa.size.y - 14), "GASÓLEO", HORIZONTAL_ALIGNMENT_LEFT, 40, 8, Color.WHITE)
		_:
			draw_colored_polygon(PackedVector2Array([casa.position + Vector2(-10, 0), casa.position + Vector2(casa.size.x / 2.0, -40), casa.position + Vector2(casa.size.x + 10, 0)]), Color("5a2e2e"))
			draw_rect(casa, Color("3b4a6b"))
	var puerta := Rect2(casa.position + Vector2(80, casa.size.y - 46), Vector2(28, 46))
	draw_rect(puerta, Color("1b2640"))
	var dentro := p > 0.25 and p < 0.8 and not fin
	for k in 2:
		var w := Rect2(casa.position + Vector2(18 + k * 112.0, 30), Vector2(40, 34))
		draw_rect(w, Color("0f1830"))
		if dentro:
			# Linternas moviéndose dentro de la casa
			var lx := w.position.x + 20 + sin(_t * 2.0 + k * 2.0) * 14.0
			draw_circle(Vector2(lx, w.position.y + 18), 9.0, Color(1.0, 0.95, 0.6, 0.55))
		draw_rect(w, Color("6d8cc4"), false, 1.0)
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var entrada := puerta.position + Vector2(14, 46)
	var n_pol := _gente("policia")
	var lleva_k := clampf((_t_fin - 0.4) / 2.6, 0.0, 1.0) if fin and exito else 0.0
	if not dentro:
		for i in mini(n_pol, 4):
			var sitio := entrada + Vector2(-60 + i * 22.0, 0)
			var pos := _entrar(puerta_pol, sitio, i * 0.25)
			if p >= 0.8 or fin:
				sitio = entrada + Vector2(-40 + i * 26.0, 0)
				pos = sitio
				if lleva_k > 0.0:
					pos = sitio.lerp(puerta_pol + Vector2(i * 8.0, 0), lleva_k)
			var pose := "andar" if _andando(puerta_pol, sitio, i * 0.25) or (lleva_k > 0.0 and lleva_k < 1.0) else "pie"
			if lleva_k < 1.0 or i > 1:
				_persona(pos, "policia", pose, _t * 8.0, 1.0)
	if (p >= 0.8 or fin) and exito:
		for i in 2:
			var sp := entrada + Vector2(-26 + i * 26.0, 0)
			if lleva_k > 0.0:
				sp = sp.lerp(puerta_pol + Vector2(4 + i * 8.0, 0), lleva_k)
			if lleva_k < 1.0:
				_persona(sp, "sospechoso", "esposado", _t * 6.0 if lleva_k > 0.0 else 0.0, -1.0)
	elif fin and not exito:
		_persona(Vector2(470 + fmod(_t_fin, 3.0) * 40.0, Y_ACERA + 4), "sospechoso", "andar", _t * 10.0, 1.0)
	_persona(Vector2(230, Y_ACERA + 4), "civil", "pie", 0.0, 1.0)   # el vecino que avisó


func _escena_busqueda() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var puertas := _aparcados()
	if _subtipo() == "embalse":
		# Barca de rescate y burbujas de los buceadores en el embalse
		var barca := Vector2(380 + sin(_t * 0.6) * 20.0, Y_ACERA - 40)
		if _hay("bomberos"):
			draw_colored_polygon(PackedVector2Array([barca + Vector2(-30, 0), barca + Vector2(30, 0), barca + Vector2(22, 10), barca + Vector2(-22, 10)]), Color("e67e22"))
			_persona(barca + Vector2(-8, 2), "bomberos", "pie", 0.0, 1.0)
			for k in 4:
				var f := fmod(_t * 0.9 + k * 0.25, 1.0)
				draw_circle(barca + Vector2(50 + k * 6.0, 30 - f * 20.0), 2.0 + f * 2.0, Color(1, 1, 1, 0.7 * (1.0 - f)))
		for k in 3:
			_persona(Vector2(200 + k * 22.0, Y_ACERA + 4), "civil", "pie", 0.0, 1.0)
		for i in mini(_gente("ambulancia"), 2):
			_persona(_entrar(puertas.get("ambulancia", Vector2(150, Y_ACERA + 6)), Vector2(150 + i * 22.0, Y_ACERA + 6)), "ambulancia", "pie", 0.0, 1.0)
		if fin and exito:
			_persona(Vector2(290, Y_ACERA + 8), "herido", "tumbado")
		return
	# Parque con árboles
	if _ambiente() == "ciudad":
		draw_rect(Rect2(ESCENA.position.x, Y_ACERA - 50, ESCENA.size.x, 50), Color("17402f"))
	var arboles := [Vector2(180, Y_ACERA - 6), Vector2(260, Y_ACERA - 14), Vector2(350, Y_ACERA - 4), Vector2(430, Y_ACERA - 12), Vector2(500, Y_ACERA - 6)]
	for a in arboles:
		draw_rect(Rect2(a + Vector2(-3, -24), Vector2(6, 24)), Color("5b3a1e"))
		draw_circle(a + Vector2(0, -34), 18.0, Color("1f6b45"))
		draw_circle(a + Vector2(-8, -28), 12.0, Color("238152"))
	var escondite: Vector2 = arboles[3] + Vector2(10, 0)
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var n_pol := _gente("policia")
	var noche := _es_noche()
	for i in mini(n_pol, 4):
		var x := ESCENA.position.x + 120.0 + fmod(i * 97.0 + _t * 30.0 * (1.0 if i % 2 == 0 else -0.8) + 600.0, ESCENA.size.x - 160.0)
		var sitio := Vector2(x, Y_ACERA + 2 + (i % 2) * 6.0)
		if fin:
			sitio = Vector2(250 + i * 26.0, Y_ACERA + 6)
		var pos := _entrar(puerta_pol, sitio, i * 0.25)
		var dir := 1.0 if i % 2 == 0 else -1.0
		_persona(pos, "policia", "pie" if fin else "andar", _t * 7.0 + i, dir)
		if noche and not fin:
			draw_colored_polygon(PackedVector2Array([pos + Vector2(6 * dir, -14), pos + Vector2(60 * dir, -30), pos + Vector2(60 * dir, 4)]), Color(1.0, 0.95, 0.6, 0.18))
	if fin and exito:
		var k := clampf(_t_fin / 2.0, 0.0, 1.0)
		var nino := escondite.lerp(Vector2(232, Y_ACERA + 6), k)
		_persona(nino, "nino", "andar" if k < 1.0 else "pie", _t * 8.0, -1.0)
		_persona(Vector2(206, Y_ACERA + 6), "civil", "saluda", _t * 3.0, 1.0)
	elif not fin:
		# El niño escondido (solo asoma la cabeza de vez en cuando)
		if p > 0.5 and int(_t * 1.5) % 3 == 0:
			draw_circle(escondite + Vector2(8, -16), 4.0, PIEL)
		_persona(Vector2(206, Y_ACERA + 6), "civil", "pie", 0.0, 1.0)


func _escena_control() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var resultado := String(inc.resultado).to_lower()
	var detenido := fin and resultado.contains("detenido")
	var huye := fin and not exito
	var salida := {}
	if detenido and _t_fin > 3.0:
		salida["policia"] = (_t_fin - 3.0) * 150.0
	elif fin and not detenido and _t_fin > 4.2:
		salida["policia"] = (_t_fin - 4.2) * 130.0
	var puertas := _aparcados(salida)
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	var sub := _subtipo()
	if sub in ["fiesta", "bomba"]:
		_control_especial(sub, p, fin, exito, puertas)
		return
	if sub == "trompos" and p < 0.4 and not fin:
		# El coche haciendo trompos antes de que lo paren
		var c := Vector2(380, Y_SUELO - 6)
		var ang := _t * 5.0
		var pos_c := c + Vector2(cos(ang), sin(ang) * 0.25) * 40.0
		_vehiculo(pos_c, "sospechoso", 1.0 if cos(ang + PI / 2.0) > 0.0 else -1.0, false)
		for k in 5:
			var f := fmod(_t * 0.8 + k * 0.2, 1.0)
			draw_circle(c + Vector2(cos(ang - k * 0.5), 0.2) * 40.0 + Vector2(0, -f * 20.0), 6.0 + f * 10.0, Color(0.8, 0.8, 0.82, 0.4 * (1.0 - f)))
		for k in 3:
			_persona(Vector2(200 + k * 24.0, Y_ACERA + 4), "civil", "saluda", _t * 3.0 + k, 1.0)   # grabando con el móvil
		_persona(_entrar(puerta_pol, Vector2(280, Y_SUELO - 2)), "policia", "trafico", _t * 3.0, 1.0)
		return
	# El coche parado
	var coche := Vector2(400, Y_SUELO)
	var se_va := 0.0
	if huye:
		se_va = _t_fin * 220.0
	elif fin and not detenido and _t_fin > 3.0:
		se_va = (_t_fin - 3.0) * 120.0
	_vehiculo(coche + Vector2(se_va, 0), "sospechoso", 1.0, false)
	var ventanilla := coche + Vector2(-6, -21)
	var conductor_dentro := not detenido or _t_fin < 0.3
	if conductor_dentro:
		draw_circle(ventanilla + Vector2(se_va, 0), 3.8, PIEL)
	var junto := coche + Vector2(-36, 0)   # al lado de la ventanilla del conductor
	var agente := _entrar(puerta_pol, junto)
	var andando := _andando(puerta_pol, junto)
	if detenido:
		var k := clampf((_t_fin - 0.3) / 2.4, 0.0, 1.0)
		if k < 1.0:
			_persona(junto.lerp(puerta_pol + Vector2(10, 0), k) + Vector2(10, 0), "civil", "esposado", _t * 6.0, -1.0)
			_persona(junto.lerp(puerta_pol, k), "policia", "andar", _t * 8.0, -1.0)
		return
	if huye:
		_persona(agente, "policia", "pie", 0.0, 1.0)
		return
	if fin:
		# Entrega la multa por la ventanilla y vuelve a su coche
		var entrega := clampf(_t_fin / 0.8, 0.0, 1.0)
		if entrega < 1.0:
			var papel := (junto + Vector2(12, -20)).lerp(ventanilla + Vector2(0, 2), entrega)
			draw_rect(Rect2(papel - Vector2(4, 5), Vector2(8, 10)), Color("fdfdfd"))
		var vuelta := clampf((_t_fin - 1.0) / 2.0, 0.0, 1.0)
		if vuelta < 1.0 or salida.is_empty():
			_persona(junto.lerp(puerta_pol, vuelta), "policia", "andar" if vuelta > 0.0 and vuelta < 1.0 else "pie", _t * 8.0, -1.0 if vuelta > 0.0 else 1.0)
		return
	var noche := _es_noche()
	var pose := "pie"
	if not andando and agente != FUERA:
		if p < 0.25:
			pose = "pie"          # pide la documentación
		elif p < 0.5 and noche:
			pose = "alcoholimetro"
		else:
			pose = "multa"
	else:
		pose = "andar"
	_persona(agente, "policia", pose, _t * 8.0, 1.0)
	if agente == FUERA or andando:
		return
	if p < 0.25:
		_bocadillo(agente + Vector2(-4, -44), "Documentación, por favor")
	elif pose == "alcoholimetro":
		_bocadillo(agente + Vector2(-4, -44), "Sople aquí...")
	else:
		_libreta(agente + Vector2(-26, -64), clampf((p - (0.5 if noche else 0.25)) / (0.5 if noche else 0.75), 0.0, 1.0))


## Fiesta ruidosa y paquete sospechoso.
func _control_especial(sub: String, p: float, fin: bool, exito: bool, puertas: Dictionary) -> void:
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	if sub == "fiesta":
		var ed := Rect2(320, 90, 170, Y_ACERA - 90)
		draw_rect(ed, Color("2c3e66"))
		var sigue := p < 0.6 and not fin
		for fila in 3:
			for col in 3:
				var w := Rect2(ed.position + Vector2(16 + col * 52.0, 14 + fila * 46.0), Vector2(30, 26))
				var c_luz := Color.from_hsv(fmod(_t * 0.6 + col * 0.3 + fila * 0.2, 1.0), 0.7, 1.0) if sigue and fila == 1 else Color("13213d")
				draw_rect(w, c_luz)
		if sigue:
			for k in 4:
				var f := fmod(_t * 0.7 + k * 0.25, 1.0)
				var nota := ed.position + Vector2(40 + k * 30.0, 60 - f * 60.0)
				draw_circle(nota, 3.0, Color(1, 1, 1, 1.0 - f))
				draw_line(nota + Vector2(2.5, 0), nota + Vector2(2.5, -11), Color(1, 1, 1, 1.0 - f), 1.5)
				draw_line(nota + Vector2(2.5, -11), nota + Vector2(7, -8), Color(1, 1, 1, 1.0 - f), 1.5)
		var portal := ed.position + Vector2(ed.size.x / 2.0, ed.size.y)
		var agente := _entrar(puerta_pol, portal + Vector2(-30, 0))
		_persona(agente, "policia", "pie", 0.0, 1.0)
		if sigue and not _andando(puerta_pol, portal + Vector2(-30, 0)):
			_bocadillo(agente + Vector2(0, -44), "Bajen la música, por favor")
			_persona(portal + Vector2(6, 0), "civil", "pie", 0.0, -1.0)
		elif not sigue:
			_persona(Vector2(200, Y_ACERA + 4), "civil", "saluda", _t * 2.0, 1.0)   # el vecino agradecido
		return
	# Paquete sospechoso: cordón, robot de los TEDAX y gente apartada
	var paquete := Vector2(400, Y_ACERA + 6)
	draw_line(Vector2(300, Y_ACERA - 4), Vector2(ESCENA.end.x, Y_ACERA - 4), Color("f1c40f"), 2.0)
	if not (fin and exito):
		draw_rect(Rect2(paquete + Vector2(-9, -12), Vector2(18, 12)), Color("6b4a2a"))
		draw_line(paquete + Vector2(-9, -6), paquete + Vector2(9, -6), Color("d8c690"), 2.0)
	if _hay("geo"):
		var k := clampf(p / 0.6, 0.0, 1.0)
		var robot := Vector2(240, Y_ACERA + 6).lerp(paquete + Vector2(-26, 0), k)
		draw_rect(Rect2(robot + Vector2(-10, -10), Vector2(20, 8)), Color("2b2f36"))
		draw_circle(robot + Vector2(-7, 0), 3.0, Color("101010"))
		draw_circle(robot + Vector2(7, 0), 3.0, Color("101010"))
		draw_line(robot + Vector2(4, -10), robot + Vector2(16, -20 + sin(_t * 3.0) * 3.0), Color("8a8f99"), 2.0)
		_persona(Vector2(200, Y_ACERA + 6), "geo", "pie", 0.0, 1.0)
	for i in mini(_gente("policia"), 3):
		_persona(_entrar(puerta_pol, Vector2(270 + i * 18.0, Y_SUELO - 2)), "policia", "trafico", _t * 3.0, -1.0)
	for k in 4:
		_persona(Vector2(ESCENA.position.x + 30 + k * 18.0, Y_ACERA + 4), "civil", "pie", 0.0, 1.0)


## Libreta de multas en la que se van escribiendo líneas, con el lápiz moviéndose.
func _libreta(p: Vector2, avance: float) -> void:
	var r := Rect2(p, Vector2(30, 36))
	draw_rect(r.grow(2.0), Color(0, 0, 0, 0.5))
	draw_rect(r, Color("fffbe6"))
	draw_rect(Rect2(p, Vector2(30, 6)), Color("c0392b"))
	draw_string(fuente, p + Vector2(2, 5), "MULTA", HORIZONTAL_ALIGNMENT_LEFT, 28, 7, Color.WHITE)
	var lineas := 5
	var hechas := avance * lineas
	for k in lineas:
		var y := p.y + 11.0 + k * 5.0
		var largo := clampf(hechas - k, 0.0, 1.0) * 24.0
		if largo > 0.0:
			draw_line(Vector2(p.x + 3, y), Vector2(p.x + 3 + largo, y), Color("34495e"), 1.0)
	var k_actual := mini(int(hechas), lineas - 1)
	var x_lapiz := p.x + 3.0 + clampf(hechas - k_actual, 0.0, 1.0) * 24.0 + sin(_t * 25.0) * 1.0
	var y_lapiz := p.y + 11.0 + k_actual * 5.0
	draw_line(Vector2(x_lapiz, y_lapiz), Vector2(x_lapiz + 7, y_lapiz - 9), Color("f1c40f"), 2.0)
	draw_line(Vector2(x_lapiz, y_lapiz), Vector2(x_lapiz + 1.5, y_lapiz - 2), Color("2d3436"), 2.0)


## Pequeño bocadillo de texto sobre una figura.
func _bocadillo(p: Vector2, texto: String) -> void:
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
	var r := Rect2(p + Vector2(-ancho / 2.0, -18), Vector2(ancho, 18))
	draw_rect(r, Color(1, 1, 1, 0.92))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(0, 6)]), Color(1, 1, 1, 0.92))
	draw_string(fuente, r.position + Vector2(5, 13), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1e1e1e"))


## Tras un fallecimiento: cinta policial, declaración de testigos, juzgado y
## forense y, al final, la funeraria se lleva el cuerpo.
func _escena_tramites() -> void:
	var p: float = inc.progreso
	var paso: int = int(inc.tramites_paso)
	var fin: bool = inc.evento == "terminado"
	var cuerpo := Vector2(310, Y_ACERA + 8)
	var puertas := _aparcados()
	var puerta_pol: Vector2 = puertas.get("policia", Vector2(ESCENA.position.x + 46, Y_SUELO - 4))
	# Cinta policial
	for k in 7:
		var x := 220.0 + k * 40.0
		draw_line(Vector2(x, Y_ACERA + 12), Vector2(x, Y_ACERA - 14), Color("8a8f99"), 2.0)
	var y_cinta := Y_ACERA - 12.0
	var pos_cinta := 220.0
	while pos_cinta < 460.0:
		var amarillo := int(pos_cinta / 12.0) % 2 == 0
		draw_line(Vector2(pos_cinta, y_cinta), Vector2(pos_cinta + 12.0, y_cinta), Color("ffd23f") if amarillo else Color("1d1d1d"), 3.0)
		pos_cinta += 12.0
	# El cuerpo cubierto (hasta que se lo lleva la funeraria)
	var levantamiento := clampf((p - 0.72) / 0.22, 0.0, 1.0) if paso >= 2 else 0.0
	if fin:
		levantamiento = 1.0
	var furgon := Vector2(470, Y_SUELO)
	if paso >= 2 or fin:
		var salida := 0.0
		if fin:
			salida = minf(_t_fin * 120.0, 300.0)
		_vehiculo(furgon + Vector2(salida, 0), "funeraria", -1.0, false)
	if String(inc.categoria) in ["pelea", "robo", "atrapado", "fuego"]:
		_sangre(cuerpo + Vector2(4, 4), 1.4)
	# Un familiar llorando al que consuela un agente o un sanitario
	var familiar := Vector2(110, Y_ACERA + 6)
	if not fin:
		_persona(familiar, "civil", "sentado", 0.0, 1.0)
		if int(_t * 0.8) % 3 != 0:
			_bocadillo(familiar + Vector2(0, -34), "(llora)" if int(_t * 0.5) % 2 == 0 else "¡No puede ser!")
		if _gente("policia") > 1 or paso >= 1:
			_persona(familiar + Vector2(22, 0), "policia" if _gente("policia") > 1 else "forense", "pie", 0.0, -1.0)
	if levantamiento < 1.0:
		if levantamiento <= 0.0:
			_persona(cuerpo, "herido", "tumbado")
			draw_rect(Rect2(cuerpo + Vector2(-16, -9), Vector2(34, 9)), Color("e8eef6"))
		else:
			var pc := cuerpo.lerp(furgon + Vector2(-30, -4), levantamiento)
			draw_rect(Rect2(pc + Vector2(-20, -10), Vector2(40, 4)), Color("dfe6ef"))
			draw_rect(Rect2(pc + Vector2(-18, -16), Vector2(34, 6)), Color("e8eef6"))
			_persona(pc + Vector2(-26, 0), "funeraria", "andar", _t * 7.0, 1.0)
			_persona(pc + Vector2(26, 0), "funeraria", "andar", _t * 7.0 + 1.5, 1.0)
	# Policía: uno toma declaración a un testigo (escribiendo en la libreta), otro vigila la cinta
	var n_pol := _gente("policia")
	if n_pol > 0:
		var testigo := Vector2(170, Y_ACERA + 6)
		_persona(testigo, "civil", "pie", 0.0, 1.0)
		var agente := _entrar(puerta_pol, testigo + Vector2(28, 0))
		_persona(agente, "policia", "multa" if not fin else "pie", _t, -1.0)
		if not fin and agente != FUERA and paso == 0:
			_bocadillo(testigo + Vector2(0, -40), "Lo encontré así...")
		if n_pol > 1:
			_persona(_entrar(puerta_pol, Vector2(240, Y_ACERA + 4), 0.3), "policia", "pie", 0.0, 1.0)
	# Juzgado de guardia y forense
	if paso >= 1 and levantamiento <= 0.0:
		_persona(cuerpo + Vector2(-24, 0), "forense", "agachado", 0.0, 1.0)
		_persona(cuerpo + Vector2(26, 0), "forense", "pie", 0.0, -1.0)
		_persona(cuerpo + Vector2(60, -2), "funeraria", "multa", 0.0, -1.0)   # el secretario judicial con sus papeles


## La policía corta un carril: conos naranjas y coches esperando.
func _corte_trafico() -> void:
	for k in 4:
		var c := Vector2(392 + k * 26.0, Y_CALZADA + 10)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 6), c + Vector2(5, 6), c + Vector2(0, -8)]), Color("ff8c1a"))
		draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), Color.WHITE, 2.0)
	# Coche esperando con los faros encendidos
	var p := Vector2(ESCENA.end.x - 14, Y_SUELO)
	_vehiculo(p, "", -1.0, false)
	if _es_noche():
		draw_colored_polygon(PackedVector2Array([p + Vector2(-28, -12), p + Vector2(-70, -20), p + Vector2(-70, -2)]), Color(1.0, 0.95, 0.7, 0.25))


## Voluntarios de Protección Civil: acordonan y ayudan en cualquier escena.
func _escena_proteccion_civil() -> void:
	var n := _gente("proteccion_civil")
	if n == 0:
		return
	var puerta := Vector2.ZERO
	for k in _puerta_serv:
		if _puerta_serv[k] == "proteccion_civil":
			puerta = k
	var sitios := [Vector2(196, Y_ACERA + 2), Vector2(492, Y_ACERA + 2), Vector2(236, Y_ACERA - 2)]
	for i in mini(n, 3):
		var sitio: Vector2 = sitios[i]
		var pos := _entrar(puerta, sitio, 0.2 + i * 0.3) if puerta != Vector2.ZERO else sitio
		_persona(pos, "proteccion_civil", "andar" if _andando(puerta, sitio, 0.2 + i * 0.3) else "trafico", _t * 3.0, 1.0 if sitio.x < 300 else -1.0)


## GEO, UME y detectives en el lugar (0.98)
func _escena_especiales() -> void:
	var sitios := {
		"geo": [Vector2(380, Y_ACERA + 4), Vector2(404, Y_ACERA + 2), Vector2(428, Y_ACERA + 4), Vector2(452, Y_ACERA + 2)],
		"ume": [Vector2(150, Y_ACERA + 4), Vector2(176, Y_ACERA + 2), Vector2(202, Y_ACERA + 4)],
		"judicial": [Vector2(120, Y_ACERA + 2), Vector2(142, Y_ACERA + 4)],
	}
	for sv in sitios:
		var n := _gente(sv)
		if n == 0:
			continue
		var puerta := Vector2.ZERO
		for k in _puerta_serv:
			if _puerta_serv[k] == sv:
				puerta = k
		var lista: Array = sitios[sv]
		for i in mini(n + (1 if sv == "geo" else 0), lista.size()):
			var sitio: Vector2 = lista[i]
			var pos := _entrar(puerta, sitio, 0.2 + i * 0.25) if puerta != Vector2.ZERO else sitio
			var andando := puerta != Vector2.ZERO and _andando(puerta, sitio, 0.2 + i * 0.25)
			var pose := "andar" if andando else "pie"
			if not andando:
				if sv == "ume":
					pose = "agachado" if i % 2 == 0 else "trafico"
				elif sv == "judicial":
					pose = "multa"
			_persona(pos, sv, pose, _t * 6.0 + i, -1.0 if sitio.x > 300 else 1.0)
			# Escudo de los agentes especiales
			if sv == "geo" and not andando:
				draw_rect(Rect2(pos + Vector2(-9, -24), Vector2(5, 18)), Color(0.55, 0.65, 0.78, 0.8))
		if sv == "judicial" and n > 0:
			_bocadillo(lista[0] + Vector2(0, -40), "Anotamos pistas…")


## Policía (u otros) de apoyo alrededor de un paciente: aseguran la zona o,
## si son los primeros en llegar, tranquilizan y atienden hasta que llegue la ambulancia.
func _apoyo_alrededor(centro: Vector2, puertas: Dictionary, primera_respuesta: bool) -> void:
	var n_pol := _gente("policia")
	for i in mini(n_pol, 3):
		# El primero atiende al herido si aún no hay sanitarios; los demás cortan el tráfico
		var atiende := primera_respuesta and i == 0
		var sitio := centro + Vector2(-20, 0) if atiende else Vector2(430 + i * 26.0, Y_SUELO - 2)
		var puerta: Vector2 = puertas.get("policia", sitio)
		var pos := _entrar(puerta, sitio, 0.2 + i * 0.3)
		var andando := _andando(puerta, sitio, 0.2 + i * 0.3)
		var pose := "andar" if andando else ("agachado" if atiende else "trafico")
		_persona(pos, "policia", pose, _t * 3.0, 1.0 if atiende else -1.0)
		if atiende and not andando and pos != FUERA:
			# Manta térmica sobre el herido y el botiquín al lado
			draw_rect(Rect2(centro + Vector2(-6, -8), Vector2(18, 6)), Color("d7dde4"))
			draw_rect(Rect2(centro + Vector2(-6, -8), Vector2(18, 6)), Color("f1c40f"), false, 1.0)
			draw_rect(Rect2(centro + Vector2(-38, -7), Vector2(9, 7)), Color("e74c3c"))
			draw_line(centro + Vector2(-35.5, -3.5), centro + Vector2(-31.5, -3.5), Color.WHITE, 1.5)
			draw_line(centro + Vector2(-33.5, -5.5), centro + Vector2(-33.5, -1.5), Color.WHITE, 1.5)
	var n_bom := _gente("bomberos")
	for i in mini(n_bom, 2):
		var sitio := centro + Vector2(50 + i * 24.0, 2)
		var puerta: Vector2 = puertas.get("bomberos", sitio)
		var pose := "agachado" if primera_respuesta and i == 0 else "pie"
		_persona(_entrar(puerta, sitio, 0.3), "bomberos", pose, 0.0, -1.0)


# ================================================================ PIEZAS

## Figura de una persona. La posición es la de los pies.
## mirando: 1 derecha, -1 izquierda.
func _persona(p: Vector2, tipo: String, pose: String = "pie", fase: float = 0.0, mirando: float = 1.0) -> void:
	var escala := 0.72 if tipo == "nino" else 1.0
	var ropa: Color = ROPA.get(tipo, Color("9aa5b1"))
	_elipse(p + Vector2(0, 1), 7.0 * escala, 2.5, Color(0, 0, 0, 0.35))
	draw_set_transform(p, 0.0, Vector2(mirando * escala, escala))
	var pantalon := ropa.darkened(0.45)
	var cadera := Vector2(0, -9)
	var hombro := Vector2(0, -19)
	var cabeza := Vector2(0, -24)
	match pose:
		"tumbado":
			draw_line(Vector2(-14, -3), Vector2(-2, -3), pantalon, 5.0)
			draw_line(Vector2(-2, -3), Vector2(8, -3), ropa, 6.0)
			draw_circle(Vector2(12, -4), 4.0, PIEL)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		"sentado":
			draw_line(Vector2(-4, -4), Vector2(6, -4), pantalon, 4.0)
			draw_line(Vector2(6, -4), Vector2(8, 0), pantalon, 4.0)
			draw_line(Vector2(-4, -4), Vector2(-4, -15), ropa, 6.0)
			draw_line(Vector2(-4, -14), Vector2(4, -8), ropa, 3.0)
			cabeza = Vector2(-4, -20)
			hombro = Vector2(-4, -15)
		"agachado", "rcp":
			var bote := 0.0
			if pose == "rcp":
				bote = absf(sin(fase * 1.6)) * 3.0
			cadera = Vector2(-2, -6)
			hombro = Vector2(2, -15 + bote)
			cabeza = Vector2(4, -20 + bote)
			draw_line(cadera, Vector2(6, -6), pantalon, 4.0)
			draw_line(Vector2(6, -6), Vector2(6, 0), pantalon, 4.0)
			draw_line(cadera, Vector2(-6, 0), pantalon, 4.0)
			draw_line(cadera, hombro, ropa, 6.0)
			if pose == "rcp":
				draw_line(hombro, Vector2(12, -4 + bote * 0.3), ropa, 3.0)
			else:
				draw_line(hombro, Vector2(11, -8), ropa, 3.0)
		_:
			# De pie / andando
			var paso := sin(fase) * 4.0 if pose == "andar" else 0.0
			draw_line(cadera, Vector2(-2 + paso, 0), pantalon, 4.0)
			draw_line(cadera, Vector2(2 - paso, 0), pantalon, 4.0)
			draw_line(cadera, hombro, ropa, 6.0)
			match pose:
				"andar":
					draw_line(hombro + Vector2(0, 1), Vector2(-paso, -10), ropa, 3.0)
					draw_line(hombro + Vector2(0, 1), Vector2(paso, -10), ropa, 3.0)
				"saluda":
					draw_line(hombro, Vector2(7, -30 + sin(fase * 4.0) * 3.0), ropa, 3.0)
					draw_line(hombro, Vector2(-3, -10), ropa, 3.0)
				"esposado":
					draw_line(hombro, Vector2(-6, -11), ropa, 3.0)
					draw_circle(Vector2(-6, -11), 2.0, Color("c8ccd4"))
				"pelea":
					var golpe := maxf(sin(fase * 1.3), 0.0) * 6.0
					draw_line(hombro, Vector2(8 + golpe, -19), ropa, 3.0)
					draw_line(hombro, Vector2(6, -14), ropa, 3.0)
				"manguera":
					draw_line(hombro, Vector2(12, -15), ropa, 3.0)
					draw_line(Vector2(4, -13), Vector2(14, -15), Color("e0c060"), 3.0)
				"herramienta":
					draw_line(hombro, Vector2(12, -14), ropa, 3.0)
					draw_rect(Rect2(10, -17, 7, 6), Color("f39c12"))
				"trafico":
					var brazo := sin(fase) * 4.0
					draw_line(hombro, Vector2(10, -24 + brazo), ropa, 3.0)
					draw_line(hombro, Vector2(-3, -10), ropa, 3.0)
				"alcoholimetro":
					draw_line(hombro, Vector2(12, -18), ropa, 3.0)
					draw_rect(Rect2(11, -21, 5, 8), Color("ecf0f1"))
				"multa":
					draw_line(hombro, Vector2(10, -15), ropa, 3.0)
					draw_rect(Rect2(9, -20, 8, 10), Color("fdfdfd"))
					draw_line(Vector2(10, -17), Vector2(16, -17), Color("2d3436"), 1.0)
				_:
					draw_line(hombro, Vector2(-3, -10), ropa, 3.0)
					draw_line(hombro, Vector2(3, -10), ropa, 3.0)
	draw_circle(cabeza, 4.2, PIEL)
	# Gorra, casco o pelo según el oficio
	match tipo:
		"policia":
			draw_rect(Rect2(cabeza + Vector2(-4.5, -5.5), Vector2(9, 3)), Color("152a55"))
			draw_rect(Rect2(cabeza + Vector2(1, -3.5), Vector2(4.5, 1.5)), Color("152a55"))
		"bomberos":
			draw_arc(cabeza + Vector2(0, -1), 5.0, PI, TAU, 10, Color("f1c40f"), 3.0)
		"geo":
			# Casco negro con visera y fusil cruzado
			draw_arc(cabeza + Vector2(0, -1), 5.2, PI, TAU, 10, Color("15181d"), 3.5)
			draw_line(cabeza + Vector2(-4, 1), cabeza + Vector2(4, 1), Color("3d4a5c"), 2.0)
			draw_line(hombro + Vector2(-6, 10), hombro + Vector2(7, -1), Color("101216"), 2.5)
		"ume":
			draw_arc(cabeza + Vector2(0, -1), 5.0, PI, TAU, 10, Color("4b5a2a"), 3.5)
			draw_rect(Rect2(hombro + Vector2(-4, 2), Vector2(8, 3)), Color("d4a017"))
		"judicial":
			draw_arc(cabeza + Vector2(0, -1), 4.0, PI, TAU, 8, Color("2d2016"), 2.5)
			draw_line(hombro + Vector2(-2, 2), hombro + Vector2(-1, 10), Color("c0c6cf"), 1.5)
		"ambulancia":
			draw_line(hombro + Vector2(-3, 4), hombro + Vector2(3, 4), Color("2ecc71"), 2.0)
		"sospechoso":
			draw_arc(cabeza, 5.0, PI * 0.9, TAU + 0.2, 10, ropa.darkened(0.3), 3.0)
		_:
			draw_arc(cabeza + Vector2(0, -1), 4.0, PI, TAU, 8, Color("4a3426"), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vehículo visto de lado. p = punto del suelo en el centro.
func _vehiculo(p: Vector2, servicio: String, mirando: float, luces: bool, tipo: String = "") -> void:
	# Dibujo del vehículo (2.3), salvo los helicópteros, que tienen su animación
	if not tipo.begins_with("heli_"):
		var tex: Texture2D = Sprites.textura(tipo, servicio)
		if tex != null:
			var ancho := 84.0 if not tipo in ["moto", "moto_sanitaria"] else 70.0
			var alto := ancho * 60.0 / 128.0
			var zona := Rect2(-ancho / 2.0, -alto * 52.0 / 60.0, ancho, alto)
			draw_set_transform(p, 0.0, Vector2(mirando, 1.0))
			draw_texture_rect(tex, zona, false)
			if luces and Sprites.LUCES.has(tipo if tipo != "" else String(Sprites.POR_SERVICIO.get(servicio, ""))):
				var l: Vector2 = Sprites.luz(tipo, servicio)
				var pl := zona.position + Vector2(zona.size.x * l.x, zona.size.y * l.y)
				var turno := int(_t * 6.0) % 2 == 0
				for k in [-1.0, 1.0]:
					var encendida: bool = (float(k) < 0.0) == turno
					draw_circle(pl + Vector2(float(k) * 4.0, 0), 10.0 if encendida else 5.0, Color(0.25, 0.5, 1.0, 0.35 if encendida else 0.12))
					if encendida:
						draw_circle(pl + Vector2(float(k) * 4.0, 0), 2.6, Color(0.8, 0.9, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	if tipo in ["camuflado", "canina", "vir", "moto_sanitaria", "moto", "pma", "guardia_civil", "ume", "heli_sanitario", "heli_policia", "heli_bomberos"]:
		_vehiculo_especial(p, tipo, mirando, luces)
		return
	_elipse(p + Vector2(0, 1), 34.0, 4.0, Color(0, 0, 0, 0.4))
	draw_set_transform(p, 0.0, Vector2(mirando, 1.0))
	var rueda := Color("101418")
	match servicio:
		"ambulancia":
			draw_rect(Rect2(-30, -32, 44, 27), Color("f4f6fa"))
			draw_rect(Rect2(14, -24, 16, 19), Color("f4f6fa"))
			draw_rect(Rect2(17, -21, 10, 8), Color("7fb2ff"))
			draw_rect(Rect2(-30, -16, 60, 4), Color("e74c3c"))
			draw_rect(Rect2(-14, -28, 4, 12), Color("e74c3c"))
			draw_rect(Rect2(-18, -24, 12, 4), Color("e74c3c"))
			_luces(Vector2(-20, -34), Vector2(6, -34), luces)
		"policia":
			draw_rect(Rect2(-30, -18, 60, 13), Color("1f4fa8"))
			draw_rect(Rect2(-16, -28, 30, 11), Color("1f4fa8"))
			draw_rect(Rect2(-13, -26, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(1, -26, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(-30, -12, 60, 3), Color("f4f6fa"))
			_luces(Vector2(-8, -30), Vector2(6, -30), luces)
		"bomberos":
			draw_rect(Rect2(-36, -34, 56, 29), Color("c0392b"))
			draw_rect(Rect2(20, -28, 16, 23), Color("c0392b"))
			draw_rect(Rect2(23, -25, 10, 9), Color("9cc9ff"))
			draw_rect(Rect2(-36, -12, 72, 3), Color("f1c40f"))
			draw_line(Vector2(-34, -37), Vector2(16, -37), Color("c8ccd4"), 3.0)
			_luces(Vector2(22, -30), Vector2(32, -30), luces)
		"proteccion_civil":
			draw_rect(Rect2(-30, -30, 44, 25), Color("f4f6fa"))
			draw_rect(Rect2(14, -24, 16, 19), Color("f4f6fa"))
			draw_rect(Rect2(17, -21, 10, 8), Color("7fb2ff"))
			draw_rect(Rect2(-30, -17, 60, 5), Color("ff8c1a"))
			draw_rect(Rect2(-12, -27, 10, 8), Color("1e3a8a"))
			_luces(Vector2(-20, -32), Vector2(6, -32), luces)
		"geo":
			# Blindado negro, alto, con ventanas pequeñas
			draw_rect(Rect2(-34, -34, 64, 29), Color("23272e"))
			draw_rect(Rect2(-34, -38, 40, 5), Color("2f343c"))
			draw_rect(Rect2(14, -30, 12, 7), Color("6f8aa8"))
			draw_rect(Rect2(-26, -30, 8, 6), Color("6f8aa8"))
			draw_rect(Rect2(-34, -14, 64, 3), Color("b8c2d6"))
			draw_string(fuente, Vector2(-22, -17), "GEO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e0e6ef"))
			_luces(Vector2(-10, -40), Vector2(4, -40), luces)
		"ume":
			# Camión militar color arena con banda amarilla
			draw_rect(Rect2(-38, -36, 52, 31), Color("7a7f4a"))
			draw_rect(Rect2(14, -28, 22, 23), Color("6b7040"))
			draw_rect(Rect2(18, -25, 12, 9), Color("9cc9ff"))
			draw_rect(Rect2(-38, -16, 74, 4), Color("d4a017"))
			draw_string(fuente, Vector2(-30, -22), "UME", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5e6a8"))
			_luces(Vector2(20, -31), Vector2(32, -31), luces)
		"judicial":
			draw_rect(Rect2(-28, -17, 56, 12), Color("4a4f5a"))
			draw_rect(Rect2(-14, -26, 26, 10), Color("4a4f5a"))
			draw_rect(Rect2(-11, -24, 9, 6), Color("9cc9ff"))
			draw_rect(Rect2(1, -24, 9, 6), Color("9cc9ff"))
		"funeraria":
			draw_rect(Rect2(-34, -24, 62, 19), Color("2d3436"))
			draw_rect(Rect2(-34, -30, 40, 7), Color("2d3436"))
			draw_rect(Rect2(8, -30, 18, 10), Color("6c7a89"))
			draw_rect(Rect2(-34, -14, 62, 2), Color("b2bec3"))
		_:
			draw_rect(Rect2(-28, -17, 56, 12), Color("8a8f99"))
			draw_rect(Rect2(-14, -26, 26, 10), Color("8a8f99"))
			draw_rect(Rect2(-11, -24, 9, 6), Color("9cc9ff"))
			draw_rect(Rect2(1, -24, 9, 6), Color("9cc9ff"))
	var x_ruedas := [-18.0, 18.0] if not servicio in ["bomberos", "ume", "geo"] else [-24.0, 0.0, 24.0]
	for x in x_ruedas:
		draw_circle(Vector2(x, -5), 5.5, rueda)
		draw_circle(Vector2(x, -5), 2.2, Color("5a6170"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vehículos con aspecto propio (0.96)
func _vehiculo_especial(p: Vector2, tipo: String, mirando: float, luces: bool) -> void:
	if tipo in ["heli_sanitario", "heli_policia", "heli_bomberos"]:
		_helicoptero(p, tipo, mirando)
		return
	var moto := tipo == "moto" or tipo == "moto_sanitaria"
	_elipse(p + Vector2(0, 1), 16.0 if moto else 34.0, 4.0, Color(0, 0, 0, 0.4))
	draw_set_transform(p, 0.0, Vector2(mirando, 1.0))
	var rueda := Color("101418")
	var ruedas := [-18.0, 18.0]
	match tipo:
		"camuflado":
			draw_rect(Rect2(-29, -17, 58, 12), Color("5b6170"))
			draw_rect(Rect2(-15, -27, 30, 11), Color("5b6170"))
			draw_rect(Rect2(-12, -25, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(1, -25, 11, 7), Color("9cc9ff"))
			if luces and int(_t * 6.0) % 2 == 0:
				draw_circle(Vector2(8, -21), 2.5, Color("3b7bff"))   # luz oculta tras el parabrisas
		"canina":
			draw_rect(Rect2(-30, -20, 60, 15), Color("1f4fa8"))
			draw_rect(Rect2(-14, -30, 30, 11), Color("1f4fa8"))
			draw_rect(Rect2(-11, -28, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(-30, -13, 60, 3), Color("f4f6fa"))
			draw_string(fuente, Vector2(-28, -6), "K9", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffd166"))
			_luces(Vector2(-6, -32), Vector2(8, -32), luces)
		"guardia_civil":
			draw_rect(Rect2(-30, -18, 60, 13), Color("2e7d4f"))
			draw_rect(Rect2(-16, -28, 30, 11), Color("2e7d4f"))
			draw_rect(Rect2(-13, -26, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(1, -26, 11, 7), Color("9cc9ff"))
			draw_rect(Rect2(-30, -12, 60, 3), Color("f4f6fa"))
			_luces(Vector2(-8, -30), Vector2(6, -30), luces)
		"ume":
			draw_rect(Rect2(-36, -34, 56, 29), Color("d4a017"))
			draw_rect(Rect2(20, -28, 16, 23), Color("d4a017"))
			draw_rect(Rect2(23, -25, 10, 9), Color("9cc9ff"))
			draw_string(fuente, Vector2(-30, -14), "UME", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("1e1e1e"))
			_luces(Vector2(22, -30), Vector2(32, -30), luces)
			ruedas = [-24.0, 0.0, 24.0]
		"vir":
			draw_rect(Rect2(-30, -22, 60, 17), Color("f4f6fa"))
			draw_rect(Rect2(-14, -31, 30, 10), Color("f4f6fa"))
			draw_rect(Rect2(-11, -29, 11, 7), Color("7fb2ff"))
			for k in 6:
				draw_rect(Rect2(-30 + k * 10.0, -15, 5, 4), Color("27ae60") if k % 2 == 0 else Color("f1c40f"))
			draw_string(fuente, Vector2(-26, -17), "VIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("27ae60"))
			_luces(Vector2(-6, -33), Vector2(8, -33), luces)
		"pma":
			draw_rect(Rect2(-38, -36, 60, 31), Color("f4f6fa"))
			draw_rect(Rect2(22, -28, 16, 23), Color("f4f6fa"))
			draw_rect(Rect2(25, -25, 10, 9), Color("7fb2ff"))
			draw_rect(Rect2(-38, -16, 76, 4), Color("e67e22"))
			draw_string(fuente, Vector2(-32, -21), "PMA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e67e22"))
			_luces(Vector2(24, -30), Vector2(34, -30), luces)
			ruedas = [-26.0, 0.0, 26.0]
		_:
			# Motos (policía o sanitaria)
			var col := Color("e3ef5a") if tipo == "moto_sanitaria" else Color("1f4fa8")
			draw_line(Vector2(-12, -6), Vector2(12, -6), col, 5.0)
			draw_line(Vector2(6, -6), Vector2(10, -16), Color("8a8f99"), 2.0)
			draw_rect(Rect2(-8, -12, 10, 6), col)
			draw_circle(Vector2(-4, -22), 4.0, Color.WHITE)   # casco
			draw_line(Vector2(-4, -18), Vector2(-4, -10), col.darkened(0.3), 4.0)
			if luces and int(_t * 6.0) % 2 == 0:
				draw_circle(Vector2(-10, -12), 2.5, Color("3b7bff"))
			ruedas = [-11.0, 11.0]
	for x in ruedas:
		var r := 4.5 if moto else 5.5
		draw_circle(Vector2(x, -5), r, rueda)
		draw_circle(Vector2(x, -5), r * 0.4, Color("5a6170"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Helicóptero posado con el rotor girando despacio.
func _helicoptero(p: Vector2, tipo: String, mirando: float) -> void:
	var col := Color("f1c40f") if tipo == "heli_sanitario" else (Color("d63a2f") if tipo == "heli_bomberos" else Color("1f4fa8"))
	_elipse(p + Vector2(0, 1), 40.0, 5.0, Color(0, 0, 0, 0.4))
	draw_set_transform(p, 0.0, Vector2(mirando, 1.0))
	# patines
	draw_line(Vector2(-22, -2), Vector2(18, -2), Color("2b2f36"), 3.0)
	draw_line(Vector2(-14, -2), Vector2(-14, -8), Color("2b2f36"), 2.0)
	draw_line(Vector2(10, -2), Vector2(10, -8), Color("2b2f36"), 2.0)
	# cabina y cola
	_elipse(Vector2(0, -18), 22.0, 11.0, col)
	draw_rect(Rect2(-48, -22, 30, 6), col)
	draw_rect(Rect2(-52, -32, 6, 14), col)
	_elipse(Vector2(10, -20), 9.0, 6.0, Color("9cc9ff"))
	if tipo == "heli_sanitario":
		draw_rect(Rect2(-8, -22, 10, 3), Color("e74c3c"))
		draw_rect(Rect2(-4.5, -26, 3, 10), Color("e74c3c"))
	elif tipo == "heli_bomberos":
		draw_string(fuente, Vector2(-18, -14), "BOMBEROS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		# helibalde colgando
		draw_line(Vector2(0, -6), Vector2(0, 14), Color("2b2f36"), 1.0)
		draw_rect(Rect2(-5, 14, 10, 8), Color("e67e22"))
	else:
		draw_string(fuente, Vector2(-16, -14), "POLICÍA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	# rotor
	draw_line(Vector2(0, -29), Vector2(0, -34), Color("2b2f36"), 2.0)
	var ancho := 46.0 * absf(cos(_t * 9.0))
	draw_line(Vector2(-ancho, -34), Vector2(ancho, -34), Color(0.1, 0.1, 0.12, 0.8), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Carpa del Puesto Médico Avanzado con heridos en camillas.
func _carpa_pma() -> void:
	var base := Vector2(150, Y_ACERA - 2)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-56, -40), base + Vector2(0, -64), base + Vector2(56, -40)]), Color("f4f6fa"))
	draw_rect(Rect2(base + Vector2(-56, -40), Vector2(112, 40)), Color(0.95, 0.96, 0.98, 0.35))
	draw_line(base + Vector2(-56, -40), base + Vector2(-56, 0), Color("c8ccd4"), 2.0)
	draw_line(base + Vector2(56, -40), base + Vector2(56, 0), Color("c8ccd4"), 2.0)
	draw_rect(Rect2(base + Vector2(-6, -58), Vector2(12, 4)), Color("e74c3c"))
	draw_rect(Rect2(base + Vector2(-2, -62), Vector2(4, 12)), Color("e74c3c"))
	for k in 2:
		var c := base + Vector2(-28 + k * 50.0, 0)
		_camilla(c, true)
	if inc.evento != "terminado":
		_persona(base + Vector2(-2, 2), "ambulancia", "pie", 0.0, 1.0)


## Perro de la unidad canina olfateando por la zona.
func _perro(p: Vector2) -> void:
	var paso := sin(_t * 10.0) * 2.0
	_elipse(p + Vector2(0, 1), 10.0, 2.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(p + Vector2(-9, -11), Vector2(16, 6)), Color("8b5a2b"))
	draw_circle(p + Vector2(9, -11), 4.0, Color("8b5a2b"))
	draw_line(p + Vector2(11, -14), p + Vector2(10, -18), Color("5b3a1e"), 2.0)   # oreja
	draw_line(p + Vector2(-9, -9), p + Vector2(-14, -14 + paso), Color("8b5a2b"), 2.0)   # cola
	for x in [-7.0, -2.0, 3.0, 6.0]:
		draw_line(p + Vector2(x, -5), p + Vector2(x + paso * (1.0 if int(x) % 2 == 0 else -1.0) * 0.5, 0), Color("6b4423"), 2.0)


func _luces(a: Vector2, b: Vector2, encendidas: bool) -> void:
	var rojo := Color("ff3b3b")
	var azul := Color("3b7bff")
	if not encendidas:
		draw_rect(Rect2(a, Vector2(b.x - a.x + 4, 3)), Color("555b66"))
		return
	var turno := int(_t * 6.0) % 2 == 0
	var c1 := rojo if turno else azul
	var c2 := azul if turno else rojo
	draw_circle(a, 9.0, Color(c1, 0.25))
	draw_circle(b, 9.0, Color(c2, 0.25))
	draw_rect(Rect2(a + Vector2(-2, -1), Vector2(5, 3)), c1)
	draw_rect(Rect2(b + Vector2(-2, -1), Vector2(5, 3)), c2)


func _coche_accidentado(p: Vector2, sin_techo: bool) -> void:
	_elipse(p + Vector2(0, 1), 34.0, 4.0, Color(0, 0, 0, 0.4))
	var cuerpo := PackedVector2Array([p + Vector2(-32, -6), p + Vector2(-30, -18), p + Vector2(-8, -22), p + Vector2(18, -15), p + Vector2(30, -8), p + Vector2(28, -4), p + Vector2(-30, -4)])
	draw_colored_polygon(cuerpo, Color("7d8796"))
	if not sin_techo:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-20, -20), p + Vector2(-12, -32), p + Vector2(6, -30), p + Vector2(12, -18)]), Color("6b7584"))
		draw_line(p + Vector2(-12, -30), p + Vector2(4, -22), Color("dfe6ef"), 1.0)
	else:
		draw_line(p + Vector2(-20, -20), p + Vector2(12, -18), Color("c8ccd4"), 2.0)
	draw_line(p + Vector2(18, -15), p + Vector2(28, -6), Color("2d3436"), 2.0)  # capó abollado
	draw_circle(p + Vector2(-18, -4), 5.5, Color("101418"))
	draw_circle(p + Vector2(16, -3), 5.0, Color("101418"))


func _tractor_volcado(p: Vector2) -> void:
	_elipse(p + Vector2(0, 1), 40.0, 5.0, Color(0, 0, 0, 0.4))
	draw_set_transform(p, 0.5, Vector2.ONE)
	draw_rect(Rect2(-30, -26, 46, 22), Color("2e8b3a"))
	draw_rect(Rect2(-10, -46, 22, 22), Color("2e8b3a"))
	draw_rect(Rect2(-6, -42, 14, 12), Color("9cc9ff"))
	draw_circle(Vector2(-20, -2), 14.0, Color("1b1b1b"))
	draw_circle(Vector2(-20, -2), 6.0, Color("c0392b"))
	draw_circle(Vector2(14, 2), 9.0, Color("1b1b1b"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _escombros(p: Vector2, alto: float, rocas: bool) -> void:
	var col := Color("7a7068") if rocas else Color("8a7f76")
	for k in 14:
		var x := -70.0 + fmod(k * 37.0, 140.0)
		var y := -fmod(k * 23.0, 40.0) * alto
		var r := 6.0 + fmod(k * 7.0, 8.0)
		draw_rect(Rect2(p + Vector2(x - r, y - r), Vector2(r * 2.0, r * 1.4)), col.darkened(fmod(k * 0.13, 0.4)))
	if not rocas:
		draw_line(p + Vector2(-60, -30 * alto), p + Vector2(40, -8), Color("5a3a22"), 4.0)   # viga
		draw_line(p + Vector2(-20, -40 * alto), p + Vector2(60, -20 * alto), Color("5a3a22"), 3.0)


func _camilla(p: Vector2, con_paciente: bool) -> void:
	draw_rect(Rect2(p + Vector2(-20, -10), Vector2(40, 4)), Color("dfe6ef"))
	draw_line(p + Vector2(-16, -6), p + Vector2(-16, 0), Color("8a8f99"), 2.0)
	draw_line(p + Vector2(16, -6), p + Vector2(16, 0), Color("8a8f99"), 2.0)
	draw_circle(p + Vector2(-16, 0), 2.0, Color("2d3436"))
	draw_circle(p + Vector2(16, 0), 2.0, Color("2d3436"))
	if con_paciente:
		draw_rect(Rect2(p + Vector2(-16, -15), Vector2(26, 5)), Color("e74c3c"))
		draw_circle(p + Vector2(14, -13), 4.0, PIEL)


func _monitor(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-9, -14), Vector2(18, 14)), Color("1d2a33"))
	draw_rect(Rect2(p + Vector2(-9, -14), Vector2(18, 14)), Color("8fa3b0"), false, 1.0)
	var pts := PackedVector2Array()
	for k in 9:
		var x := -7.0 + k * 1.75
		var fase := fmod(_t * 2.0 + k * 0.11, 1.0)
		var y := -7.0
		if fase > 0.82 and fase < 0.9:
			y = -12.0
		pts.append(p + Vector2(x, y))
	draw_polyline(pts, Color("2ecc71"), 1.0)


func _llama(c: Vector2, alto: float) -> void:
	var w := alto * 0.45
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w, alto * 0.4), c + Vector2(0, -alto * 0.6), c + Vector2(w, alto * 0.4)]), Color(1.0, 0.45, 0.1, 0.85))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.5, alto * 0.4), c + Vector2(0, -alto * 0.2), c + Vector2(w * 0.5, alto * 0.4)]), Color(1.0, 0.85, 0.3, 0.95))


## Chorro de agua en parábola, con gotas que avanzan.
func _chorro(desde: Vector2, hasta: Vector2) -> void:
	var altura := -40.0
	var anterior := desde
	for k in range(1, 13):
		var u := k / 12.0
		var punto := desde.lerp(hasta, u) + Vector2(0, altura * 4.0 * u * (1.0 - u))
		draw_line(anterior, punto, Color(0.5, 0.8, 1.0, 0.55), 2.0)
		anterior = punto
	for g in 4:
		var u := fmod(_t * 1.4 + g * 0.25, 1.0)
		var punto := desde.lerp(hasta, u) + Vector2(0, altura * 4.0 * u * (1.0 - u))
		draw_circle(punto, 2.2, Color(0.8, 0.93, 1.0, 0.9))


func _humo_suave(p: Vector2) -> void:
	for k in 3:
		var fase := fmod(_t * 0.5 + k * 0.33, 1.0)
		draw_circle(p + Vector2(fase * 12.0, -fase * 40.0), 6.0 + fase * 10.0, Color(0.55, 0.55, 0.58, 0.4 * (1.0 - fase)))


## Charco de sangre en el suelo (escenas duras).
func _sangre(c: Vector2, tam: float) -> void:
	_elipse(c, 16.0 * tam, 4.5 * tam, Color(0.45, 0.02, 0.04, 0.85))
	_elipse(c + Vector2(10, 2) * tam, 7.0 * tam, 2.5 * tam, Color(0.55, 0.03, 0.05, 0.8))
	_elipse(c + Vector2(-12, 1) * tam, 4.0 * tam, 1.6 * tam, Color(0.35, 0.01, 0.03, 0.8))


func _elipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _chispa(p: Vector2) -> void:
	if _chispas.size() > 40:
		return
	_chispas.append([p, Vector2(randf_range(-60, 60), randf_range(-90, -20)), 0.5, Color("ffe066")])


func _actualizar_chispas(delta: float) -> void:
	var vivas: Array = []
	for c in _chispas:
		c[2] -= delta
		c[1] += Vector2(0, 220) * delta
		c[0] += c[1] * delta
		if c[2] > 0.0:
			vivas.append(c)
	_chispas = vivas


func _dibujar_chispas() -> void:
	for c in _chispas:
		draw_circle(c[0], 1.6, c[3])


# ================================================================ TEXTOS

func _carteles() -> void:
	var texto := ""
	var color := Color("ffd166")
	match String(inc.evento):
		"tramites", "tramites_espera":
			texto = "TRÁMITES JUDICIALES"
			color = Color("cfd9e6")
		"refuerzos", "en_curso":
			if float(inc.t_ambulancia) >= 0.0:
				if int(_t * 3.0) % 2 == 0:
					texto = "¡HERIDO: FALTA AMBULANCIA!"
					color = Color("ff6b6b")
			elif int(inc.faltan_apoyo()) > 0 and int(_t * 1.5) % 2 == 0:
				texto = "PIDEN REFUERZOS (opcional)"
				color = Color("ffd166")
		"decision":
			texto = "ESPERAN TUS ÓRDENES"
			color = Color("9ff3ff")
		"":
			if inc.apoyos.size() > 0:
				texto = "PRIMERA RESPUESTA"
				color = Color("9ff3ff")
	if texto != "":
		var r := Rect2(ESCENA.position + Vector2(ESCENA.size.x / 2.0 - 120, 8), Vector2(240, 28))
		draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(r, color, false, 2.0)
		draw_string(fuente, r.position + Vector2(0, 20), texto, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, color)


func _dibujar_estado() -> void:
	var texto := ""
	var color := Color("e2f0ff")
	match String(inc.evento):
		"en_curso", "refuerzos":
			texto = "Interviniendo... %d%%" % int(float(inc.progreso) * 100.0)
			if float(inc.t_ambulancia) >= 0.0:
				texto = "Herido esperando ambulancia · %d s" % int(ceil(float(inc.t_ambulancia)))
				color = Color("ffd166") if int(_t * 3.0) % 2 == 0 else Color("ff6b6b")
			elif int(inc.faltan_apoyo()) > 0:
				texto += " · más lento sin refuerzos (%s)" % inc.texto_requeridas()
				color = Color("ffd166")
		"decision":
			texto = "Esperando órdenes de la central..."
			color = Color("9ff3ff")
		"tramites_espera":
			texto = "Hace falta una patrulla para custodiar el lugar"
			color = Color("ffd166")
		"tramites":
			match int(inc.tramites_paso):
				0:
					texto = "La policía toma declaración a los testigos..."
				1:
					texto = "El juzgado de guardia y el forense trabajan en el lugar..."
				_:
					texto = "La funeraria realiza el levantamiento del cuerpo..."
			color = Color("cfd9e6")
		"terminado":
			texto = String(inc.resultado)
			color = Color("8fd3a0") if inc.exito else Color("ff8a65")
		_:
			if inc.apoyos.size() > 0:
				texto = "Atendiendo hasta que llegue el servicio principal"
			else:
				texto = "Esperando al resto: %s" % inc.texto_requeridas()
	# Barra de progreso
	var barra := Rect2(12, ALTO - 44, ANCHO - 24, 8)
	draw_rect(barra, Color("13283a"))
	var prog: float = 1.0 if inc.evento == "terminado" else clampf(float(inc.progreso), 0.0, 1.0)
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * prog, barra.size.y)), Color("2ecc71") if inc.exito or inc.evento != "terminado" else Color("e67e22"))
	draw_string(fuente, Vector2(12, ALTO - 14), texto, HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 24, 16, color)
