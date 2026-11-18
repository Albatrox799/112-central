extends RefCounted
## LLAMADAS NUEVAS (0.97)
## Para no escribir cada conversación entera, las llamadas sencillas se
## describen en pocas líneas y construir() monta la conversación completa
## (dónde, qué ha pasado, pregunta clave, consejos...). Con las preguntas
## extra y las personalidades, cada vez salen distintas.
##
## Llamada real:
##   "inicio": varias frases posibles para empezar
##   "que": [respuesta a «qué ha pasado», dato]
##   "clave": [pregunta clave, respuesta, dato, efectos extra (opcional)]
##   "bueno"/"malo": [consejo del operador, respuesta]
##   "linea": "fijo" para que salga la dirección del abonado al localizar
## Llamada falsa: "falsa": true, "inicio", "aclara" (lo que dice al final)

const SIMPLES := [
	# ======================================================== DÍA
	{"id": "atragantamiento", "turno": "dia", "llamante": "Madre, unos 35 años", "calma": 15,
		"referencias": ["parque", "colegio", "plaza", "restaurante"],
		"incidente": {"titulo": "Niño atragantado", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 55.0, "traslado": true, "intervencion": 8.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["¡Mi hijo se ha atragantado con una gominola! ¡No puede respirar bien!", "¡Ayuda! ¡El niño se está ahogando, se ha tragado algo!"],
		"que": ["Estaba comiendo y de repente se ha puesto rojo y tose muchísimo.", "Niño de 4 años atragantado con un caramelo"],
		"clave": ["¿Tose o llora? ¿Le sale algo de voz?", "Tose... tose fuerte y llora un poco.", "El niño tose: obstrucción parcial"],
		"bueno": ["Anímele a seguir tosiendo y no le meta los dedos en la boca. Si deja de toser, le digo qué hacer.", "Vale... ¡tose, cariño, tose!"],
		"malo": ["Póngalo boca abajo y sacúdalo fuerte.", "¿Sacudirlo? ¡Es muy pequeño! Bueno... lo intento..."]},
	{"id": "golpe_calor", "turno": "dia", "llamante": "Encargado de obra", "calma": 45,
		"referencias": ["edificio", "colegio", "deporte", "comercio"],
		"incidente": {"titulo": "Trabajador con golpe de calor", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 80.0, "traslado": true, "intervencion": 10.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["Llamo desde una obra. Uno de mis chicos se ha mareado y está muy raro, con este calor...", "Oiga, tengo a un albañil que se ha desplomado en el andamio de abajo. Está ardiendo."],
		"que": ["Estaba en la hormigonera, ha empezado a decir tonterías y se ha caído al suelo.", "Trabajador confuso y caliente tras horas al sol"],
		"clave": ["¿Suda o tiene la piel seca?", "Está rojo y seco, quema al tocarlo.", "Piel seca y muy caliente: golpe de calor", {"urgencia": 60.0}],
		"bueno": ["Llévenlo a la sombra, quítenle ropa y mójenle con agua fresca, sin hielo.", "Vale, lo metemos debajo del toldo y le echamos agua."],
		"malo": ["Denle una cerveza fría para que se recupere.", "¿Una cerveza? Bueno... hay en la nevera..."]},
	{"id": "ciclista", "turno": "dia", "llamante": "Conductor, unos 60 años", "calma": 25,
		"referencias": ["gasolinera", "deporte", "supermercado", "parque"],
		"incidente": {"titulo": "Ciclista atropellado", "servicios": ["ambulancia", "policia"], "principal": "ambulancia",
			"urgencia": 70.0, "traslado": true, "intervencion": 11.0, "categoria": "medico", "requeridas": {"ambulancia": 1, "policia": 1}},
		"inicio": ["¡Dios mío, he atropellado a un ciclista! ¡No lo he visto, de verdad!", "¡Ha salido de golpe! ¡Le he dado a un chico con la bici!"],
		"que": ["Estaba girando y se me ha metido por la derecha. Está en el suelo con la bici debajo.", "Ciclista arrollado por un turismo"],
		"clave": ["¿Lleva casco? ¿Se mueve?", "Lleva casco, se mueve pero dice que no siente la pierna.", "Ciclista con casco, consciente, dolor en una pierna"],
		"bueno": ["No le quite el casco ni lo mueva. Ponga los triángulos y quédese con él.", "Vale, pongo los triángulos. No lo toco."],
		"malo": ["Quítele el casco para que respire mejor.", "Vale... se lo intento quitar... grita mucho..."]},
	{"id": "nino_coche", "turno": "dia", "llamante": "Mujer, unos 50 años", "calma": 20,
		"referencias": ["supermercado", "comercio", "deporte"],
		"incidente": {"titulo": "Bebé encerrado en un coche al sol", "servicios": ["bomberos", "policia"], "principal": "bomberos",
			"urgencia": 60.0, "traslado": false, "intervencion": 7.0, "categoria": "atrapado", "requeridas": {"bomberos": 1}},
		"inicio": ["¡Hay un bebé dentro de un coche cerrado en el aparcamiento y está llorando muchísimo!", "¡Socorro! ¡Un niño pequeño encerrado en un coche al sol! ¡No hay nadie!"],
		"que": ["El coche está cerrado con llave, las ventanillas subidas y hace un calor horrible.", "Bebé atrapado en un coche cerrado al sol"],
		"clave": ["¿Sigue llorando o está quieto?", "Ahora llora menos... está muy colorado.", "El bebé empieza a estar decaído", {"urgencia": 45.0}],
		"bueno": ["Si deja de responder, rompa la ventanilla más alejada del bebé. Si no, espere a los bomberos.", "Vale, tengo una piedra preparada... de momento llora."],
		"malo": ["Váyase a buscar al dueño por las tiendas.", "¿Y dejo al niño solo? Bueno... voy..."]},
	{"id": "avispa", "turno": "dia", "llamante": "Hombre, unos 40 años", "calma": 25,
		"referencias": ["parque", "deporte", "plaza"],
		"incidente": {"titulo": "Reacción alérgica grave por picadura", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 50.0, "traslado": true, "intervencion": 8.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["¡A mi mujer le ha picado una avispa y se le está hinchando la cara!", "¡Es alérgica! ¡Le ha picado algo y le cuesta respirar!"],
		"que": ["Estábamos merendando en el césped y le ha picado en el cuello.", "Picadura en el cuello en persona alérgica"],
		"clave": ["¿Lleva encima su autoinyector de adrenalina?", "¡Sí! Lo lleva en el bolso, ¿se lo pongo?", "Lleva autoinyector de adrenalina"],
		"bueno": ["Sí: en el muslo, por fuera, y mantenga diez segundos. Déjela sentada.", "Ya está... parece que respira algo mejor."],
		"malo": ["Póngale barro en la picadura y espere.", "¿Barro? Bueno... pero cada vez respira peor..."]},
	{"id": "tiron", "turno": "dia", "llamante": "Mujer mayor, 78 años", "calma": 30,
		"referencias": ["plaza", "iglesia", "comercio", "supermercado"],
		"incidente": {"titulo": "Robo de bolso por el método del tirón", "servicios": ["policia"], "principal": "policia",
			"urgencia": 90.0, "traslado": false, "intervencion": 9.0, "categoria": "robo", "requeridas": {"policia": 1}},
		"inicio": ["¡Me han robado el bolso! ¡Un chico en moto me ha dado un tirón!", "Ay, hijo, que me han tirado al suelo para quitarme el bolso..."],
		"que": ["Salía de la iglesia y un muchacho en un ciclomotor me ha arrancado el bolso. Me he caído.", "Tirón desde un ciclomotor, la víctima ha caído al suelo"],
		"clave": ["¿Se ha hecho daño al caer?", "Me duele la muñeca y tengo sangre en la rodilla.", "La víctima tiene heridas leves", {"requiere": {"ambulancia": 1}}],
		"bueno": ["Siéntese en un banco, no vaya detrás de él. La patrulla va para allá.", "Sí, me siento... qué susto, Dios mío."],
		"malo": ["Intente seguirle para ver por dónde va.", "¿Yo? ¿Con mis años? Bueno... lo intento..."]},
	{"id": "hurto_super", "turno": "dia", "llamante": "Vigilante de seguridad", "calma": 60,
		"referencias": ["supermercado", "comercio"],
		"incidente": {"titulo": "Hurto retenido en un supermercado", "servicios": ["policia"], "principal": "policia",
			"urgencia": 120.0, "traslado": false, "intervencion": 8.0, "categoria": "control", "requeridas": {"policia": 1}},
		"inicio": ["Buenas, soy el vigilante. Tenemos retenido a un hombre que ha intentado salir con botellas debajo del abrigo.", "Central, llamo del súper: hemos pillado a uno robando y se está poniendo violento."],
		"que": ["Llevaba seis botellas de whisky escondidas. Ahora dice que se quiere ir.", "Hurto de bebidas, el sospechoso retenido por seguridad"],
		"clave": ["¿Está agresivo? ¿Lleva algo peligroso?", "Está nervioso, pero no veo nada. Lo tengo en la trastienda.", "Retenido en la trastienda, sin armas a la vista"],
		"bueno": ["No le retenga por la fuerza si quiere irse: fíjese en él y espere a la patrulla.", "Entendido, no me la juego. Le tengo vigilado."],
		"malo": ["Si se pone tonto, dele un buen escarmiento.", "Bueno... yo sé cómo tratar a estos..."]},
	{"id": "perro_suelto", "turno": "dia", "llamante": "Repartidor", "calma": 35,
		"referencias": ["parque", "colegio", "plaza"],
		"incidente": {"titulo": "Perro suelto agresivo cerca de un colegio", "servicios": ["policia"], "principal": "policia",
			"urgencia": 85.0, "traslado": false, "intervencion": 9.0, "categoria": "busqueda", "requeridas": {"policia": 1}},
		"inicio": ["Hay un perro enorme suelto que ha mordido a otro perro y está gruñendo a la gente.", "¡Oiga, un perrazo suelto sin dueño, se ha tirado a mi furgoneta!"],
		"que": ["Es tipo pitbull, sin collar. Los niños están a punto de salir del cole.", "Perro de raza potencialmente peligrosa sin dueño"],
		"clave": ["¿Ha mordido a alguna persona?", "A una persona no, al perrillo de una señora.", "Ha mordido a otro perro, no a personas"],
		"bueno": ["Avise para que nadie se acerque y no intente cogerlo.", "Vale, aviso en la puerta del colegio."],
		"malo": ["Intente atraerlo con comida y agárrelo del cuello.", "¿Del cuello? ¿A eso? Bueno..."]},
	{"id": "dolor_pecho_dia", "turno": "ambos", "llamante": "Mujer, unos 55 años", "calma": 25,
		"referencias": ["iglesia", "plaza", "supermercado", "sanidad", "edificio"],
		"linea": "fijo",
		"incidente": {"titulo": "Dolor fuerte en el pecho", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 55.0, "traslado": true, "intervencion": 10.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["Mi marido... tiene un dolor horrible en el pecho, le baja por el brazo.", "Llamo desde casa, a mi marido le duele mucho el pecho y está sudando."],
		"que": ["Estaba en el sofá y de repente se ha agarrado el pecho. Dice que le aprieta.", "Dolor opresivo en el pecho que baja al brazo"],
		"clave": ["¿Suda? ¿Tiene mal color?", "Sí, está pálido y sudando frío.", "Pálido y con sudor frío: posible infarto", {"urgencia": 45.0}],
		"bueno": ["Que esté sentado, sin hacer esfuerzos. Abra la puerta para los sanitarios.", "Vale, le dejo sentado y abro la puerta."],
		"malo": ["Que camine un poco para ver si se le pasa.", "¿Que camine? Bueno... ¡Pepe, levanta!"]},
	{"id": "caida_escalera", "turno": "ambos", "llamante": "Vecino, unos 30 años", "calma": 40,
		"referencias": ["edificio", "plaza", "iglesia"],
		"incidente": {"titulo": "Caída por las escaleras de un bloque", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 85.0, "traslado": true, "intervencion": 11.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["Se ha caído una vecina por las escaleras del portal, está abajo del todo.", "Oiga, he oído un golpe tremendo: la del tercero se ha caído rodando por la escalera."],
		"que": ["Ha rodado un tramo entero. Está quejándose de la espalda.", "Caída por las escaleras con dolor de espalda"],
		"clave": ["¿Puede mover las piernas?", "Dice que sí, pero le duele mucho la espalda.", "Mueve las piernas, dolor de espalda"],
		"bueno": ["No la mueva ni la siente. Tápela y háblele hasta que lleguen.", "Vale, le pongo una manta. Tranquila, Encarna."],
		"malo": ["Ayúdela a subir a su casa para que esté más cómoda.", "Vale... la cojo de los brazos..."]},
	# ======================================================== NOCHE
	{"id": "navaja", "turno": "noche", "llamante": "Chica joven, unos 20 años", "calma": 10,
		"referencias": ["bar", "plaza", "parque", "restaurante"],
		"incidente": {"titulo": "Pelea con navaja: hay un herido", "servicios": ["policia", "ambulancia"], "principal": "policia",
			"urgencia": 60.0, "traslado": true, "intervencion": 12.0, "categoria": "pelea", "requeridas": {"policia": 2, "ambulancia": 1}, "heridos": 1},
		"inicio": ["¡Han apuñalado a un chico! ¡Hay sangre por todas partes!", "¡Vengan ya, por favor! ¡Uno ha sacado una navaja y le ha dado a mi amigo!"],
		"que": ["Estaban discutiendo a la salida del bar y uno ha sacado una navaja. Le ha dado en el costado.", "Herido por arma blanca en el costado"],
		"clave": ["¿El agresor sigue ahí?", "¡Se ha ido corriendo hacia el parque! Lleva una chaqueta negra.", "Agresor huido a pie, chaqueta negra"],
		"bueno": ["Presione la herida con fuerza con una prenda limpia y no la suelte.", "Vale... aprieto... ¡aguanta, Dani!"],
		"malo": ["Sáquele lo que tenga clavado.", "¿Que se lo saque? ¡Ay, Dios!... bueno..."]},
	{"id": "ruido_fiesta", "turno": "noche", "llamante": "Vecino harto, unos 50 años", "calma": 55,
		"referencias": ["edificio", "plaza", "bar"],
		"incidente": {"titulo": "Fiesta con música a todo volumen", "servicios": ["policia"], "principal": "policia",
			"urgencia": 150.0, "traslado": false, "intervencion": 7.0, "categoria": "control", "requeridas": {"policia": 1}},
		"inicio": ["Son las tantas y los del piso de arriba tienen una fiesta con la música a tope. Mañana trabajo.", "Llamo por el ruido. Llevan desde las doce con música, gritos y botellas."],
		"que": ["Habrá veinte personas, se oyen golpes y han tirado algo por la ventana.", "Fiesta ruidosa con unas veinte personas"],
		"clave": ["¿Ha visto peleas o a alguien en peligro?", "Peleas no, pero han tirado una botella a la calle.", "Han tirado botellas a la calle"],
		"bueno": ["No suba a discutir. La patrulla irá a hablar con ellos.", "Vale, mejor no subo, que están muy bebidos."],
		"malo": ["Suba usted y córteles la luz del cuadro.", "Pues mira, sí, que ya estoy harto..."]},
	{"id": "trompos", "turno": "noche", "llamante": "Hombre, unos 35 años", "calma": 45,
		"referencias": ["supermercado", "deporte", "gasolinera"],
		"incidente": {"titulo": "Coche haciendo trompos y carreras", "servicios": ["policia"], "principal": "policia",
			"urgencia": 100.0, "traslado": false, "intervencion": 8.0, "categoria": "control", "requeridas": {"policia": 1}},
		"inicio": ["Hay unos chavales con un coche haciendo derrapes en el aparcamiento. Casi atropellan a uno.", "Llevan media hora con un coche quemando rueda y dando acelerones."],
		"que": ["Son varios, uno conduce y los demás graban con el móvil. Va a pasar algo.", "Conducción temeraria con público alrededor"],
		"clave": ["¿Cómo es el coche?", "Un coche blanco, bajito, con el tubo de escape enorme.", "Coche blanco con escape modificado"],
		"bueno": ["Apártese y no se ponga delante. La patrulla va para allá.", "Sí, sí, yo desde el portal."],
		"malo": ["Póngase en medio para que paren.", "¿En medio? Bueno... si usted lo dice..."]},
	{"id": "coma_etilico", "turno": "noche", "llamante": "Chico joven, unos 18 años", "calma": 30,
		"referencias": ["parque", "plaza", "bar", "deporte"],
		"incidente": {"titulo": "Joven inconsciente por alcohol", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 70.0, "traslado": true, "intervencion": 9.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["Mi colega ha bebido muchísimo y no se despierta. ¿Me van a multar?", "Oiga... una amiga está tirada en el suelo, ha bebido mucho y ha vomitado."],
		"que": ["Estábamos de botellón y se ha bebido media botella de ron él solo.", "Intoxicación etílica en un botellón"],
		"clave": ["¿Respira? ¿Está boca arriba?", "Respira raro y está boca arriba...", "Respira con dificultad, boca arriba"],
		"bueno": ["Póngalo de lado, con la cabeza hacia abajo, para que no se ahogue si vomita.", "Vale, de lado... ya está. Respira mejor."],
		"malo": ["Échele agua fría y dele un café.", "Vale... le echo agua... no se despierta..."]},
	{"id": "incendio_coche", "turno": "noche", "llamante": "Vecina, unos 40 años", "calma": 30,
		"referencias": ["edificio", "plaza", "supermercado", "gasolinera"],
		"incidente": {"titulo": "Coche ardiendo junto a otros aparcados", "servicios": ["bomberos"], "principal": "bomberos",
			"urgencia": 70.0, "traslado": false, "intervencion": 11.0, "categoria": "fuego", "requeridas": {"bomberos": 1}, "intensidad": 2},
		"inicio": ["¡Hay un coche ardiendo debajo de mi ventana! ¡Las llamas llegan al de al lado!", "¡Fuego! ¡Un coche está en llamas en la calle!"],
		"que": ["Ha empezado a salir humo del capó y ahora arde entero. Ha habido un pequeño estallido.", "Turismo en llamas que amenaza a otros coches"],
		"clave": ["¿Hay alguien dentro o cerca?", "No, está vacío. Pero hay gente asomada a los balcones.", "Vehículo vacío, vecinos asomados"],
		"bueno": ["Que nadie se acerque, puede estallar un neumático. Cierren las ventanas.", "Vale, aviso a los vecinos de que se metan."],
		"malo": ["Baje con un cubo de agua y vaya echándole.", "¿Yo? Bueno... voy a por un cubo..."]},
	{"id": "ruidos_casa", "turno": "noche", "llamante": "Mujer, unos 65 años, en voz baja", "calma": 15,
		"referencias": ["edificio", "iglesia", "parque"],
		"linea": "fijo",
		"incidente": {"titulo": "Ruidos de alguien dentro de una vivienda", "servicios": ["policia"], "principal": "policia",
			"urgencia": 70.0, "traslado": false, "intervencion": 10.0, "categoria": "robo", "requeridas": {"policia": 1}},
		"inicio": ["(susurrando) Hay alguien en mi casa... he oído romperse el cristal de la cocina...", "(muy bajito) Por favor... creo que han entrado en casa. Estoy en el dormitorio."],
		"que": ["Vivo sola. He oído un cristal y pasos abajo. Estoy encerrada arriba.", "Posible intruso en una vivienda, la víctima escondida arriba"],
		"clave": ["¿Ha visto a alguien? ¿Cuántos son?", "No lo he visto... pero creo que hablan dos personas.", "Posiblemente dos intrusos", {"requiere": {"policia": 2}}],
		"bueno": ["Quédese encerrada, en silencio, y no cuelgue. No baje.", "Vale... me quedo quieta... no cuelgo."],
		"malo": ["Baje con algo en la mano para asustarlos.", "¿Bajar? Ay... cojo el paraguas..."]},
	{"id": "conductor_ebrio", "turno": "noche", "llamante": "Camarero de un bar", "calma": 55,
		"referencias": ["bar", "restaurante", "gasolinera"],
		"incidente": {"titulo": "Conductor muy bebido a punto de conducir", "servicios": ["policia"], "principal": "policia",
			"urgencia": 60.0, "traslado": false, "intervencion": 7.0, "categoria": "control", "requeridas": {"policia": 1}},
		"inicio": ["Llamo del bar. Un cliente que no se tiene en pie se acaba de subir al coche.", "Oiga, uno muy borracho ha cogido el coche, le hemos dicho que no y nada."],
		"que": ["Ha estado bebiendo toda la tarde. Ha arrancado y ha rozado un coche al salir.", "Conductor ebrio que ya ha rozado un coche"],
		"clave": ["¿Hacia dónde va?", "Hacia la carretera de Ciudad Real, muy despacio y haciendo eses.", "Va hacia la salida del pueblo haciendo eses"],
		"bueno": ["No le persiga. Si ve la matrícula, dígamela.", "Vale. Me quedo aquí, la apunto."],
		"malo": ["Vaya detrás con su coche y ciérrele el paso.", "¿Yo? Bueno... cojo las llaves..."]},
	{"id": "pelea_parque", "turno": "noche", "llamante": "Hombre, unos 45 años", "calma": 30,
		"referencias": ["parque", "plaza", "deporte"],
		"incidente": {"titulo": "Pelea multitudinaria en un parque", "servicios": ["policia"], "principal": "policia",
			"urgencia": 70.0, "traslado": false, "intervencion": 12.0, "categoria": "pelea", "requeridas": {"policia": 2}},
		"inicio": ["¡Hay una pelea enorme en el parque, por lo menos diez chavales pegándose!", "¡Vengan! ¡Se están dando con palos y cinturones en el parque!"],
		"que": ["Parecen dos grupos. Uno ha caído al suelo y le siguen dando patadas.", "Pelea entre dos grupos, uno en el suelo"],
		"clave": ["¿Alguno está herido de gravedad?", "Uno no se levanta... tiene la cara llena de sangre.", "Hay un herido en el suelo", {"requiere": {"ambulancia": 1}, "traslado": true}],
		"bueno": ["No se meta. Fíjese en hacia dónde se van y quédese lejos.", "Vale, vale, me quedo en la esquina."],
		"malo": ["Grite que viene la policía para asustarlos.", "Bueno... ¡QUE VIENE LA POLICÍA!... ay, vienen hacia mí..."]},
	{"id": "convulsion", "turno": "noche", "llamante": "Compañero de piso", "calma": 20,
		"referencias": ["edificio", "plaza", "colegio"],
		"incidente": {"titulo": "Persona con convulsiones", "servicios": ["ambulancia"], "principal": "ambulancia",
			"urgencia": 65.0, "traslado": true, "intervencion": 9.0, "categoria": "medico", "requeridas": {"ambulancia": 1}},
		"inicio": ["¡Mi compañero de piso está en el suelo temblando entero! ¡No para!", "¡Le está dando un ataque! ¡Se mueve sin parar y echa espuma!"],
		"que": ["Estaba viendo la tele y se ha caído del sofá temblando. Lleva así un minuto.", "Convulsiones de más de un minuto"],
		"clave": ["¿Es epiléptico? ¿Le ha pasado antes?", "Creo que sí, toma unas pastillas.", "Posible epilepsia conocida"],
		"bueno": ["Aparte los muebles para que no se golpee y no le meta nada en la boca. Cuando pare, póngalo de lado.", "Vale, aparto la mesa... ya para un poco..."],
		"malo": ["Sujétele fuerte y métale una cuchara en la boca.", "¿Una cuchara? Bueno... voy a la cocina..."]},
	# ======================================================== FALSAS Y PESADAS
	{"id": "pizzeria", "turno": "ambos", "falsa": true, "llamante": "Hombre, unos 30 años", "calma": 80,
		"inicio": ["Hola, quería una barbacoa familiar y una de cuatro quesos para llevar.", "Buenas, ¿es la pizzería? Para pedir a domicilio."],
		"aclara": "¡Uy! Me he equivocado de número. Perdone, perdone."},
	{"id": "farmacia", "turno": "ambos", "falsa": true, "llamante": "Señora mayor", "calma": 75,
		"inicio": ["Hija, ¿me puede decir qué farmacia está de guardia hoy?", "Perdone, ¿a qué hora abre el centro de salud mañana?"],
		"aclara": "Ah, que esto es solo para urgencias... Pues lo miro en el periódico. Gracias, guapa."},
	{"id": "bolsillo", "turno": "ambos", "falsa": true, "llamante": "Desconocido (ruido de fondo)", "calma": 70,
		"inicio": ["(ruido de bolsillo, se oye una conversación lejana y risas)", "(se oye música y gente hablando, nadie contesta)"],
		"aclara": "¿Eh? ¿Quién es? ¡Ay, perdón, se me ha marcado solo el móvil!"},
	{"id": "bache", "turno": "dia", "falsa": true, "llamante": "Vecino quejica", "calma": 60,
		"inicio": ["Llamo para quejarme del bache de mi calle, que lleva así tres meses y nadie hace nada.", "¿Es el 112? Quiero poner una queja de las farolas, que están siempre apagadas."],
		"aclara": "Ya, ya, que llame al Ayuntamiento... Pues eso haré. ¡Y apunten lo del bache!"},
	{"id": "broma_ninos", "turno": "dia", "falsa": true, "llamante": "Voces de niños", "calma": 90,
		"inicio": ["(risas) ¿Es el 112? ¡Mi amigo dice que es usted un robot! (risas)", "(voz de niño) ¡Socorro! Jajaja... no, era broma..."],
		"aclara": "(se oyen risas y cuelgan)"},
	{"id": "tiempo", "turno": "noche", "falsa": true, "llamante": "Hombre, unos 70 años", "calma": 70,
		"inicio": ["Buenas noches. Es que no puedo dormir y quería saber si mañana va a llover.", "Oiga, ¿ustedes saben si mañana hay mercadillo?"],
		"aclara": "Ah, vale, vale... perdone, es que estoy solo y no tenía con quién hablar. Buenas noches."},
]


## Llamadas especiales escritas enteras: sin voz o con alguien desorientado.
## Aquí la localización automática de la llamada es casi lo único que hay.
const ESPECIALES := [
	{
		"id": "silenciosa", "turno": "ambos", "linea": "movil",
		"llamante": "Número oculto (nadie habla)", "calma_inicial": 20,
		"estados": ["Aterrorizada", "Muy asustada", "Asustada", "Algo más tranquila"],
		"referencias": ["edificio", "parque", "plaza", "iglesia"],
		"incidente": {"titulo": "Llamada silenciosa: posible persona en peligro", "servicios": ["policia"],
			"principal": "policia", "urgencia": 80.0, "traslado": false, "intervencion": 10.0,
			"categoria": "busqueda", "requeridas": {"policia": 1}},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"texto": "(Silencio. Se oye una respiración y, de fondo, a un hombre gritando.)",
				"opciones": [
					{"texto": "¿Hola? Emergencias, ¿me oye?", "ir_a": "silencio"},
					{"texto": "Si no puede hablar, pulse una tecla del teléfono.", "efectos": {"calma": 10}, "ir_a": "tecla"},
					{"texto": "Si nadie contesta, voy a colgar.", "efectos": {"calma": -20}, "ir_a": "cuelga"}]},
			"silencio": {"texto": "(Nada. Solo la respiración. El hombre de fondo dice: «¿Con quién hablas?»)",
				"efectos": {"info": "Se oye a un hombre gritando de fondo"},
				"opciones": [
					{"texto": "Si no puede hablar, pulse una tecla del teléfono.", "efectos": {"calma": 10}, "ir_a": "tecla"},
					{"texto": "¡Conteste! ¿Qué pasa?", "efectos": {"calma": -15}, "ir_a": "cuelga"}]},
			"tecla": {"texto": "(Bip.) (Se oye una tecla.)", "efectos": {"info": "La persona pulsa una tecla: necesita ayuda y no puede hablar", "marca": "consejo_bueno"},
				"opciones": [
					{"texto": "Le hago preguntas de sí o no. Una tecla, sí; dos, no. ¿Está en su casa?", "ir_a": "casa"},
					{"texto": "Le estamos localizando. No cuelgue y no haga ruido.", "efectos": {"calma": 10}, "ir_a": "casa"}]},
			"casa": {"texto": "(Bip.) (Una voz de mujer susurra:) «...está aquí... cerca de {lugar}...»",
				"efectos": {"precision": 2, "info": "Mujer en su casa, cerca de {lugar}; el agresor está con ella"},
				"opciones": [
					{"texto": "¿Está herida? Una tecla, sí.", "ir_a": "herida"},
					{"texto": "La patrulla va para allá. Si puede, enciérrese en una habitación.", "efectos": {"calma": 10, "marca": "consejo_bueno"}, "ir_a": "fin"}]},
			"herida": {"texto": "(Bip.) (Se oye un golpe y la llamada se corta.)", "efectos": {"info": "Está herida", "requiere": {"ambulancia": 1}, "traslado": true},
				"cuelga": true},
			"cuelga": {"texto": "(La llamada se corta.)", "cuelga": true},
			"fin": {"texto": "(Bip.) (Silencio. La llamada sigue abierta.)", "fin": true},
		},
	},
	{
		"id": "desorientado", "turno": "ambos", "linea": "movil",
		"llamante": "Hombre mayor, unos 82 años", "calma_inicial": 35,
		"estados": ["Muy asustado", "Perdido", "Confuso", "Tranquilo"],
		"referencias": ["parque", "deporte", "iglesia", "plaza"],
		"incidente": {"titulo": "Persona mayor desorientada y perdida", "servicios": ["policia"],
			"principal": "policia", "urgencia": 110.0, "traslado": false, "intervencion": 12.0,
			"categoria": "busqueda", "requeridas": {"policia": 1}},
		"inicio": "inicio",
		"nodos": {
			"inicio": {"texto": "Perdone... no sé dónde estoy. Salí a por el pan y ahora no conozco nada.",
				"opciones": [
					{"texto": "No se preocupe, le vamos a encontrar. ¿Cómo se llama?", "efectos": {"calma": 15}, "ir_a": "nombre"},
					{"texto": "¿En qué calle está?", "ir_a": "no_sabe"},
					{"texto": "¿Qué ve a su alrededor?", "ir_a": "ve"}]},
			"nombre": {"texto": "Me llamo Julián... vivo con mi hija, pero no me acuerdo del número de casa.", "efectos": {"info": "Se llama Julián, vive con su hija"},
				"opciones": [
					{"texto": "Muy bien, Julián. ¿Qué ve a su alrededor?", "efectos": {"calma": 10}, "ir_a": "ve"},
					{"texto": "¿Tiene el teléfono de su hija?", "ir_a": "hija"}]},
			"no_sabe": {"texto": "No lo sé... todas las calles me parecen iguales. Tengo frío.", "efectos": {"calma": -5},
				"opciones": [
					{"texto": "Tranquilo. Dígame qué ve: tiendas, una iglesia, un parque...", "efectos": {"calma": 10}, "ir_a": "ve"},
					{"texto": "¿Tiene el teléfono de su hija?", "ir_a": "hija"}]},
			"hija": {"texto": "Está apuntado en un papel... no lo encuentro. Ay, no sé.", "efectos": {"calma": -5},
				"opciones": [
					{"texto": "No pasa nada. ¿Qué ve a su alrededor?", "efectos": {"calma": 10}, "ir_a": "ve"}]},
			"ve": {"si_calma_menor": {"valor": 30, "ir_a": "confuso"},
				"texto": "Hay unos árboles... y a lo lejos se ve {lugar}, creo.", "efectos": {"precision": 2, "info": "Ve {lugar} a lo lejos"},
				"opciones": [
					{"texto": "Quédese ahí sentado, no se mueva. La policía va a buscarle.", "efectos": {"calma": 15, "marca": "consejo_bueno"}, "ir_a": "fin_bien"},
					{"texto": "Camine hacia allí y me dice qué pone en la calle.", "efectos": {"calma": -5, "marca": "consejo_malo"}, "ir_a": "fin_mal"}]},
			"confuso": {"texto": "No sé... ¿esto es Miguelturra? Antes vivía en otro sitio...", "efectos": {"calma": -5},
				"opciones": [
					{"texto": "Sí, está en Miguelturra. Respire. ¿Ve algún edificio grande?", "efectos": {"calma": 20}, "ir_a": "ve"}]},
			"fin_bien": {"texto": "Vale... me siento en este banco. Gracias, joven.", "fin": true},
			"fin_mal": {"texto": "Voy... voy andando... ¿Oiga? Se me va la batería... (se corta)", "cuelga": true},
		},
	},
]


## Devuelve todas las llamadas nuevas con su conversación completa.
static func construir() -> Array:
	var lista: Array = []
	for d in SIMPLES:
		if d.get("falsa", false):
			lista.append(_falsa(d))
		else:
			lista.append(_real(d))
	for d in ESPECIALES:
		lista.append(d)
	return lista


static func _real(d: Dictionary) -> Dictionary:
	var que: Array = d["que"]
	var clave: Array = d["clave"]
	var bueno: Array = d["bueno"]
	var malo: Array = d["malo"]
	var efectos_clave: Dictionary = {"info": clave[2]}
	if clave.size() > 3:
		for k in clave[3]:
			efectos_clave[k] = clave[3][k]
	var nodos := {
		"inicio": {"textos": d["inicio"],
			"opciones": [
				{"texto": "Está hablando con emergencias, le vamos a ayudar. ¿Dónde se encuentra?", "efectos": {"calma": 15}, "ir_a": "donde"},
				{"texto": "Cuénteme exactamente qué ha pasado.", "ir_a": "que"},
				{"texto": clave[0], "ir_a": "clave"}]},
		"que": {"si_calma_menor": {"valor": 22, "ir_a": "panico"}, "texto": que[0], "efectos": {"info": que[1]},
			"opciones": [
				{"texto": "Entendido. ¿Dónde está exactamente?", "efectos": {"calma": 8}, "ir_a": "donde"},
				{"texto": clave[0], "ir_a": "clave"}]},
		"clave": {"si_calma_menor": {"valor": 18, "ir_a": "panico"}, "texto": clave[1], "efectos": efectos_clave,
			"opciones": [
				{"texto": "Muy bien, lo está haciendo genial. ¿Dónde se encuentra?", "efectos": {"calma": 12}, "ir_a": "donde"},
				{"texto": "¿Qué ha pasado exactamente?", "ir_a": "que"}]},
		"panico": {"textos": ["¡No lo sé! ¡No sé qué hacer! ¡Vengan ya!", "¡Por favor, por favor, dense prisa!", "¡No puedo pensar! ¡Ayúdenme!"],
			"opciones": [
				{"texto": "Respire hondo conmigo. Estoy aquí y vamos paso a paso.", "efectos": {"calma": 25}, "ir_a": "que"},
				{"texto": "¡Cálmese y conteste a lo que le pregunto!", "efectos": {"calma": -10}, "ir_a": "panico2"}]},
		"panico2": {"textos": ["¡Le estoy diciendo que es urgente!", "¡No me grite!"],
			"opciones": [
				{"texto": "Perdone. Estoy con usted. Dígame solo dónde está.", "efectos": {"calma": 22}, "ir_a": "donde"}]},
		"donde": {"textos": ["Estoy en Miguelturra... con los nervios no sé ni la calle.", "En Miguelturra, en el pueblo, pero no sé decirle bien.", "Aquí, en Miguelturra... ¿no lo ve usted?"],
			"efectos": {"precision": 1},
			"opciones": [
				{"texto": "¿Qué ve a su alrededor? ¿Algún edificio o comercio?", "ir_a": "ref"},
				{"texto": "¿Sabe el nombre de la calle?", "ir_a": "calle"},
				{"texto": "¡Necesito la dirección exacta ya!", "efectos": {"calma": -20}, "ir_a": "brusco"}]},
		"ref": {"textos": ["Estoy justo al lado de {lugar}.", "Enfrente tengo {lugar}.", "A dos pasos de {lugar}."], "efectos": {"precision": 2, "info": "Junto a {lugar}"},
			"opciones": [
				{"texto": "¿Y la calle?", "ir_a": "calle"},
				{"texto": "¿Puede leer alguna placa con el nombre de la calle?", "ir_a": "placa"}]},
		"calle": {"si_calma_menor": {"valor": 38, "ir_a": "calle_nerv"}, "textos": ["Es {calle}, sí.", "Creo que {calle}... ¡sí, {calle}!"], "efectos": {"precision": 3, "info": "{calle}"},
			"opciones": [{"texto": "Perfecto, ya sé dónde está.", "ir_a": "consejos"}]},
		"placa": {"si_calma_menor": {"valor": 42, "ir_a": "calle_nerv"}, "texto": "Espere... pone «{calle}».", "efectos": {"precision": 3, "info": "{calle}"},
			"opciones": [{"texto": "Estupendo, ya sé dónde está.", "ir_a": "consejos"}]},
		"calle_nerv": {"texto": "¡No me sale! ¡No me puedo mover de aquí para mirar!", "efectos": {"calma": -5},
			"opciones": [
				{"texto": "No pasa nada. ¿Qué tiene cerca?", "efectos": {"calma": 12}, "ir_a": "ref"},
				{"texto": "Respire. Piense en por dónde ha venido. ¿Qué calle era?", "efectos": {"calma": 15}, "ir_a": "calle"}]},
		"brusco": {"textos": ["¡Que no lo sé! ¡No me grite!", "¡Bastante tengo ya!"],
			"opciones": [
				{"texto": "Perdone. Vamos con calma. ¿Qué ve a su alrededor?", "efectos": {"calma": 15}, "ir_a": "ref"}]},
		"consejos": {"textos": ["Vale... ¿y ahora qué hago?", "¿Qué hago mientras llegan?", "¿Y yo qué hago, me quedo aquí?"],
			"opciones": [
				{"texto": bueno[0], "efectos": {"calma": 15, "marca": "consejo_bueno"}, "ir_a": "fin_bien"},
				{"texto": malo[0], "efectos": {"calma": -10, "marca": "consejo_malo"}, "ir_a": "fin_mal"},
				{"texto": "Espere ahí, ya van.", "ir_a": "fin_neutro"}]},
		"fin_bien": {"texto": bueno[1], "fin": true},
		"fin_mal": {"texto": malo[1], "fin": true},
		"fin_neutro": {"textos": ["Vale... ¿tardarán mucho?", "Bueno... dense prisa, por favor."], "fin": true},
	}
	var r := {
		"id": d["id"], "turno": d["turno"], "llamante": d["llamante"], "calma_inicial": d.get("calma", 30),
		"referencias": d["referencias"], "incidente": d["incidente"], "inicio": "inicio", "nodos": nodos,
	}
	if d.has("linea"):
		r["linea"] = d["linea"]
	return r


static func _falsa(d: Dictionary) -> Dictionary:
	var nodos := {
		"inicio": {"textos": d["inicio"],
			"opciones": [
				{"texto": "Esto es el 112, solo para emergencias. ¿Tiene usted una emergencia?", "ir_a": "aclara"},
				{"texto": "¿Dónde se encuentra? ¿Qué le ocurre?", "ir_a": "lia"},
				{"texto": "¿Está usted bien? ¿Necesita ayuda?", "ir_a": "aclara"}]},
		"lia": {"textos": ["¿Eh? No, no... no me pasa nada.", "¿Cómo? Yo solo llamaba para... bueno..."],
			"opciones": [
				{"texto": "Esta línea es solo para emergencias. ¿Necesita ayuda o no?", "ir_a": "aclara"}]},
		"aclara": {"texto": d["aclara"], "efectos": {"info": "No es una emergencia"}, "fin": true},
	}
	return {"id": d["id"], "turno": d["turno"], "falsa": true, "llamante": d["llamante"], "calma_inicial": d.get("calma", 70),
		"referencias": ["plaza"], "inicio": "inicio", "nodos": nodos}
