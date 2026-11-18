extends Node
## Efectos de luz y de ambiente, por encima del mapa y por debajo de la interfaz:
##   - Farolas que se encienden una a una al anochecer
##   - Destellos rojos y azules de las sirenas sobre las calles
##   - Resplandor naranja de los incendios y faros de los coches de noche
##   - Burbujas de radio sobre las unidades ("A-01: llegamos al lugar")
##   - Meteorología: lluvia, niebla, tormenta (con relámpagos) y calor
## Las luces van en una capa aparte para que la oscuridad de la noche no las apague.

const SEPARACION_FAROLAS := 90.0
const MATERIAL_SUMA := preload("res://scripts/effects/material_suma.tres")

var datos: Dictionary = {}
var vehiculos: Array = []
var incidentes: Array = []
var noche := 0.0             # 0 = día, 1 = noche cerrada
var zoom := 1.0
var calidad_alta := true:
	set(valor):
		calidad_alta = valor
		_encendidas = -1   # vuelve a dibujar las farolas con la nueva calidad
var clima := "despejado"     # despejado, lluvia, niebla, tormenta, calor
var activo := true           # false en los menús (se queda quieto)
var zona_evento: Dictionary = {}   # {pos, nombre}: fiesta del día (gente, confeti)
var capa := ""                     # "", "calor" o "historial"
var historial: Array = []          # [x, y, estrellas, titulo, dia, turno]

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
var _habia_burbujas := false
var _habia_meteo := false
var _flash := 0.0
var _t_relampago := 6.0
var sonido_lluvia: AudioStreamPlayer
var sonido_trueno: AudioStreamPlayer
var fuente: Font
var brillo: GradientTexture2D   # una sola imagen de luz difuminada para todas las luces (muy rápido)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fuente = ThemeDB.fallback_font
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	brillo = GradientTexture2D.new()
	brillo.gradient = g
	brillo.width = 64
	brillo.height = 64
	brillo.fill = GradientTexture2D.FILL_RADIAL
	brillo.fill_from = Vector2(0.5, 0.5)
	brillo.fill_to = Vector2(1.0, 0.5)
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
			var d := SEPARACION_FAROLAS - resto
			while d < largo:
				var lado := (b - a).normalized().orthogonal() * 9.0
				_farolas.append([a.lerp(b, d / largo) + lado, randf()])
				d += SEPARACION_FAROLAS
			resto = largo - (d - SEPARACION_FAROLAS)
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
	if not _burbujas.is_empty() or _habia_burbujas or capa == "historial" or not zona_evento.is_empty():
		burbujas.queue_redraw()
	_habia_burbujas = not _burbujas.is_empty() or capa == "historial" or not zona_evento.is_empty()
	if activo and not pausado:
		_actualizar_meteo(delta)
	if clima != "despejado" or _flash > 0.0 or _habia_meteo:
		meteo.queue_redraw()
	_habia_meteo = clima != "despejado" or _flash > 0.0


# ================================================================ LUCES

func _luz(nodo: CanvasItem, p: Vector2, radio: float, color: Color) -> void:
	nodo.draw_texture_rect(brillo, Rect2(p - Vector2(radio, radio), Vector2(radio, radio) * 2.0), false, color)


func _dibujar_farolas() -> void:
	var cuantas := float(_encendidas) / 20.0
	var radio := 30.0 if calidad_alta else 20.0
	var color := Color(1.0, 0.75, 0.4, 0.5 if calidad_alta else 0.35)
	for f in _farolas:
		if float(f[1]) < cuantas:
			_luz(farolas, f[0], radio, color)


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
			if calidad_alta:
				var cono := PackedVector2Array([p + dir * 6.0 + lado * 4.0, p + dir * largo + lado * 26.0, p + dir * largo - lado * 26.0, p + dir * 6.0 - lado * 4.0])
				luces.draw_colored_polygon(cono, Color(1.0, 0.95, 0.75, 0.10 * noche))
		# Sirenas: destellos rojo y azul que iluminan la calle
		var sirena: bool = v.en_emergencia or (v.estado == "En intervención")
		if sirena and v.servicio != "sospechoso":
			var col := Color(1.0, 0.15, 0.15) if turno else Color(0.2, 0.4, 1.0)
			if v.servicio == "bomberos" and not turno:
				col = Color(1.0, 0.45, 0.1)
			var r := 80.0 if calidad_alta else 55.0
			_luz(luces, p, r, Color(col, 0.45 * fuerza))
	# Fiesta del día: mucha gente y luces de colores
	if not zona_evento.is_empty():
		var c: Vector2 = zona_evento["pos"]
		var colores := [Color(1.0, 0.3, 0.6), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.2), Color(0.5, 1.0, 0.4)]
		_luz(luces, c, 180.0 + 15.0 * sin(_t * 2.0), Color(1.0, 0.6, 0.9, 0.18))
		for k in (10 if calidad_alta else 5):
			var a := _t * 0.6 + k * TAU / 10.0
			var q := c + Vector2(cos(a), sin(a * 1.3)) * (60.0 + 50.0 * sin(_t + k))
			_luz(luces, q, 22.0, Color(colores[k % 4], 0.6))
	# Mapa de calor: dónde ha habido más emergencias
	if capa == "calor":
		for h in historial:
			_luz(luces, Vector2(float(h[0]), float(h[1])), 120.0, Color(1.0, 0.25, 0.1, 0.35))
	for inc in incidentes:
		if not is_instance_valid(inc) or not inc.activo():
			continue
		if inc.tipo == "incendio" or inc.categoria == "fuego":
			var parpadeo := 0.8 + 0.2 * sin(_t * 9.0 + inc.position.x)
			var r := (90.0 + 45.0 * int(inc.intensidad)) * parpadeo
			_luz(luces, inc.position, r, Color(1.0, 0.45, 0.08, 0.5 * fuerza))


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
	# Nombre de la fiesta del día sobre la zona
	if not zona_evento.is_empty():
		var nombre: String = zona_evento["nombre"]
		var w := fuente.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
		var pz: Vector2 = zona_evento["pos"]
		burbujas.draw_set_transform(pz + Vector2(0, -120) * esc, 0.0, Vector2(esc, esc))
		burbujas.draw_rect(Rect2(-w / 2.0, -22, w, 26), Color(0.25, 0.05, 0.25, 0.85))
		burbujas.draw_rect(Rect2(-w / 2.0, -22, w, 26), Color("ff7ad9"), false, 2.0)
		burbujas.draw_string(fuente, Vector2(-w / 2.0 + 8, -3), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		burbujas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Historial: una chincheta por emergencia, con su nota
	if capa == "historial":
		for h in historial:
			var p := Vector2(float(h[0]), float(h[1]))
			var e := int(h[2])
			var col := Color("e74c3c").lerp(Color("2ecc71"), (e - 1) / 4.0)
			burbujas.draw_set_transform(p, 0.0, Vector2(esc, esc))
			burbujas.draw_circle(Vector2(0, -14), 9.0, col)
			burbujas.draw_line(Vector2(0, -6), Vector2.ZERO, col, 2.0)
			burbujas.draw_string(fuente, Vector2(-10, -9), str(e), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color.WHITE)
		burbujas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
		var n := (110 if clima == "tormenta" else 70) if calidad_alta else 40
		for i in n:
			_gotas.append([randf() * 1280.0, randf() * 720.0, randf_range(0.8, 1.2)])
		if sonido_lluvia.stream != null and not sonido_lluvia.playing:
			sonido_lluvia.play()
	else:
		sonido_lluvia.stop()
	if clima == "niebla":
		for i in (6 if calidad_alta else 3):
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
				_luz(meteo, n[0], float(n[1]), Color(0.8, 0.84, 0.9, 0.18))
		"calor":
			meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.55, 0.15, 0.07))
	if _flash > 0.0:
		meteo.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _flash * 0.45))
