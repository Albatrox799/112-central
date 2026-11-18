extends Node
## Efectos de luz y de ambiente, por encima del mapa y por debajo de la interfaz:
##   - Farolas que se encienden una a una al anochecer
##   - Destellos rojos y azules de las sirenas sobre las calles
##   - Resplandor naranja de los incendios y faros de los coches de noche
##   - Burbujas de radio sobre las unidades ("A-01: llegamos al lugar")
##   - Meteorología: lluvia, niebla, tormenta (con relámpagos) y calor
## Las luces van en una capa aparte para que la oscuridad de la noche no las apague.

const MATERIAL_SUMA := preload("res://scripts/effects/material_suma.tres")

var datos: Dictionary = {}
var vehiculos: Array = []
var incidentes: Array = []
var noche := 0.0             # 0 = día, 1 = noche cerrada
var zoom := 1.0
var calidad_alta := true
var clima := "despejado"     # despejado, lluvia, niebla, tormenta, calor
var activo := true           # false en los menús (se queda quieto)

var capa_mundo: CanvasLayer
var capa_pantalla: CanvasLayer
var farolas: Node2D
var luces: Node2D
var burbujas: Node2D
var meteo: Node2D
var _farolas: Array = []      # [pos, umbral]
var _encendidas := -1
var _burbujas: Array = []     # {nodo, texto, color, vida}
var _gotas: Array = []        # [x, y, velocidad]
var _niebla: Array = []       # [pos, radio, velocidad]
var _t := 0.0
var _flash := 0.0
var _t_relampago := 6.0
var sonido_lluvia: AudioStreamPlayer
var sonido_trueno: AudioStreamPlayer
var fuente: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fuente = ThemeDB.fallback_font
	capa_mundo = CanvasLayer.new()
	capa_mundo.layer = 1
	capa_mundo.follow_viewport_enabled = true
	add_child(capa_mundo)
	farolas = Node2D.new()
	farolas.material = MATERIAL_SUMA
	farolas.draw.connect(_dibujar_farolas)
	capa_mundo.add_child(farolas)
	luces = Node2D.new()
	luces.material = MATERIAL_SUMA
	luces.draw.connect(_dibujar_luces)
	capa_mundo.add_child(luces)
	burbujas = Node2D.new()
	burbujas.draw.connect(_dibujar_burbujas)
	capa_mundo.add_child(burbujas)
	capa_pantalla = CanvasLayer.new()
	capa_pantalla.layer = 5
	add_child(capa_pantalla)
	meteo = Node2D.new()
	meteo.draw.connect(_dibujar_meteo)
	capa_pantalla.add_child(meteo)
	sonido_lluvia = _reproductor("lluvia", -10.0)
	sonido_lluvia.finished.connect(_repetir_lluvia)
	sonido_trueno = _reproductor("trueno", -4.0)


func _reproductor(nombre: String, volumen: float) -> AudioStreamPlayer:
	var r := AudioStreamPlayer.new()
	var ruta := "res://assets/audio/%s.wav" % nombre
	if ResourceLoader.exists(ruta):
		r.stream = load(ruta)
	r.volume_db = volumen
	add_child(r)
	return r


## Prepara las farolas a lo largo de las calles (una cada ~55 m).
func configurar(p_datos: Dictionary) -> void:
	datos = p_datos
	_farolas.clear()
	for via in datos.get("vias", []):
		if via["tipo"] in ["path", "footway", "cycleway", "track", "service"]:
			continue
		var lista: Array = via["puntos"]
		var resto := 0.0
		for i in range(1, lista.size() / 2):
			var a := Vector2(float(lista[(i - 1) * 2]), float(lista[(i - 1) * 2 + 1]))
			var b := Vector2(float(lista[i * 2]), float(lista[i * 2 + 1]))
			var largo := a.distance_to(b)
			var d := 55.0 - resto
			while d < largo:
				var lado := (b - a).normalized().orthogonal() * 9.0
				_farolas.append([a.lerp(b, d / largo) + lado, randf()])
				d += 55.0
			resto = largo - (d - 55.0)
	_encendidas = -1


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	var pausado := get_tree().paused
	if not pausado:
		_t += delta
	# Farolas: se redibujan solo cuando cambia cuántas hay encendidas
	var paso := int(noche * 20.0)
	if paso != _encendidas:
		_encendidas = paso
		farolas.queue_redraw()
	farolas.visible = noche > 0.02
	# Burbujas de radio
	var vivas: Array = []
	for b in _burbujas:
		b["vida"] -= real
		if b["vida"] > 0.0 and is_instance_valid(b["nodo"]):
			vivas.append(b)
	_burbujas = vivas
	luces.queue_redraw()
	burbujas.queue_redraw()
	if activo and not pausado:
		_actualizar_meteo(delta)
	meteo.queue_redraw()


# ================================================================ LUCES

func _dibujar_farolas() -> void:
	var cuantas := float(_encendidas) / 20.0
	var radio := 26.0 if calidad_alta else 18.0
	for f in _farolas:
		if float(f[1]) < cuantas:
			var p: Vector2 = f[0]
			if calidad_alta:
				farolas.draw_circle(p, radio, Color(1.0, 0.72, 0.35, 0.10))
			farolas.draw_circle(p, radio * 0.45, Color(1.0, 0.78, 0.45, 0.16))
			farolas.draw_circle(p, 2.5, Color(1.0, 0.9, 0.7, 0.8))


func _dibujar_luces() -> void:
	var fuerza := 0.35 + 0.65 * noche
	var turno := int(_t * 5.0) % 2 == 0
	for v in vehiculos:
		if not is_instance_valid(v):
			continue
		var p: Vector2 = v.position
		# Faros delanteros de noche
		if noche > 0.3 and v.en_movimiento:
			var dir := Vector2.from_angle(float(v.direccion))
			var lado := dir.orthogonal()
			var largo := 70.0
			var cono := PackedVector2Array([p + dir * 6.0 + lado * 4.0, p + dir * largo + lado * 26.0, p + dir * largo - lado * 26.0, p + dir * 6.0 - lado * 4.0])
			luces.draw_colored_polygon(cono, Color(1.0, 0.95, 0.75, 0.10 * noche))
		# Sirenas: destellos rojo y azul que iluminan la calle
		var sirena: bool = v.en_emergencia or (v.estado == "En intervención")
		if sirena and v.servicio != "sospechoso":
			var col := Color(1.0, 0.15, 0.15) if turno else Color(0.2, 0.4, 1.0)
			if v.servicio == "bomberos" and not turno:
				col = Color(1.0, 0.45, 0.1)
			var r := 75.0 if calidad_alta else 55.0
			if calidad_alta:
				luces.draw_circle(p, r, Color(col, 0.10 * fuerza))
			luces.draw_circle(p, r * 0.5, Color(col, 0.18 * fuerza))
	for inc in incidentes:
		if not is_instance_valid(inc) or not inc.activo():
			continue
		if inc.tipo == "incendio" or inc.categoria == "fuego":
			var parpadeo := 0.8 + 0.2 * sin(_t * 9.0 + inc.position.x)
			var r := (90.0 + 45.0 * int(inc.intensidad)) * parpadeo
			if calidad_alta:
				luces.draw_circle(inc.position, r, Color(1.0, 0.4, 0.05, 0.10 * fuerza))
			luces.draw_circle(inc.position, r * 0.5, Color(1.0, 0.55, 0.1, 0.16 * fuerza))
	if _flash > 0.0:
		# Relámpago: ilumina todo el pueblo un instante
		luces.draw_rect(Rect2(-2000, -2000, 12000, 12000), Color(0.7, 0.75, 1.0, _flash * 0.35))


# ================================================================ BURBUJAS DE RADIO

func burbuja(nodo: Node2D, texto: String, color: Color) -> void:
	if nodo == null:
		return
	var corto := texto
	if corto.length() > 46:
		corto = corto.left(44) + "…"
	for b in _burbujas:
		if b["nodo"] == nodo:
			b["texto"] = corto
			b["color"] = color
			b["vida"] = 4.5
			return
	_burbujas.append({"nodo": nodo, "texto": corto, "color": color, "vida": 4.5})
	while _burbujas.size() > 5:
		_burbujas.pop_front()


func _dibujar_burbujas() -> void:
	var esc := clampf(1.0 / maxf(zoom, 0.05), 0.6, 3.5)
	var tam := 15
	for b in _burbujas:
		var nodo: Node2D = b["nodo"]
		var alfa := clampf(float(b["vida"]) / 0.5, 0.0, 1.0)
		var texto: String = b["texto"]
		var colb: Color = b["color"]
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 16.0
		burbujas.draw_set_transform(nodo.position + Vector2(0, -62) * esc, 0.0, Vector2(esc, esc))
		var r := Rect2(-ancho / 2.0, -26, ancho, 24)
		burbujas.draw_rect(r, Color(0.02, 0.06, 0.15, 0.88 * alfa))
		burbujas.draw_rect(r, Color(colb, alfa), false, 2.0)
		burbujas.draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(0, 8)]), Color(colb, alfa))
		burbujas.draw_string(fuente, Vector2(-ancho / 2.0 + 8, -9), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, alfa))
	burbujas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================ METEOROLOGÍA

func set_clima(nuevo: String) -> void:
	clima = nuevo
	_gotas.clear()
	_niebla.clear()
	var lluvia := clima == "lluvia" or clima == "tormenta"
	if lluvia:
		var n := (140 if clima == "tormenta" else 90) if calidad_alta else 55
		for i in n:
			_gotas.append([randf() * 1280.0, randf() * 720.0, randf_range(0.8, 1.2)])
		if sonido_lluvia.stream != null and not sonido_lluvia.playing:
			sonido_lluvia.play()
	else:
		sonido_lluvia.stop()
	if clima == "niebla":
		for i in (9 if calidad_alta else 5):
			_niebla.append([Vector2(randf() * 1400.0 - 60.0, randf() * 720.0), randf_range(160, 300), randf_range(8, 20)])
	_t_relampago = randf_range(5.0, 12.0)


func _repetir_lluvia() -> void:
	if clima == "lluvia" or clima == "tormenta":
		sonido_lluvia.play()


func detener_sonidos() -> void:
	sonido_lluvia.stop()


func _actualizar_meteo(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	for g in _gotas:
		g[1] += 900.0 * real * float(g[2])
		g[0] -= 260.0 * real * float(g[2])
		if g[1] > 730.0:
			g[1] = -20.0
			g[0] = randf() * 1500.0
	for n in _niebla:
		var pn: Vector2 = n[0]
		pn.x += float(n[2]) * real
		if pn.x > 1500.0:
			pn.x = -300.0
		n[0] = pn
	if _flash > 0.0:
		_flash = maxf(_flash - real * 2.5, 0.0)
	if clima == "tormenta":
		_t_relampago -= real
		if _t_relampago <= 0.0:
			_t_relampago = randf_range(7.0, 16.0)
			_flash = 1.0
			if sonido_trueno.stream != null:
				get_tree().create_timer(randf_range(0.4, 1.5), true, false, true).timeout.connect(sonido_trueno.play)


func _dibujar_meteo() -> void:
	match clima:
		"lluvia", "tormenta":
			meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.1, 0.2, 0.18 if clima == "lluvia" else 0.28))
			for g in _gotas:
				var p := Vector2(float(g[0]), float(g[1]))
				meteo.draw_line(p, p + Vector2(-5, 16), Color(0.7, 0.8, 1.0, 0.35), 1.5)
		"niebla":
			meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(0.75, 0.8, 0.88, 0.16))
			for n in _niebla:
				meteo.draw_circle(n[0], float(n[1]), Color(0.8, 0.84, 0.9, 0.07))
		"calor":
			meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.55, 0.15, 0.07))
	if _flash > 0.0:
		meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _flash * 0.45))
