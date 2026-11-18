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
	"furgon": {"nombre": "Furgón policial", "servicio": "policia", "velocidad": 62.0, "plazas": 4, "precio": 30000, "bono": "detenidos"},
	"ambulancia_b": {"nombre": "Ambulancia básica", "servicio": "ambulancia", "velocidad": 55.0, "plazas": 2, "precio": 40000, "bono": ""},
	"ambulancia_sva": {"nombre": "Ambulancia de soporte vital avanzado", "servicio": "ambulancia", "velocidad": 60.0, "plazas": 3, "precio": 65000, "bono": "medico"},
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
	"geo_tedax": "TEDAX", "ume_nrbq": "UME NRBQ", "ume_forestal": "UME Forestal",
	"ume_rescate": "UME Rescate", "ume_anfibio": "UME Anfibio", "judicial": "Detectives",
}

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
