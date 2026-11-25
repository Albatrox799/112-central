class_name Sprites
extends RefCounted
## Generado por herramientas/dibujar_vehiculos.py

const LUCES := {
	"ambulancia_b": Vector2(0.336, 0.068),
	"ambulancia_sva": Vector2(0.336, 0.068),
	"autobomba": Vector2(0.781, 0.102),
	"camuflado": Vector2(0.594, 0.25),
	"canina": Vector2(0.508, 0.245),
	"escalera": Vector2(0.781, 0.102),
	"furgon": Vector2(0.625, 0.125),
	"geo_antidisturbios": Vector2(0.625, 0.125),
	"geo_blindado": Vector2(0.406, 0.068),
	"geo_mando": Vector2(0.625, 0.125),
	"geo_tedax": Vector2(0.406, 0.068),
	"guardia_civil": Vector2(0.508, 0.245),
	"heli_bomberos": Vector2(0.656, 0.25),
	"heli_policia": Vector2(0.656, 0.25),
	"heli_sanitario": Vector2(0.656, 0.25),
	"judicial": Vector2(0.594, 0.25),
	"moto": Vector2(0.539, 0.283),
	"moto_sanitaria": Vector2(0.539, 0.283),
	"patrulla": Vector2(0.508, 0.245),
	"pc_vehiculo": Vector2(0.625, 0.125),
	"pma": Vector2(0.781, 0.102),
	"rescate": Vector2(0.781, 0.102),
	"ume": Vector2(0.781, 0.102),
	"ume_anfibio": Vector2(0.781, 0.102),
	"ume_forestal": Vector2(0.781, 0.102),
	"ume_nrbq": Vector2(0.781, 0.102),
	"ume_rescate": Vector2(0.781, 0.102),
	"vir": Vector2(0.508, 0.245),
}

## Dibujo por servicio cuando el tipo no tiene uno propio
const POR_SERVICIO := {"policia": "patrulla", "ambulancia": "ambulancia_b", "bomberos": "autobomba",
	"proteccion_civil": "pc_vehiculo", "geo": "geo_blindado", "ume": "ume", "judicial": "judicial",
	"sospechoso": "sospechoso", "funeraria": "funeraria"}

static var _cache := {}


static func textura(tipo: String, servicio: String = "") -> Texture2D:
	var clave := tipo + "|" + servicio
	if _cache.has(clave):
		return _cache[clave]
	var tex: Texture2D = null
	for nombre in [tipo, String(POR_SERVICIO.get(servicio, "")), "civil"]:
		if nombre == "":
			continue
		var ruta := "res://assets/vehiculos/%s.png" % nombre
		if ResourceLoader.exists(ruta):
			tex = load(ruta)
			break
	_cache[clave] = tex
	return tex


static func luz(tipo: String, servicio: String = "") -> Vector2:
	if LUCES.has(tipo):
		return LUCES[tipo]
	return LUCES.get(String(POR_SERVICIO.get(servicio, "")), Vector2(0.5, 0.15))
