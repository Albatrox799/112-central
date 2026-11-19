extends RefCounted
## CATÁLOGO DE LA TIENDA (nombres y modelos propios del juego)
##
## Vehículos: servicio, velocidad en emergencia (m/s reales), plazas de
## personal, precio y "bono" (ventaja especial en el lugar).
## Equipo: se compra para un vehículo concreto y da ventajas en los mini eventos.

const DINERO_INICIAL := 60000
const SUELDO_POR_TURNO := 150        # por persona y turno
const PRECIO_CONTRATAR := 2000       # coste de fichar a una persona
const TURNOS_BAJA := 2               # turnos que un herido está de baja

const VEHICULOS := {
	"patrulla": {"nombre": "Coche patrulla", "servicio": "policia", "velocidad": 75.0, "plazas": 2, "precio": 18000, "bono": ""},
	"moto": {"nombre": "Moto de policía", "servicio": "policia", "velocidad": 92.0, "plazas": 1, "precio": 9000, "bono": "rapida"},
	"furgon": {"nombre": "Furgón policial (4 detenidos)", "servicio": "policia", "velocidad": 62.0, "plazas": 4, "precio": 30000, "bono": "detenidos"},
	"ambulancia_b": {"nombre": "Ambulancia básica (1 herido)", "servicio": "ambulancia", "velocidad": 55.0, "plazas": 2, "precio": 40000, "bono": "", "camillas": 1},
	"ambulancia_sva": {"nombre": "Ambulancia de soporte vital avanzado (2 heridos)", "servicio": "ambulancia", "velocidad": 60.0, "plazas": 3, "precio": 65000, "bono": "medico", "camillas": 2},
	"autobomba": {"nombre": "Autobomba", "servicio": "bomberos", "velocidad": 45.0, "plazas": 4, "precio": 120000, "bono": ""},
	"escalera": {"nombre": "Camión escalera", "servicio": "bomberos", "velocidad": 40.0, "plazas": 3, "precio": 150000, "bono": "altura"},
	"rescate": {"nombre": "Unidad de rescate", "servicio": "bomberos", "velocidad": 55.0, "plazas": 3, "precio": 90000, "bono": "rescate"},
	"camuflado": {"nombre": "Coche camuflado", "servicio": "policia", "velocidad": 80.0, "plazas": 2, "precio": 26000, "bono": "camuflado"},
	"canina": {"nombre": "Unidad canina", "servicio": "policia", "velocidad": 70.0, "plazas": 2, "precio": 24000, "bono": "canino"},
	"vir": {"nombre": "VIR (vehículo de intervención rápida)", "servicio": "ambulancia", "velocidad": 78.0, "plazas": 2, "precio": 35000, "bono": "vir"},
	"moto_sanitaria": {"nombre": "Moto sanitaria", "servicio": "ambulancia", "velocidad": 85.0, "plazas": 1, "precio": 15000, "bono": "moto_sanitaria"},
	"pma": {"nombre": "Puesto Médico Avanzado", "servicio": "ambulancia", "velocidad": 40.0, "plazas": 4, "precio": 80000, "bono": "pma"},
	"pc_vehiculo": {"nombre": "Vehículo de Protección Civil", "servicio": "proteccion_civil", "velocidad": 50.0, "plazas": 4, "precio": 22000, "bono": "apoyo"},
	# ---- Unidad de Intervención Especial (tipo GEO): se desbloquea con el rango
	"geo_blindado": {"nombre": "Blindado GEO", "servicio": "geo", "velocidad": 70.0, "plazas": 6, "precio": 90000, "bono": "blindado", "rango": 2, "inicial": 4},
	"geo_antidisturbios": {"nombre": "Furgón antidisturbios", "servicio": "geo", "velocidad": 62.0, "plazas": 8, "precio": 60000, "bono": "antidisturbios_geo", "rango": 2, "inicial": 6},
	"geo_mando": {"nombre": "Mando táctico GEO", "servicio": "geo", "velocidad": 68.0, "plazas": 3, "precio": 50000, "bono": "mando", "rango": 3, "inicial": 3},
	"geo_tedax": {"nombre": "TEDAX (artificieros)", "servicio": "geo", "velocidad": 62.0, "plazas": 3, "precio": 75000, "bono": "tedax", "rango": 2, "inicial": 3},
	# ---- UME (Unidad Militar de Emergencias): grandes catástrofes
	"ume_nrbq": {"nombre": "UME NRBQ (químico y radiactivo)", "servicio": "ume", "velocidad": 52.0, "plazas": 5, "precio": 110000, "bono": "nrbq", "rango": 3, "inicial": 4},
	"ume_forestal": {"nombre": "UME autobomba forestal pesada", "servicio": "ume", "velocidad": 48.0, "plazas": 5, "precio": 100000, "bono": "forestal", "rango": 3, "inicial": 4},
	"ume_rescate": {"nombre": "UME rescate en derrumbes", "servicio": "ume", "velocidad": 52.0, "plazas": 6, "precio": 95000, "bono": "derrumbes", "rango": 3, "inicial": 4},
	"ume_anfibio": {"nombre": "UME anfibio y bombas de achique", "servicio": "ume", "velocidad": 46.0, "plazas": 5, "precio": 85000, "bono": "anfibio", "rango": 3, "inicial": 4},
	# ---- Helicópteros (0.99): vuelan en línea recta; cada salida cuesta combustible
	"heli_sanitario": {"nombre": "Helicóptero sanitario", "servicio": "ambulancia", "velocidad": 190.0, "plazas": 3, "precio": 150000, "bono": "heli_sanitario", "rango": 2, "inicial": 3, "aereo": true, "base": "helipuerto", "camillas": 1},
	"heli_bomberos": {"nombre": "Helicóptero de bomberos", "servicio": "bomberos", "velocidad": 180.0, "plazas": 3, "precio": 140000, "bono": "heli_bomberos", "rango": 2, "inicial": 3, "aereo": true, "base": "helipuerto"},
	"heli_policia": {"nombre": "Helicóptero de policía", "servicio": "policia", "velocidad": 200.0, "plazas": 2, "precio": 130000, "bono": "heli_policia", "rango": 2, "inicial": 2, "aereo": true, "base": "helipuerto"},
	# ---- Policía Judicial (detectives): investiga las denuncias
	"judicial": {"nombre": "Policía Judicial (detectives)", "servicio": "judicial", "velocidad": 70.0, "plazas": 3, "precio": 40000, "bono": "detectives", "rango": 1, "inicial": 2},
}

## Nombre corto que se ve en el mapa y en la radio: «Coche patrulla 2», «Moto 1»...
const NOMBRE_CORTO := {
	"patrulla": "Coche patrulla", "moto": "Moto", "furgon": "Furgón",
	"ambulancia_b": "Ambulancia", "ambulancia_sva": "Ambulancia SVA",
	"autobomba": "Autobomba", "escalera": "Escalera", "rescate": "Rescate",
	"camuflado": "Camuflado", "canina": "Canina", "vir": "VIR", "moto_sanitaria": "Moto sanitaria",
	"pma": "PMA", "pc_vehiculo": "Protección Civil",
	"geo_blindado": "Blindado GEO", "geo_antidisturbios": "Antidisturbios", "geo_mando": "Mando GEO",
	"geo_tedax": "TEDAX", "heli_sanitario": "Helicóptero sanitario", "heli_policia": "Helicóptero policía", "heli_bomberos": "Helicóptero bomberos", "ume_nrbq": "UME NRBQ", "ume_forestal": "UME Forestal",
	"ume_rescate": "UME Rescate", "ume_anfibio": "UME Anfibio", "judicial": "Detectives",
}

## Mejoras de la ambulancia básica (2.0)
const MEJORAS_AMBULANCIA := {
	"motor": {"nombre": "Motor nuevo", "precio": 6000, "ayuda": "Va un 15 % más rápida"},
	"tecnico": {"nombre": "Técnico con formación avanzada", "precio": 5000, "ayuda": "Atiende antes y baja el riesgo de muerte"},
	"equipamiento": {"nombre": "Equipamiento avanzado (monitor, oxígeno, inmovilización)", "precio": 7000, "ayuda": "Los pacientes aguantan más y hay menos muertes"},
	"4x4": {"nombre": "Tracción 4x4", "precio": 6500, "ayuda": "Un 25 % más rápida fuera del pueblo (fincas, caminos, monte)"},
}
const PRECIO_PASAR_A_SVA := 25000

## PLANTILLA (1.1)
const XP_NIVEL := [0, 8, 20]          # servicios para ser experto / veterano
const NOMBRES_NIVEL := ["Novato/a", "Experto/a", "Veterano/a"]
const FACTOR_SUELDO_RESERVA := 0.6     # la reserva cobra el 60 %
const PRECIO_CURSO := 2500             # curso que enseña una habilidad a una persona
const PRECIO_PSICOLOGO := 300          # por turno
## Habilidades que se aprenden al subir de nivel (o con un curso)
const HABILIDADES := {
	"ambulancia": {"reanimacion": "Reanimación avanzada: menos riesgo de muerte", "traslado_rapido": "Traslado rápido: llegan antes al hospital", "triaje": "Triaje: trabajan más rápido con varios heridos"},
	"policia": {"negociador": "Negociador: mejor con peleas, armados y rehenes", "conduccion": "Conducción evasiva: van más rápido en emergencia", "interrogador": "Interrogador: avanzan más rápido en casos y controles"},
	"bomberos": {"altura": "Rescate en altura y excarcelación: rescates más rápidos", "forestal": "Experto en incendios: apagan antes los fuegos grandes", "conduccion": "Conducción de emergencia: van más rápido"},
	"proteccion_civil": {"primeros_auxilios": "Primeros auxilios: los heridos aguantan más", "trafico": "Ordenación del tráfico: el resto trabaja más rápido"},
	"geo": {"negociador": "Negociador: mejor con armados y rehenes", "tirador": "Tirador de precisión: menos riesgo en asaltos", "conduccion": "Conducción evasiva"},
	"ume": {"rescate": "Rescate en catástrofes: más rápidos en derrumbes y riadas", "nrbq": "Especialista NRBQ: más rápidos con químicos", "forestal": "Experto forestal"},
	"judicial": {"olfato": "Olfato: más rápidos en cada paso de un caso", "interrogador": "Interrogador: sacan más de los testigos", "paciencia": "Paciencia: vigilancias más cortas"},
}
## Mejoras de las bases
const MEJORAS := {
	"gimnasio": {"nombre": "Gimnasio y sala de descanso", "precio": 12000, "ayuda": "El cansancio baja el doble de rápido en la base y la moral sube más cada turno"},
	"taller": {"nombre": "Taller propio", "precio": 15000, "ayuda": "Vehículos bien puestos a punto: todos van un 5 % más rápido"},
	"calabozo": {"nombre": "Ampliación del calabozo", "precio": 10000, "ayuda": "El calabozo pasa de 6 a 12 plazas"},
	"aula": {"nombre": "Aula de formación", "precio": 9000, "ayuda": "Los cursos cuestan la mitad"},
}

## Plazas del calabozo de la comisaría (si se llena, hay que llevar presos a la cárcel)
const PLAZAS_CALABOZO := 6

## Combustible de cada salida de un helicóptero
const COSTE_VUELO := 350

## Sueldo por persona y turno de los servicios del Estado (más barato de mantener)
const SUELDO_ESPECIAL := {"geo": 40, "ume": 40, "judicial": 60}

const EQUIPO := {
	"chaleco": {"nombre": "Chalecos antibalas", "servicio": "policia", "precio": 1500, "ayuda": "Menos riesgo de heridos en peleas y robos"},
	"antidisturbios": {"nombre": "Equipo antidisturbios", "servicio": "policia", "precio": 2500, "ayuda": "Más fuerza en peleas"},
	"alcoholimetro": {"nombre": "Alcoholímetro", "servicio": "policia", "precio": 800, "ayuda": "Permite hacer controles de alcoholemia"},
	"extincion": {"nombre": "Equipo de extinción", "servicio": "bomberos", "precio": 2000, "ayuda": "Apaga los incendios más rápido"},
	"busqueda": {"nombre": "Trajes de búsqueda", "servicio": "bomberos", "precio": 2000, "ayuda": "Rescata a personas dentro de edificios"},
	"tecnico": {"nombre": "Equipo técnico (excarcelación)", "servicio": "bomberos", "precio": 2500, "ayuda": "Saca a personas atrapadas en coches"},
	"botiquin": {"nombre": "Botiquín avanzado", "servicio": "ambulancia", "precio": 1200, "ayuda": "Estabiliza más rápido a los heridos"},
	"desfibrilador": {"nombre": "Desfibrilador", "servicio": "ambulancia", "precio": 3000, "ayuda": "Salva a pacientes graves"},
	# GEO
	"fusiles": {"nombre": "Fusiles de asalto y escudos balísticos", "servicio": "geo", "precio": 6000, "ayuda": "Mucho menos riesgo de heridos ante personas armadas y rehenes"},
	"escudos_humo": {"nombre": "Escudos antidisturbios y botes de humo", "servicio": "geo", "precio": 4000, "ayuda": "Disuelven peleas multitudinarias mucho más rápido"},
	"robot_tedax": {"nombre": "Traje y robot TEDAX", "servicio": "geo", "precio": 9000, "ayuda": "Desactivan bombas sin acercarse: casi sin riesgo de explosión"},
	"dron": {"nombre": "Dron con cámara térmica", "servicio": ["geo", "ume", "judicial"], "precio": 5000, "ayuda": "Encuentran antes a personas y sospechosos"},
	"perro_explosivos": {"nombre": "Perro detector de explosivos", "servicio": "geo", "precio": 4500, "ayuda": "Localiza explosivos y revisa los edificios más rápido"},
	# UME
	"trajes_nrbq": {"nombre": "Trajes NRBQ", "servicio": "ume", "precio": 6000, "ayuda": "Trabajan dentro de nubes tóxicas sin intoxicarse"},
	"geofono": {"nombre": "Geófono y cámaras de búsqueda", "servicio": "ume", "precio": 5000, "ayuda": "Encuentran supervivientes entre los escombros"},
	"bombas_achique": {"nombre": "Bombas de achique de gran caudal", "servicio": "ume", "precio": 4000, "ayuda": "Vacían garajes y calles inundadas mucho más rápido"},
	# Detectives
	"kit_forense": {"nombre": "Kit de huellas y ADN", "servicio": "judicial", "precio": 3000, "ayuda": "Cada paso de una investigación da mejores pistas"},
}

## Flota con la que empieza una partida nueva.
## base: ambulancia1, ambulancia2, policia, bomberos
const FLOTA_INICIAL := [
	{"tipo": "ambulancia_b", "base": "ambulancia1", "personal": 2, "heridos": [], "equipo": []},
	{"tipo": "ambulancia_b", "base": "ambulancia2", "personal": 2, "heridos": [], "equipo": []},
	{"tipo": "patrulla", "base": "policia", "personal": 2, "heridos": [], "equipo": []},
	{"tipo": "patrulla", "base": "policia", "personal": 2, "heridos": [], "equipo": []},
	{"tipo": "autobomba", "base": "bomberos", "personal": 4, "heridos": [], "equipo": []},
]

## Base por defecto de cada servicio para los vehículos nuevos
const BASE_SERVICIO := {"ambulancia": "ambulancia1", "policia": "policia", "bomberos": "bomberos", "proteccion_civil": "proteccion_civil",
	"geo": "geo", "ume": "ume", "judicial": "policia"}
const PRECIO_FORMACION := 1500     # curso de formación para un vehículo (máximo 2)
const SUBVENCION_BASE := 500       # presupuesto del ayuntamiento por turno (+ según la reputación)
