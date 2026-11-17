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

const ANCHO := 1280.0
const ALTO := 720.0

var tema: Theme
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
	_crear_aviso_llamada()
	_crear_ventana_llamada()
	_crear_panel_lateral()
	_crear_calibracion()
	var osm := _etiqueta("Mapa: © colaboradores de OpenStreetMap", 14, Color(0.8, 0.85, 0.9, 0.7))
	osm.position = Vector2(ANCHO - 300, ALTO - 62)
	raiz.add_child(osm)


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


func _process(_delta: float) -> void:
	mira.visible = not ventana_abierta()
	if calibrando():
		etiqueta_ayuda.text = "Configuración del mando"
	elif get_tree().paused:
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Options o Círculo: continuar"
	elif panel_abierto():
		etiqueta_ayuda.text = "Cruceta: elegir   ·   X: confirmar   ·   Círculo: volver"
	elif llamada_abierta():
		etiqueta_ayuda.text = "Cruceta: elegir qué decir   ·   X: decirlo"
	elif aviso_llamada.visible:
		etiqueta_ayuda.text = "X: contestar la llamada   ·   Triángulo: emergencias   ·   Joystick: mover mapa"
	else:
		etiqueta_ayuda.text = "Joystick izq.: mover · L2/R2: zoom · X: seleccionar · Cuadrado: unidades · Triángulo: emergencias · Options: pausa"


# ---------------------------------------------------------------- API

func set_reloj(texto: String) -> void:
	etiqueta_reloj.text = texto


func set_velocidad(texto: String) -> void:
	etiqueta_velocidad.text = texto


func set_pausa(activa: bool) -> void:
	etiqueta_pausa.visible = activa


func set_debug(visible_debug: bool, texto: String) -> void:
	panel_debug.visible = visible_debug
	etiqueta_debug.text = texto


func notificar(texto: String, color: Color = Color("e8eef6")) -> void:
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", _caja(Color(0.05, 0.08, 0.12, 0.92), 2, 10, color))
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := _etiqueta(texto, 19, color)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(430, 0)
	caja.add_child(e)
	caja_notificaciones.add_child(caja)
	while caja_notificaciones.get_child_count() > 4:
		var vieja := caja_notificaciones.get_child(0)
		caja_notificaciones.remove_child(vieja)
		vieja.queue_free()
	var tw := caja.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(caja, "modulate:a", 0.0, 0.8)
	tw.tween_callback(caja.queue_free)


## opciones: Array de Dictionary {"texto": String, "accion": Callable, "activo": bool (opcional)}
func mostrar_panel(titulo: String, texto: String, opciones: Array) -> void:
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
	var normal := _caja(Color("22324a"), 0, 12)
	var foco := _caja(Color(0, 0, 0, 0), 4, 12, Color("ffd166"))
	foco.draw_center = false
	var pulsado := _caja(Color("3d5a80"), 0, 12)
	var desactivado := _caja(Color("1a2233"), 0, 12)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", pulsado)
	t.set_stylebox("focus", "Button", foco)
	t.set_stylebox("disabled", "Button", desactivado)
	t.set_color("font_color", "Button", Color("dfe7f2"))
	t.set_color("font_focus_color", "Button", Color("ffffff"))
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_disabled_color", "Button", Color("6b7a90"))
	t.set_stylebox("panel", "PanelContainer", _caja(Color(0.06, 0.09, 0.14, 0.95), 2, 18, Color("4a6fa5"), 10))
	t.set_color("font_color", "Label", Color("e8eef6"))
	t.set_stylebox("background", "ProgressBar", _caja(Color("1a2233"), 0, 0))
	return t


func _crear_barra_superior() -> void:
	var barra := PanelContainer.new()
	barra.position = Vector2.ZERO
	barra.custom_minimum_size = Vector2(ANCHO, 54)
	barra.add_theme_stylebox_override("panel", _caja(Color(0.04, 0.06, 0.1, 0.95), 0, 10, Color.TRANSPARENT, 0))
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
	var col := Color(1, 1, 1, 0.85)
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
	barra.add_theme_stylebox_override("panel", _caja(Color(0.04, 0.06, 0.1, 0.95), 0, 8, Color.TRANSPARENT, 0))
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
	ventana_llamada.add_theme_stylebox_override("panel", _caja(Color(0.04, 0.07, 0.11, 0.97), 3, 22, Color("4a90d9"), 12))
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
	panel_texto = _etiqueta("", 20, Color("cfd9e6"))
	panel_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(panel_texto)
	panel_opciones = VBoxContainer.new()
	panel_opciones.add_theme_constant_override("separation", 8)
	v.add_child(panel_opciones)
	panel_lateral.visible = false
	raiz.add_child(panel_lateral)
