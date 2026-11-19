extends RefCounted
## CASOS DE LA POLICÍA JUDICIAL (0.98)
## Una denuncia se convierte en un caso. Los detectives hacen pasos (cada uno
## es un aviso al que mandas su coche) y cada paso da una pista sobre el
## culpable. Con las pistas, eliges a quién acusar entre tres sospechosos.

## Rasgos posibles de los sospechosos, por categoría.
const RASGOS := {
	"ropa": ["sudadera roja", "chaqueta de cuero negra", "chándal azul", "gorra de un equipo de fútbol", "abrigo verde"],
	"vehiculo": ["un coche gris", "una moto negra", "una furgoneta blanca", "un patinete eléctrico", "un coche rojo antiguo"],
	"senas": ["un tatuaje en la mano", "una cicatriz en la ceja", "cojea de una pierna", "lleva gafas", "barba muy larga"],
	"trabajo": ["trabaja en el polígono", "está en paro", "es repartidor", "trabaja de noche en un bar", "es vendedor ambulante"],
}

## Cómo se cuenta cada pista según la categoría.
const FRASE_PISTA := {
	"ropa": "El culpable llevaba %s.",
	"vehiculo": "El culpable se movía en %s.",
	"senas": "El culpable tiene %s.",
	"trabajo": "El culpable %s.",
}

const NOMBRES := ["Jonathan R.", "Iván M.", "Francisco G.", "Raúl P.", "Kevin S.", "Antonio L.", "Cristian D.",
	"Rubén T.", "Marcos V.", "Sergio C.", "David H.", "Adrián B.", "Óscar F.", "Manuel J.", "Alberto N."]

## Pasos de la investigación (se eligen al azar, sin repetir).
const PASOS := [
	{"titulo": "Entrevistar a la víctima", "lugar": ["edificio", "plaza"], "radio": "Hemos hablado con la víctima: recuerda un detalle."},
	{"titulo": "Revisar las cámaras de seguridad", "lugar": ["comercio", "supermercado", "gasolinera"], "radio": "Las cámaras han grabado algo interesante."},
	{"titulo": "Buscar huellas en el lugar", "lugar": ["edificio", "comercio"], "radio": "Huellas recogidas. La base de datos nos da una pista."},
	{"titulo": "Preguntar a los vecinos", "lugar": ["plaza", "parque", "iglesia"], "radio": "Una vecina vio algo esa noche."},
	{"titulo": "Vigilar un punto de venta de objetos robados", "lugar": ["bar", "industrial", "parque"], "radio": "Tras horas de vigilancia, hemos visto al que vende lo robado."},
	{"titulo": "Hablar con un confidente", "lugar": ["bar", "plaza"], "radio": "El confidente nos ha dado un dato a cambio de un favor."},
	{"titulo": "Revisar los movimientos de una tarjeta", "lugar": ["comercio", "supermercado"], "radio": "La tarjeta robada se usó aquí: las cámaras lo grabaron."},
	{"titulo": "Registrar un trastero con orden judicial", "lugar": ["edificio", "industrial"], "radio": "En el trastero aparecen objetos robados y algo más."},
	{"titulo": "Seguir a un sospechoso hasta su casa", "lugar": ["edificio", "parque"], "radio": "Seguimiento discreto: sabemos dónde vive y con quién se junta."},
	{"titulo": "Buscar en un desguace", "lugar": ["industrial", "finca"], "radio": "En el desguace reconocen el vehículo y a quien lo trajo."},
]

## Palabras de las denuncias que se pueden investigar.
const INVESTIGABLES := ["rob", "estaf", "peg", "agred", "desapare", "quitad", "sacad", "forzad", "romp", "rajad", "claves", "tirón", "entrad", "dinero",
	"amenaz", "pintad", "quemad", "incendi", "acos", "chantaj", "suplant", "tarjeta", "móvil", "bici", "perro", "envenen"]
