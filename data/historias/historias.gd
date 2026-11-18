extends RefCounted
## HISTORIAS: llamadas que son el comienzo de algo más largo.
##
## - "desenlaces": lo que pasa DE VERDAD. Se elige en secreto al azar (según
##   su "peso") al empezar la llamada. El jugador lo va descubriendo.
## - "llamantes": perfiles de quien llama (nombres, edad, personalidad).
## - "nodos": la conversación. Además de lo normal admite:
##     "textos": [variantes]                 -> se elige una al azar
##     "texto_por_desenlace": {d: texto, "_": por defecto}
##     "efectos_por_desenlace": {d: efectos, "_": efectos}
##     "si_desenlace": {d: nodo}             -> desvío según lo que pasa de verdad
##     "sorpresa": {"prob": 0.5, "ir_a": nodo, "desenlaces": [..]} -> imprevisto
##   Efectos extra: "requiere" {servicio: n}, "urgencia", "confirmado", "marca"
## - "llamadas": llamadas relacionadas (otros vecinos, testigos...).
## - "eventos": lo que pasa DESPUÉS de colgar:
##     "cuando": "llegada" (llega una unidad de "servicio"), "tiempo" ("segundos"
##       desde que se creó el incidente) o "tras" (lo lanza una decisión)
##     "desenlaces": solo si lo que pasa de verdad es uno de estos
##     "radio" / "radio_por_desenlace": mensaje de la unidad o de la central
##     "efectos" / "efectos_por_desenlace": cambios en el incidente
##       (requiere, quitar, principal, categoria, traslado, duracion,
##        intensidad, confirmado, marca)
##     "llamada": clave de una llamada relacionada que entra
##     "decision": {"titulo", "opciones": [{"texto", "efectos", "siguiente"}]}
## - "finales": reglas en orden; se usa la primera que encaja
##     (desenlace, marca, sin_marca, empeorado, exito) -> texto, estrellas, exito_final

const HISTORIAS := [
	# ================================================================
	# 1. "MI MARIDO SE HA DESPLOMADO" (sanitaria)
	# ================================================================
	{
		"id": "desplome", "turno": "ambos", "tipo": "llamada",
		"referencias": ["iglesia", "plaza", "colegio", "supermercado", "parque", "sanidad"],
		"llamantes": [
			{"desc": "Mujer, unos 70 años", "calma": 35, "nombres": ["Carmen", "Pilar", "Rosario", "Juliana", "Antonia"],
				"personalidades": [["muy nerviosa", -15], ["nerviosa", -5], ["entera", 15], ["confusa", -10]]},
		],
		"estados": ["En pánico", "Muy asustada", "Nerviosa", "Tranquila"],
		"desenlaces": {
			"azucar": {"peso": 3}, "desmayo": {"peso": 3}, "ictus": {"peso": 2}, "infarto": {"peso": 2},
		},
		"incidente": {"titulo": "Persona desplomada en su casa", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 80.0, "intervencion": 10.0, "categoria": "medico", "requeridas": {"ambulancia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Mi marido se ha caído en el salón! ¡No reacciona bien, ayúdenme!",
					"¡Por favor! ¡Mi marido se ha desplomado de repente en la cocina!",
					"Es mi marido... estaba sentado y de pronto se ha ido al suelo. ¡No sé qué le pasa!"],
				"opciones": [
					{"texto": "Tranquila, le vamos a ayudar. ¿Respira?", "efectos": {"calma": 10}, "ir_a": "respira"},
					{"texto": "¿Está consciente? ¿Le habla?", "ir_a": "consciente"},
					{"texto": "¿Dónde viven?", "ir_a": "donde"}]},
			"respira": {"si_desenlace": {"infarto": "respira_mal"},
				"texto": "Sí, respira... pero está muy pálido y sudando.", "efectos": {"info": "Respira, pálido y sudoroso"},
				"opciones": [
					{"texto": "¿Le habla con normalidad?", "ir_a": "consciente"},
					{"texto": "¿Toma alguna medicación?", "ir_a": "medicacion"},
					{"texto": "¿Dónde viven?", "ir_a": "donde"}]},
			"respira_mal": {"texto": "Respira raro... como si le faltara el aire. ¡Se ha llevado la mano al pecho!",
				"efectos": {"info": "Dolor en el pecho, le falta el aire", "urgencia": 60.0},
				"opciones": [
					{"texto": "¿Toma alguna medicación?", "ir_a": "medicacion"},
					{"texto": "¿Dónde viven? Le mando la ambulancia ya.", "ir_a": "donde"}]},
			"consciente": {"si_desenlace": {"ictus": "consciente_ictus"},
				"texto_por_desenlace": {
					"azucar": "Me contesta, pero está confuso y temblando mucho...",
					"desmayo": "Ya abre los ojos... dice que se ha mareado.",
					"infarto": "Me habla poco... dice que le duele mucho el pecho.",
					"_": "Me habla, sí."},
				"efectos": {"info": "Está consciente"},
				"opciones": [
					{"texto": "¿Toma alguna medicación?", "ir_a": "medicacion"},
					{"texto": "¿Puede levantar los dos brazos?", "ir_a": "brazos"},
					{"texto": "¿Dónde viven?", "ir_a": "donde"}]},
			"consciente_ictus": {"texto": "Me habla... pero raro, se le traba la lengua. ¡Y tiene la boca torcida!",
				"efectos": {"info": "Habla con dificultad y tiene la boca torcida"},
				"opciones": [
					{"texto": "¿Puede levantar los dos brazos?", "ir_a": "brazos"},
					{"texto": "¿Dónde viven?", "ir_a": "donde"}]},
			"brazos": {"texto_por_desenlace": {"ictus": "¡El brazo derecho no lo puede levantar! ¡Se le cae!", "_": "Sí, los levanta los dos."},
				"efectos_por_desenlace": {"ictus": {"info": "No mueve el brazo derecho: posible ictus", "urgencia": 55.0, "traslado": true}, "_": {}},
				"opciones": [
					{"texto": "¿Toma alguna medicación?", "ir_a": "medicacion"},
					{"texto": "¿Dónde viven?", "ir_a": "donde"}]},
			"medicacion": {"texto_por_desenlace": {
					"azucar": "Es diabético, se pincha insulina... ¡y hoy no ha desayunado!",
					"infarto": "Toma pastillas para la tensión y para el corazón.",
					"_": "Solo unas pastillas para el colesterol."},
				"efectos_por_desenlace": {
					"azucar": {"info": "Diabético y sin comer: posible bajada de azúcar"},
					"infarto": {"info": "Tiene problemas de corazón"}, "_": {}},
				"opciones": [{"texto": "Entendido. ¿Dónde viven?", "ir_a": "donde"}]},
			"donde": {"texto": "En Miguelturra, en una casa cerca de {lugar}.", "efectos": {"precision": 2, "info": "Cerca de {lugar}"},
				"opciones": [{"texto": "¿En qué calle?", "ir_a": "calle"}]},
			"calle": {"texto": "En {calle}. Les dejo la puerta abierta.", "efectos": {"precision": 3, "info": "{calle}"},
				"opciones": [{"texto": "Muy bien, la ambulancia va para allá.", "ir_a": "consejos"}]},
			"consejos": {"sorpresa": {"prob": 0.85, "ir_a": "parada", "desenlaces": ["infarto"]},
				"texto": "¿Y qué hago mientras llegan?",
				"opciones": [
					{"texto": "Quédese a su lado, no le dé de comer ni de beber y avíseme si cambia algo.",
						"efectos_por_desenlace": {"azucar": {}, "_": {"marca": "consejo_bueno"}}, "ir_a": "fin_bien"},
					{"texto": "Si puede tragar, dele un zumo o algo con azúcar.",
						"efectos_por_desenlace": {"azucar": {"marca": "consejo_bueno"}, "desmayo": {}, "_": {"marca": "consejo_malo"}}, "ir_a": "fin_azucar"},
					{"texto": "Túmbelo con las piernas en alto.",
						"efectos_por_desenlace": {"desmayo": {"marca": "consejo_bueno"}, "_": {}}, "ir_a": "fin_bien"}]},
			"parada": {"texto": "¡Espere! ¡Ha dejado de respirar! ¡No se mueve! ¡Dios mío!",
				"efectos": {"calma": -20, "confirmado": "¡Parada cardiaca!", "urgencia": 40.0, "traslado": true, "marca": "parada"},
				"opciones": [
					{"texto": "Túmbelo boca arriba en el suelo y ponga las manos en el centro del pecho.", "efectos": {"calma": 10}, "ir_a": "rcp1"},
					{"texto": "Siéntelo y dele un poco de agua.", "efectos": {"calma": -10, "marca": "consejo_malo"}, "ir_a": "parada_mal"},
					{"texto": "Espere a que llegue la ambulancia.", "ir_a": "parada_espera"}]},
			"parada_mal": {"texto": "¡No puede beber! ¡No se mueve nada!",
				"opciones": [{"texto": "Túmbelo en el suelo y ponga las manos en el centro del pecho.", "ir_a": "rcp1"}]},
			"parada_espera": {"texto": "¿Esperar? ¡Pero si no respira!", "efectos": {"calma": -10},
				"opciones": [{"texto": "Tiene razón: túmbelo y ponga las manos en el centro del pecho.", "ir_a": "rcp1"}]},
			"rcp1": {"texto": "Ya está en el suelo... tengo las manos en su pecho.",
				"opciones": [{"texto": "Apriete fuerte y rápido, unas dos veces por segundo. Cuente conmigo: uno, dos, tres...", "efectos": {"marca": "rcp", "calma": 10}, "ir_a": "rcp2"}]},
			"rcp2": {"texto": "Uno, dos, tres, cuatro... ¡no paro, no paro!",
				"opciones": [{"texto": "Muy bien. Siga sin parar hasta que lleguen. Lo está haciendo genial.", "efectos": {"calma": 10, "marca": "consejo_bueno"}, "ir_a": "fin_rcp"}]},
			"fin_bien": {"texto": "Vale... me quedo con él.", "fin": true},
			"fin_azucar": {"texto_por_desenlace": {"azucar": "Se lo está bebiendo... ¡parece que reacciona!", "_": "Le cuesta tragar... no sé si le está sentando bien..."}, "fin": true},
			"fin_rcp": {"texto": "¡Ya oigo la sirena! ¡No paro!", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia",
				"radio_por_desenlace": {
					"azucar": "Glucosa muy baja. Le damos azúcar y se recupera.",
					"desmayo": "Ha sido una lipotimia. Constantes normales.",
					"ictus": "Sospecha de ictus. Activamos el código ictus.",
					"infarto": "Paciente en parada. Iniciamos reanimación."},
				"efectos_por_desenlace": {
					"azucar": {"confirmado": "Bajada de azúcar", "duracion": -4.0, "traslado": false},
					"desmayo": {"confirmado": "Desmayo leve", "duracion": -4.0, "traslado": false},
					"ictus": {"confirmado": "Ictus", "traslado": true},
					"infarto": {"confirmado": "Infarto con parada cardiaca", "traslado": true, "duracion": 6.0}}},
		],
		"finales": [
			{"desenlace": "infarto", "marca": "rcp", "sin_empeorar": true, "texto": "¡Recuperado gracias a la reanimación guiada por teléfono! Trasladado estable.", "estrellas": 1},
			{"desenlace": "infarto", "empeorado": true, "texto": "Llega al hospital en estado crítico.", "exito_final": false},
			{"desenlace": "infarto", "texto": "Reanimado por los sanitarios y trasladado en estado grave."},
			{"desenlace": "ictus", "empeorado": true, "texto": "Llega tarde al hospital: el ictus deja secuelas.", "exito_final": false},
			{"desenlace": "ictus", "texto": "Trasladado a tiempo con el código ictus activado."},
			{"desenlace": "azucar", "texto": "Bajada de azúcar resuelta en casa. No necesita ir al hospital."},
			{"desenlace": "desmayo", "texto": "Simple desmayo. Se recupera en casa."},
		],
	},
	# ================================================================
	# 2. "GRITOS EN EL PISO DE AL LADO" (policial con llamadas relacionadas)
	# ================================================================
	{
		"id": "gritos", "turno": "ambos", "tipo": "llamada",
		"referencias": ["iglesia", "plaza", "colegio", "parque", "supermercado", "bar"],
		"llamantes": [
			{"desc": "Hombre, unos 40 años (vecino)", "calma": 50, "nombres": ["Javier", "Raúl", "Antonio", "Sergio", "Manuel"],
				"personalidades": [["preocupado", 0], ["asustado", -15], ["tranquilo", 15]]},
			{"desc": "Mujer, unos 55 años (vecina)", "calma": 45, "nombres": ["Mari Carmen", "Isabel", "Lola", "Encarna"],
				"personalidades": [["preocupada", 0], ["muy asustada", -15], ["cotilla", 10]]},
		],
		"estados": ["En pánico", "Muy asustado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {
			"discusion": {"peso": 3}, "pelea": {"peso": 2, "peso_noche": 3}, "caida": {"peso": 2},
			"fiesta": {"peso": 1, "peso_noche": 3}, "tele": {"peso": 1},
		},
		"incidente": {"titulo": "Gritos y golpes en una vivienda", "servicios": ["policia"], "principal": "policia",
			"urgencia": 75.0, "intervencion": 8.0, "categoria": "robo", "requeridas": {"policia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["Llamo porque en el piso de enfrente se oyen gritos y golpes desde hace un rato.",
					"Perdone que moleste... en la casa de al lado hay muchos gritos y me estoy asustando.",
					"Buenas. Se oyen golpes y voces en el piso de mis vecinos, no sé si pasa algo."],
				"opciones": [
					{"texto": "¿Qué tipo de gritos? ¿Una discusión o alguien pidiendo ayuda?", "ir_a": "tipo"},
					{"texto": "¿Cuántas voces oye?", "ir_a": "voces"},
					{"texto": "¿Dónde vive usted?", "ir_a": "donde"}]},
			"tipo": {"texto_por_desenlace": {
					"discusion": "Parece una discusión... un hombre y una mujer gritándose.",
					"pelea": "Parece que se pegan... se oyen golpes contra la pared.",
					"caida": "Es una voz mayor... como si pidiera ayuda. «¡Socorro!», creo.",
					"fiesta": "Bueno, hay gritos... pero también música y risas.",
					"tele": "Son gritos... aunque suenan un poco raros, siempre iguales."},
				"efectos_por_desenlace": {
					"discusion": {"info": "Parece una discusión de pareja"}, "pelea": {"info": "Posible pelea con golpes"},
					"caida": {"info": "Una voz mayor pide ayuda"}, "fiesta": {"info": "Hay música y risas"}, "tele": {"info": "Los gritos suenan siempre igual"}},
				"opciones": [
					{"texto": "¿Cuántas voces oye?", "ir_a": "voces"},
					{"texto": "¿Sabe quién vive en ese piso?", "ir_a": "quien"},
					{"texto": "¿Dónde vive usted?", "ir_a": "donde"}]},
			"voces": {"texto_por_desenlace": {
					"discusion": "Dos, un hombre y una mujer.", "pelea": "Varias... al menos tres hombres.",
					"caida": "Solo una... la de una señora mayor, creo.", "fiesta": "¡Muchísimas! Mucha gente.",
					"tele": "No sabría decirle... suenan como de lejos."},
				"opciones": [
					{"texto": "¿Sabe quién vive en ese piso?", "ir_a": "quien"},
					{"texto": "¿Dónde vive usted?", "ir_a": "donde"}]},
			"quien": {"texto_por_desenlace": {
					"caida": "Doña Pilar, una señora de 85 años. Vive sola.",
					"tele": "Un señor muy mayor, oye fatal el pobre.",
					"_": "No los conozco mucho... una pareja joven, creo."},
				"efectos_por_desenlace": {"caida": {"info": "Vive una señora mayor sola"}, "tele": {"info": "Vive un señor mayor que oye mal"}, "_": {"info": "Vive una pareja joven"}},
				"opciones": [{"texto": "¿Dónde vive usted?", "ir_a": "donde"}]},
			"donde": {"texto": "En Miguelturra, en un bloque cerca de {lugar}.", "efectos": {"precision": 2, "info": "Bloque cerca de {lugar}"},
				"opciones": [{"texto": "¿En qué calle?", "ir_a": "calle"}]},
			"calle": {"texto": "En {calle}, el portal de la esquina, segundo piso.", "efectos": {"precision": 3, "info": "{calle}, segundo piso"},
				"opciones": [{"texto": "Una patrulla va hacia allí.", "ir_a": "consejos"}]},
			"consejos": {"sorpresa": {"prob": 0.6, "ir_a": "golpe"},
				"texto": "¿Y yo qué hago?",
				"opciones": [
					{"texto": "Quédese en casa y no salga al rellano. La policía está llegando.", "efectos": {"marca": "consejo_bueno"}, "ir_a": "fin"},
					{"texto": "Vaya a llamar a su puerta a ver qué pasa.", "efectos": {"marca": "consejo_malo", "calma": -10}, "ir_a": "fin_mal"},
					{"texto": "Si vuelve a oír algo, llámenos.", "ir_a": "fin"}]},
			"golpe": {"texto_por_desenlace": {
					"fiesta": "¡Ahora se han puesto a cantar todos a la vez!",
					"tele": "¡Espere! Ahora se oyen disparos... bueno... creo que es una película.",
					"_": "¡Espere! ¡Se ha oído un golpe muy fuerte... y ahora no se oye nada!"},
				"efectos": {"calma": -10},
				"efectos_por_desenlace": {"caida": {"info": "Un golpe fuerte y después silencio", "urgencia": 60.0},
					"pelea": {"info": "Un golpe fuerte y después silencio"}, "_": {}},
				"opciones": [
					{"texto": "Mantenga la calma. No salga de casa. La policía está llegando.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Vaya a llamar a su puerta a ver qué pasa.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, gracias. Me quedo aquí.", "fin": true},
			"fin_mal": {"texto": "¿Yo? Bueno... voy a ver...", "fin": true},
		},
		"llamadas": {
			"vecina": {"llamante": "Mujer, unos 65 años (vecina de abajo)", "calma": 55, "inicio": "inicio",
				"estados": ["En pánico", "Muy asustada", "Nerviosa", "Tranquila"],
				"nodos": {
					"inicio": {"texto_por_desenlace": {
							"caida": "Llamo por lo de arriba... ¡es doña Pilar! No la he visto en todo el día y no coge el teléfono.",
							"discusion": "Llamo por los del segundo... discuten mucho, pero nunca ha pasado nada.",
							"pelea": "¡He visto a tres hombres subir corriendo por la escalera hace un rato!",
							"fiesta": "Es que todos los fines de semana igual, ¡con la música no hay quien duerma!",
							"tele": "Yo no he oído nada raro... será la tele del señor del segundo."},
						"efectos_por_desenlace": {
							"caida": {"confirmado": "Vive una señora mayor sola que no contesta"},
							"discusion": {"info": "Una vecina dice que discuten a menudo"},
							"pelea": {"confirmado": "Tres hombres subieron corriendo"},
							"fiesta": {"info": "Una vecina habla de fiestas frecuentes"},
							"tele": {"info": "Una vecina cree que es la tele (sin confirmar)"}},
						"opciones": [
							{"texto": "Gracias. ¿Sabe algo más?", "ir_a": "mas"},
							{"texto": "Gracias, la policía ya va para allá.", "ir_a": "fin"}]},
					"mas": {"texto_por_desenlace": {
							"caida": "Tengo una llave de su casa... ¡pero me da miedo subir sola!",
							"pelea": "Uno llevaba una capucha... no les vi la cara.",
							"_": "No, nada más, perdone."},
						"efectos_por_desenlace": {"caida": {"info": "La vecina tiene una llave"}, "_": {}},
						"opciones": [{"texto": "No suba. Los agentes se encargan.", "ir_a": "fin"}]},
					"fin": {"texto": "De acuerdo, gracias.", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_vecina", "cuando": "tiempo", "segundos": 30.0, "llamada": "vecina"},
			{"id": "llega_ruido", "cuando": "llegada", "servicio": "policia", "desenlaces": ["fiesta", "tele"],
				"radio_por_desenlace": {"fiesta": "Es una fiesta con la música altísima. Les pedimos que la bajen.",
					"tele": "Un señor mayor con la tele a todo volumen. Todo en orden."},
				"efectos": {"categoria": "control", "duracion": -3.0}},
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia", "desenlaces": ["discusion", "pelea", "caida"],
				"radio": "Estamos en la puerta. Nadie abre, pero se oye algo dentro.",
				"decision": {"titulo": "Nadie abre la puerta", "opciones": [
					{"texto": "Esperar y seguir llamando", "siguiente": "esperar"},
					{"texto": "Preguntar a los vecinos", "siguiente": "vecinos"},
					{"texto": "Pedir a los bomberos que abran la puerta", "efectos": {"requiere": {"bomberos": 1}, "marca": "puerta"}, "siguiente": "puerta"}]}},
			{"id": "esperar", "cuando": "tras",
				"radio_por_desenlace": {
					"discusion": "Por fin abre la pareja. Se han calmado. Hablamos con ellos.",
					"pelea": "¡Abren de golpe y salen corriendo dos hombres! Hay un herido dentro.",
					"caida": "Seguimos sin respuesta... se oyen quejidos muy débiles. Hay que entrar: pedimos bomberos y ambulancia."},
				"efectos_por_desenlace": {
					"discusion": {"categoria": "pelea", "confirmado": "Discusión de pareja"},
					"pelea": {"categoria": "pelea", "requiere": {"ambulancia": 1}, "confirmado": "Pelea con un herido"},
					"caida": {"categoria": "medico", "requiere": {"bomberos": 1, "ambulancia": 1}, "principal": "ambulancia",
						"traslado": true, "marca": "espera_larga", "confirmado": "Persona mayor caída dentro"}}},
			{"id": "vecinos", "cuando": "tras",
				"radio_por_desenlace": {
					"discusion": "Los vecinos dicen que discuten a menudo. Al final abren y se calman.",
					"pelea": "Un vecino vio entrar a varios hombres. Abren a la fuerza: hay un herido.",
					"caida": "La vecina dice que vive una señora mayor sola y tiene llave. ¡Entramos! Necesitamos una ambulancia."},
				"efectos_por_desenlace": {
					"discusion": {"categoria": "pelea", "confirmado": "Discusión de pareja"},
					"pelea": {"categoria": "pelea", "requiere": {"ambulancia": 1}, "confirmado": "Pelea con un herido"},
					"caida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "traslado": true,
						"confirmado": "Señora mayor caída en el pasillo"}}},
			{"id": "puerta", "cuando": "tras",
				"radio_por_desenlace": {
					"discusion": "Antes de que lleguen los bomberos, la pareja abre. Era una discusión.",
					"pelea": "Mientras esperamos a los bomberos, abren de golpe: ¡hay un herido!",
					"caida": "Esperamos a los bomberos para abrir. Se oye a una señora pedir ayuda. Pedimos también ambulancia."},
				"efectos_por_desenlace": {
					"discusion": {"categoria": "pelea", "quitar": "bomberos", "confirmado": "Discusión de pareja"},
					"pelea": {"categoria": "pelea", "quitar": "bomberos", "requiere": {"ambulancia": 1}, "confirmado": "Pelea con un herido"},
					"caida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "traslado": true,
						"confirmado": "Persona mayor caída dentro"}}},
		],
		"finales": [
			{"desenlace": "caida", "marca": "espera_larga", "texto": "Doña Pilar rescatada, pero tras mucho tiempo en el suelo: trasladada en estado grave.", "estrellas": -1},
			{"desenlace": "caida", "empeorado": true, "texto": "Rescatada tarde: la señora ingresa en estado grave.", "exito_final": false},
			{"desenlace": "caida", "texto": "Doña Pilar estaba caída en el pasillo. Rescatada a tiempo y trasladada al hospital.", "estrellas": 1},
			{"desenlace": "pelea", "exito": false, "texto": "Los agresores han huido. El herido ha sido atendido."},
			{"desenlace": "pelea", "texto": "Un detenido y un herido atendido."},
			{"desenlace": "discusion", "texto": "Discusión de pareja sin violencia. Los agentes han mediado."},
			{"desenlace": "fiesta", "texto": "Fiesta denunciada por ruido. Música apagada."},
			{"desenlace": "tele", "texto": "Falsa alarma: era la televisión de un vecino mayor."},
		],
	},
	# ================================================================
	# 3. "HAY HUMO EN MI EDIFICIO" (incendio que evoluciona tras colgar)
	# ================================================================
	{
		"id": "humo", "turno": "ambos", "tipo": "incendio",
		"referencias": ["colegio", "parque", "supermercado", "plaza", "deporte", "iglesia"],
		"llamantes": [
			{"desc": "Hombre, unos 30 años (vecino del primero)", "calma": 40, "nombres": ["Álvaro", "David", "Jesús", "Pablo"],
				"personalidades": [["nervioso", -10], ["muy alterado", -20], ["sereno", 15]]},
			{"desc": "Mujer, unos 45 años (vecina del primero)", "calma": 40, "nombres": ["Laura", "Silvia", "Montse", "Eva"],
				"personalidades": [["nerviosa", -10], ["muy alterada", -20], ["serena", 15]]},
		],
		"estados": ["En pánico", "Muy asustado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {
			"basura": {"peso": 3}, "cocina": {"peso": 3}, "garaje": {"peso": 2}, "barbacoa": {"peso": 1},
		},
		"incidente": {"titulo": "Humo en un bloque de pisos", "servicios": ["bomberos"], "principal": "bomberos",
			"urgencia": 70.0, "intervencion": 12.0, "categoria": "fuego", "requeridas": {"bomberos": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Hay humo en la escalera de mi edificio! ¡Huele muchísimo a quemado!",
					"Buenas... estoy en mi casa y está entrando humo por debajo de la puerta.",
					"¡Oiga, que sale humo de mi bloque! ¡Vengan rápido!"],
				"opciones": [
					{"texto": "¿De dónde sale el humo?", "ir_a": "origen"},
					{"texto": "¿Hay gente en el edificio?", "ir_a": "gente"},
					{"texto": "¿Dónde está el edificio?", "ir_a": "donde"}]},
			"origen": {"texto_por_desenlace": {
					"basura": "Parece que del portal... de abajo del todo.",
					"cocina": "Del tercero, creo... ¡se ven llamas por una ventana!",
					"garaje": "De abajo, del garaje... sale humo negro por la rampa.",
					"barbacoa": "Pues... del patio de atrás, creo. Huele a carne, ¿eh?"},
				"efectos_por_desenlace": {
					"basura": {"info": "El humo sale del portal"}, "cocina": {"info": "Llamas en una ventana del tercero"},
					"garaje": {"info": "Humo negro saliendo del garaje", "urgencia": 55.0}, "barbacoa": {"info": "El humo viene del patio y huele a carne"}},
				"opciones": [
					{"texto": "¿Hay gente en el edificio?", "ir_a": "gente"},
					{"texto": "¿Dónde está el edificio?", "ir_a": "donde"}]},
			"gente": {"texto": "Es un bloque de cuatro pisos. A esta hora hay vecinos en casa.", "efectos": {"info": "Bloque de cuatro pisos con vecinos"},
				"opciones": [{"texto": "¿Dónde está el edificio?", "ir_a": "donde"}]},
			"donde": {"texto": "En Miguelturra, al lado de {lugar}.", "efectos": {"precision": 2, "info": "Junto a {lugar}"},
				"opciones": [{"texto": "¿En qué calle?", "ir_a": "calle"}]},
			"calle": {"texto": "En {calle}. ¡Dense prisa!", "efectos": {"precision": 3, "info": "{calle}"},
				"opciones": [{"texto": "Los bomberos van para allá.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Qué hago? ¿Salgo?",
				"opciones": [
					{"texto": "Si la escalera no tiene humo, baje a la calle. No coja el ascensor.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin_bien"},
					{"texto": "Coja sus cosas de valor y luego salga.", "efectos": {"marca": "consejo_malo", "calma": -10}, "ir_a": "fin_mal"},
					{"texto": "Quédese en casa con la puerta cerrada.", "efectos_por_desenlace": {"garaje": {"marca": "consejo_bueno"}, "_": {}}, "ir_a": "fin_casa"}]},
			"fin_bien": {"texto": "Vale, ya estoy bajando. Gracias.", "fin": true},
			"fin_mal": {"texto": "Vale, cojo el bolso y salgo...", "fin": true},
			"fin_casa": {"texto": "De acuerdo, cierro y espero.", "fin": true},
		},
		"llamadas": {
			"atrapado": {"llamante": "Hombre, unos 70 años (vecino del cuarto)", "calma": 20, "inicio": "inicio",
				"estados": ["En pánico", "Muy asustado", "Nervioso", "Tranquilo"],
				"nodos": {
					"inicio": {"texto": "¡Estoy en el cuarto y no puedo bajar! ¡La escalera está llena de humo!",
						"efectos": {"confirmado": "Vecino atrapado en el cuarto piso", "requiere": {"ambulancia": 1}},
						"opciones": [
							{"texto": "Cierre la puerta, ponga toallas mojadas en las rendijas y vaya a una ventana.", "efectos": {"marca": "atrapado_bien", "calma": 20}, "ir_a": "ventana"},
							{"texto": "Baje corriendo por la escalera, rápido.", "efectos": {"marca": "atrapado_mal"}, "ir_a": "fin_mal"}]},
					"ventana": {"texto": "Vale... ya estoy en la ventana, ¡se ve a la gente abajo!",
						"opciones": [{"texto": "Muy bien. Haga señas a los bomberos y no salga. Ya llegan.", "efectos": {"calma": 10}, "ir_a": "fin"}]},
					"fin": {"texto": "Vale... aquí espero.", "fin": true},
					"fin_mal": {"texto": "Vale... voy... ¡cof, cof!", "fin": true},
				}},
			"todos_fuera": {"llamante": "Mujer, unos 35 años (vecina)", "calma": 60, "inicio": "inicio",
				"estados": ["En pánico", "Asustada", "Nerviosa", "Tranquila"],
				"nodos": {
					"inicio": {"texto": "Llamo por el humo del bloque... yo ya estoy en la calle. ¡Creo que ya ha salido todo el mundo!",
						"efectos_por_desenlace": {
							"basura": {"confirmado": "Todos los vecinos están fuera"},
							"barbacoa": {"confirmado": "Todos los vecinos están fuera"},
							"_": {"info": "Una vecina cree que han salido todos (sin confirmar)"}},
						"opciones": [{"texto": "Gracias. Aléjense del edificio y dejen paso a los bomberos.", "ir_a": "fin"}]},
					"fin": {"texto": "Vale, nos apartamos.", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_atrapado", "cuando": "tiempo", "segundos": 18.0, "desenlaces": ["cocina", "garaje"], "llamada": "atrapado"},
			{"id": "llamada_todos_fuera", "cuando": "tiempo", "segundos": 35.0, "llamada": "todos_fuera"},
			{"id": "llega_bomberos", "cuando": "llegada", "servicio": "bomberos",
				"radio_por_desenlace": {
					"basura": "Era un cubo de basura ardiendo en el portal. Lo apagamos enseguida.",
					"cocina": "Fuego en una cocina del tercero. Atacamos el fuego.",
					"garaje": "Incendio en el garaje y mucho humo en la escalera. ¡Esto es serio!",
					"barbacoa": "Falsa alarma: una barbacoa en un patio interior. Todo en orden."},
				"efectos_por_desenlace": {
					"basura": {"confirmado": "Cubo de basura ardiendo", "duracion": -6.0},
					"cocina": {"confirmado": "Incendio en una cocina", "requiere": {"ambulancia": 1}},
					"garaje": {"confirmado": "Incendio en el garaje", "intensidad": 2, "requiere": {"ambulancia": 1}},
					"barbacoa": {"confirmado": "Barbacoa en un patio", "categoria": "control", "duracion": -8.0}}},
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio": "Cortamos la calle al tráfico y alejamos a los curiosos."},
		],
		"finales": [
			{"desenlace": "barbacoa", "texto": "Falsa alarma: era una barbacoa en un patio."},
			{"desenlace": "basura", "texto": "Cubo de basura apagado en el portal. Sin daños."},
			{"marca": "atrapado_mal", "texto": "El vecino del cuarto bajó por la escalera y respiró mucho humo: trasladado grave.", "estrellas": -1},
			{"desenlace": "garaje", "empeorado": true, "texto": "El fuego del garaje subió por el edificio: daños graves.", "exito_final": false},
			{"marca": "atrapado_bien", "texto": "Vecino rescatado por la ventana. ¡Gran coordinación!", "estrellas": 1},
			{"desenlace": "cocina", "texto": "Incendio de cocina extinguido. Vecinos atendidos por el humo."},
			{"desenlace": "garaje", "texto": "Incendio del garaje controlado. Edificio desalojado a tiempo."},
		],
	},
]
