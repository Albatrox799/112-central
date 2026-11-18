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
		nuevas.append({"id": v.id_unidad, "servicio": v.servicio, "n": clampi(v.efectivos(), 1, 3),
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
	_dibujar_chispas()
	_carteles()
	draw_rect(ESCENA, Color("2a6f8f"), false, 1.0)
	_dibujar_estado()
	draw_rect(Rect2(Vector2.ZERO, size), Color("3fb6d8"), false, 2.0)


func _fondo() -> void:
	var noche := _es_noche()
	var cielo := Color("0b1a3a") if noche else Color("1b3a6b")
	draw_rect(Rect2(ESCENA.position, Vector2(ESCENA.size.x, Y_ACERA - ESCENA.position.y)), cielo)
	# Edificios lejanos
	var x := ESCENA.position.x
	var i := 0
	while x < ESCENA.end.x:
		var ancho := 40.0 + fmod(i * 37.0, 30.0)
		var alto := 60.0 + fmod(i * 53.0, 70.0)
		draw_rect(Rect2(x, Y_ACERA - alto, ancho - 4.0, alto), Color("13254a") if noche else Color("274a80"))
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
	var x := ESCENA.position.x + 46.0
	for u in _unidades:
		var sv: String = u["servicio"]
		var edad := ahora - float(u.get("llegada", -1000.0))
		var p := Vector2(x, Y_SUELO)
		var desplazamiento: float = salen.get(sv, 0.0)
		if edad < T_LLEGADA:
			var k := clampf(edad / T_LLEGADA, 0.0, 1.0)
			desplazamiento -= (1.0 - (1.0 - pow(1.0 - k, 3.0))) * 460.0
		_vehiculo(p + Vector2(desplazamiento, 0), sv, 1.0, true)
		if edad >= T_LLEGADA and edad < T_LLEGADA + T_BAJAR + 1.2:
			# Puerta abierta mientras se bajan
			draw_rect(Rect2(p + Vector2(-2, -26), Vector2(4, 20)), Color("c8ccd4"))
		if desplazamiento == 0.0:
			draw_string(fuente, p + Vector2(-30, 12), String(u["id"]), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 1, 1, 0.75))
		if not puertas.has(sv):
			puertas[sv] = p + Vector2(0, -4)
			_puerta_serv[p + Vector2(0, -4)] = sv
		_edad_serv[sv] = maxf(float(_edad_serv.get(sv, -1.0)), edad)
		x += 84.0 if sv == "bomberos" else 72.0
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
	# Coche accidentado
	var sin_techo := p > 0.6 or fin
	_coche_accidentado(coche, sin_techo)
	if not fin or not exito:
		draw_circle(coche + Vector2(-4, -26), 4.5, PIEL)   # la persona atrapada dentro
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
	if inc.evento == "refuerzos" or inc.evento == "":
		fuego = 0.5 + 0.12 * int(inc.intensidad)
	if fin:
		fuego = 0.0 if exito else 0.55
	var puertas := _aparcados()
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


func _escena_pelea() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var salida := {}
	if fin and exito and _t_fin > 3.4:
		salida["policia"] = (_t_fin - 3.4) * 150.0
	var puertas := _aparcados(salida)
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
	# Un herido en el suelo
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


func _escena_robo() -> void:
	var p: float = inc.progreso
	var fin: bool = inc.evento == "terminado"
	var exito: bool = inc.exito
	var salida := {}
	if fin and exito and _t_fin > 3.4:
		salida["policia"] = (_t_fin - 3.4) * 150.0
	var puertas := _aparcados(salida)
	var casa := Rect2(300, 110, 190, Y_ACERA - 110)
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
	# Parque con árboles
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


## Policía (u otros) de apoyo alrededor de un paciente: aseguran la zona o,
## si son los primeros en llegar, tranquilizan y atienden hasta que llegue la ambulancia.
func _apoyo_alrededor(centro: Vector2, puertas: Dictionary, primera_respuesta: bool) -> void:
	var n_pol := _gente("policia")
	for i in mini(n_pol, 3):
		var sitio := centro + Vector2(-48 - i * 24.0, 2)
		if primera_respuesta and i == 0:
			sitio = centro + Vector2(-20, 0)
		var puerta: Vector2 = puertas.get("policia", sitio)
		var pos := _entrar(puerta, sitio, 0.2 + i * 0.3)
		var pose := "andar" if _andando(puerta, sitio, 0.2 + i * 0.3) else ("agachado" if primera_respuesta and i == 0 else "trafico")
		_persona(pos, "policia", pose, _t * 3.0, 1.0)
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
		"ambulancia":
			draw_line(hombro + Vector2(-3, 4), hombro + Vector2(3, 4), Color("2ecc71"), 2.0)
		"sospechoso":
			draw_arc(cabeza, 5.0, PI * 0.9, TAU + 0.2, 10, ropa.darkened(0.3), 3.0)
		_:
			draw_arc(cabeza + Vector2(0, -1), 4.0, PI, TAU, 8, Color("4a3426"), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vehículo visto de lado. p = punto del suelo en el centro.
func _vehiculo(p: Vector2, servicio: String, mirando: float, luces: bool) -> void:
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
	var x_ruedas := [-18.0, 18.0] if servicio != "bomberos" else [-24.0, 0.0, 24.0]
	for x in x_ruedas:
		draw_circle(Vector2(x, -5), 5.5, rueda)
		draw_circle(Vector2(x, -5), 2.2, Color("5a6170"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		"refuerzos":
			if int(_t * 3.0) % 2 == 0:
				texto = "¡PIDEN REFUERZOS!"
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
		"en_curso":
			texto = "Interviniendo... %d%%" % int(float(inc.progreso) * 100.0)
		"refuerzos":
			texto = "Faltan: %s · %d s" % [inc.texto_requeridas(), int(ceil(float(inc.t_refuerzos)))]
			color = Color("ffd166") if int(_t * 3.0) % 2 == 0 else Color("ff6b6b")
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
