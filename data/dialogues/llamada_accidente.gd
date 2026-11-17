extends RefCounted
## LLAMADA DE PRUEBA: accidente de tráfico con un herido.
##
## Cómo funciona una conversación:
##   - "nodos": cada momento de la conversación.
##   - "texto": lo que dice el ciudadano.
##   - "opciones": lo que puede decir el operador.
##       "efectos": cambios al elegirla
##           calma (+/-), precision (1 zona, 2 calle, 3 punto exacto),
##           info (dato conseguido), marca (para el informe final)
##       "ir_a": siguiente nodo.
##   - "si_calma_menor": si el ciudadano está demasiado nervioso,
##       la conversación se desvía a otro nodo.
##   - "fin": true -> la conversación termina.
## Para crear llamadas nuevas basta con copiar este archivo y cambiar los textos.

const DATOS := {
	"id": "accidente_calle_mayor",
	"llamante": "Mujer, unos 45 años",
	"localidad": "Miguelturra",
	"calma_inicial": 30,
	"estados": ["En pánico", "Muy asustada", "Nerviosa", "Tranquila"],
	"inicio": "inicio",
	"incidente": {
		"titulo": "Accidente de tráfico con herido",
		"servicio": "ambulancia",
		"nodo_real": "D3",
		"pos_exacta": Vector2(1140, 900),
		"pos_calle": Vector2(980, 870),
		"radio_calle": 200.0,
		"pos_zona": Vector2(1000, 760),
		"radio_zona": 320.0,
	},
	"nodos": {
		"inicio": {
			"texto": "¡Por favor, necesito ayuda! Ha habido un accidente. Hay un coche parado en mitad de la calle y creo que hay una persona herida.",
			"opciones": [
				{"texto": "Tranquila, está hablando con emergencias. Voy a ayudarla. ¿Dónde se encuentra?", "efectos": {"calma": 15}, "ir_a": "donde"},
				{"texto": "Necesito que me explique exactamente qué ha ocurrido.", "efectos": {"calma": -5}, "ir_a": "que_paso"},
				{"texto": "¿Hay alguien atrapado dentro del vehículo?", "ir_a": "atrapado"},
			],
		},
		"donde": {
			"texto": "Vale... vale. Estoy en Miguelturra, en una calle del centro, pero no sé cómo se llama.",
			"efectos": {"precision": 1},
			"opciones": [
				{"texto": "¿Ve algún comercio o edificio cerca de usted?", "ir_a": "comercio"},
				{"texto": "¿Puede leer el nombre de la calle en alguna placa?", "ir_a": "placa"},
				{"texto": "¡Necesito la dirección exacta ya!", "efectos": {"calma": -20}, "ir_a": "brusco"},
			],
		},
		"que_paso": {
			"si_calma_menor": {"valor": 30, "ir_a": "panico"},
			"texto": "Un coche se ha subido a la acera y ha chocado contra una farola. El conductor no se mueve.",
			"efectos": {"info": "Coche contra una farola, conductor inmóvil"},
			"opciones": [
				{"texto": "Entendido, ya la estoy ayudando. ¿En qué localidad está?", "efectos": {"calma": 10}, "ir_a": "localidad"},
				{"texto": "¿El conductor respira?", "ir_a": "respira"},
			],
		},
		"panico": {
			"texto": "¡No lo sé! ¡Hay sangre! ¡No sé qué hacer, no sé qué hacer!",
			"opciones": [
				{"texto": "Respire hondo. La voy a ayudar, pero necesito que me escuche.", "efectos": {"calma": 25}, "ir_a": "que_paso_calmada"},
				{"texto": "¡Cálmese y responda a lo que le pregunto!", "efectos": {"calma": -10}, "ir_a": "panico_2"},
			],
		},
		"que_paso_calmada": {
			"texto": "Vale... perdone. Un coche se ha subido a la acera y ha chocado contra una farola. El conductor no se mueve.",
			"efectos": {"info": "Coche contra una farola, conductor inmóvil"},
			"opciones": [
				{"texto": "Lo está haciendo bien. ¿En qué localidad está?", "efectos": {"calma": 10}, "ir_a": "localidad"},
				{"texto": "¿El conductor respira?", "ir_a": "respira"},
			],
		},
		"panico_2": {
			"texto": "¡Le estoy diciendo que hay un herido! ¡Manden a alguien ya!",
			"opciones": [
				{"texto": "Lo siento. Estoy aquí con usted y vamos paso a paso. ¿En qué pueblo está?", "efectos": {"calma": 25}, "ir_a": "localidad"},
			],
		},
		"atrapado": {
			"texto": "No sé... la puerta está abollada, creo que no puede salir. ¡Está sangrando por la cabeza!",
			"efectos": {"info": "Posible persona atrapada con herida en la cabeza", "calma": -5},
			"opciones": [
				{"texto": "De acuerdo. No toque al herido. ¿Dónde se encuentra exactamente?", "efectos": {"calma": 10}, "ir_a": "donde"},
				{"texto": "¿El conductor respira?", "ir_a": "respira"},
			],
		},
		"respira": {
			"si_calma_menor": {"valor": 20, "ir_a": "panico"},
			"texto": "Sí... sí, veo que se le mueve el pecho. Pero tiene sangre en la cabeza.",
			"efectos": {"info": "El herido respira"},
			"opciones": [
				{"texto": "Bien, eso es muy importante. Lo está haciendo muy bien. ¿En qué localidad está?", "efectos": {"calma": 15}, "ir_a": "localidad"},
			],
		},
		"localidad": {
			"texto": "En Miguelturra. En el centro, creo.",
			"efectos": {"precision": 1},
			"opciones": [
				{"texto": "¿Ve algún comercio o edificio cerca de usted?", "ir_a": "comercio"},
				{"texto": "¿Puede leer el nombre de la calle en alguna placa?", "ir_a": "placa"},
			],
		},
		"comercio": {
			"texto": "Hay una farmacia justo enfrente... y un poco más allá, una panadería.",
			"efectos": {"precision": 2, "info": "Frente a una farmacia, cerca de una panadería"},
			"opciones": [
				{"texto": "¿Esa calle es la calle Mayor?", "ir_a": "confirmar_calle"},
				{"texto": "¿Puede acercarse a la esquina y leer la placa?", "ir_a": "placa"},
			],
		},
		"placa": {
			"si_calma_menor": {"valor": 45, "ir_a": "placa_nerviosa"},
			"texto": "Espere... Sí, pone «Calle Mayor». Estoy delante de la farmacia.",
			"efectos": {"precision": 3, "info": "Calle Mayor, frente a la farmacia"},
			"opciones": [
				{"texto": "Perfecto, ya sé dónde está.", "ir_a": "consejos"},
			],
		},
		"placa_nerviosa": {
			"texto": "¡No puedo dejar sola a esta persona! ¡Desde aquí no veo ninguna placa!",
			"efectos": {"calma": -5},
			"opciones": [
				{"texto": "Tiene razón, quédese con el herido. ¿Ve algún comercio cerca?", "efectos": {"calma": 10}, "ir_a": "comercio"},
			],
		},
		"confirmar_calle": {
			"texto": "¡Sí! Calle Mayor, eso es. Justo delante de la farmacia.",
			"efectos": {"precision": 3, "calma": 5, "info": "Calle Mayor, frente a la farmacia"},
			"opciones": [
				{"texto": "Perfecto, ya sé dónde está.", "ir_a": "consejos"},
			],
		},
		"brusco": {
			"texto": "¡Que no lo sé! ¡Ya le he dicho que no lo sé!",
			"opciones": [
				{"texto": "Perdone. Vamos con calma. ¿Ve algún comercio o edificio cerca?", "efectos": {"calma": 15}, "ir_a": "comercio"},
			],
		},
		"consejos": {
			"texto": "Vale... ¿Y ahora qué hago?",
			"opciones": [
				{"texto": "La ayuda va de camino. No mueva al herido y quédese a su lado hablándole.", "efectos": {"calma": 15}, "ir_a": "fin_bien"},
				{"texto": "Saque al herido del coche para que respire mejor.", "efectos": {"calma": -10, "marca": "mover_herido"}, "ir_a": "fin_mal"},
				{"texto": "Espere ahí.", "ir_a": "fin_neutro"},
			],
		},
		"fin_bien": {"texto": "De acuerdo... Gracias. Me quedo con él.", "fin": true},
		"fin_neutro": {"texto": "Vale... ¿Tardarán mucho?", "fin": true},
		"fin_mal": {"texto": "¿Sacarlo? ¡Pero si está sangrando! Bueno... lo intento...", "fin": true},
	},
}
