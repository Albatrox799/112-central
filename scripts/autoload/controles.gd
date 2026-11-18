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
	# Moverse por las listas de los menús (cruceta o joystick) y abrir la comisaría
	_asegurar("nav_abajo", ZONA_MUERTA_NAV)
	_asegurar("nav_arriba", ZONA_MUERTA_NAV)
	_asegurar("abrir_comisaria", ZONA_MUERTA_NAV)
	_teclas("nav_abajo", [KEY_DOWN])
	_teclas("nav_arriba", [KEY_UP])
	_teclas("abrir_comisaria", [KEY_C])
	aplicar_cruceta(CRUCETA_DEFECTO["arriba"], CRUCETA_DEFECTO["abajo"], CRUCETA_DEFECTO["izquierda"])

	# Acciones con ejes (joystick izquierdo y gatillos)
	_eje("mover_izquierda", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_eje("mover_derecha", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_eje("mover_arriba", JOY_AXIS_LEFT_Y, -1.0, [KEY_W, KEY_UP])
	_eje("mover_abajo", JOY_AXIS_LEFT_Y, 1.0, [KEY_S, KEY_DOWN])
	_eje("zoom_mas", JOY_AXIS_TRIGGER_RIGHT, 1.0, [KEY_Z, KEY_PAGEUP])
	_eje("zoom_menos", JOY_AXIS_TRIGGER_LEFT, 1.0, [KEY_X, KEY_PAGEDOWN])


# ------------------------------------------------------------------
# CONFIGURACIÓN DEL MANDO
# Cada mando/sistema puede numerar los botones de forma distinta
# (en algunos Fire TV la X del mando de PS4 no llega como "botón A").
# Por eso el juego pregunta qué botón es X y cuál es Círculo, y lo guarda.

const RUTA_CONFIG := "user://controles.cfg"


func cargar_configuracion() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_CONFIG) != OK:
		return false
	var sel: int = cfg.get_value("mando", "seleccionar", -1)
	var can: int = cfg.get_value("mando", "cancelar", -1)
	if sel < 0 or can < 0:
		return false
	boton_sel = sel
	boton_can = can
	aplicar_botones(sel, can)
	# La cruceta (versión 0.96). La configuración antigua de las versiones
	# anteriores se ignora: podía tener la misma flecha guardada dos veces.
	var arriba: Dictionary = cfg.get_value("mando", "cruceta_arriba", {})
	var abajo: Dictionary = cfg.get_value("mando", "cruceta_abajo", {})
	var izquierda: Dictionary = cfg.get_value("mando", "cruceta_izquierda", {})
	if not arriba.is_empty() and not abajo.is_empty() and not izquierda.is_empty():
		aplicar_cruceta(arriba, abajo, izquierda)
	return true


# ------------------------------------------------------------------
# CRUCETA
# Puede llegar como botón o como eje según el mando y el sistema.
# dato = {"tipo": "boton", "indice": 11} o {"tipo": "eje", "indice": 7, "valor": -1.0}

const ZONA_MUERTA_NAV := 0.6
const CRUCETA_DEFECTO := {
	"arriba": {"tipo": "boton", "indice": JOY_BUTTON_DPAD_UP},       # 11
	"abajo": {"tipo": "boton", "indice": JOY_BUTTON_DPAD_DOWN},      # 12
	"izquierda": {"tipo": "boton", "indice": JOY_BUTTON_DPAD_LEFT},  # 13
}
var boton_sel := -1
var boton_can := -1


func guardar_cruceta(arriba: Dictionary, abajo: Dictionary, izquierda: Dictionary) -> void:
	aplicar_cruceta(arriba, abajo, izquierda)
	var cfg := ConfigFile.new()
	cfg.load(RUTA_CONFIG)
	cfg.set_value("mando", "cruceta_arriba", arriba)
	cfg.set_value("mando", "cruceta_abajo", abajo)
	cfg.set_value("mando", "cruceta_izquierda", izquierda)
	cfg.save(RUTA_CONFIG)


## Vuelve a la cruceta normal (arriba 11, abajo 12, izquierda 13).
func restablecer_cruceta() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUTA_CONFIG)
	for k in ["cruceta_arriba", "cruceta_abajo", "cruceta_izquierda", "nav_arriba", "nav_abajo"]:
		if cfg.has_section_key("mando", k):
			cfg.erase_section_key("mando", k)
	cfg.save(RUTA_CONFIG)
	aplicar_cruceta(CRUCETA_DEFECTO["arriba"], CRUCETA_DEFECTO["abajo"], CRUCETA_DEFECTO["izquierda"])


## Borra lo que hubiera del mando en estas acciones y pone solo lo nuevo
## (así un mismo botón nunca puede ser dos flechas a la vez).
func aplicar_cruceta(arriba: Dictionary, abajo: Dictionary, izquierda: Dictionary) -> void:
	var pares := [["nav_arriba", arriba], ["ui_up", arriba], ["nav_abajo", abajo], ["ui_down", abajo], ["abrir_comisaria", izquierda]]
	for par in pares:
		var accion: String = par[0]
		if not InputMap.has_action(accion):
			continue
		InputMap.action_set_deadzone(accion, ZONA_MUERTA_NAV)
		for e in InputMap.action_get_events(accion):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(accion, e)
			elif e is InputEventKey and par[1].get("tipo", "") == "tecla" and e.keycode == int(par[1].get("indice", -1)):
				InputMap.action_erase_event(accion, e)
	for par in pares:
		var accion: String = par[0]
		if not InputMap.has_action(accion):
			continue
		InputMap.action_add_event(accion, _evento_de(par[1]))
	# El joystick izquierdo también sirve para subir y bajar (necesita un empujón claro)
	for par in [["nav_arriba", -1.0], ["ui_up", -1.0], ["nav_abajo", 1.0], ["ui_down", 1.0]]:
		if InputMap.has_action(par[0]):
			var m := InputEventJoypadMotion.new()
			m.axis = JOY_AXIS_LEFT_Y
			m.axis_value = par[1]
			m.device = -1
			InputMap.action_add_event(par[0], m)


func _evento_de(dato: Dictionary) -> InputEvent:
	if dato.get("tipo", "") == "tecla":
		var k := InputEventKey.new()
		k.keycode = int(dato["indice"])
		return k
	if dato.get("tipo", "") == "eje":
		var m := InputEventJoypadMotion.new()
		m.axis = int(dato["indice"])
		m.axis_value = float(dato["valor"])
		m.device = -1
		return m
	var b := InputEventJoypadButton.new()
	b.button_index = int(dato.get("indice", 0))
	b.device = -1
	return b


## Texto para enseñar al jugador qué llega al pulsar.
func describir(dato: Dictionary) -> String:
	match String(dato.get("tipo", "")):
		"tecla":
			return "tecla %s" % OS.get_keycode_string(int(dato["indice"]))
		"eje":
			return "eje %d (%s)" % [int(dato["indice"]), "+" if float(dato["valor"]) > 0.0 else "-"]
	return "botón %d" % int(dato.get("indice", -1))


func guardar_configuracion(sel: int, can: int) -> void:
	boton_sel = sel
	boton_can = can
	aplicar_botones(sel, can)
	var cfg := ConfigFile.new()
	cfg.load(RUTA_CONFIG)
	cfg.set_value("mando", "seleccionar", sel)
	cfg.set_value("mando", "cancelar", can)
	cfg.save(RUTA_CONFIG)


func aplicar_botones(sel: int, can: int) -> void:
	for accion in ["seleccionar", "ui_accept"]:
		_cambiar_boton(accion, sel)
	for accion in ["cancelar", "ui_cancel"]:
		_cambiar_boton(accion, can)


func _cambiar_boton(accion: String, boton: int) -> void:
	if not InputMap.has_action(accion):
		return
	for e in InputMap.action_get_events(accion):
		if e is InputEventJoypadButton:
			InputMap.action_erase_event(accion, e)
	var nuevo := InputEventJoypadButton.new()
	nuevo.button_index = boton
	nuevo.device = -1
	InputMap.action_add_event(accion, nuevo)


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
