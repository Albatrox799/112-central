extends Node
## Controles del juego.
## Mando principal: DualShock 4 de PlayStation 4.
## También se añade teclado para poder probar el juego en el ordenador.
##
## Botones del mando en Godot:
##   X (cruz) = JOY_BUTTON_A        Círculo = JOY_BUTTON_B
##   Cuadrado = JOY_BUTTON_X        Triángulo = JOY_BUTTON_Y
##   Share = JOY_BUTTON_BACK        Options = JOY_BUTTON_START
##   L1 / R1 = hombros              L2 / R2 = gatillos (ejes)


func _ready() -> void:
	# Acciones con botones
	_boton("seleccionar", JOY_BUTTON_A, [KEY_ENTER, KEY_SPACE])
	_boton("cancelar", JOY_BUTTON_B, [KEY_ESCAPE, KEY_BACKSPACE])
	_boton("abrir_unidades", JOY_BUTTON_X, [KEY_U])
	_boton("abrir_emergencias", JOY_BUTTON_Y, [KEY_E])
	_boton("pausa", JOY_BUTTON_START, [KEY_P])
	_boton("depuracion", JOY_BUTTON_BACK, [KEY_F1])
	_boton("categoria_anterior", JOY_BUTTON_LEFT_SHOULDER, [KEY_Q])
	_boton("categoria_siguiente", JOY_BUTTON_RIGHT_SHOULDER, [KEY_R])

	# Acciones con ejes (joystick izquierdo y gatillos)
	_eje("mover_izquierda", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_eje("mover_derecha", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_eje("mover_arriba", JOY_AXIS_LEFT_Y, -1.0, [KEY_W, KEY_UP])
	_eje("mover_abajo", JOY_AXIS_LEFT_Y, 1.0, [KEY_S, KEY_DOWN])
	_eje("zoom_mas", JOY_AXIS_TRIGGER_RIGHT, 1.0, [KEY_Z, KEY_PAGEUP])
	_eje("zoom_menos", JOY_AXIS_TRIGGER_LEFT, 1.0, [KEY_X, KEY_PAGEDOWN])


func _asegurar(accion: String, zona_muerta: float = 0.3) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion, zona_muerta)


func _boton(accion: String, boton: JoyButton, teclas: Array) -> void:
	_asegurar(accion)
	var e := InputEventJoypadButton.new()
	e.button_index = boton
	e.device = -1  # cualquier mando conectado
	InputMap.action_add_event(accion, e)
	_teclas(accion, teclas)


func _eje(accion: String, eje: JoyAxis, direccion: float, teclas: Array) -> void:
	_asegurar(accion)
	var e := InputEventJoypadMotion.new()
	e.axis = eje
	e.axis_value = direccion
	e.device = -1
	InputMap.action_add_event(accion, e)
	_teclas(accion, teclas)


func _teclas(accion: String, teclas: Array) -> void:
	for t in teclas:
		var k := InputEventKey.new()
		k.physical_keycode = t
		InputMap.action_add_event(accion, k)
