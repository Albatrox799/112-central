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
			{"desenlace": "infarto", "empeorado": true, "sin_marca": "rcp", "fallecido": true, "texto": "Sin reanimación a tiempo, no ha podido superar la parada cardiaca.", "exito_final": false},
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
					"mas": {"si_desenlace": {"caida": "llave"},
						"texto_por_desenlace": {
							"pelea": "Uno llevaba una capucha... no les vi la cara.",
							"_": "No, nada más, perdone."},
						"opciones": [{"texto": "No suba. Los agentes se encargan.", "ir_a": "fin"}]},
					"llave": {"texto": "Tengo una llave de su casa... ¡pero me da miedo subir sola!",
						"efectos": {"info": "La vecina de abajo tiene una llave"},
						"opciones": [
							{"texto": "No suba sola. Baje al portal y dele la llave a los agentes en cuanto lleguen.", "efectos": {"marca": "llave_vecina", "calma": 10, "confirmado": "La vecina baja la llave a los agentes"}, "ir_a": "fin_llave"},
							{"texto": "No haga nada. Los agentes se encargan.", "ir_a": "fin"}]},
					"fin_llave": {"texto": "Vale, ahora mismo bajo al portal con la llave.", "fin": true},
					"fin": {"texto": "De acuerdo, gracias.", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_vecina", "cuando": "tiempo", "segundos": 30.0, "llamada": "vecina"},
			{"id": "llega_ruido", "cuando": "llegada", "servicio": "policia", "desenlaces": ["fiesta", "tele"],
				"radio_por_desenlace": {"fiesta": "Es una fiesta con la música altísima. Les pedimos que la bajen.",
					"tele": "Un señor mayor con la tele a todo volumen. Todo en orden."},
				"efectos": {"categoria": "control", "duracion": -3.0}},
			{"id": "llega_con_llave", "cuando": "llegada", "servicio": "policia", "desenlaces": ["caida"], "si_marca": "llave_vecina",
				"radio": "La vecina de abajo nos espera en el portal con la llave. ¡Abrimos!", "siguiente": "vecinos"},
			{"id": "llave_esperando", "cuando": "marca", "desenlaces": ["caida"], "si_marca": "llave_vecina",
				"solo_si_decision": true, "resuelve_decision": true, "excluye": ["llega_con_llave"],
				"radio": "La vecina acaba de bajar con la llave. ¡Abrimos la puerta!", "siguiente": "vecinos"},
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia", "desenlaces": ["discusion", "pelea", "caida"], "sin_marca": "llave_vecina",
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
	# ================================================================
	# 4. "ACCIDENTE CON VARIOS HERIDOS" (tráfico, varios servicios)
	# ================================================================
	{
		"id": "accidente_multiple", "turno": "ambos", "tipo": "llamada",
		"referencias": ["gasolinera", "supermercado", "plaza", "deporte", "colegio", "comercio"],
		"llamantes": [
			{"desc": "Hombre, unos 50 años (testigo)", "calma": 40, "nombres": ["Ramón", "Francisco", "Julián", "Ángel", "Paco"],
				"personalidades": [["nervioso", -10], ["muy alterado", -20], ["sereno", 15]]},
			{"desc": "Mujer, unos 25 años (testigo)", "calma": 35, "nombres": ["Lucía", "Marta", "Andrea", "Paula", "Noelia"],
				"personalidades": [["asustada", -10], ["en shock", -20], ["decidida", 15]]},
		],
		"estados": ["En pánico", "Muy alterado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {
			"leve": {"peso": 3}, "grave": {"peso": 2}, "moto": {"peso": 2}, "humo": {"peso": 1},
		},
		"incidente": {"titulo": "Accidente de tráfico con varios heridos", "servicios": ["ambulancia", "policia"], "principal": "ambulancia",
			"urgencia": 80.0, "intervencion": 12.0, "categoria": "medico", "requeridas": {"ambulancia": 1, "policia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Ha habido un accidente muy fuerte! ¡Dos coches han chocado delante de mí!",
					"¡Acabo de ver un choque horrible! ¡Hay gente herida, vengan rápido!",
					"Llamo por un accidente... un coche se ha saltado el ceda y se ha empotrado contra otro."],
				"opciones": [
					{"texto": "¿Hay heridos? ¿Cuántos?", "ir_a": "heridos"},
					{"texto": "¿Está usted bien? ¿Está en un sitio seguro?", "efectos": {"calma": 10}, "ir_a": "seguro"},
					{"texto": "¿Dónde ha sido exactamente?", "ir_a": "donde"}]},
			"seguro": {"texto": "Sí, sí, estoy en la acera. Yo no iba en los coches.",
				"opciones": [
					{"texto": "Bien. ¿Hay heridos? ¿Cuántos?", "ir_a": "heridos"},
					{"texto": "¿Dónde ha sido exactamente?", "ir_a": "donde"}]},
			"heridos": {"texto_por_desenlace": {
					"leve": "Dos personas... están de pie, pero sangran un poco por la cara.",
					"grave": "¡Tres! Y hay un chico que no puede salir del coche, ¡está atrapado!",
					"moto": "¡Es un motorista! Está tirado en el suelo y casi no se mueve.",
					"humo": "Los conductores han salido... pero uno de los coches está echando humo."},
				"efectos_por_desenlace": {
					"leve": {"info": "Dos heridos leves", "heridos": 2},
					"grave": {"info": "Tres heridos, uno atrapado en el coche", "requiere": {"ambulancia": 2, "bomberos": 1}, "categoria": "atrapado", "traslado": true, "urgencia": 60.0, "heridos": 3},
					"moto": {"info": "Motorista herido en el suelo", "traslado": true},
					"humo": {"info": "Un coche echa humo", "requiere": {"bomberos": 1}}},
				"opciones": [
					{"texto": "¿Están conscientes?", "ir_a": "conscientes"},
					{"texto": "¿Dónde ha sido exactamente?", "ir_a": "donde"}]},
			"conscientes": {"texto_por_desenlace": {
					"moto": "Se queja mucho... y está intentando quitarse el casco.",
					"grave": "El chico atrapado está despierto, pero dice que no siente bien las piernas.",
					"_": "Sí, todos hablan y se mueven."},
				"efectos_por_desenlace": {"grave": {"info": "El atrapado no siente bien las piernas"}, "moto": {"info": "El motorista está consciente"}, "_": {"info": "Todos están conscientes"}},
				"opciones": [{"texto": "¿Dónde ha sido exactamente?", "ir_a": "donde"}]},
			"donde": {"texto": "En Miguelturra, en la carretera, a la altura de {lugar}.", "efectos": {"precision": 2, "info": "A la altura de {lugar}"},
				"opciones": [{"texto": "¿En qué calle exactamente?", "ir_a": "calle"}]},
			"calle": {"texto": "En {calle}. Se está formando un atasco tremendo.", "efectos": {"precision": 3, "info": "{calle}"},
				"opciones": [{"texto": "Ambulancia y policía van para allá.", "ir_a": "consejos"}]},
			"consejos": {"si_desenlace": {"moto": "casco"},
				"sorpresa": {"prob": 0.55, "ir_a": "humo_sorpresa", "desenlaces": ["humo", "grave"]},
				"texto": "¿Y qué hago? ¿Saco a la gente de los coches?",
				"opciones": [
					{"texto": "No mueva a los heridos. Encienda las luces de emergencia, apártese de la carretera y avíseme si cambia algo.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Sí, sáquelos de los coches cuanto antes.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"},
					{"texto": "Quédese mirando y avíseme si cambia algo.", "ir_a": "fin"}]},
			"casco": {"texto": "¡Se quiere quitar el casco porque dice que se ahoga! ¿Se lo quito yo?",
				"opciones": [
					{"texto": "¡No! No le quite el casco ni le mueva el cuello. Háblele para que esté tranquilo.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "efectos_por_desenlace": {"moto": {"marca": "casco_bien"}, "_": {}}, "ir_a": "fin"},
					{"texto": "Sí, quíteselo con cuidado para que respire mejor.", "efectos": {"marca": "consejo_malo"}, "efectos_por_desenlace": {"moto": {"marca": "casco_mal"}, "_": {}}, "ir_a": "fin_mal"}]},
			"humo_sorpresa": {"texto_por_desenlace": {
					"humo": "¡Espere! ¡Ahora sale muchísimo humo del capó! ¡Huele a gasolina!",
					"_": "¡Uno de los coches empieza a echar humo! ¡Y el chico sigue dentro!"},
				"efectos": {"calma": -10, "requiere": {"bomberos": 1}, "urgencia": 50.0},
				"efectos_por_desenlace": {"humo": {"confirmado": "Humo y olor a gasolina en un coche"}, "_": {"confirmado": "Humo en el coche del atrapado"}},
				"opciones": [
					{"texto": "Aléjese del coche y aparte a la gente. Los bomberos van para allá.", "efectos": {"marca": "consejo_bueno"}, "ir_a": "fin"},
					{"texto": "Intente apagarlo echándole agua.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, me aparto y espero. ¡Ya se oyen las sirenas!", "fin": true},
			"fin_mal": {"texto": "Vale... voy a ver si puedo...", "fin": true},
		},
		"llamadas": {
			"atasco": {"llamante": "Hombre, unos 45 años (conductor en el atasco)", "calma": 60, "inicio": "inicio",
				"estados": ["En pánico", "Enfadado", "Impaciente", "Tranquilo"],
				"nodos": {
					"inicio": {"texto_por_desenlace": {
							"humo": "Estoy en el atasco del accidente... ¡desde aquí se ve humo negro! La gente se acerca a mirar.",
							"grave": "Estoy atrapado en el atasco... ¡se ve humo en uno de los coches y la gente está nerviosa!",
							"_": "Estoy en el atasco del accidente. Llevo diez minutos parado, ¿tardarán mucho?"},
						"efectos_por_desenlace": {"humo": {"confirmado": "Humo visible desde el atasco"}, "grave": {"info": "Se ve humo desde el atasco"}, "_": {"info": "Atasco largo en la zona"}},
						"opciones": [{"texto": "Gracias. No se baje del coche y deje paso a las sirenas.", "ir_a": "fin"}]},
					"fin": {"texto": "Vale, vale, me aparto.", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_atasco", "cuando": "tiempo", "segundos": 25.0, "llamada": "atasco"},
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio": "Cortamos el tráfico en los dos sentidos y señalizamos el accidente."},
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia", "desenlaces": ["leve", "moto", "humo"],
				"radio_por_desenlace": {
					"leve": "Dos heridos leves con cortes. Los curamos aquí mismo.",
					"moto": "Motorista con posible lesión de cuello. Lo inmovilizamos.",
					"humo": "Los conductores están bien, solo un poco mareados por el susto."},
				"efectos_por_desenlace": {
					"leve": {"confirmado": "Dos heridos leves", "duracion": -3.0, "heridos": 2},
					"moto": {"confirmado": "Motorista con lesión de cuello", "traslado": true},
					"humo": {"confirmado": "Conductores ilesos", "duracion": -4.0}}},
			{"id": "llega_ambulancia_grave", "cuando": "llegada", "servicio": "ambulancia", "desenlaces": ["grave"],
				"radio": "Tres heridos: uno atrapado y grave, y dos leves. Con una sola ambulancia vamos justos.",
				"efectos": {"confirmado": "Tres heridos, uno atrapado", "traslado": true, "categoria": "atrapado", "requiere": {"bomberos": 1}, "heridos": 3},
				"decision": {"titulo": "Tres heridos y poca ayuda", "opciones": [
					{"texto": "Pedir una segunda ambulancia", "efectos": {"requiere": {"ambulancia": 2}, "marca": "segunda"}},
					{"texto": "Atender primero al grave; los leves esperan", "efectos": {"marca": "esperan_leves", "duracion": 6.0}}]}},
			{"id": "llega_bomberos", "cuando": "llegada", "servicio": "bomberos", "desenlaces": ["grave", "humo"],
				"radio_por_desenlace": {
					"grave": "Estabilizamos el coche. Vamos a cortar el techo para sacar al herido.",
					"humo": "Coche echando humo: lo enfriamos y desconectamos la batería."},
				"efectos_por_desenlace": {"grave": {"categoria": "atrapado"}, "humo": {"confirmado": "Coche asegurado por los bomberos"}}},
		],
		"finales": [
			{"desenlace": "grave", "exito": false, "fallecido": true, "texto": "El conductor atrapado ha fallecido antes de poder sacarlo del coche.", "exito_final": false},
			{"desenlace": "grave", "empeorado": true, "texto": "Excarcelado tarde: el herido grave ingresa en estado crítico.", "exito_final": false},
			{"desenlace": "grave", "marca": "segunda", "texto": "Herido excarcelado y los tres trasladados a la vez. ¡Gran coordinación!", "estrellas": 1},
			{"desenlace": "grave", "texto": "Herido excarcelado y trasladado. Los heridos leves tuvieron que esperar."},
			{"desenlace": "moto", "marca": "casco_mal", "texto": "Al quitarle el casco se agravó la lesión de cuello del motorista.", "estrellas": -1, "exito_final": false},
			{"desenlace": "moto", "marca": "casco_bien", "texto": "Motorista inmovilizado a tiempo gracias a tus instrucciones. Trasladado estable.", "estrellas": 1},
			{"desenlace": "moto", "texto": "Motorista trasladado al hospital con una lesión de cuello."},
			{"desenlace": "humo", "empeorado": true, "texto": "El coche llegó a arder antes de que llegaran los bomberos.", "exito_final": false},
			{"desenlace": "humo", "texto": "Coche asegurado por los bomberos. Los conductores, ilesos."},
			{"desenlace": "leve", "texto": "Dos heridos leves curados en el lugar. Tráfico restablecido."},
		],
	},
	# ================================================================
	# 5. "MI VECINA NO DA SEÑALES" (puede acabar en fallecimiento y trámites)
	# ================================================================
	{
		"id": "sin_noticias", "turno": "dia", "tipo": "llamada",
		"referencias": ["iglesia", "plaza", "colegio", "supermercado", "farmacia", "parque"],
		"llamantes": [
			{"desc": "Mujer, unos 60 años (vecina)", "calma": 55, "nombres": ["Mercedes", "Amparo", "Josefa", "Concha", "Remedios"],
				"personalidades": [["preocupada", 0], ["muy angustiada", -15], ["serena", 15]]},
			{"desc": "Hombre, unos 65 años (vecino)", "calma": 60, "nombres": ["Eusebio", "Valentín", "Gregorio", "Tomás"],
				"personalidades": [["preocupado", 0], ["nervioso", -10], ["tranquilo", 15]]},
		],
		"estados": ["En pánico", "Muy angustiado/a", "Preocupado/a", "Tranquilo/a"],
		"desenlaces": {
			"caida": {"peso": 3}, "fallecida": {"peso": 2}, "viaje": {"peso": 2},
		},
		"incidente": {"titulo": "Vecina mayor sin dar señales de vida", "servicios": ["policia"], "principal": "policia",
			"urgencia": 95.0, "intervencion": 8.0, "categoria": "robo", "requeridas": {"policia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["Hola... llamo porque mi vecina, una señora mayor que vive sola, no da señales desde hace dos días.",
					"Perdone que les llame... no veo a mi vecina desde el lunes y tiene el buzón lleno de cartas.",
					"Buenas. Estoy preocupada: la señora de al lado no abre la puerta, y eso que sale todos los días a por el pan."],
				"opciones": [
					{"texto": "¿Cuándo la vio por última vez?", "ir_a": "ultima"},
					{"texto": "¿Ha llamado a su puerta?", "ir_a": "puerta"},
					{"texto": "¿Dónde vive la señora?", "ir_a": "donde"}]},
			"ultima": {"texto_por_desenlace": {
					"viaje": "Pues el lunes... me pareció verla con una maleta, pero no estoy segura.",
					"_": "El lunes por la mañana, comprando el pan. Desde entonces, nada."},
				"efectos_por_desenlace": {"viaje": {"info": "Quizá la vieron con una maleta"}, "_": {"info": "No la ven desde hace dos días"}},
				"opciones": [
					{"texto": "¿Ha llamado a su puerta?", "ir_a": "puerta"},
					{"texto": "¿Tiene familia?", "ir_a": "familia"},
					{"texto": "¿Dónde vive la señora?", "ir_a": "donde"}]},
			"puerta": {"texto_por_desenlace": {
					"caida": "Sí, y me ha parecido oír algo dentro... como un quejido muy flojito.",
					"fallecida": "Sí, muchas veces. No se oye nada. Y tiene la persiana bajada.",
					"viaje": "Sí, pero no contesta nadie. La persiana está bajada."},
				"efectos_por_desenlace": {"caida": {"info": "Se oye un quejido dentro", "urgencia": 70.0}, "_": {"info": "No contesta y tiene la persiana bajada"}},
				"opciones": [
					{"texto": "¿Tiene familia?", "ir_a": "familia"},
					{"texto": "¿Dónde vive la señora?", "ir_a": "donde"}]},
			"familia": {"texto": "Tiene una hija que vive en Ciudad Real, pero no tengo su teléfono.", "efectos": {"info": "Tiene una hija en Ciudad Real"},
				"opciones": [{"texto": "¿Dónde vive la señora?", "ir_a": "donde"}]},
			"donde": {"texto": "En Miguelturra, cerca de {lugar}.", "efectos": {"precision": 2, "info": "Cerca de {lugar}"},
				"opciones": [{"texto": "¿En qué calle?", "ir_a": "calle"}]},
			"calle": {"texto": "En {calle}, la casa de la puerta verde.", "efectos": {"precision": 3, "info": "{calle}, casa de la puerta verde"},
				"opciones": [{"texto": "Mandamos una patrulla.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Intento entrar yo por la ventana del patio?",
				"opciones": [
					{"texto": "No, no intente entrar. Espere en la puerta para indicar a los agentes.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Si puede entrar sin peligro, entre a ver.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, les espero en la puerta. Gracias.", "fin": true},
			"fin_mal": {"texto": "Bueno... voy a intentarlo...", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio": "Estamos en la puerta. Nadie abre y el buzón está lleno.",
				"decision": {"titulo": "Nadie abre y el buzón está lleno", "opciones": [
					{"texto": "Pedir a los bomberos que abran la puerta", "efectos": {"requiere": {"bomberos": 1}, "marca": "puerta"}, "siguiente": "abrir"},
					{"texto": "Preguntar a los vecinos si alguien tiene llave", "siguiente": "llave"},
					{"texto": "Esperar a localizar a la familia", "efectos": {"marca": "esperar"}, "siguiente": "familia"}]}},
			{"id": "abrir", "cuando": "tras",
				"radio_por_desenlace": {
					"caida": "Esperamos a los bomberos para abrir... ¡se oye a la señora pedir ayuda! Pedimos ambulancia.",
					"fallecida": "Esperamos a los bomberos para abrir. Dentro no se oye nada. Pedimos ambulancia.",
					"viaje": "Antes de que lleguen los bomberos aparece su hija: la señora está pasando unos días con ella."},
				"efectos_por_desenlace": {
					"caida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "traslado": true, "confirmado": "Señora caída dentro de casa"},
					"fallecida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "confirmado": "No hay respuesta dentro"},
					"viaje": {"categoria": "control", "quitar": "bomberos", "confirmado": "La señora está con su hija", "duracion": -3.0}}},
			{"id": "llave", "cuando": "tras",
				"radio_por_desenlace": {
					"caida": "La vecina de abajo tiene llave. ¡Entramos! La señora está en el suelo del baño. Necesitamos una ambulancia.",
					"fallecida": "Entramos con la llave de una vecina... Lo sentimos, la señora no respira. Pedimos ambulancia para certificar.",
					"viaje": "Un vecino dice que se fue con su hija el lunes. Lo confirmamos por teléfono: está bien."},
				"efectos_por_desenlace": {
					"caida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "traslado": true, "confirmado": "Señora caída en el baño"},
					"fallecida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "confirmado": "Encontrada sin vida", "duracion": -4.0},
					"viaje": {"categoria": "control", "confirmado": "La señora está con su hija", "duracion": -3.0}}},
			{"id": "familia", "cuando": "tras",
				"radio_por_desenlace": {
					"caida": "Localizar a la familia nos ha llevado mucho tiempo... Por fin entramos: la señora lleva horas en el suelo.",
					"fallecida": "La hija llega con la llave. Lo sentimos mucho: la señora ha fallecido.",
					"viaje": "La hija nos contesta: su madre está con ella en Ciudad Real. Todo en orden."},
				"efectos_por_desenlace": {
					"caida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "traslado": true, "marca": "espera_larga", "confirmado": "Señora caída desde hace horas"},
					"fallecida": {"categoria": "medico", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "confirmado": "Encontrada sin vida", "duracion": -4.0},
					"viaje": {"categoria": "control", "confirmado": "La señora está con su hija", "duracion": -3.0}}},
			{"id": "llega_bomberos", "cuando": "llegada", "servicio": "bomberos", "desenlaces": ["caida", "fallecida"],
				"radio_por_desenlace": {
					"caida": "Puerta abierta. La señora está consciente en el suelo, muy dolorida.",
					"fallecida": "Puerta abierta. Lo sentimos: la señora está sin vida en la cama."},
				"efectos_por_desenlace": {"fallecida": {"confirmado": "Encontrada sin vida", "duracion": -4.0}, "_": {}}},
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia", "desenlaces": ["caida", "fallecida"],
				"radio_por_desenlace": {
					"caida": "Señora con posible fractura de cadera. La inmovilizamos y la trasladamos.",
					"fallecida": "Confirmamos que lleva varias horas fallecida. Causas naturales, a falta del forense."},
				"efectos_por_desenlace": {"caida": {"traslado": true}, "fallecida": {"traslado": false, "duracion": -3.0}}},
		],
		"finales": [
			{"desenlace": "fallecida", "fallecido": true, "texto": "La señora había fallecido en su casa por causas naturales.", "exito_final": true, "estrellas": 1},
			{"desenlace": "caida", "marca": "espera_larga", "texto": "Rescatada tras muchas horas en el suelo: ingresa en estado grave.", "estrellas": -1},
			{"desenlace": "caida", "empeorado": true, "texto": "La señora ingresa en estado grave por la espera.", "exito_final": false},
			{"desenlace": "caida", "texto": "Señora rescatada a tiempo y trasladada al hospital. ¡Bien hecho!", "estrellas": 1},
			{"desenlace": "viaje", "marca": "puerta", "texto": "Falsa alarma: la señora estaba con su hija. Se pidió abrir la puerta sin necesidad.", "estrellas": -1},
			{"desenlace": "viaje", "texto": "Falsa alarma: la señora estaba pasando unos días con su familia."},
		],
	},
	# ================================================================
	# 6. "FIESTA ILEGAL EN EL MONTE DE SAN ISIDRO" (solo en la noche de la fiesta ilegal)
	# ================================================================
	{
		"id": "rave", "turno": "noche", "tipo": "llamada", "solo_evento": "rave",
		"referencias": ["monte"],
		"llamantes": [
			{"desc": "Voz joven, con mucho ruido de fondo", "calma": 35, "nombres": ["Dani", "Sara", "Álex", "Irene", "Marcos"],
				"personalidades": [["asustado/a", -10], ["muy nervioso/a", -20], ["espabilado/a", 10]]},
			{"desc": "Hombre, unos 55 años (vecino de La Lobera)", "calma": 50, "nombres": ["Julián", "Andrés", "Felipe"],
				"personalidades": [["harto", 0], ["muy enfadado", -15], ["tranquilo", 10]]},
		],
		"estados": ["En pánico", "Muy nervioso/a", "Inquieto/a", "Tranquilo/a"],
		"desenlaces": {"ruido": {"peso": 3}, "intoxicado": {"peso": 2}, "pelea": {"peso": 2}, "hoguera": {"peso": 1}},
		"incidente": {"titulo": "Fiesta ilegal en el Monte de San Isidro", "servicios": ["policia"], "principal": "policia",
			"urgencia": 120.0, "intervencion": 12.0, "categoria": "control", "requeridas": {"policia": 2}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"texto_por_desenlace": {
					"ruido": "Llamo desde La Lobera... ¡hay una fiesta en el monte con una música que retumba en todo el barrio!",
					"intoxicado": "Estoy en la fiesta del monte de San Isidro... mi amigo se ha caído al suelo y no reacciona bien.",
					"pelea": "¡En la fiesta del monte se están pegando! ¡Son muchísimos!",
					"hoguera": "¡En la fiesta del monte han hecho una hoguera enorme y se está prendiendo el pasto!"},
				"opciones": [
					{"texto": "¿Qué está pasando exactamente?", "ir_a": "que"},
					{"texto": "¿Dónde está?", "ir_a": "donde"}]},
			"que": {"texto_por_desenlace": {
					"ruido": "Hay cientos de coches y unos altavoces enormes. Nadie puede dormir.",
					"intoxicado": "Ha tomado algo que le dieron... está muy pálido y respira raro.",
					"pelea": "Son muchos, y hay uno sangrando en el suelo.",
					"hoguera": "El fuego avanza hacia los pinos y la gente sigue bailando."},
				"efectos_por_desenlace": {
					"ruido": {"info": "Cientos de personas y música a todo volumen"},
					"intoxicado": {"info": "Joven intoxicado que respira con dificultad", "requiere": {"ambulancia": 1}, "principal": "ambulancia", "categoria": "medico", "traslado": true, "urgencia": 60.0},
					"pelea": {"info": "Pelea con un herido sangrando", "requiere": {"ambulancia": 1}, "categoria": "pelea"},
					"hoguera": {"info": "Hoguera que prende el pasto del monte", "requiere": {"bomberos": 1}, "categoria": "fuego"}},
				"opciones": [{"texto": "¿Dónde está exactamente?", "ir_a": "donde"}]},
			"donde": {"texto": "En el monte de San Isidro, subiendo por La Lobera.", "efectos": {"precision": 2, "info": "Monte de San Isidro"},
				"opciones": [{"texto": "¿Por qué calle se llega?", "ir_a": "calle"}]},
			"calle": {"texto": "Al final de {calle}, donde están todos los coches aparcados.", "efectos": {"precision": 3, "info": "Al final de {calle}"},
				"opciones": [{"texto": "Los agentes van para allá.", "ir_a": "consejos"}]},
			"consejos": {"si_desenlace": {"intoxicado": "consejo_intox", "hoguera": "consejo_fuego"},
				"texto": "¿Y qué hago mientras tanto?",
				"opciones": [
					{"texto": "Aléjese de la zona y no se enfrente a nadie.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Intente usted calmarlos.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"consejo_intox": {"texto": "¿Qué hago con él? ¡No sé qué hacer!",
				"opciones": [
					{"texto": "Póngalo de lado, no le deje solo y no le dé nada de beber. Si deja de respirar, avíseme.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "efectos_por_desenlace": {"intoxicado": {"marca": "lateral"}, "_": {}}, "ir_a": "fin"},
					{"texto": "Échele agua fría en la cara para que espabile.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"consejo_fuego": {"texto": "¿Intentamos apagarlo entre todos?",
				"opciones": [
					{"texto": "No. Que todo el mundo se aleje del fuego, en dirección contraria al viento.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Sí, échenle tierra entre todos.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, vale... ¡que vengan rápido!", "fin": true},
			"fin_mal": {"texto": "Vale... a ver qué puedo hacer...", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"ruido": "Hay más de doscientas personas. Cortamos la música.",
					"intoxicado": "Mucha gente y un joven en el suelo. Abrimos paso a la ambulancia.",
					"pelea": "Varios grupos peleando. La cosa está caliente.",
					"hoguera": "La hoguera ha prendido el pasto. Apartamos a la gente."},
				"decision": {"titulo": "Fiesta ilegal con cientos de personas", "opciones": [
					{"texto": "Desalojar a todo el mundo ya", "efectos": {"marca": "desalojo", "duracion": -3.0}},
					{"texto": "Cortar la música y desalojar poco a poco", "efectos": {"marca": "poco_a_poco", "duracion": 5.0}}]}},
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia", "desenlaces": ["intoxicado", "pelea"],
				"radio_por_desenlace": {"intoxicado": "Joven con una intoxicación grave. Lo estabilizamos y nos lo llevamos.",
					"pelea": "Un herido con un corte en la cabeza. Lo curamos aquí."},
				"efectos_por_desenlace": {"intoxicado": {"traslado": true}, "pelea": {"duracion": -2.0}}},
		],
		"finales": [
			{"desenlace": "intoxicado", "empeorado": true, "texto": "El joven ingresa en estado grave por la intoxicación.", "exito_final": false},
			{"desenlace": "intoxicado", "marca": "lateral", "texto": "Gracias a la postura lateral de seguridad, el joven llega estable al hospital.", "estrellas": 1},
			{"desenlace": "intoxicado", "texto": "Joven trasladado al hospital por una intoxicación."},
			{"desenlace": "pelea", "marca": "desalojo", "texto": "El desalojo rápido provocó carreras: dos heridos leves más.", "estrellas": -1},
			{"desenlace": "pelea", "texto": "Pelea controlada: dos detenidos y un herido atendido."},
			{"desenlace": "hoguera", "empeorado": true, "texto": "El fuego quemó parte del pinar antes de poder apagarlo.", "exito_final": false},
			{"desenlace": "hoguera", "texto": "Fuego de pasto apagado y fiesta desalojada."},
			{"desenlace": "ruido", "marca": "poco_a_poco", "texto": "Música cortada y desalojo tranquilo. Los vecinos de La Lobera por fin duermen.", "estrellas": 1},
			{"desenlace": "ruido", "texto": "Fiesta ilegal desalojada. Algún momento de tensión, pero sin heridos."},
		],
	},
	# ================================================================
	# 7. "INCENDIO EN UNA NAVE DEL POLÍGONO" (con evacuación)
	# ================================================================
	{
		"id": "nave_poligono", "turno": "ambos", "tipo": "incendio",
		"referencias": ["industrial"],
		"llamantes": [
			{"desc": "Hombre, unos 40 años (trabaja en el polígono)", "calma": 35, "nombres": ["Rafael", "Emilio", "Joaquín", "Nacho"],
				"personalidades": [["muy nervioso", -15], ["alterado", -10], ["sereno", 15]]},
			{"desc": "Mujer, unos 30 años (trabaja en una nave vecina)", "calma": 35, "nombres": ["Raquel", "Gema", "Susana", "Vanesa"],
				"personalidades": [["muy nerviosa", -15], ["asustada", -10], ["serena", 15]]},
		],
		"estados": ["En pánico", "Muy alterado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {"vacia": {"peso": 2}, "trabajadores": {"peso": 3}, "quimicos": {"peso": 2}},
		"incidente": {"titulo": "Incendio en una nave del polígono", "servicios": ["bomberos", "policia"], "principal": "bomberos",
			"urgencia": 60.0, "intervencion": 22.0, "categoria": "fuego", "requeridas": {"bomberos": 1, "policia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Fuego! ¡Está ardiendo una nave del polígono, sale un humo negrísimo!",
					"Llamo desde el polígono industrial: ¡la nave de al lado está en llamas!",
					"¡Corran! ¡Se está quemando una nave entera en el polígono!"],
				"opciones": [
					{"texto": "¿Hay alguien dentro?", "ir_a": "dentro"},
					{"texto": "¿Qué hay en la nave?", "ir_a": "material"},
					{"texto": "¿Dónde está la nave?", "ir_a": "donde"}]},
			"dentro": {"texto_por_desenlace": {
					"vacia": "Creo que no, hoy no trabajaban... está cerrada.",
					"trabajadores": "¡Sí! Estaban trabajando... han salido algunos, pero faltan dos.",
					"quimicos": "Han salido todos, pero dicen que dentro hay bidones de productos químicos."},
				"efectos_por_desenlace": {
					"vacia": {"info": "La nave parece vacía"},
					"trabajadores": {"info": "Faltan dos trabajadores dentro", "requiere": {"ambulancia": 1}, "heridos": 2, "urgencia": 45.0},
					"quimicos": {"info": "Bidones de productos químicos dentro", "requiere": {"bomberos": 2}}},
				"opciones": [
					{"texto": "¿Qué hay en la nave?", "ir_a": "material"},
					{"texto": "¿Dónde está la nave?", "ir_a": "donde"}]},
			"material": {"texto_por_desenlace": {
					"vacia": "Es un almacén de muebles, hay mucha madera.",
					"trabajadores": "Es un taller con maquinaria y aceites.",
					"quimicos": "¡Productos de limpieza industrial y disolventes!"},
				"efectos_por_desenlace": {"quimicos": {"confirmado": "Productos químicos en la nave", "intensidad": 3}, "_": {"intensidad": 2}},
				"opciones": [{"texto": "¿Dónde está la nave?", "ir_a": "donde"}]},
			"donde": {"texto": "En el polígono industrial, junto a {calle}.", "efectos": {"precision": 3, "info": "{calle}, polígono industrial"},
				"opciones": [{"texto": "Bomberos y policía van para allá.", "ir_a": "consejos"}]},
			"consejos": {"si_desenlace": {"quimicos": "consejo_humo"},
				"texto": "¿Qué hacemos los que estamos aquí?",
				"opciones": [
					{"texto": "Aléjense de la nave, no entren a buscar a nadie y esperen a los bomberos en la entrada del polígono.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Intenten sacar a los que faltan.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"consejo_humo": {"texto": "El humo huele fatal y va hacia las otras naves... ¿qué hacemos?",
				"opciones": [
					{"texto": "Que salga todo el mundo de las naves cercanas, en dirección contraria al humo.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Cierren puertas y ventanas y quédense dentro.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, vale. ¡Que vengan rápido!", "fin": true},
			"fin_mal": {"texto": "Vale... lo intentamos...", "fin": true},
		},
		"llamadas": {
			"vecino": {"llamante": "Hombre, unos 50 años (nave de al lado)", "calma": 40, "inicio": "inicio",
				"estados": ["En pánico", "Muy nervioso", "Nervioso", "Tranquilo"],
				"nodos": {
					"inicio": {"texto_por_desenlace": {
							"quimicos": "Trabajo en la nave de al lado... ¡el humo entra por las ventanas y pica muchísimo en la garganta!",
							"_": "Estoy en la nave de al lado. ¡Las llamas se ven desde aquí! ¿Salimos?"},
						"efectos_por_desenlace": {"quimicos": {"confirmado": "El humo llega a las naves vecinas"}, "_": {"info": "Hay gente en las naves de al lado"}},
						"opciones": [
							{"texto": "Sí, salgan todos ya, en dirección contraria al humo.", "efectos": {"marca": "consejo_bueno"}, "ir_a": "fin"},
							{"texto": "Quédense dentro hasta que llegue alguien.", "ir_a": "fin"}]},
					"fin": {"texto": "¡Vale, salimos!", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_vecino", "cuando": "tiempo", "segundos": 30.0, "llamada": "vecino"},
			{"id": "llega_bomberos", "cuando": "llegada", "servicio": "bomberos", "desenlaces": ["vacia", "trabajadores"],
				"radio_por_desenlace": {
					"vacia": "Nave en llamas, sin personas dentro. Atacamos el fuego.",
					"trabajadores": "¡Dos trabajadores atrapados al fondo de la nave! Entramos con equipos de respiración."},
				"efectos_por_desenlace": {"trabajadores": {"marca": "atrapado_bien", "confirmado": "Dos trabajadores atrapados"}, "_": {}}},
			{"id": "llega_bomberos_quimicos", "cuando": "llegada", "servicio": "bomberos", "desenlaces": ["quimicos"],
				"radio": "Columna de humo tóxico hacia las naves vecinas. ¿Evacuamos el polígono?",
				"efectos": {"confirmado": "Humo tóxico hacia las naves vecinas", "intensidad": 3},
				"decision": {"titulo": "Humo tóxico en el polígono", "opciones": [
					{"texto": "Evacuar todas las naves cercanas (hacen falta más agentes)", "efectos": {"requiere": {"policia": 2}, "marca": "evacuacion", "duracion": 4.0}},
					{"texto": "Solo confinar: que cierren puertas y ventanas", "efectos": {"marca": "confinar"}}]}},
		],
		"finales": [
			{"desenlace": "quimicos", "marca": "evacuacion", "texto": "Incendio controlado y polígono evacuado a tiempo: nadie respiró el humo tóxico.", "estrellas": 1},
			{"desenlace": "quimicos", "texto": "Incendio apagado, pero varios trabajadores de naves vecinas respiraron humo tóxico.", "estrellas": -1},
			{"desenlace": "trabajadores", "empeorado": true, "texto": "Los trabajadores salieron tarde: uno de ellos está grave.", "exito_final": false},
			{"desenlace": "trabajadores", "texto": "Los dos trabajadores rescatados con vida y trasladados al hospital.", "estrellas": 1},
			{"desenlace": "vacia", "empeorado": true, "texto": "La nave ha quedado completamente destruida."},
			{"desenlace": "vacia", "texto": "Incendio controlado. Solo daños materiales."},
		],
	},
]
