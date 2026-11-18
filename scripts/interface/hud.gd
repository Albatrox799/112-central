extends CanvasLayer
## Interfaz para televisión. Todo se maneja con el mando (sin ratón):
##   - Barra superior con la hora y la velocidad del tiempo
##   - Mira central para seleccionar cosas en el mapa
##   - Notificaciones y mensajes de radio
##   - Panel lateral (unidades, emergencias, informes, pausa)
##   - Aviso de llamada entrante y ventana de conversación
##   - Barra de ayuda con los botones disponibles

signal llamada_contestada
signal opcion_llamada(indice: int)

var pausa_tactica := false
var modo_envio := ""   # id de la unidad que se está enviando con la mira

const ANCHO := 1280.0
const ALTO := 720.0

const VistaLugar = preload("res://scripts/interface/vista_lugar.gd")

var tema: Theme
var etiqueta_dinero: Label
var barra_superior: PanelContainer
var portada: Control
var panel_consejo: PanelContainer
var texto_consejo: Label
var tween_consejo: Tween
var _t_portada := 0.0
var vista_lugar
var lugar_inc = null
var lugar_final := false
var scroll_opciones: ScrollContainer
var raiz: Control
var etiqueta_reloj: Label
var etiqueta_velocidad: Label
var etiqueta_clima: Label
var etiqueta_pausa: Label
var caja_notificaciones: VBoxContainer
var etiqueta_ayuda: Label
var mira: Control
var panel_lateral: PanelContainer
var panel_titulo: Label
var panel_texto: Label
var panel_opciones: VBoxContainer
var ventana_llamada: PanelContainer
var ll_cabecera: Label
var ll_luz: Control
var ll_duracion: Label
var ll_pestana_dialogo: Label
var ll_pestana_info: Label
var ll_caja_dialogo: VBoxContainer
var ll_caja_info: VBoxContainer
var ll_scroll_historial: ScrollContainer
var ll_historial: VBoxContainer
var ll_saltar: Label
var ll_precision: Control
var icono_llamada: Control
var tecleo: AudioStreamPlayer
var pestana_llamada := 0
var precision_llamada := 0
var texto_animado := true
var _texto_completo := ""
var _letras := 0.0
var _textos_opciones: Array = []
var _ultima_frase_operador := ""
var _t_duracion := 0.0
var _t_aviso := 0.0
var _t_aviso_total := 25.0
var _t_icono := 0.0
const ANCHO_LLAMADA := 540.0
const LETRAS_POR_SEGUNDO := 48.0
var ll_estado: Label
var ll_barra: ProgressBar
var ll_localizacion: Label
var ll_info: Label
var ll_texto: Label
var ll_opciones: VBoxContainer
var aviso_llamada: PanelContainer
var aviso_texto: Label
var boton_contestar: Button
var tween_aviso: Tween
var panel_debug: PanelContainer
var etiqueta_debug: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	tema = _crear_tema()
	raiz = Control.new()
	raiz.theme = tema
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.position = Vector2.ZERO
	raiz.size = Vector2(ANCHO, ALTO)
	add_child(raiz)
	_crear_mira()
	_crear_barra_superior()
	_crear_notificaciones()
	_crear_barra_ayuda()
	_crear_barra_unidades()
	_crear_debug()
	vista_lugar = VistaLugar.new()
	vista_lugar.position = Vector2(14, 262)
	vista_lugar.visible = false
	raiz.add_child(vista_lugar)
	_crear_aviso_llamada()
	_crear_ventana_llamada()
	tecleo = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/tecla.wav"):
		tecleo.stream = load("res://assets/audio/tecla.wav")
	tecleo.volume_db = -14.0
	add_child(tecleo)
	_crear_panel_lateral()
	_crear_calibracion()
	_crear_consejo()
	_crear_portada()
	var osm := _etiqueta("Mapa: © colaboradores de OpenStreetMap", 14, Color(0.8, 0.85, 0.9, 0.7))
	osm.position = Vector2(ANCHO - 300, ALTO - 62)
	raiz.add_child(osm)


# ---------------------------------------------------------------- PORTADA

func _crear_portada() -> void:
	portada = Control.new()
	portada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portada.size = Vector2(ANCHO, ALTO)
	portada.draw.connect(_dibujar_portada)
	portada.visible = false
	raiz.add_child(portada)
	raiz.move_child(portada, 0)


func mostrar_portada(si: bool) -> void:
	portada.visible = si
	barra_superior.visible = not si
	barra_unidades.visible = not si


func _dibujar_portada() -> void:
	var f := ThemeDB.fallback_font
	# Oscurecer arriba para que se lea el logo
	portada.draw_rect(Rect2(0, 0, ANCHO, 360), Color(0.02, 0.05, 0.13, 0.55))
	# Emblema: hexágono con los colores de los tres servicios
	var c := Vector2(ANCHO / 2.0, 120)
	var r := 62.0
	var hex := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		hex.append(c + Vector2(cos(a), sin(a)) * r)
	var colores := [Color("f2f6fc"), Color("3b8eea"), Color("d64545")]
	var franja := r * 2.0 / 3.0
	for k in 3:
		var x0 := c.x - r + k * franja
		var rect := PackedVector2Array([Vector2(x0, c.y - r * 1.2), Vector2(x0 + franja, c.y - r * 1.2), Vector2(x0 + franja, c.y + r * 1.2), Vector2(x0, c.y + r * 1.2)])
		for trozo in Geometry2D.intersect_polygons(hex, rect):
			portada.draw_colored_polygon(trozo, colores[k])
	var borde := hex.duplicate()
	borde.append(hex[0])
	portada.draw_polyline(borde, Color.WHITE, 4.0)
	portada.draw_string(f, c + Vector2(-60, 14), "112", HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color("0a1430"))
	# Título
	portada.draw_string_outline(f, Vector2(0, 250), "CENTRAL 112", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 76, 10, Color("0a1430"))
	portada.draw_string(f, Vector2(0, 250), "CENTRAL 112", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 76, Color.WHITE)
	portada.draw_string_outline(f, Vector2(0, 298), "M I G U E L T U R R A", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 32, 8, Color("0a1430"))
	portada.draw_string(f, Vector2(0, 298), "M I G U E L T U R R A", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 32, Color("9ff3ff"))
	# Destello rojo y azul que recorre el título, como una sirena
	var x := fmod(_t_portada * 260.0, ANCHO + 400.0) - 200.0
	var col := Color(1, 0.2, 0.2, 0.22) if int(_t_portada * 2.0) % 2 == 0 else Color(0.2, 0.45, 1.0, 0.22)
	portada.draw_rect(Rect2(x, 185, 140, 125), col)
	portada.draw_string(f, Vector2(0, ALTO - 50), "Mapa: © colaboradores de OpenStreetMap · Versión 0.8.1", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 15, Color(0.75, 0.82, 0.9, 0.7))


# ---------------------------------------------------------------- PERIÓDICO (fin de turno)

var periodico: Control
var datos_periodico: Dictionary = {}


func mostrar_periodico(d: Dictionary) -> void:
	datos_periodico = d
	if periodico == null:
		periodico = Control.new()
		periodico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		periodico.position = Vector2(ANCHO / 2.0 - 380.0, 58)
		periodico.size = Vector2(760, 500)
		periodico.draw.connect(_dibujar_periodico)
		raiz.add_child(periodico)
	periodico.visible = true
	periodico.pivot_offset = periodico.size / 2.0
	periodico.rotation = -0.6
	periodico.scale = Vector2(0.2, 0.2)
	var tw := periodico.create_tween().set_parallel(true)
	tw.tween_property(periodico, "rotation", -0.02, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(periodico, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	periodico.queue_redraw()


func ocultar_periodico() -> void:
	if periodico != null:
		periodico.visible = false


func _dibujar_periodico() -> void:
	var f := ThemeDB.fallback_font
	var w := periodico.size.x
	var h := periodico.size.y
	var tinta := Color("1e1e1e")
	periodico.draw_rect(Rect2(8, 10, w, h), Color(0, 0, 0, 0.45))
	periodico.draw_rect(Rect2(0, 0, w, h), Color("f3ecd8"))
	# Cabecera
	periodico.draw_string(f, Vector2(0, 52), "LA VOZ DE MIGUELTURRA", HORIZONTAL_ALIGNMENT_CENTER, w, 44, tinta)
	periodico.draw_line(Vector2(24, 66), Vector2(w - 24, 66), tinta, 2.0)
	periodico.draw_string(f, Vector2(24, 86), String(datos_periodico.get("fecha", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 15, Color("4a4a4a"))
	periodico.draw_string(f, Vector2(24, 86), "Edición especial · 1 €", HORIZONTAL_ALIGNMENT_RIGHT, w - 48, 15, Color("4a4a4a"))
	periodico.draw_line(Vector2(24, 94), Vector2(w - 24, 94), tinta, 1.0)
	# Titular
	var titular := String(datos_periodico.get("titular", ""))
	var y := _texto_parrafo(titular, Vector2(24, 132), w - 48, 34, tinta, 40)
	y = _texto_parrafo(String(datos_periodico.get("subtitulo", "")), Vector2(24, y + 6), w - 48, 19, Color("3a3a3a"), 24)
	# "Foto": la central de noche con sirenas
	var foto := Rect2(24, y + 14, 300, 170)
	periodico.draw_rect(foto, Color("2a2f3a"))
	for k in 6:
		var x := foto.position.x + 10 + k * 48.0
		var alto := 50.0 + fmod(k * 37.0, 60.0)
		periodico.draw_rect(Rect2(x, foto.end.y - alto, 40, alto), Color("4a5160"))
	periodico.draw_circle(foto.position + Vector2(90, 120), 34.0, Color(0.9, 0.3, 0.3, 0.45))
	periodico.draw_circle(foto.position + Vector2(200, 120), 34.0, Color(0.35, 0.5, 0.95, 0.45))
	periodico.draw_rect(Rect2(foto.position + Vector2(110, 120), Vector2(80, 30)), Color("d8d8d8"))
	periodico.draw_rect(foto, tinta, false, 1.0)
	periodico.draw_string(f, Vector2(foto.position.x, foto.end.y + 18), "Foto: Central 112 de Miguelturra.", HORIZONTAL_ALIGNMENT_LEFT, 300, 13, Color("555555"))
	# Columna de breves
	var x0 := 344.0
	var yb := y + 30
	periodico.draw_string(f, Vector2(x0, yb), "BREVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8e1f1f"))
	yb += 10
	for b in datos_periodico.get("breves", []):
		yb = _texto_parrafo("· " + String(b), Vector2(x0, yb + 20), w - x0 - 24, 15, tinta, 19)
		if yb > h - 70:
			break
	# Pie: valoración de los vecinos
	periodico.draw_line(Vector2(24, h - 46), Vector2(w - 24, h - 46), tinta, 1.0)
	periodico.draw_string(f, Vector2(24, h - 20), String(datos_periodico.get("pie", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 16, tinta)


## Escribe un párrafo partiendo las líneas; devuelve la altura final.
func _texto_parrafo(texto: String, pos: Vector2, ancho: float, tam: int, color: Color, interlineado: float) -> float:
	var f := ThemeDB.fallback_font
	var palabras := texto.split(" ")
	var linea := ""
	var y := pos.y
	for p in palabras:
		var prueba := p if linea == "" else linea + " " + p
		if f.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > ancho and linea != "":
			periodico.draw_string(f, Vector2(pos.x, y), linea, HORIZONTAL_ALIGNMENT_LEFT, ancho, tam, color)
			y += interlineado
			linea = p
		else:
			linea = prueba
	if linea != "":
		periodico.draw_string(f, Vector2(pos.x, y), linea, HORIZONTAL_ALIGNMENT_LEFT, ancho, tam, color)
		y += interlineado
	return y


# ---------------------------------------------------------------- CONSEJOS (tutorial)

func _crear_consejo() -> void:
	panel_consejo = PanelContainer.new()
	panel_consejo.position = Vector2(ANCHO / 2.0 - 380.0, 62)
	panel_consejo.custom_minimum_size = Vector2(760, 0)
	panel_consejo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_consejo.add_theme_stylebox_override("panel", _caja(Color(0.25, 0.2, 0.02, 0.95), 3, 14, Color("ffd166"), 10))
	texto_consejo = _etiqueta("", 21, Color("fff3c4"))
	texto_consejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_consejo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_consejo.add_child(texto_consejo)
	panel_consejo.visible = false
	raiz.add_child(panel_consejo)


func mostrar_consejo(texto: String) -> void:
	texto_consejo.text = "CONSEJO · " + texto
	panel_consejo.visible = true
	panel_consejo.modulate = Color.WHITE
	call_deferred("_ajustar", panel_consejo)
	if tween_consejo:
		tween_consejo.kill()
	tween_consejo = panel_consejo.create_tween()
	tween_consejo.tween_interval(13.0)
	tween_consejo.tween_property(panel_consejo, "modulate:a", 0.0, 0.8)
	tween_consejo.tween_callback(func(): panel_consejo.visible = false)


func set_texto_grande(grande: bool) -> void:
	tema.default_font_size = 26 if grande else 22


var panel_calibracion: PanelContainer
var texto_calibracion: Label


func _crear_calibracion() -> void:
	panel_calibracion = PanelContainer.new()
	panel_calibracion.position = Vector2(240, 220)
	panel_calibracion.custom_minimum_size = Vector2(800, 0)
	panel_calibracion.add_theme_stylebox_override("panel", _caja(Color(0.04, 0.07, 0.11, 0.98), 3, 30, Color("ffd166"), 12))
	texto_calibracion = _etiqueta("", 30, Color.WHITE)
	texto_calibracion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_calibracion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_calibracion.add_child(texto_calibracion)
	panel_calibracion.visible = false
	raiz.add_child(panel_calibracion)


func mostrar_calibracion(texto: String) -> void:
	texto_calibracion.text = texto
	panel_calibracion.visible = true
	call_deferred("_ajustar", panel_calibracion)


func ocultar_calibracion() -> void:
	panel_calibracion.visible = false


func calibrando() -> bool:
	return panel_calibracion.visible


# ---------------------------------------------------------------- ESTADO

func panel_abierto() -> bool:
	return panel_lateral.visible


func llamada_abierta() -> bool:
	return ventana_llamada.visible


func ventana_abierta() -> bool:
	return panel_abierto() or llamada_abierta()


## Moverse por la lista activa con la cruceta, siempre en orden
## (arriba/abajo), sin depender de la posición de los botones en pantalla.
func _input(event: InputEvent) -> void:
	if calibrando():
		return
	# Durante la llamada: L1/R1 cambian de pestaña y X salta el texto que se escribe
	if ventana_llamada.visible and not panel_lateral.visible:
		if event.is_action_pressed("categoria_siguiente") or event.is_action_pressed("categoria_anterior"):
			_elegir_pestana(1 - pestana_llamada)
			get_viewport().set_input_as_handled()
			return
		if escribiendo() and (event.is_action_pressed("seleccionar") or event.is_action_pressed("ui_accept")):
			saltar_texto()
			get_viewport().set_input_as_handled()
			return
	var abajo := event.is_action_pressed("nav_abajo")
	var arriba := event.is_action_pressed("nav_arriba")
	if not abajo and not arriba:
		return
	var lista: Node = null
	if panel_lateral.visible:
		lista = panel_opciones
	elif ventana_llamada.visible:
		lista = ll_opciones
	if lista == null:
		return
	var botones := []
	for h in lista.get_children():
		if h is Button and not h.disabled and h.focus_mode != Control.FOCUS_NONE:
			botones.append(h)
	if botones.is_empty():
		return
	var actual := botones.find(raiz.get_viewport().gui_get_focus_owner())
	var siguiente := 0
	if actual >= 0:
		siguiente = (actual + (1 if abajo else -1) + botones.size()) % botones.size()
	botones[siguiente].grab_focus()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Tiempo real (la llamada va a cámara lenta, pero el texto y los relojes no)
	var real := delta / maxf(Engine.time_scale, 0.01)
	_t_icono += real
	if aviso_llamada.visible:
		if not get_tree().paused:
			_t_aviso = maxf(_t_aviso - delta, 0.0)
		icono_llamada.queue_redraw()
	if ventana_llamada.visible:
		if not get_tree().paused:
			_t_duracion += real
		ll_duracion.text = "%02d:%02d" % [int(_t_duracion) / 60, int(_t_duracion) % 60]
		ll_luz.queue_redraw()
		_avanzar_texto(real)
		caja_notificaciones.position = Vector2(ANCHO - 460.0, 66)
	else:
		caja_notificaciones.position = Vector2(14, 66)
	if portada.visible:
		_t_portada += delta
		portada.queue_redraw()
	mira.visible = not ventana_abierta() and not portada.visible
	mira.queue_redraw()
	_actualizar_vista_lugar()
	if calibrando():
		etiqueta_ayuda.text = "Configuración del mando"
	elif get_tree().paused and not pausa_tactica:
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Options o Círculo: continuar"
	elif pausa_tactica and not ventana_abierta():
		etiqueta_ayuda.text = "TIEMPO DETENIDO · R1: continuar · Joystick: mover · X: seleccionar · Cuadrado: unidades · Triángulo: emergencias"
	elif panel_abierto():
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Círculo: volver"
	elif llamada_abierta():
		if escribiendo():
			etiqueta_ayuda.text = "X: ver todo el texto   ·   L1/R1: Diálogo / Información"
		elif pestana_llamada == 1:
			etiqueta_ayuda.text = "L1/R1: volver al diálogo"
		else:
			etiqueta_ayuda.text = "Cruceta: elegir qué decir   ·   X: decirlo   ·   L1/R1: Diálogo / Información"
	elif modo_envio != "":
		etiqueta_ayuda.text = "ENVIANDO %s · Mueve la mira a una emergencia · X: enviar · Círculo: cancelar" % modo_envio
	elif aviso_llamada.visible:
		etiqueta_ayuda.text = "X: contestar la llamada   ·   Triángulo: emergencias   ·   Joystick: mover mapa"
	else:
		etiqueta_ayuda.text = "Joystick izq.: mover · L2/R2: zoom · L1/R1: velocidad · X: seleccionar · Cuadrado: unidades · Triángulo: emergencias · Options: pausa"


# ---------------------------------------------------------------- API

func set_reloj(texto: String) -> void:
	etiqueta_reloj.text = texto


func set_dinero(cantidad: int) -> void:
	etiqueta_dinero.text = formato_euros(cantidad)


static func formato_euros(cantidad: int) -> String:
	var signo := "-" if cantidad < 0 else ""
	var t := str(absi(cantidad))
	var out := ""
	while t.length() > 3:
		out = "." + t.right(3) + out
		t = t.left(t.length() - 3)
	return signo + t + out + " €"


## La vista "En el lugar" va ligada a la emergencia que se está mirando:
## aparece cuando hay alguna unidad trabajando allí (también de apoyo),
## cambia al mirar otra y se cierra al salir del panel.
## final = true: se muestra junto al informe aunque las unidades ya se vayan.
func mirar_lugar(inc, final: bool = false) -> void:
	lugar_inc = inc
	lugar_final = final


func dejar_de_mirar() -> void:
	lugar_inc = null
	lugar_final = false


func _actualizar_vista_lugar() -> void:
	var mostrar := false
	if lugar_inc != null and is_instance_valid(lugar_inc) and panel_lateral.visible:
		mostrar = lugar_final or lugar_inc.hay_unidades_en_escena()
	if mostrar:
		vista_lugar.inc = lugar_inc
		vista_lugar.final = lugar_final
	vista_lugar.visible = mostrar


func set_clima(texto: String, color: Color) -> void:
	etiqueta_clima.text = texto
	etiqueta_clima.add_theme_color_override("font_color", color)


func set_velocidad(texto: String) -> void:
	etiqueta_velocidad.text = texto


func set_pausa(activa: bool) -> void:
	etiqueta_pausa.visible = activa


func set_debug(visible_debug: bool, texto: String) -> void:
	panel_debug.visible = visible_debug
	etiqueta_debug.text = texto


func notificar(texto: String, color: Color = Color("e8eef6")) -> void:
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", _caja(Color(0.03, 0.08, 0.19, 0.92), 2, 10, color))
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := _etiqueta(texto, 19, color)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(430, 0)
	caja.add_child(e)
	caja_notificaciones.add_child(caja)
	while caja_notificaciones.get_child_count() > 3:
		var vieja := caja_notificaciones.get_child(0)
		caja_notificaciones.remove_child(vieja)
		vieja.queue_free()
	var tw := caja.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(caja, "modulate:a", 0.0, 0.8)
	tw.tween_callback(caja.queue_free)


## opciones: Array de Dictionary {"texto": String, "accion": Callable, "activo": bool (opcional)}
func mostrar_panel(titulo: String, texto: String, opciones: Array, centrado: bool = false, pos_y: float = 90.0, ancho: float = 620.0) -> void:
	dejar_de_mirar()
	if centrado:
		panel_lateral.custom_minimum_size = Vector2(ancho, 0)
		panel_lateral.position = Vector2(ANCHO / 2.0 - ancho / 2.0, pos_y)
	else:
		panel_lateral.custom_minimum_size = Vector2(460, 0)
		panel_lateral.position = Vector2(ANCHO - 474.0, 64)
	panel_titulo.text = titulo
	panel_texto.text = texto
	panel_texto.visible = texto != ""
	_vaciar(panel_opciones)
	var primero: Button = null
	for o in opciones:
		var b := _boton(o["texto"])
		var activo: bool = o.get("activo", true)
		if activo:
			var accion: Callable = o["accion"]
			b.pressed.connect(func(): accion.call_deferred())
			if primero == null:
				primero = b
		else:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		panel_opciones.add_child(b)
	scroll_opciones.custom_minimum_size = Vector2(0, minf(opciones.size() * 56.0, 400.0 if centrado else 330.0))
	scroll_opciones.scroll_vertical = 0
	panel_lateral.visible = true
	call_deferred("_ajustar", panel_lateral)
	if primero != null:
		primero.call_deferred("grab_focus")


func cerrar_panel() -> void:
	dejar_de_mirar()
	panel_lateral.visible = false
	_vaciar(panel_opciones)
	_reenfocar()


func mostrar_aviso_llamada(texto: String, segundos: float = 25.0) -> void:
	aviso_texto.text = texto
	_t_aviso = segundos
	_t_aviso_total = segundos
	aviso_llamada.visible = true
	call_deferred("_ajustar", aviso_llamada)
	if tween_aviso:
		tween_aviso.kill()
	tween_aviso = aviso_llamada.create_tween().set_loops()
	tween_aviso.tween_property(aviso_llamada, "modulate", Color(0.8, 1.0, 0.85), 0.4)
	tween_aviso.tween_property(aviso_llamada, "modulate", Color.WHITE, 0.4)
	if not ventana_abierta():
		boton_contestar.call_deferred("grab_focus")


func ocultar_aviso_llamada() -> void:
	if tween_aviso:
		tween_aviso.kill()
		tween_aviso = null
	aviso_llamada.modulate = Color.WHITE
	aviso_llamada.visible = false


func abrir_llamada() -> void:
	ventana_llamada.visible = true
	_vaciar(ll_historial)
	_t_duracion = 0.0
	_texto_completo = ""
	_letras = 0.0
	_elegir_pestana(0)


func cerrar_llamada() -> void:
	ventana_llamada.visible = false
	_vaciar(ll_opciones)
	_reenfocar()


func escribiendo() -> bool:
	return ventana_llamada.visible and _letras < _texto_completo.length()


func actualizar_llamada(cabecera: String, texto: String, calma: int, estado: String, localizacion: String, info: Array, opciones: Array, precision: int = 0) -> void:
	ll_cabecera.text = cabecera
	# Lo que dijo el operador queda en el historial, y la respuesta anterior también
	if _texto_completo != "":
		_anadir_historial("Llamante", _texto_completo, Color("7dffb3"))
	if _ultima_frase_operador != "":
		_anadir_historial("Tú", _ultima_frase_operador, Color.WHITE)
		_ultima_frase_operador = ""
	_texto_completo = "«" + texto + "»"
	_letras = 0.0 if texto_animado else float(_texto_completo.length())
	ll_texto.text = ""
	ll_estado.text = "Estado: " + estado
	ll_barra.value = calma
	var c := Color("e74c3c").lerp(Color("2ecc71"), calma / 100.0)
	ll_barra.add_theme_stylebox_override("fill", _caja(c, 0, 0))
	ll_localizacion.text = "Localización: " + localizacion
	precision_llamada = precision
	ll_precision.queue_redraw()
	var datos := "· ninguno todavía"
	if info.size() > 0:
		datos = ""
		for i in info.size():
			datos += ("" if i == 0 else "\n") + "· " + str(info[i])
	ll_info.text = "Datos obtenidos:\n" + datos
	_vaciar(ll_opciones)
	_textos_opciones = opciones.duplicate()
	for i in opciones.size():
		var b := _boton("%d. %s" % [i + 1, opciones[i]])
		var op := String(opciones[i])
		if op.begins_with("[Terminar") or op.begins_with("[Colgar"):
			b.text = "FINALIZAR LLAMADA" if op == "[Colgar]" else "FINALIZAR LLAMADA Y CREAR EL INCIDENTE"
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_stylebox_override("normal", _caja(Color("8e1f1f"), 2, 12, Color("ff6b6b"), 8))
			b.add_theme_stylebox_override("hover", _caja(Color("8e1f1f"), 2, 12, Color("ff6b6b"), 8))
		b.pressed.connect(_al_elegir.bind(i))
		ll_opciones.add_child(b)
	ll_opciones.visible = not escribiendo()
	ll_saltar.visible = escribiendo()
	if pestana_llamada != 0:
		_elegir_pestana(0)
	call_deferred("_ajustar", ventana_llamada)
	if not escribiendo():
		_texto_terminado()


func _anadir_historial(quien: String, texto: String, color: Color) -> void:
	var e := _etiqueta("%s: %s" % [quien, texto], 17, color)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(ANCHO_LLAMADA - 60, 0)
	ll_historial.add_child(e)
	while ll_historial.get_child_count() > 14:
		var vieja := ll_historial.get_child(0)
		ll_historial.remove_child(vieja)
		vieja.queue_free()
	call_deferred("_bajar_historial")


func _bajar_historial() -> void:
	ll_scroll_historial.scroll_vertical = 100000


## Texto que se va escribiendo letra a letra, con sonido de tecleo.
func _avanzar_texto(delta: float) -> void:
	if not escribiendo():
		return
	var antes := int(_letras)
	_letras = minf(_letras + delta * LETRAS_POR_SEGUNDO, float(_texto_completo.length()))
	var ahora := int(_letras)
	ll_texto.text = _texto_completo.left(ahora)
	if ahora / 3 != antes / 3 and tecleo.stream != null:
		tecleo.pitch_scale = randf_range(0.9, 1.15)
		tecleo.play()
	if not escribiendo():
		_texto_terminado()


func saltar_texto() -> void:
	_letras = float(_texto_completo.length())
	ll_texto.text = _texto_completo
	_texto_terminado()


func _texto_terminado() -> void:
	ll_texto.text = _texto_completo
	ll_opciones.visible = true
	ll_saltar.visible = false
	call_deferred("_ajustar", ventana_llamada)
	if pestana_llamada == 0:
		_enfocar_primera_opcion()


func _enfocar_primera_opcion() -> void:
	if panel_lateral == null or panel_abierto() or ll_opciones.get_child_count() == 0:
		return
	var b: Button = ll_opciones.get_child(0)
	b.call_deferred("grab_focus")


# ---------------------------------------------------------------- INTERNO

func _al_elegir(i: int) -> void:
	if i >= 0 and i < _textos_opciones.size():
		_ultima_frase_operador = String(_textos_opciones[i])
	call_deferred("emit_signal", "opcion_llamada", i)


func _al_contestar() -> void:
	call_deferred("emit_signal", "llamada_contestada")


func _reenfocar() -> void:
	if panel_lateral.visible and panel_opciones.get_child_count() > 0:
		return
	if ventana_llamada.visible and ll_opciones.get_child_count() > 0:
		var b: Button = ll_opciones.get_child(0)
		b.call_deferred("grab_focus")
	elif aviso_llamada.visible:
		boton_contestar.call_deferred("grab_focus")
	else:
		var foco := raiz.get_viewport().gui_get_focus_owner()
		if foco != null:
			foco.release_focus()


func _ajustar(c: Control) -> void:
	c.reset_size()
	if c == panel_lateral:
		call_deferred("_limitar_altura")


## Si el panel no cabe en pantalla, se encoge la lista (que tiene barra de
## desplazamiento) para que siempre se vean todas las opciones bajando.
func _limitar_altura() -> void:
	var limite := ALTO - 48.0
	var sobra := panel_lateral.position.y + panel_lateral.size.y - limite
	if sobra > 1.0:
		var nuevo := maxf(scroll_opciones.custom_minimum_size.y - sobra, 120.0)
		scroll_opciones.custom_minimum_size = Vector2(0, nuevo)
		panel_lateral.reset_size()


func _vaciar(contenedor: Node) -> void:
	for h in contenedor.get_children():
		contenedor.remove_child(h)
		h.queue_free()


func _caja(color: Color, borde: int = 0, margen: int = 0, color_borde: Color = Color.TRANSPARENT, radio: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(borde)
	s.border_color = color_borde
	s.set_corner_radius_all(radio)
	s.content_margin_left = margen
	s.content_margin_right = margen
	s.content_margin_top = margen
	s.content_margin_bottom = margen
	return s


func _etiqueta(texto: String, tam: int, color: Color) -> Label:
	var e := Label.new()
	e.text = texto
	e.add_theme_font_size_override("font_size", tam)
	e.add_theme_color_override("font_color", color)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 46)
	if "autowrap_mode" in b:
		b.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	else:
		b.clip_text = true
	return b


func _crear_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var normal := _caja(Color("1d5468"), 1, 12, Color("2f8aa6"), 6)
	var foco := _caja(Color(0, 0, 0, 0), 4, 12, Color("9ff3ff"), 6)
	foco.draw_center = false
	var pulsado := _caja(Color("2b7f99"), 1, 12, Color("9ff3ff"), 6)
	var desactivado := _caja(Color("13283a"), 0, 12, Color.TRANSPARENT, 6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", pulsado)
	t.set_stylebox("focus", "Button", foco)
	t.set_stylebox("disabled", "Button", desactivado)
	t.set_color("font_color", "Button", Color("dfe7f2"))
	t.set_color("font_focus_color", "Button", Color("ffffff"))
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_disabled_color", "Button", Color("6b7a90"))
	t.set_stylebox("panel", "PanelContainer", _caja(Color(0.04, 0.09, 0.2, 0.95), 2, 18, Color("3fb6d8"), 10))
	t.set_color("font_color", "Label", Color("e2f0ff"))
	t.set_stylebox("background", "ProgressBar", _caja(Color("1a2233"), 0, 0))
	return t


func _crear_barra_superior() -> void:
	var barra := PanelContainer.new()
	barra_superior = barra
	barra.position = Vector2.ZERO
	barra.custom_minimum_size = Vector2(ANCHO, 54)
	barra.add_theme_stylebox_override("panel", _caja(Color(0.03, 0.07, 0.17, 0.95), 0, 10, Color.TRANSPARENT, 0))
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	barra.add_child(fila)
	fila.add_child(_etiqueta("CENTRAL 112 · MIGUELTURRA", 24, Color("ff6b6b")))
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	etiqueta_pausa = _etiqueta("PAUSA", 24, Color("ffd166"))
	etiqueta_pausa.visible = false
	fila.add_child(etiqueta_pausa)
	etiqueta_dinero = _etiqueta("", 24, Color("6ee7b7"))
	fila.add_child(etiqueta_dinero)
	etiqueta_clima = _etiqueta("", 22, Color("9fd3ff"))
	fila.add_child(etiqueta_clima)
	etiqueta_velocidad = _etiqueta("Tiempo x1", 22, Color("9fb3c8"))
	fila.add_child(etiqueta_velocidad)
	etiqueta_reloj = _etiqueta("08:00", 28, Color.WHITE)
	fila.add_child(etiqueta_reloj)


func _crear_mira() -> void:
	mira = Control.new()
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mira.position = Vector2(ANCHO / 2.0 - 30.0, ALTO / 2.0 - 30.0)
	mira.size = Vector2(60, 60)
	mira.draw.connect(_dibujar_mira)
	raiz.add_child(mira)


func _dibujar_mira() -> void:
	var c := Vector2(30, 30)
	var col := Color("9ff3ff") if modo_envio != "" else Color(1, 1, 1, 0.85)
	mira.draw_arc(c, 20.0, 0.0, TAU, 32, col, 2.0)
	mira.draw_line(c + Vector2(-30, 0), c + Vector2(-12, 0), col, 2.0)
	mira.draw_line(c + Vector2(12, 0), c + Vector2(30, 0), col, 2.0)
	mira.draw_line(c + Vector2(0, -30), c + Vector2(0, -12), col, 2.0)
	mira.draw_line(c + Vector2(0, 12), c + Vector2(0, 30), col, 2.0)


func _crear_notificaciones() -> void:
	caja_notificaciones = VBoxContainer.new()
	caja_notificaciones.position = Vector2(14, 66)
	caja_notificaciones.add_theme_constant_override("separation", 8)
	caja_notificaciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja_notificaciones)


func _crear_barra_ayuda() -> void:
	var barra := PanelContainer.new()
	barra.position = Vector2(0, ALTO - 40)
	barra.custom_minimum_size = Vector2(ANCHO, 40)
	barra.add_theme_stylebox_override("panel", _caja(Color(0.03, 0.07, 0.17, 0.95), 0, 8, Color.TRANSPARENT, 0))
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra)
	etiqueta_ayuda = _etiqueta("", 18, Color("cfd9e6"))
	etiqueta_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barra.add_child(etiqueta_ayuda)


var barra_unidades: HBoxContainer

const COLORES_ESTADO := {
	"Disponible": Color("2e7d32"), "En desplazamiento": Color("e67e22"),
	"Buscando el lugar": Color("d35400"), "En intervención": Color("c0392b"),
	"Persecución": Color("8e44ad"), "Regresando": Color("2471a3"),
	"Patrullando": Color("1e8449"), "Traslado al hospital": Color("7d3c98"),
	"Reponiendo material": Color("b7950b"), "Sin personal": Color("555555"),
}


func _crear_barra_unidades() -> void:
	barra_unidades = HBoxContainer.new()
	barra_unidades.position = Vector2(14, ALTO - 84)
	barra_unidades.add_theme_constant_override("separation", 8)
	barra_unidades.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra_unidades)


## lista: Array de [id, estado, color_servicio]
func actualizar_unidades(lista: Array) -> void:
	_vaciar(barra_unidades)
	for u in lista:
		var chip := PanelContainer.new()
		var color_estado: Color = COLORES_ESTADO.get(u[1], Color("555555"))
		chip.add_theme_stylebox_override("panel", _caja(Color(color_estado, 0.85), 3, 6, u[2], 6))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_etiqueta("%s · %s" % [u[0], u[1]], 16, Color.WHITE))
		barra_unidades.add_child(chip)


func _crear_debug() -> void:
	panel_debug = PanelContainer.new()
	panel_debug.position = Vector2(14, 470)
	panel_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_debug.add_theme_stylebox_override("panel", _caja(Color(0, 0, 0, 0.8), 2, 10, Color("ffd166")))
	etiqueta_debug = _etiqueta("", 17, Color("ffd166"))
	panel_debug.add_child(etiqueta_debug)
	panel_debug.visible = false
	raiz.add_child(panel_debug)


func _crear_aviso_llamada() -> void:
	aviso_llamada = PanelContainer.new()
	aviso_llamada.position = Vector2(ANCHO / 2.0 - 280.0, 66)
	aviso_llamada.custom_minimum_size = Vector2(560, 0)
	aviso_llamada.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.12, 0.08, 0.96), 3, 14, Color("3ddc84"), 14))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	aviso_llamada.add_child(fila)
	icono_llamada = Control.new()
	icono_llamada.custom_minimum_size = Vector2(110, 110)
	icono_llamada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono_llamada.draw.connect(_dibujar_icono_llamada)
	fila.add_child(icono_llamada)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(v)
	var titulo := _etiqueta("LLAMADA ENTRANTE · 112", 28, Color("7dffb3"))
	titulo.add_theme_constant_override("outline_size", 6)
	titulo.add_theme_color_override("font_outline_color", Color(0.1, 0.6, 0.3, 0.6))
	v.add_child(titulo)
	aviso_texto = _etiqueta("", 19, Color("d8ffe8"))
	aviso_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(aviso_texto)
	boton_contestar = _boton("   Contestar (X)")
	boton_contestar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton_contestar.add_theme_stylebox_override("normal", _caja(Color("1e8f4e"), 2, 12, Color("3ddc84"), 10))
	boton_contestar.add_theme_stylebox_override("hover", _caja(Color("1e8f4e"), 2, 12, Color("3ddc84"), 10))
	boton_contestar.add_theme_stylebox_override("pressed", _caja(Color("27b765"), 2, 12, Color("b9ffd6"), 10))
	boton_contestar.add_theme_font_size_override("font_size", 24)
	boton_contestar.pressed.connect(_al_contestar)
	v.add_child(boton_contestar)
	aviso_llamada.visible = false
	raiz.add_child(aviso_llamada)


## Teléfono con ondas y la cuenta atrás antes de que cuelguen.
func _dibujar_icono_llamada() -> void:
	var c := Vector2(55, 55)
	var fr := clampf(_t_aviso / maxf(_t_aviso_total, 0.1), 0.0, 1.0)
	icono_llamada.draw_circle(c, 50.0, Color(0.05, 0.25, 0.15, 1.0))
	icono_llamada.draw_arc(c, 50.0, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 6.0)
	var col := Color("e74c3c").lerp(Color("3ddc84"), fr)
	icono_llamada.draw_arc(c, 50.0, -PI / 2.0, -PI / 2.0 + TAU * fr, 48, col, 6.0)
	# Ondas
	for k in 3:
		var fase := fmod(_t_icono * 1.2 + k * 0.33, 1.0)
		icono_llamada.draw_arc(c, 22.0 + fase * 22.0, -0.7, 0.7, 12, Color(0.6, 1.0, 0.8, 0.7 * (1.0 - fase)), 3.0)
		icono_llamada.draw_arc(c, 22.0 + fase * 22.0, PI - 0.7, PI + 0.7, 12, Color(0.6, 1.0, 0.8, 0.7 * (1.0 - fase)), 3.0)
	# Auricular (vibra un poco)
	var temblor := Vector2(sin(_t_icono * 40.0) * 1.5, 0) if fmod(_t_icono, 1.0) < 0.5 else Vector2.ZERO
	var cc := c + temblor
	icono_llamada.draw_arc(cc + Vector2(0, 8), 18.0, PI * 1.15, PI * 1.85, 16, Color.WHITE, 8.0)
	icono_llamada.draw_circle(cc + Vector2(-15, 0), 6.5, Color.WHITE)
	icono_llamada.draw_circle(cc + Vector2(15, 0), 6.5, Color.WHITE)
	icono_llamada.draw_string(ThemeDB.fallback_font, c + Vector2(-30, 34), "%d s" % ceili(_t_aviso), HORIZONTAL_ALIGNMENT_CENTER, 60, 16, col)


func _crear_ventana_llamada() -> void:
	ventana_llamada = PanelContainer.new()
	ventana_llamada.position = Vector2(14, 62)
	ventana_llamada.custom_minimum_size = Vector2(ANCHO_LLAMADA, 0)
	ventana_llamada.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.07, 0.16, 0.97), 3, 14, Color("3ddc84"), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	ventana_llamada.add_child(v)
	# Cabecera verde
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	v.add_child(cab)
	ll_luz = Control.new()
	ll_luz.custom_minimum_size = Vector2(22, 22)
	ll_luz.draw.connect(func(): ll_luz.draw_circle(Vector2(11, 11), 8.0 if int(_t_icono * 2.0) % 2 == 0 else 6.0, Color("3ddc84")))
	cab.add_child(ll_luz)
	var titulo := _etiqueta("LLAMADA EN CURSO", 22, Color("7dffb3"))
	cab.add_child(titulo)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(hueco)
	ll_duracion = _etiqueta("00:00", 22, Color("d8ffe8"))
	cab.add_child(ll_duracion)
	ll_cabecera = _etiqueta("", 16, Color("9fc7e8"))
	ll_cabecera.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ll_cabecera)
	# Pestañas
	var pest := HBoxContainer.new()
	pest.add_theme_constant_override("separation", 6)
	v.add_child(pest)
	ll_pestana_dialogo = _etiqueta("  DIÁLOGO  ", 19, Color.WHITE)
	ll_pestana_info = _etiqueta("  INFORMACIÓN  ", 19, Color.WHITE)
	pest.add_child(ll_pestana_dialogo)
	pest.add_child(ll_pestana_info)
	var hueco2 := Control.new()
	hueco2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pest.add_child(hueco2)
	pest.add_child(_etiqueta("L1 / R1", 15, Color("6b8aa8")))
	# --- Pestaña DIÁLOGO
	ll_caja_dialogo = VBoxContainer.new()
	ll_caja_dialogo.add_theme_constant_override("separation", 8)
	v.add_child(ll_caja_dialogo)
	ll_scroll_historial = ScrollContainer.new()
	ll_scroll_historial.custom_minimum_size = Vector2(0, 236)
	ll_scroll_historial.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ll_caja_dialogo.add_child(ll_scroll_historial)
	ll_historial = VBoxContainer.new()
	ll_historial.add_theme_constant_override("separation", 6)
	ll_historial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll_scroll_historial.add_child(ll_historial)
	ll_texto = _etiqueta("", 22, Color("7dffb3"))
	ll_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll_texto.custom_minimum_size = Vector2(ANCHO_LLAMADA - 40, 0)
	ll_caja_dialogo.add_child(ll_texto)
	ll_saltar = _etiqueta("X: ver todo el texto", 15, Color("6b8aa8"))
	ll_caja_dialogo.add_child(ll_saltar)
	ll_opciones = VBoxContainer.new()
	ll_opciones.add_theme_constant_override("separation", 6)
	ll_caja_dialogo.add_child(ll_opciones)
	# --- Pestaña INFORMACIÓN
	ll_caja_info = VBoxContainer.new()
	ll_caja_info.add_theme_constant_override("separation", 10)
	ll_caja_info.visible = false
	v.add_child(ll_caja_info)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	ll_caja_info.add_child(fila)
	ll_estado = _etiqueta("", 20, Color.WHITE)
	fila.add_child(ll_estado)
	ll_barra = ProgressBar.new()
	ll_barra.min_value = 0
	ll_barra.max_value = 100
	ll_barra.show_percentage = false
	ll_barra.custom_minimum_size = Vector2(180, 18)
	ll_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(ll_barra)
	ll_localizacion = _etiqueta("", 20, Color("ffd166"))
	ll_localizacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll_caja_info.add_child(ll_localizacion)
	ll_precision = Control.new()
	ll_precision.custom_minimum_size = Vector2(ANCHO_LLAMADA - 40, 26)
	ll_precision.draw.connect(_dibujar_precision)
	ll_caja_info.add_child(ll_precision)
	ll_info = _etiqueta("", 18, Color("cfe3f5"))
	ll_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll_info.custom_minimum_size = Vector2(ANCHO_LLAMADA - 40, 0)
	ll_caja_info.add_child(ll_info)
	ll_caja_info.add_child(_etiqueta("R1: volver al diálogo para seguir hablando", 15, Color("6b8aa8")))
	ventana_llamada.visible = false
	raiz.add_child(ventana_llamada)
	_elegir_pestana(0)


func _elegir_pestana(i: int) -> void:
	pestana_llamada = i
	ll_caja_dialogo.visible = i == 0
	ll_caja_info.visible = i == 1
	var activa := _caja(Color("1e8f4e"), 0, 4, Color.TRANSPARENT, 6)
	var inactiva := _caja(Color("13283a"), 0, 4, Color.TRANSPARENT, 6)
	ll_pestana_dialogo.add_theme_stylebox_override("normal", activa if i == 0 else inactiva)
	ll_pestana_info.add_theme_stylebox_override("normal", activa if i == 1 else inactiva)
	if not ventana_llamada.visible:
		return
	if i == 0 and not escribiendo():
		_enfocar_primera_opcion()
	elif i == 1:
		var foco := raiz.get_viewport().gui_get_focus_owner()
		if foco != null:
			foco.release_focus()
	call_deferred("_ajustar", ventana_llamada)


## Barra de precisión de la localización: 4 tramos, del desconocido al punto exacto.
func _dibujar_precision() -> void:
	var w := (ll_precision.size.x - 30.0) / 4.0
	var nombres := ["Desconocida", "Zona", "Calle", "Exacta"]
	for k in 4:
		var r := Rect2(k * (w + 10.0), 0, w, 10)
		var lleno := k <= precision_llamada
		var col := Color("ffd166") if lleno else Color("1f3047")
		if lleno and k == 3:
			col = Color("3ddc84")
		ll_precision.draw_rect(r, col)
		ll_precision.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, 25), nombres[k], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color("8fa9c4"))


func _crear_panel_lateral() -> void:
	panel_lateral = PanelContainer.new()
	panel_lateral.position = Vector2(ANCHO - 474.0, 64)
	panel_lateral.custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel_lateral.add_child(v)
	panel_titulo = _etiqueta("", 25, Color("ffd166"))
	panel_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(panel_titulo)
	panel_texto = _etiqueta("", 18, Color("cfd9e6"))
	panel_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(panel_texto)
	scroll_opciones = ScrollContainer.new()
	scroll_opciones.follow_focus = true
	scroll_opciones.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll_opciones)
	panel_opciones = VBoxContainer.new()
	panel_opciones.add_theme_constant_override("separation", 8)
	panel_opciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_opciones.add_child(panel_opciones)
	panel_lateral.visible = false
	raiz.add_child(panel_lateral)
