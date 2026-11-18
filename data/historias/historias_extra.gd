extends RefCounted
## HISTORIAS NUEVAS (0.97): más duras y más variadas.
## Mismo formato que historias.gd (ver la explicación allí).

const HISTORIAS := [
	# ================================================================
	# PELEA ENTRE BANDAS
	# ================================================================
	{
		"id": "bandas", "turno": "noche", "tipo": "llamada",
		"referencias": ["parque", "plaza", "bar", "deporte"],
		"llamantes": [
			{"desc": "Vecino, unos 50 años, desde el balcón", "calma": 30, "nombres": ["Manolo", "Andrés", "Felipe", "Ramón"],
				"personalidades": [["muy alterado", -15], ["asustado", -5], ["sereno", 15]]},
			{"desc": "Camarera de un bar cercano", "calma": 25, "nombres": ["Lorena", "Sara", "Inma", "Bea"],
				"personalidades": [["aterrada", -15], ["nerviosa", -5], ["decidida", 10]]},
		],
		"estados": ["En pánico", "Muy asustado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {"dispersan": {"peso": 2}, "apunalado": {"peso": 3}, "masiva": {"peso": 2}},
		"incidente": {"titulo": "Pelea entre bandas en la calle", "servicios": ["policia"], "principal": "policia",
			"urgencia": 60.0, "intervencion": 14.0, "categoria": "pelea", "requeridas": {"policia": 2}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Se están pegando dos grupos de chavales aquí abajo! ¡Llevan palos!",
					"¡Vengan ya! ¡Hay una batalla campal entre dos bandas, se están matando!",
					"¡Son muchísimos! ¡Se han juntado dos grupos y se están dando de todo!"],
				"opciones": [
					{"texto": "¿Cuántos son, más o menos?", "ir_a": "cuantos"},
					{"texto": "¿Ve armas? ¿Navajas, palos...?", "ir_a": "armas"},
					{"texto": "¿Dónde es exactamente?", "ir_a": "donde"}]},
			"cuantos": {"texto_por_desenlace": {"masiva": "¡Treinta por lo menos! ¡Y siguen llegando más en coches!", "_": "Unos diez o doce, en dos grupos."},
				"efectos_por_desenlace": {"masiva": {"info": "Unas treinta personas y llegan más", "requiere": {"policia": 3}}, "_": {"info": "Unos diez o doce implicados"}},
				"opciones": [
					{"texto": "¿Ve armas?", "ir_a": "armas"},
					{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"armas": {"texto_por_desenlace": {"apunalado": "¡Uno ha sacado un cuchillo! ¡Le ha dado a otro, está en el suelo!", "_": "Palos y cinturones... y botellas rotas."},
				"efectos_por_desenlace": {"apunalado": {"confirmado": "Un herido por arma blanca", "requiere": {"ambulancia": 1}, "traslado": true, "urgencia": 45.0, "heridos": 1},
					"_": {"info": "Palos, cinturones y botellas"}},
				"opciones": [{"texto": "¿Dónde es exactamente?", "ir_a": "donde"}]},
			"donde": {"texto": "Junto a {lugar}, en {calle}.", "efectos": {"precision": 3, "info": "{calle}, junto a {lugar}"},
				"opciones": [{"texto": "Las patrullas van para allá.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Qué hago? ¡Hay gente mirando desde los portales!",
				"opciones": [
					{"texto": "Que nadie baje ni se acerque. Si puede, grabe desde lejos y fíjese en hacia dónde van.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Bajen varios vecinos a separarlos.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Vale, me quedo arriba. ¡Que vengan ya!", "fin": true},
			"fin_mal": {"texto": "Bueno... voy a llamar a los del segundo...", "fin": true},
		},
		"llamadas": {
			"herido": {"llamante": "Chico joven, muy alterado", "calma": 15, "inicio": "inicio",
				"estados": ["En pánico", "Muy asustado", "Nervioso", "Tranquilo"],
				"nodos": {
					"inicio": {"texto_por_desenlace": {"apunalado": "¡Mi colega está sangrando muchísimo! ¡Le han pinchado en la tripa!", "_": "¡A mi amigo le han abierto la cabeza con una botella! ¡Sangra mucho!"},
						"efectos": {"requiere": {"ambulancia": 1}, "traslado": true},
						"opciones": [
							{"texto": "Aprieta la herida con algo de ropa y no la sueltes. La ambulancia va.", "efectos": {"marca": "consejo_bueno"}, "ir_a": "fin"},
							{"texto": "Llévalo tú al hospital en un coche.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin"}]},
					"fin": {"texto": "¡Vale! ¡Daos prisa, por favor!", "fin": true},
				}},
		},
		"eventos": [
			{"id": "llamada_herido", "cuando": "tiempo", "segundos": 25.0, "desenlaces": ["apunalado", "masiva"], "llamada": "herido"},
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"dispersan": "Al vernos llegar salen corriendo en todas direcciones. Perseguimos a dos.",
					"apunalado": "Hay un chico en el suelo con una herida de arma blanca. El agresor ha huido. ¡Ambulancia urgente!",
					"masiva": "¡Esto es enorme, central! Siguen llegando coches. ¿Qué hacemos?"},
				"efectos_por_desenlace": {"apunalado": {"requiere": {"ambulancia": 1}, "traslado": true, "confirmado": "Herido grave por arma blanca"}, "_": {}}},
			{"id": "decision_masiva", "cuando": "llegada", "servicio": "policia", "desenlaces": ["masiva"],
				"decision": {"titulo": "Pelea multitudinaria", "opciones": [
					{"texto": "Entrar ya a separarlos (más riesgo para los agentes)", "efectos": {"marca": "carga", "duracion": -3.0}},
					{"texto": "Contener y esperar refuerzos para rodearlos", "efectos": {"requiere": {"policia": 3}, "marca": "esperar_refuerzos", "duracion": 3.0}}]}},
		],
		"finales": [
			{"desenlace": "apunalado", "empeorado": true, "texto": "El chico apuñalado ha muerto antes de llegar al hospital. La policía busca al agresor.", "fallecido": true, "exito_final": false},
			{"desenlace": "apunalado", "marca": "consejo_malo", "texto": "El herido llegó al hospital en un coche particular y en estado crítico.", "estrellas": -1},
			{"desenlace": "apunalado", "texto": "Herido por arma blanca trasladado grave pero estable. Agresor identificado.", "estrellas": 1},
			{"desenlace": "masiva", "marca": "carga", "texto": "Pelea disuelta a la fuerza: varios detenidos y un agente herido.", "estrellas": 0},
			{"desenlace": "masiva", "texto": "Grupos rodeados y disueltos sin heridos graves. Seis detenidos.", "estrellas": 1},
			{"desenlace": "dispersan", "texto": "Los grupos se han dispersado. Dos detenidos y varios identificados."},
		],
	},
	# ================================================================
	# ASALTO VIOLENTO EN UNA VIVIENDA
	# ================================================================
	{
		"id": "asalto_vivienda", "turno": "ambos", "tipo": "llamada",
		"referencias": ["edificio", "iglesia", "parque", "plaza"],
		"llamantes": [
			{"desc": "Hija de los dueños, unos 40 años", "calma": 20, "nombres": ["Mercedes", "Isabel", "Nuria", "Elena"],
				"personalidades": [["llorando", -15], ["en shock", -10], ["entera", 10]]},
		],
		"estados": ["En shock", "Muy alterada", "Nerviosa", "Tranquila"],
		"desenlaces": {"atados": {"peso": 3}, "dentro": {"peso": 2}, "grave": {"peso": 2}},
		"incidente": {"titulo": "Asalto violento en una vivienda", "servicios": ["policia", "ambulancia"], "principal": "policia",
			"urgencia": 60.0, "intervencion": 13.0, "categoria": "robo", "requeridas": {"policia": 1, "ambulancia": 1}, "traslado": true},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡He llegado a casa de mis padres y está todo revuelto! ¡Los han atado! ¡Mi padre sangra!",
					"¡Por favor! ¡Han entrado a robar en casa de mis padres y les han pegado!",
					"Acabo de entrar en casa de mis padres... ¡están en el suelo, atados, y hay sangre!"],
				"opciones": [
					{"texto": "¿Los ladrones siguen dentro?", "ir_a": "dentro"},
					{"texto": "¿Cómo están sus padres?", "ir_a": "padres"},
					{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"dentro": {"texto_por_desenlace": {"dentro": "(susurra) ...creo que sí... se oye a alguien arriba, abriendo cajones...", "_": "No... se oyó un coche salir rápido cuando llegaba."},
				"efectos_por_desenlace": {"dentro": {"confirmado": "Los asaltantes siguen dentro", "requiere": {"policia": 2}, "calma": -10},
					"_": {"info": "Los asaltantes han huido en coche"}},
				"opciones": [
					{"texto": "¿Cómo están sus padres?", "ir_a": "padres"},
					{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"padres": {"texto_por_desenlace": {"grave": "Mi madre llora, pero mi padre... no contesta. Tiene un golpe en la cabeza y respira raro.", "_": "Están atados con bridas. Mi padre tiene la cara hinchada, mi madre está temblando."},
				"efectos_por_desenlace": {"grave": {"confirmado": "Hombre mayor inconsciente por un golpe en la cabeza", "urgencia": 45.0, "heridos": 2},
					"_": {"info": "Pareja mayor atada y golpeada", "heridos": 2}},
				"opciones": [
					{"texto": "¿Dónde es?", "ir_a": "donde"},
					{"texto": "¿Ha visto a los ladrones?", "ir_a": "dentro"}]},
			"donde": {"texto": "En {calle}, cerca de {lugar}. Una casa de dos plantas.", "efectos": {"precision": 3, "info": "{calle}, casa de dos plantas"},
				"opciones": [{"texto": "La policía y la ambulancia van para allá.", "ir_a": "consejos"}]},
			"consejos": {"si_desenlace": {"dentro": "consejo_dentro"}, "texto": "¿Les desato? ¿Qué hago?",
				"opciones": [
					{"texto": "Córteles las bridas con cuidado, no toque nada más y no mueva a su padre.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Siente a su padre y dele agua.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin"}]},
			"consejo_dentro": {"texto": "(muy bajito) ¿Qué hago? Estoy en la entrada...",
				"opciones": [
					{"texto": "Salga ahora mismo a la calle sin hacer ruido y espere a la patrulla lejos de la casa.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Escóndase dentro para vigilarlos.", "efectos": {"marca": "consejo_malo", "calma": -10}, "ir_a": "fin"}]},
			"fin": {"texto": "Vale... vale... ¡dense prisa!", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"atados": "Dos personas mayores atadas y golpeadas. Los asaltantes han huido. Precintamos la casa.",
					"dentro": "¡Hay dos tipos arriba! Salen por la ventana trasera. ¡Vamos tras ellos!",
					"grave": "Hombre mayor inconsciente con un fuerte golpe en la cabeza. ¡Necesitamos la ambulancia ya!"},
				"efectos_por_desenlace": {"dentro": {"duracion": 4.0}, "_": {}}},
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia",
				"radio_por_desenlace": {"grave": "Traumatismo craneal grave. Lo estabilizamos para el traslado.", "_": "Contusiones y crisis de ansiedad. Los trasladamos para valorarlos."}},
		],
		"finales": [
			{"desenlace": "grave", "empeorado": true, "texto": "El dueño de la casa ha fallecido por el golpe en la cabeza. Investigación abierta por homicidio.", "fallecido": true, "exito_final": false},
			{"desenlace": "grave", "texto": "El hombre ingresa en la UCI con un traumatismo grave. Su mujer, con contusiones.", "estrellas": 0},
			{"desenlace": "dentro", "exito": true, "texto": "Los dos asaltantes detenidos al saltar la tapia. Los dueños, heridos leves.", "estrellas": 1},
			{"desenlace": "dentro", "texto": "Los asaltantes han escapado por la parte de atrás."},
			{"desenlace": "atados", "marca": "consejo_bueno", "texto": "Pareja mayor atendida. La policía ha recogido huellas de los asaltantes.", "estrellas": 1},
			{"desenlace": "atados", "texto": "Pareja mayor atendida tras el asalto. Los ladrones se llevaron joyas y dinero."},
		],
	},
	# ================================================================
	# PERSONA ARMADA
	# ================================================================
	{
		"id": "armado", "turno": "ambos", "tipo": "llamada",
		"referencias": ["plaza", "supermercado", "parque", "iglesia", "edificio"],
		"llamantes": [
			{"desc": "Mujer, unos 35 años", "calma": 20, "nombres": ["Laura", "Cristina", "Patricia", "Rocío"],
				"personalidades": [["aterrada", -15], ["asustada", -5], ["fría", 15]]},
			{"desc": "Dependiente de una tienda", "calma": 30, "nombres": ["Óscar", "David", "Rubén", "Iván"],
				"personalidades": [["muy nervioso", -15], ["asustado", -5], ["sereno", 15]]},
		],
		"estados": ["Aterrado/a", "Muy asustado/a", "Nervioso/a", "Tranquilo/a"],
		"desenlaces": {"brote": {"peso": 3}, "escopeta": {"peso": 2}, "juguete": {"peso": 2}},
		"incidente": {"titulo": "Persona armada amenazando en la calle", "servicios": ["policia"], "principal": "policia",
			"urgencia": 50.0, "intervencion": 14.0, "categoria": "pelea", "requeridas": {"policia": 2}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Hay un hombre con un arma gritando en mitad de la calle! ¡La gente está corriendo!",
					"¡Corran! ¡Un tío está amenazando a todo el mundo con un arma!",
					"Llamo escondido... hay un hombre armado aquí fuera, está fuera de sí."],
				"opciones": [
					{"texto": "¿Qué tipo de arma lleva?", "ir_a": "arma"},
					{"texto": "¿Ha herido a alguien?", "ir_a": "herido"},
					{"texto": "¿Dónde está? ¿Usted está a salvo?", "ir_a": "donde"}]},
			"arma": {"texto_por_desenlace": {"brote": "Un cuchillo de cocina enorme. Habla solo, dice que le persiguen.",
					"escopeta": "¡Una escopeta de caza! Se ha metido en un portal y grita que no se acerque nadie.",
					"juguete": "Parece una pistola... negra... la mueve mucho."},
				"efectos_por_desenlace": {"brote": {"info": "Cuchillo; parece una crisis, dice que le persiguen", "requiere": {"ambulancia": 1}},
					"escopeta": {"confirmado": "Escopeta de caza, atrincherado en un portal", "requiere": {"policia": 3}, "duracion": 6.0},
					"juguete": {"info": "Lo que parece una pistola negra"}},
				"opciones": [
					{"texto": "¿Ha herido a alguien?", "ir_a": "herido"},
					{"texto": "¿Dónde está?", "ir_a": "donde"}]},
			"herido": {"texto_por_desenlace": {"brote": "A un señor le ha hecho un corte en el brazo al pasar...", "_": "No, de momento no... solo amenaza."},
				"efectos_por_desenlace": {"brote": {"requiere": {"ambulancia": 1}, "traslado": true, "info": "Un transeúnte con un corte en el brazo"}, "_": {}},
				"opciones": [{"texto": "¿Dónde está?", "ir_a": "donde"}]},
			"donde": {"texto": "En {calle}, delante de {lugar}. Yo estoy metido en una tienda.", "efectos": {"precision": 3, "info": "{calle}, delante de {lugar}"},
				"opciones": [{"texto": "Varias patrullas van para allá.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Qué hacemos los de dentro?",
				"opciones": [
					{"texto": "Cierren la puerta, apártense de los cristales y no salgan hasta que se lo diga la policía.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Salgan corriendo por la otra calle.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin"},
					{"texto": "Intenten hablar con él para calmarle.", "efectos": {"marca": "consejo_malo", "calma": -5}, "ir_a": "fin"}]},
			"fin": {"texto": "Vale... ¡vengan rápido!", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"brote": "Hombre con un cuchillo, muy alterado, parece un brote psicótico. ¿Cómo actuamos?",
					"escopeta": "Atrincherado en el portal con una escopeta. Acordonamos la zona. ¿Órdenes?",
					"juguete": "Le hemos dado el alto: ¡era una pistola de juguete! Un chaval haciendo el tonto para un vídeo."},
				"efectos_por_desenlace": {"juguete": {"categoria": "control", "duracion": -6.0, "quitar": "ambulancia"}, "_": {}}},
			{"id": "decision_armado", "cuando": "llegada", "servicio": "policia", "desenlaces": ["brote", "escopeta"],
				"decision": {"titulo": "Persona armada", "opciones": [
					{"texto": "Negociar con calma y esperar (más lento, más seguro)", "efectos": {"marca": "negociar", "duracion": 8.0}},
					{"texto": "Reducirlo ya (rápido, pero arriesgado)", "efectos": {"marca": "reducir", "duracion": -4.0}},
					{"texto": "Pedir a la Guardia Civil que apoye (hacen falta más agentes)", "efectos": {"marca": "negociar", "requiere": {"policia": 3}}}]}},
		],
		"finales": [
			{"desenlace": "escopeta", "marca": "reducir", "texto": "Al intentar reducirle disparó: un agente herido grave. Finalmente detenido.", "estrellas": -1, "exito_final": false},
			{"desenlace": "escopeta", "texto": "Tras horas de negociación, se entregó y dejó la escopeta. Nadie herido.", "estrellas": 1},
			{"desenlace": "brote", "marca": "reducir", "texto": "Reducido con dificultad: un agente con un corte en la mano. El hombre, ingresado en psiquiatría."},
			{"desenlace": "brote", "texto": "Los agentes le convencieron de soltar el cuchillo. Trasladado al hospital en plena crisis.", "estrellas": 1},
			{"desenlace": "juguete", "texto": "Era una pistola de juguete. Denuncia por alarma social al joven y a quien grababa."},
		],
	},
	# ================================================================
	# CONTRABANDO EN EL POLÍGONO
	# ================================================================
	{
		"id": "contrabando", "turno": "noche", "tipo": "llamada",
		"referencias": ["industrial"],
		"llamantes": [
			{"desc": "Vigilante de seguridad del polígono", "calma": 55, "nombres": ["Paco", "Jesús", "Toni", "Gonzalo"],
				"personalidades": [["desconfiado", 0], ["nervioso", -10], ["profesional", 15]]},
		],
		"estados": ["Muy nervioso", "Nervioso", "Atento", "Tranquilo"],
		"desenlaces": {"tabaco": {"peso": 3}, "droga": {"peso": 3}, "huida": {"peso": 2}},
		"incidente": {"titulo": "Descarga sospechosa de madrugada en el polígono", "servicios": ["policia"], "principal": "policia",
			"urgencia": 75.0, "intervencion": 14.0, "categoria": "control", "requeridas": {"policia": 2}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["Central, soy el vigilante del polígono. Hay un camión descargando fardos en una nave que debería estar vacía.",
					"Buenas noches. Llevo un rato viendo movimiento raro: furgonetas y un camión, a estas horas, con las luces apagadas.",
					"Llamo del polígono. Están metiendo bultos en una nave abandonada y hay dos tíos vigilando la entrada."],
				"opciones": [
					{"texto": "¿Cuántas personas ve?", "ir_a": "cuantos"},
					{"texto": "¿Qué están descargando?", "ir_a": "que"},
					{"texto": "¿Qué nave es?", "ir_a": "donde"}]},
			"cuantos": {"texto": "Cinco o seis. Dos en la puerta, mirando a todos lados.", "efectos": {"info": "Cinco o seis personas, dos vigilando"},
				"opciones": [
					{"texto": "¿Qué están descargando?", "ir_a": "que"},
					{"texto": "¿Qué nave es?", "ir_a": "donde"}]},
			"que": {"texto_por_desenlace": {"tabaco": "Cajas de cartón muy bien precintadas, muchísimas.", "droga": "Fardos envueltos en plástico negro, como balas de paja pequeñas.", "huida": "No se ve bien... bultos envueltos. Uno me ha mirado."},
				"efectos_por_desenlace": {"droga": {"info": "Fardos envueltos en plástico negro"}, "huida": {"info": "Creen que les han visto", "urgencia": 50.0}, "_": {"info": "Muchas cajas precintadas"}},
				"opciones": [{"texto": "¿Qué nave es?", "ir_a": "donde"}]},
			"donde": {"texto": "La nave que hay junto a {calle}, la del portón azul.", "efectos": {"precision": 3, "info": "{calle}, nave del portón azul"},
				"opciones": [{"texto": "Mandamos patrullas. No se deje ver.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Me acerco a ver las matrículas?",
				"opciones": [
					{"texto": "No. Quédese en la garita, apague la luz y vaya contándome lo que ve.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Sí, acérquese y apunte las matrículas.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "Entendido. Apago la luz y no me muevo.", "fin": true},
			"fin_mal": {"texto": "Vale... me acerco con cuidado...", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"tabaco": "Camión cargado de cajas de tabaco de contrabando. Varios intentan escapar.",
					"droga": "¡Fardos de hachís, central! Mucha cantidad. Hay gente armada dentro. ¿Entramos o esperamos?",
					"huida": "Han salido a toda velocidad en dos furgonetas al vernos. Han dejado parte de la carga."},
				"efectos_por_desenlace": {"droga": {"confirmado": "Alijo de hachís en la nave"}, "tabaco": {"confirmado": "Tabaco de contrabando"}, "_": {}}},
			{"id": "decision_alijo", "cuando": "llegada", "servicio": "policia", "desenlaces": ["droga"],
				"decision": {"titulo": "Alijo en la nave", "opciones": [
					{"texto": "Entrar ya, antes de que se lleven la droga", "efectos": {"marca": "entrar", "duracion": -3.0}},
					{"texto": "Rodear la nave y esperar más agentes", "efectos": {"marca": "rodear", "requiere": {"policia": 3}, "duracion": 4.0}}]}},
			{"id": "vigilante_herido", "cuando": "tiempo", "segundos": 40.0, "si_marca": "consejo_malo",
				"radio": "Central: el vigilante se acercó a los camiones y le han dado una paliza. Necesita una ambulancia.",
				"efectos": {"requiere": {"ambulancia": 1}, "traslado": true, "marca": "vigilante_herido"}},
		],
		"finales": [
			{"desenlace": "droga", "marca": "rodear", "texto": "Nave rodeada: seis detenidos y 800 kilos de hachís intervenidos. ¡Golpe al narcotráfico!", "estrellas": 2},
			{"desenlace": "droga", "marca": "entrar", "texto": "Tres detenidos y parte del alijo intervenido, pero varios escaparon con droga. Un agente herido.", "estrellas": 0},
			{"desenlace": "droga", "texto": "Alijo de hachís intervenido en el polígono. Varios detenidos.", "estrellas": 1},
			{"desenlace": "tabaco", "marca": "vigilante_herido", "texto": "Tabaco de contrabando intervenido, pero el vigilante resultó herido.", "estrellas": -1},
			{"desenlace": "tabaco", "texto": "Camión de tabaco de contrabando intervenido. Cuatro detenidos.", "estrellas": 1},
			{"desenlace": "huida", "texto": "Los contrabandistas huyeron, pero dejaron parte de la carga y una furgoneta."},
		],
	},
	# ================================================================
	# PARTO EN UN COCHE
	# ================================================================
	{
		"id": "parto", "turno": "ambos", "tipo": "llamada",
		"referencias": ["gasolinera", "supermercado", "plaza", "sanidad"],
		"llamantes": [
			{"desc": "Hombre, unos 30 años (el padre)", "calma": 15, "nombres": ["Álvaro", "Sergio", "Jorge", "Pablo"],
				"personalidades": [["histérico", -15], ["muy nervioso", -5], ["sorprendentemente sereno", 20]]},
		],
		"estados": ["Histérico", "Muy nervioso", "Nervioso", "Tranquilo"],
		"desenlaces": {"bien": {"peso": 4}, "cordon": {"peso": 2}, "ya": {"peso": 2}},
		"incidente": {"titulo": "Parto inminente dentro de un coche", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 60.0, "intervencion": 10.0, "categoria": "medico", "requeridas": {"ambulancia": 1}, "traslado": true},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Mi mujer está de parto! ¡Íbamos al hospital y dice que ya sale! ¡He parado el coche!",
					"¡Que viene el niño! ¡Estamos en el coche y no llegamos a Ciudad Real!",
					"¡Ayuda! ¡Ha roto aguas en el coche y dice que tiene que empujar!"],
				"opciones": [
					{"texto": "Enhorabuena, le voy a ayudar. ¿Cada cuánto tiene las contracciones?", "efectos": {"calma": 15}, "ir_a": "contracciones"},
					{"texto": "¿Ve ya la cabeza del bebé?", "ir_a": "cabeza"},
					{"texto": "¿Dónde han parado el coche?", "ir_a": "donde"}]},
			"contracciones": {"texto_por_desenlace": {"ya": "¡Seguidas! ¡No para! ¡Está empujando ya!", "_": "Cada dos minutos o menos... ¡grita muchísimo!"},
				"efectos_por_desenlace": {"ya": {"urgencia": 40.0, "info": "Contracciones continuas: el bebé está saliendo"}, "_": {"info": "Contracciones cada dos minutos"}},
				"opciones": [
					{"texto": "¿Ve ya la cabeza del bebé?", "ir_a": "cabeza"},
					{"texto": "¿Dónde están?", "ir_a": "donde"}]},
			"cabeza": {"si_desenlace": {"ya": "sale"}, "texto": "¡Sí! ¡Se ve la cabecita! ¡Madre mía!", "efectos": {"info": "Se ve la cabeza del bebé"},
				"opciones": [{"texto": "Muy bien. Dígame dónde están y le guío paso a paso.", "efectos": {"calma": 10}, "ir_a": "donde"}]},
			"sale": {"texto": "¡Está saliendo! ¡Está saliendo ya! ¡¿Qué hago?!", "efectos": {"calma": -10, "confirmado": "El bebé está naciendo"},
				"opciones": [
					{"texto": "Ponga las manos debajo para recibirlo, sin tirar. Deje que salga solo.", "efectos": {"marca": "parto_guiado", "calma": 15}, "ir_a": "nacido"},
					{"texto": "Tire de la cabeza con cuidado para ayudar.", "efectos": {"marca": "consejo_malo", "calma": -10}, "ir_a": "nacido"}]},
			"donde": {"texto": "En el arcén, al lado de {lugar}, en {calle}.", "efectos": {"precision": 3, "info": "{calle}, junto a {lugar}"},
				"opciones": [{"texto": "La ambulancia va para allá. Ahora escúcheme bien.", "ir_a": "guia"}]},
			"guia": {"si_desenlace": {"cordon": "cordon"}, "sorpresa": {"prob": 0.7, "ir_a": "sale", "desenlaces": ["bien"]},
				"texto": "¡Vale! ¿Qué hago?",
				"opciones": [
					{"texto": "Recline el asiento, ponga toallas o ropa limpia debajo y prepare algo para abrigar al bebé.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "espera"},
					{"texto": "Siga conduciendo hacia el hospital lo más rápido posible.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"cordon": {"texto": "¡Ya ha salido la cabeza! ¡Pero tiene el cordón enrollado en el cuello!", "efectos": {"calma": -15, "confirmado": "Cordón umbilical alrededor del cuello", "urgencia": 35.0},
				"opciones": [
					{"texto": "Con un dedo, pase el cordón con suavidad por encima de la cabeza del bebé. Sin tirar.", "efectos": {"marca": "cordon_bien", "calma": 10}, "ir_a": "nacido"},
					{"texto": "Corte el cordón con lo que tenga.", "efectos": {"marca": "consejo_malo", "calma": -10}, "ir_a": "nacido"}]},
			"nacido": {"texto": "¡Ya está fuera! ¡Es una niña! ...pero no llora...", "efectos": {"calma": -5},
				"opciones": [
					{"texto": "Séquela con una toalla y frótele la espalda con suavidad. Póngala sobre el pecho de la madre.", "efectos": {"marca": "consejo_bueno", "calma": 20}, "ir_a": "llora"},
					{"texto": "Póngala boca abajo y dele una palmada.", "efectos": {"marca": "consejo_malo"}, "ir_a": "llora"}]},
			"llora": {"texto": "¡Llora! ¡Está llorando! (se oye un llanto de bebé) ¡Gracias, gracias!", "efectos": {"calma": 30}, "fin": true},
			"espera": {"texto": "Vale... toallas... ya está. ¡Viene otra contracción!", "fin": true},
			"fin_mal": {"texto": "¿Conducir? ¡Pero si está empujando!... Vale, arranco...", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_ambulancia", "cuando": "llegada", "servicio": "ambulancia",
				"radio_por_desenlace": {"cordon": "Recién nacida con algo de dificultad para respirar. La atendemos.", "_": "Madre y bebé en buen estado. Cortamos el cordón y los trasladamos."}},
		],
		"finales": [
			{"desenlace": "cordon", "marca": "cordon_bien", "texto": "¡Ha nacido una niña en un coche guiada por la central! Madre e hija, perfectas.", "estrellas": 2},
			{"desenlace": "cordon", "empeorado": true, "texto": "La recién nacida sufrió falta de oxígeno: ingresada en la UCI neonatal.", "estrellas": -1, "exito_final": false},
			{"desenlace": "cordon", "texto": "Bebé nacida con el cordón al cuello: está en observación, pero bien."},
			{"desenlace": "ya", "marca": "parto_guiado", "texto": "¡Parto atendido por teléfono! Madre y bebé trasladados en perfecto estado.", "estrellas": 2},
			{"desenlace": "bien", "marca": "consejo_malo", "texto": "Parto en el arcén con algún susto, pero todo ha salido bien."},
			{"desenlace": "bien", "texto": "¡Bebé nacido en un coche en Miguelturra! Todos sanos y trasladados.", "estrellas": 1},
			{"texto": "Madre y bebé trasladados al hospital.", "estrellas": 1},
		],
	},
	# ================================================================
	# EXPLOSIÓN DE BUTANO
	# ================================================================
	{
		"id": "butano", "turno": "dia", "tipo": "incendio",
		"referencias": ["edificio", "plaza", "iglesia", "colegio"],
		"llamantes": [
			{"desc": "Vecino, unos 60 años", "calma": 20, "nombres": ["Tomás", "Agustín", "Benito", "Jacinto"],
				"personalidades": [["aturdido", -10], ["muy nervioso", -15], ["entero", 10]]},
		],
		"estados": ["Aturdido", "Muy nervioso", "Nervioso", "Tranquilo"],
		"desenlaces": {"cocina": {"peso": 3}, "derrumbe": {"peso": 2}, "fuga": {"peso": 2}},
		"incidente": {"titulo": "Explosión de una bombona de butano", "servicios": ["bomberos", "ambulancia"], "principal": "bomberos",
			"urgencia": 55.0, "intervencion": 16.0, "categoria": "fuego", "requeridas": {"bomberos": 1, "ambulancia": 1}, "traslado": true},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Ha habido una explosión en la casa de al lado! ¡Han reventado los cristales!",
					"¡Un estruendo enorme! ¡Ha explotado algo en casa de la vecina, sale humo!",
					"¡Creo que ha explotado una bombona! ¡Se ha caído media fachada!"],
				"opciones": [
					{"texto": "¿Hay alguien dentro de la casa?", "ir_a": "dentro"},
					{"texto": "¿Hay fuego? ¿Huele a gas?", "ir_a": "fuego"},
					{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"dentro": {"texto_por_desenlace": {"derrumbe": "¡La vecina estaba dentro! ¡Se ha caído el techo de la cocina y la oigo gritar debajo!",
					"cocina": "La vecina ha salido a rastras... tiene quemaduras en los brazos y en la cara.",
					"fuga": "No, no ha explotado del todo: la vecina ha salido diciendo que olía muchísimo a gas y ha oído un chasquido."},
				"efectos_por_desenlace": {"derrumbe": {"confirmado": "Mujer atrapada bajo los escombros", "requiere": {"bomberos": 2}, "categoria": "atrapado", "urgencia": 40.0},
					"cocina": {"info": "Mujer con quemaduras en brazos y cara", "heridos": 1},
					"fuga": {"info": "Fuga de gas, posible deflagración pequeña", "quitar": "ambulancia", "traslado": false}},
				"opciones": [
					{"texto": "¿Hay fuego?", "ir_a": "fuego"},
					{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"fuego": {"texto_por_desenlace": {"fuga": "No hay fuego, pero el olor a gas es tremendo en toda la calle.", "_": "Sale humo negro por la ventana y huele a quemado."},
				"efectos_por_desenlace": {"fuga": {"confirmado": "Fuerte olor a gas en la calle"}, "_": {"intensidad": 2}},
				"opciones": [{"texto": "¿Dónde es?", "ir_a": "donde"}]},
			"donde": {"texto": "En {calle}, cerca de {lugar}.", "efectos": {"precision": 3, "info": "{calle}, cerca de {lugar}"},
				"opciones": [{"texto": "Bomberos y ambulancia van para allá.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Qué hacemos los vecinos?",
				"opciones": [
					{"texto": "Salgan todos de las casas de alrededor, no enciendan nada, ni luces ni móviles cerca, y aléjense.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Entren a cerrar la llave del gas de la vecina.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"fin": {"texto": "¡Vale! ¡Todo el mundo fuera!", "fin": true},
			"fin_mal": {"texto": "Vale... entro un momento... huele fatal...", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_bomberos", "cuando": "llegada", "servicio": "bomberos",
				"radio_por_desenlace": {
					"derrumbe": "Derrumbe parcial. Hay una mujer atrapada bajo el techo de la cocina. Apuntalamos y excavamos.",
					"cocina": "Cocina destrozada y fuego pequeño. Lo apagamos. Cortamos el gas de la vivienda.",
					"fuga": "Fuga de gas localizada y cerrada. Ventilamos la casa. Por poco."},
				"efectos_por_desenlace": {"fuga": {"duracion": -6.0}, "_": {}}},
			{"id": "vecino_intoxicado", "cuando": "tiempo", "segundos": 35.0, "si_marca": "consejo_malo",
				"radio": "Central: un vecino entró en la casa a cerrar el gas y se ha desmayado. Necesitamos otra ambulancia.",
				"efectos": {"requiere": {"ambulancia": 2}, "marca": "vecino_intoxicado", "heridos": 2}},
		],
		"finales": [
			{"desenlace": "derrumbe", "empeorado": true, "texto": "La vecina atrapada en el derrumbe ha fallecido antes de poder sacarla.", "fallecido": true, "exito_final": false},
			{"desenlace": "derrumbe", "texto": "La vecina, rescatada con vida de entre los escombros tras una hora de trabajo.", "estrellas": 1},
			{"desenlace": "cocina", "marca": "vecino_intoxicado", "texto": "Herida por quemaduras y un vecino intoxicado por entrar en la casa.", "estrellas": -1},
			{"desenlace": "cocina", "texto": "Explosión controlada: una herida con quemaduras, trasladada al hospital."},
			{"desenlace": "fuga", "texto": "Fuga de gas controlada a tiempo. Ningún herido.", "estrellas": 1},
		],
	},
	# ================================================================
	# SUSTRACCIÓN DE UN MENOR POR SU PADRE
	# ================================================================
	{
		"id": "sustraccion", "turno": "dia", "tipo": "llamada",
		"referencias": ["colegio", "parque", "plaza"],
		"llamantes": [
			{"desc": "Madre, unos 35 años", "calma": 15, "nombres": ["Raquel", "Silvia", "Marta", "Ana"],
				"personalidades": [["desesperada", -15], ["muy nerviosa", -5], ["firme", 10]]},
		],
		"estados": ["Desesperada", "Muy nerviosa", "Nerviosa", "Tranquila"],
		"desenlaces": {"huye": {"peso": 2}, "parque": {"peso": 3}, "visita": {"peso": 2}},
		"incidente": {"titulo": "Padre que se lleva a su hijo sin permiso", "servicios": ["policia"], "principal": "policia",
			"urgencia": 70.0, "intervencion": 12.0, "categoria": "busqueda", "requeridas": {"policia": 1}, "traslado": false},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"textos": ["¡Mi exmarido se ha llevado a mi hijo de la puerta del colegio! ¡Tiene una orden de alejamiento!",
					"¡Se lo ha llevado! ¡El padre de mi hijo lo ha metido en el coche y se ha ido!",
					"Por favor... mi ex ha recogido al niño sin decirme nada y no me coge el teléfono."],
				"opciones": [
					{"texto": "¿Hay alguna orden judicial sobre la custodia?", "ir_a": "orden"},
					{"texto": "¿En qué coche iban? ¿Hacia dónde?", "ir_a": "coche"},
					{"texto": "¿Desde dónde me llama?", "ir_a": "donde"}]},
			"orden": {"texto_por_desenlace": {"visita": "Bueno... hoy le tocaría a él, pero habíamos quedado en cambiarlo... no sé.", "_": "¡Sí! No puede acercarse al niño sin permiso del juzgado."},
				"efectos_por_desenlace": {"visita": {"info": "Hoy podría ser su día de visita"}, "_": {"confirmado": "Hay una orden judicial que se lo impide"}},
				"opciones": [
					{"texto": "¿En qué coche iban?", "ir_a": "coche"},
					{"texto": "¿Desde dónde me llama?", "ir_a": "donde"}]},
			"coche": {"texto_por_desenlace": {"huye": "¡Un coche rojo! ¡Ha salido hacia la carretera de Ciudad Real!", "_": "Un coche rojo... no sé hacia dónde, iba despacio."},
				"efectos_por_desenlace": {"huye": {"info": "Coche rojo hacia la salida a Ciudad Real", "urgencia": 50.0, "requiere": {"policia": 2}}, "_": {"info": "Coche rojo, sin dirección clara"}},
				"opciones": [{"texto": "¿Desde dónde me llama?", "ir_a": "donde"}]},
			"donde": {"texto": "Desde la puerta de {lugar}, en {calle}.", "efectos": {"precision": 3, "info": "{calle}, puerta de {lugar}"},
				"opciones": [{"texto": "Una patrulla va para allá y avisamos al resto.", "ir_a": "consejos"}]},
			"consejos": {"texto": "¿Voy detrás con mi coche?",
				"opciones": [
					{"texto": "No. Espere a la patrulla y tenga a mano una foto reciente del niño.", "efectos": {"marca": "consejo_bueno", "calma": 10}, "ir_a": "fin"},
					{"texto": "Sí, intente alcanzarle.", "efectos": {"marca": "consejo_malo"}, "ir_a": "fin"}]},
			"fin": {"texto": "Vale... tengo una foto en el móvil. ¡Encuéntrenlo, por favor!", "fin": true},
		},
		"llamadas": {},
		"eventos": [
			{"id": "llega_policia", "cuando": "llegada", "servicio": "policia",
				"radio_por_desenlace": {
					"huye": "Coche localizado saliendo del pueblo. Le damos el alto en la rotonda.",
					"parque": "Encontrado en el parque con el niño. Está tranquilo; hablamos con él.",
					"visita": "Hablamos con los dos: era su día de visita y hubo un malentendido."},
				"efectos_por_desenlace": {"visita": {"categoria": "control", "duracion": -5.0}, "_": {}}},
		],
		"finales": [
			{"desenlace": "huye", "empeorado": true, "texto": "El padre salió del pueblo con el niño. La Guardia Civil lo intercepta horas después.", "exito_final": false},
			{"desenlace": "huye", "texto": "Coche interceptado en la salida del pueblo. El niño, sano y salvo con su madre. Padre detenido.", "estrellas": 1},
			{"desenlace": "parque", "texto": "Niño devuelto a su madre. El padre, denunciado por incumplir la orden judicial.", "estrellas": 1},
			{"desenlace": "visita", "texto": "Malentendido con el régimen de visitas. Los agentes median entre los padres."},
		],
	},
]
