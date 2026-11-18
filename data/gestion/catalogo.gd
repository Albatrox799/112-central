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
}

const EQUIPO := {
	"chaleco": {"nombre": "Chalecos antibalas", "servicio": "policia", "precio": 1500, "ayuda": "Menos riesgo de heridos en peleas y robos"},
	"antidisturbios": {"nombre": "Equipo antidisturbios", "servicio": "policia", "precio": 2500, "ayuda": "Más fuerza en peleas"},
	"alcoholimetro": {"nombre": "Alcoholímetro", "servicio": "policia", "precio": 800, "ayuda": "Permite hacer controles de alcoholemia"},
	"extincion": {"nombre": "Equipo de extinción", "servicio": "bomberos", "precio": 2000, "ayuda": "Apaga los incendios más rápido"},
	"busqueda": {"nombre": "Trajes de búsqueda", "servicio": "bomberos", "precio": 2000, "ayuda": "Rescata a personas dentro de edificios"},
	"tecnico": {"nombre": "Equipo técnico (excarcelación)", "servicio": "bomberos", "precio": 2500, "ayuda": "Saca a personas atrapadas en coches"},
	"botiquin": {"nombre": "Botiquín avanzado", "servicio": "ambulancia", "precio": 1200, "ayuda": "Estabiliza más rápido a los heridos"},
	"desfibrilador": {"nombre": "Desfibrilador", "servicio": "ambulancia", "precio": 3000, "ayuda": "Salva a pacientes graves"},
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
const BASE_SERVICIO := {"ambulancia": "ambulancia1", "policia": "policia", "bomberos": "bomberos", "proteccion_civil": "proteccion_civil"}
const PRECIO_FORMACION := 1500     # curso de formación para un vehículo (máximo 2)
const SUBVENCION_BASE := 500       # presupuesto del ayuntamiento por turno (+ según la reputación)
