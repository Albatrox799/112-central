#!/usr/bin/env python3
"""
Convierte un archivo de OpenStreetMap (.osm) en el mapa del juego (JSON).

Uso:
    python3 tools/osm_a_mapa.py entrada.osm data/map/miguelturra.json

Datos del mapa: © colaboradores de OpenStreetMap, licencia ODbL.

Qué genera:
  - nodos / tramos: red de calles por la que circulan los vehículos (A*)
  - vias: líneas de calles para dibujar (con tipo y nombre)
  - edificios, zonas (parques, polígonos, agua...), vías de tren
  - lugares: puntos de referencia con nombre (para las llamadas)
"""
import json
import math
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

CIRCULABLES = {
    "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
    "secondary", "secondary_link", "tertiary", "tertiary_link", "unclassified",
    "residential", "living_street", "service", "pedestrian",
}
PRINCIPALES = {"motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
               "secondary", "secondary_link", "tertiary", "tertiary_link"}
DIBUJABLES = CIRCULABLES | {"track", "footway", "path", "cycleway"}

TIPOS_LUGAR = {
    ("amenity", "doctors"): "sanidad", ("amenity", "hospital"): "sanidad",
    ("amenity", "clinic"): "sanidad", ("amenity", "pharmacy"): "farmacia",
    ("amenity", "townhall"): "ayuntamiento", ("amenity", "police"): "policia",
    ("amenity", "fire_station"): "bomberos", ("amenity", "school"): "colegio",
    ("building", "school"): "colegio", ("amenity", "place_of_worship"): "iglesia",
    ("amenity", "theatre"): "teatro", ("amenity", "fuel"): "gasolinera",
    ("shop", "supermarket"): "supermercado", ("amenity", "restaurant"): "restaurante",
    ("amenity", "cafe"): "bar", ("amenity", "bar"): "bar",
    ("leisure", "swimming_pool"): "deporte", ("leisure", "sports_centre"): "deporte",
    ("leisure", "stadium"): "deporte", ("leisure", "park"): "parque",
    ("leisure", "fitness_centre"): "deporte", ("shop", "optician"): "comercio",
    ("shop", "florist"): "comercio",
}


def etiquetas(e):
    return {t.get("k"): t.get("v") for t in e.findall("tag")}


def main(entrada, salida):
    raiz = ET.parse(entrada).getroot()
    b = raiz.find("bounds").attrib
    minlat, maxlat = float(b["minlat"]), float(b["maxlat"])
    minlon, maxlon = float(b["minlon"]), float(b["maxlon"])
    lat0 = math.radians((minlat + maxlat) / 2)
    kx = math.cos(lat0) * 111320.0
    ky = 110574.0

    def proy(lat, lon):
        return (round((lon - minlon) * kx, 1), round((maxlat - lat) * ky, 1))

    ancho, alto = proy(minlat, maxlon)
    nodos_osm = {}
    nodos_tags = {}
    for n in raiz.findall("node"):
        nodos_osm[n.get("id")] = proy(float(n.get("lat")), float(n.get("lon")))
        t = etiquetas(n)
        if t:
            nodos_tags[n.get("id")] = t

    vias, edificios, zonas, tren, lugares = [], [], [], [], []
    tramos_osm = []  # (id_a, id_b, nombre, tipo)

    def centro(puntos):
        xs = [p[0] for p in puntos]
        ys = [p[1] for p in puntos]
        return (round(sum(xs) / len(xs), 1), round(sum(ys) / len(ys), 1))

    def plano(puntos):
        out = []
        for p in puntos:
            out += [p[0], p[1]]
        return out

    def tipo_lugar(t):
        for (k, v), tipo in TIPOS_LUGAR.items():
            if t.get(k) == v:
                return tipo
        if "building" in t and "name" in t:
            return "edificio"
        return None

    for w in raiz.findall("way"):
        t = etiquetas(w)
        refs = [nd.get("ref") for nd in w.findall("nd") if nd.get("ref") in nodos_osm]
        if len(refs) < 2:
            continue
        pts = [nodos_osm[r] for r in refs]
        hw = t.get("highway")
        cerrado = refs[0] == refs[-1]
        if hw in DIBUJABLES:
            vias.append({"tipo": hw, "nombre": t.get("name", ""), "puntos": plano(pts)})
            if hw in CIRCULABLES:
                for a, c in zip(refs, refs[1:]):
                    tramos_osm.append((a, c, t.get("name", ""), hw))
            continue
        if t.get("railway") in ("rail", "light_rail"):
            tren.append(plano(pts))
            continue
        if cerrado and len(pts) >= 4:
            zona = None
            if t.get("leisure") in ("park", "playground", "garden"):
                zona = "parque"
            elif t.get("leisure") in ("pitch", "sports_centre", "stadium", "swimming_pool", "bleachers"):
                zona = "deporte"
            elif t.get("landuse") in ("residential",):
                zona = "residencial"
            elif t.get("landuse") in ("industrial",):
                zona = "industrial"
            elif t.get("landuse") in ("retail", "commercial"):
                zona = "comercial"
            elif t.get("landuse") in ("farmland", "meadow", "grass"):
                zona = "campo"
            elif t.get("natural") == "water" or t.get("landuse") == "reservoir":
                zona = "agua"
            elif t.get("amenity") == "parking":
                zona = "aparcamiento"
            elif "name" in t and t["name"].startswith("Plaza"):
                zona = "plaza"
            if "building" in t:
                edificios.append(plano(pts[:-1]))
            elif zona:
                zonas.append({"tipo": zona, "puntos": plano(pts[:-1])})
        tl = tipo_lugar(t)
        if tl and "name" in t:
            c = centro(pts)
            lugares.append({"nombre": t["name"], "tipo": tl, "x": c[0], "y": c[1]})
        elif "name" in t and t["name"].startswith("Plaza"):
            c = centro(pts)
            lugares.append({"nombre": t["name"], "tipo": "plaza", "x": c[0], "y": c[1]})

    # Multipolígonos con edificio (p. ej. Plaza de Toros)
    ways_por_id = {w.get("id"): w for w in raiz.findall("way")}
    for rel in raiz.findall("relation"):
        t = etiquetas(rel)
        if t.get("type") != "multipolygon":
            continue
        for m in rel.findall("member"):
            if m.get("type") == "way" and m.get("role") == "outer" and m.get("ref") in ways_por_id:
                w = ways_por_id[m.get("ref")]
                pts = [nodos_osm[nd.get("ref")] for nd in w.findall("nd") if nd.get("ref") in nodos_osm]
                if len(pts) >= 4:
                    edificios.append(plano(pts[:-1]))
                    if "name" in t:
                        c = centro(pts)
                        lugares.append({"nombre": t["name"], "tipo": tipo_lugar(t) or "deporte", "x": c[0], "y": c[1]})

    for nid, t in nodos_tags.items():
        tl = tipo_lugar(t)
        if tl and "name" in t:
            x, y = nodos_osm[nid]
            lugares.append({"nombre": t["name"], "tipo": tl, "x": x, "y": y})

    # ---------- Red de calles: componente conectado más grande
    ady = defaultdict(set)
    for a, c, _, _ in tramos_osm:
        ady[a].add(c)
        ady[c].add(a)
    visto, mejor = set(), set()
    for inicio in ady:
        if inicio in visto:
            continue
        comp, pila = set(), [inicio]
        while pila:
            n = pila.pop()
            if n in comp:
                continue
            comp.add(n)
            pila.extend(ady[n] - comp)
        visto |= comp
        if len(comp) > len(mejor):
            mejor = comp

    indice = {}
    nodos = []
    for nid in sorted(mejor, key=lambda k: nodos_osm[k]):
        indice[nid] = len(nodos)
        nodos.append(list(nodos_osm[nid]))

    calles = [""]
    idx_calle = {"": 0}
    tramos = []
    vistos_tramos = set()
    for a, c, nombre, hw in tramos_osm:
        if a not in indice or c not in indice:
            continue
        clave = tuple(sorted((indice[a], indice[c])))
        if clave in vistos_tramos or clave[0] == clave[1]:
            continue
        vistos_tramos.add(clave)
        if nombre not in idx_calle:
            idx_calle[nombre] = len(calles)
            calles.append(nombre)
        tramos.append([indice[a], indice[c], idx_calle[nombre], 1 if hw in PRINCIPALES else 0])

    # Calle y nodo más cercanos para cada lugar
    def dist_seg(px, py, ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        u = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
        qx, qy = ax + u * dx, ay + u * dy
        return math.hypot(px - qx, py - qy)

    vistos_lugares = set()
    lugares_final = []
    for l in lugares:
        clave = (l["nombre"], l["tipo"])
        if clave in vistos_lugares:
            continue
        vistos_lugares.add(clave)
        mejor_d, mejor_t = 1e18, None
        for tr in tramos:
            if tr[2] == 0:
                continue
            a, c = nodos[tr[0]], nodos[tr[1]]
            d = dist_seg(l["x"], l["y"], a[0], a[1], c[0], c[1])
            if d < mejor_d:
                mejor_d, mejor_t = d, tr
        if mejor_t is None:
            continue
        a, c = nodos[mejor_t[0]], nodos[mejor_t[1]]
        nodo = mejor_t[0] if math.hypot(l["x"] - a[0], l["y"] - a[1]) <= math.hypot(l["x"] - c[0], l["y"] - c[1]) else mejor_t[1]
        l["calle"] = calles[mejor_t[2]]
        l["nodo"] = nodo
        l["distancia_calle"] = round(mejor_d)
        lugares_final.append(l)

    # ---------- Desplazar todo para que no haya coordenadas negativas
    todos = [tuple(n) for n in nodos]
    for v in vias:
        todos += list(zip(v["puntos"][0::2], v["puntos"][1::2]))
    for e in edificios:
        todos += list(zip(e[0::2], e[1::2]))
    for z in zonas:
        todos += list(zip(z["puntos"][0::2], z["puntos"][1::2]))
    margen = 150.0
    ox = margen - min(p[0] for p in todos)
    oy = margen - min(p[1] for p in todos)

    def mover(lista):
        return [round(v + (ox if i % 2 == 0 else oy), 1) for i, v in enumerate(lista)]

    nodos = [[round(n[0] + ox, 1), round(n[1] + oy, 1)] for n in nodos]
    for v in vias:
        v["puntos"] = mover(v["puntos"])
    edificios = [mover(e) for e in edificios]
    for z in zonas:
        z["puntos"] = mover(z["puntos"])
    tren = [mover(t) for t in tren]
    for l in lugares_final:
        l["x"] = round(l["x"] + ox, 1)
        l["y"] = round(l["y"] + oy, 1)
    ancho = round(max(p[0] for p in todos) + ox + margen)
    alto = round(max(p[1] for p in todos) + oy + margen)

    datos = {
        "fuente": "© colaboradores de OpenStreetMap (ODbL)",
        "tamano": [ancho, alto],
        "nodos": nodos,
        "tramos": tramos,
        "calles": calles,
        "vias": vias,
        "edificios": edificios,
        "zonas": zonas,
        "tren": tren,
        "lugares": lugares_final,
    }
    with open(salida, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Tamaño {ancho}x{alto} m · nodos {len(nodos)} · tramos {len(tramos)} · calles {len(calles)}")
    print(f"vías {len(vias)} · edificios {len(edificios)} · zonas {len(zonas)} · tren {len(tren)} · lugares {len(lugares_final)}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
