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
var scroll_opciones: ScrollContainer
var raiz: Control
var etiqueta_reloj: Label
var etiqueta_velocidad: Label
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
	vista_lugar.position = Vector2(14, 296)
	vista_lugar.visible = false
	raiz.add_child(vista_lugar)
	_crear_aviso_llamada()
	_crear_ventana_llamada()
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
	portada.draw_string(f, Vector2(0, ALTO - 50), "Mapa: © colaboradores de OpenStreetMap · Versión 0.7.1", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 15, Color(0.75, 0.82, 0.9, 0.7))


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
	if portada.visible:
		_t_portada += delta
		portada.queue_redraw()
	mira.visible = not ventana_abierta() and not portada.visible
	mira.queue_redraw()
	if calibrando():
		etiqueta_ayuda.text = "Configuración del mando"
	elif get_tree().paused and not pausa_tactica:
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Options o Círculo: continuar"
	elif pausa_tactica and not ventana_abierta():
		etiqueta_ayuda.text = "TIEMPO DETENIDO · R1: continuar · Joystick: mover · X: seleccionar · Cuadrado: unidades · Triángulo: emergencias"
	elif panel_abierto():
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Círculo: volver"
	elif llamada_abierta():
		etiqueta_ayuda.text = "Cruceta: elegir qué decir   ·   X: decirlo"
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


func mostrar_lugar(inc) -> void:
	vista_lugar.inc = inc
	vista_lugar.visible = true


func ocultar_lugar(inc) -> void:
	if vista_lugar.inc == inc:
		vista_lugar.visible = false


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
	panel_lateral.visible = false
	_vaciar(panel_opciones)
	_reenfocar()


func mostrar_aviso_llamada(texto: String) -> void:
	aviso_texto.text = texto
	aviso_llamada.visible = true
	call_deferred("_ajustar", aviso_llamada)
	if tween_aviso:
		tween_aviso.kill()
	tween_aviso = aviso_llamada.create_tween().set_loops()
	tween_aviso.tween_property(aviso_llamada, "modulate", Color(1, 0.75, 0.75), 0.4)
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


func cerrar_llamada() -> void:
	ventana_llamada.visible = false
	_vaciar(ll_opciones)
	_reenfocar()


func actualizar_llamada(cabecera: String, texto: String, calma: int, estado: String, localizacion: String, info: Array, opciones: Array) -> void:
	ll_cabecera.text = cabecera
	ll_texto.text = "«" + texto + "»"
	ll_estado.text = "Estado: " + estado
	ll_barra.value = calma
	var c := Color("e74c3c").lerp(Color("2ecc71"), calma / 100.0)
	ll_barra.add_theme_stylebox_override("fill", _caja(c, 0, 0))
	ll_localizacion.text = "Localización: " + localizacion
	var datos := "ninguno todavía"
	if info.size() > 0:
		datos = ""
		for i in info.size():
			datos += ("" if i == 0 else " · ") + str(info[i])
	ll_info.text = "Datos obtenidos: " + datos
	_vaciar(ll_opciones)
	var primero: Button = null
	for i in opciones.size():
		var b := _boton("%d. %s" % [i + 1, opciones[i]])
		b.pressed.connect(_al_elegir.bind(i))
		ll_opciones.add_child(b)
		if primero == null:
			primero = b
	call_deferred("_ajustar", ventana_llamada)
	if primero != null and not panel_abierto():
		primero.call_deferred("grab_focus")


# ---------------------------------------------------------------- INTERNO

func _al_elegir(i: int) -> void:
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
	aviso_llamada.position = Vector2(ANCHO / 2.0 - 270.0, 70)
	aviso_llamada.custom_minimum_size = Vector2(540, 0)
	aviso_llamada.add_theme_stylebox_override("panel", _caja(Color("5c1a1a"), 3, 16, Color("ff6b6b"), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	aviso_llamada.add_child(v)
	var titulo := _etiqueta("LLAMADA ENTRANTE AL 112", 30, Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	aviso_texto = _etiqueta("", 21, Color("ffd6d6"))
	aviso_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(aviso_texto)
	boton_contestar = _boton("Contestar la llamada (X)")
	boton_contestar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton_contestar.pressed.connect(_al_contestar)
	v.add_child(boton_contestar)
	aviso_llamada.visible = false
	raiz.add_child(aviso_llamada)


func _crear_ventana_llamada() -> void:
	ventana_llamada = PanelContainer.new()
	ventana_llamada.position = Vector2(90, 66)
	ventana_llamada.custom_minimum_size = Vector2(1100, 0)
	ventana_llamada.add_theme_stylebox_override("panel", _caja(Color(0.03, 0.08, 0.19, 0.97), 3, 22, Color("3fb6d8"), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ventana_llamada.add_child(v)
	ll_cabecera = _etiqueta("", 21, Color("7fc8ff"))
	v.add_child(ll_cabecera)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	v.add_child(fila)
	ll_estado = _etiqueta("", 21, Color.WHITE)
	fila.add_child(ll_estado)
	ll_barra = ProgressBar.new()
	ll_barra.min_value = 0
	ll_barra.max_value = 100
	ll_barra.show_percentage = false
	ll_barra.custom_minimum_size = Vector2(200, 20)
	ll_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(ll_barra)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	ll_localizacion = _etiqueta("", 21, Color("ffd166"))
	fila.add_child(ll_localizacion)
	ll_info = _etiqueta("", 18, Color("9fb3c8"))
	ll_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ll_info)
	v.add_child(HSeparator.new())
	ll_texto = _etiqueta("", 27, Color.WHITE)
	ll_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll_texto.custom_minimum_size = Vector2(0, 80)
	v.add_child(ll_texto)
	ll_opciones = VBoxContainer.new()
	ll_opciones.add_theme_constant_override("separation", 8)
	v.add_child(ll_opciones)
	ventana_llamada.visible = false
	raiz.add_child(ventana_llamada)


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
