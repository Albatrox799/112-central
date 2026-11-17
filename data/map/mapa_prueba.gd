extends RefCounted
## MAPA DE PRUEBA (Fase 1) – esquema simplificado de un casco urbano.
## No es todavía el plano real de Miguelturra: los nombres de calles y la
## posición de los edificios son provisionales. En la Fase 2 se sustituirá
## por un mapa basado en la geografía real (p. ej. datos de OpenStreetMap).
##
## Para editar el mapa:
##   - NODOS: cruces de calles (nombre -> posición en píxeles).
##   - TRAMOS: calles que unen dos cruces y su nombre.
##   - LUGARES: edificios y puntos de referencia que se dibujan.

const TAMANO := Vector2(2700, 1500)

# Rejilla de manzanas (posición de las calles verticales y horizontales)
const COLUMNAS := [300, 600, 900, 1200, 1500, 1800]
const FILAS := [300, 600, 900, 1200]

# Manzanas especiales: "columna,fila" -> tipo
const MANZANAS_ESPECIALES := {
	"2,0": "plaza",
	"0,2": "parque",
	"4,2": "industrial",
}

const NODOS := {
	"A1": Vector2(300, 300), "B1": Vector2(600, 300), "C1": Vector2(900, 300),
	"D1": Vector2(1200, 300), "E1": Vector2(1500, 300), "F1": Vector2(1800, 300),
	"A2": Vector2(300, 600), "B2": Vector2(600, 600), "C2": Vector2(900, 600),
	"D2": Vector2(1200, 600), "E2": Vector2(1500, 600), "F2": Vector2(1800, 600),
	"A3": Vector2(300, 900), "B3": Vector2(600, 900), "C3": Vector2(900, 900),
	"D3": Vector2(1200, 900), "E3": Vector2(1500, 900), "F3": Vector2(1800, 900),
	"A4": Vector2(300, 1200), "B4": Vector2(600, 1200), "C4": Vector2(900, 1200),
	"D4": Vector2(1200, 1200), "E4": Vector2(1500, 1200), "F4": Vector2(1800, 1200),
	"R": Vector2(2150, 750),   # rotonda
	"E": Vector2(2620, 750),   # salida hacia Ciudad Real
}

const TRAMOS := [
	# Calles horizontales
	["A1", "B1", "Calle del Ejido"], ["B1", "C1", "Calle del Ejido"], ["C1", "D1", "Calle del Ejido"],
	["D1", "E1", "Calle del Ejido"], ["E1", "F1", "Calle del Ejido"],
	["A2", "B2", "Calle Real"], ["B2", "C2", "Calle Real"], ["C2", "D2", "Calle Real"],
	["D2", "E2", "Calle Real"], ["E2", "F2", "Calle Real"],
	["A3", "B3", "Calle Mayor"], ["B3", "C3", "Calle Mayor"], ["C3", "D3", "Calle Mayor"],
	["D3", "E3", "Calle Mayor"], ["E3", "F3", "Calle Mayor"],
	["A4", "B4", "Calle de la Estación"], ["B4", "C4", "Calle de la Estación"], ["C4", "D4", "Calle de la Estación"],
	["D4", "E4", "Calle de la Estación"], ["E4", "F4", "Calle de la Estación"],
	# Calles verticales
	["A1", "A2", "Calle Huertas"], ["A2", "A3", "Calle Huertas"], ["A3", "A4", "Calle Huertas"],
	["B1", "B2", "Calle Toledo"], ["B2", "B3", "Calle Toledo"], ["B3", "B4", "Calle Toledo"],
	["C1", "C2", "Calle Almagro"], ["C2", "C3", "Calle Almagro"], ["C3", "C4", "Calle Almagro"],
	["D1", "D2", "Calle Cervantes"], ["D2", "D3", "Calle Cervantes"], ["D3", "D4", "Calle Cervantes"],
	["E1", "E2", "Calle San Antón"], ["E2", "E3", "Calle San Antón"], ["E3", "E4", "Calle San Antón"],
	["F1", "F2", "Avenida de la Feria"], ["F2", "F3", "Avenida de la Feria"], ["F3", "F4", "Avenida de la Feria"],
	# Ronda, rotonda y carretera
	["F2", "R", "Ronda Este"], ["F3", "R", "Ronda Este"],
	["R", "E", "Carretera de Ciudad Real"],
]

# letra = "" -> solo se dibuja el nombre (sin icono)
const LUGARES := [
	{"nombre": "Centro de Salud", "letra": "+", "color": Color("27ae60"), "pos": Vector2(450, 450)},
	{"nombre": "Base de ambulancias", "letra": "A", "color": Color("f4d35e"), "pos": Vector2(530, 660)},
	{"nombre": "Colegio", "letra": "C", "color": Color("9b8cff"), "pos": Vector2(750, 380)},
	{"nombre": "Plaza de España", "letra": "", "color": Color.WHITE, "pos": Vector2(1050, 520)},
	{"nombre": "Iglesia", "letra": "I", "color": Color("d9c8a9"), "pos": Vector2(1000, 400)},
	{"nombre": "Comisaría (Policía Local)", "letra": "P", "color": Color("4d96ff"), "pos": Vector2(1580, 360)},
	{"nombre": "Supermercado", "letra": "S", "color": Color("f2994a"), "pos": Vector2(1680, 540)},
	{"nombre": "Panadería", "letra": "Pa", "color": Color("e0a96d"), "pos": Vector2(740, 840)},
	{"nombre": "Farmacia", "letra": "F", "color": Color("2ecc71"), "pos": Vector2(1130, 840)},
	{"nombre": "Parque Municipal", "letra": "", "color": Color.WHITE, "pos": Vector2(450, 1060)},
	{"nombre": "Polígono industrial", "letra": "", "color": Color.WHITE, "pos": Vector2(1650, 1000)},
	{"nombre": "Parque de bomberos", "letra": "B", "color": Color("e74c3c"), "pos": Vector2(1730, 1140)},
	{"nombre": "Gasolinera", "letra": "G", "color": Color("bdbdbd"), "pos": Vector2(1920, 880)},
	{"nombre": "Hacia Ciudad Real", "letra": "", "color": Color("ffd166"), "pos": Vector2(2480, 700)},
]
