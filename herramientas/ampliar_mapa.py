"""Amplía el mapa real de Miguelturra (OpenStreetMap) con el resto del término
municipal INVENTADO: carreteras, caminos, fincas, una pedanía, el monte, un
embalse y una cantera. Uso: python3 herramientas/ampliar_mapa.py
Lee herramientas/miguelturra_pueblo.json y escribe data/map/miguelturra.json."""
import json, math, random, os
random.seed(112)
BASE = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(BASE, 'miguelturra_pueblo.json')))
OX, OY = 5000.0, 4500.0
W, H = d['tamano'][0] + 10000, d['tamano'][1] + 9000

def mover(pts):
    return [round(p + (OX if i % 2 == 0 else OY), 1) for i, p in enumerate(pts)]

nodos = [[round(x + OX, 1), round(y + OY, 1)] for x, y in d['nodos']]
n_pueblo = len(nodos)
tramos = [list(t) for t in d['tramos']]
calles = list(d['calles'])
vias = [dict(v, puntos=mover(v['puntos'])) for v in d['vias']]
edificios = [mover(e) for e in d['edificios']]
zonas = [dict(z, puntos=mover(z['puntos'])) for z in d['zonas']]
tren = [mover(t) for t in d['tren']]
lugares = []
for l in d['lugares']:
    l = dict(l); l['x'] = round(l['x'] + OX, 1); l['y'] = round(l['y'] + OY, 1); lugares.append(l)

grado = {}
for a, b, *_ in tramos:
    grado[a] = grado.get(a, 0) + 1; grado[b] = grado.get(b, 0) + 1
salida = min(range(n_pueblo), key=lambda i: nodos[i][0])

def calle(nombre):
    if nombre in calles: return calles.index(nombre)
    calles.append(nombre); return len(calles) - 1

def nuevo_nodo(x, y):
    nodos.append([round(x, 1), round(y, 1)]); return len(nodos) - 1

def mas_cercano(x, y, hasta=None):
    rango = range(len(nodos)) if hasta is None else range(hasta)
    return min(rango, key=lambda i: (nodos[i][0] - x) ** 2 + (nodos[i][1] - y) ** 2)

def camino(desde, x2, y2, nombre, tipo, paso=170.0, curva=0.25, principal=1, hasta_nodo=None):
    """Traza una vía desde un nodo existente hasta (x2, y2) con curvas suaves."""
    ci = calle(nombre)
    x1, y1 = nodos[desde]
    if hasta_nodo is not None:
        x2, y2 = nodos[hasta_nodo]
    largo = math.hypot(x2 - x1, y2 - y1)
    n = max(2, int(largo / paso))
    nx, ny = -(y2 - y1) / largo, (x2 - x1) / largo
    fase = random.uniform(0, math.pi * 2)
    amp = largo * curva * random.uniform(0.3, 1.0) / 6.0
    previo = desde
    puntos = [x1, y1]
    ids = [desde]
    for k in range(1, n + 1):
        t = k / n
        if k == n and hasta_nodo is not None:
            nid = hasta_nodo
        else:
            off = math.sin(t * math.pi) * math.sin(t * 3.0 + fase) * amp
            px = x1 + (x2 - x1) * t + nx * off
            py = y1 + (y2 - y1) * t + ny * off
            nid = nuevo_nodo(px, py)
        tramos.append([previo, nid, ci, principal])
        puntos += nodos[nid]
        ids.append(nid)
        previo = nid
    vias.append({'tipo': tipo, 'nombre': nombre, 'puntos': puntos})
    return ids

def rect(cx, cy, w, h, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    out = []
    for dx, dy in [(-w/2, -h/2), (w/2, -h/2), (w/2, h/2), (-w/2, h/2)]:
        out += [round(cx + dx * c - dy * s, 1), round(cy + dx * s + dy * c, 1)]
    return out

def poligono(cx, cy, r, n=9, var=0.3):
    out = []
    for k in range(n):
        a = k / n * math.pi * 2
        rr = r * random.uniform(1 - var, 1 + var)
        out += [round(cx + math.cos(a) * rr, 1), round(cy + math.sin(a) * rr * 0.8, 1)]
    return out

def lugar(nombre, tipo, x, y, nodo):
    lugares.append({'nombre': nombre, 'tipo': tipo, 'x': round(x, 1), 'y': round(y, 1),
        'calle': calles[next(t[2] for t in tramos if nodo in (t[0], t[1]))], 'nodo': nodo, 'distancia_calle': 20})

def borde(ang):
    """Nodo del pueblo con pocas salidas más alejado en esa dirección."""
    cx, cy = OX + d['tamano'][0] / 2, OY + d['tamano'][1] / 2
    dx, dy = math.cos(ang), math.sin(ang)
    cands = [i for i in range(n_pueblo) if grado.get(i, 0) <= 2]
    return max(cands, key=lambda i: (nodos[i][0] - cx) * dx + (nodos[i][1] - cy) * dy)

cx, cy = OX + d['tamano'][0] / 2, OY + d['tamano'][1] / 2

# ---------------------------------------------------------------- CARRETERAS
# Carretera de Ciudad Real (hacia el hospital): sigue al oeste desde la salida
carretera_cr = camino(salida, 300, nodos[salida][1] + 300, 'Carretera de Ciudad Real', 'secondary', paso=220, curva=0.1, principal=1)
# Carretera de Los Pozuelos (pedanía, suroeste)
n_sur = borde(math.radians(130))
c_pozuelos = camino(n_sur, 2600, 11200, 'Carretera de Los Pozuelos', 'tertiary', paso=200, curva=0.3)
# Carretera del Monte (noreste)
n_ne = borde(math.radians(-40))
c_monte = camino(n_ne, 12600, 2600, 'Carretera del Monte de San Isidro', 'tertiary', paso=200, curva=0.35)
# Carretera de los Molinos (este)
n_e = borde(math.radians(5))
c_molinos = camino(n_e, 15000, 7600, 'Carretera de los Molinos', 'tertiary', paso=220, curva=0.25)
# Carretera de la Vega (sur)
n_s = borde(math.radians(95))
c_vega = camino(n_s, 8800, 13200, 'Carretera de la Vega', 'tertiary', paso=220, curva=0.3)
# Carretera del Embalse (noroeste)
n_no = borde(math.radians(-140))
c_embalse = camino(n_no, 2400, 1600, 'Carretera del Embalse', 'tertiary', paso=220, curva=0.3)
# Camino del norte
n_n = borde(math.radians(-90))
c_norte = camino(n_n, 7600, 400, 'Camino de las Huertas', 'track', paso=200, curva=0.4, principal=0)

# Caminos que unen carreteras (para que el campo tenga rutas alternativas)
camino(c_monte[len(c_monte) * 2 // 3], 0, 0, 'Camino de la Cañada', 'track', paso=200, curva=0.3, principal=0, hasta_nodo=c_molinos[len(c_molinos) * 2 // 3])
camino(c_vega[len(c_vega) * 2 // 3], 0, 0, 'Camino Viejo de la Vega', 'track', paso=200, curva=0.3, principal=0, hasta_nodo=c_pozuelos[len(c_pozuelos) * 2 // 3])
camino(c_embalse[len(c_embalse) // 2], 0, 0, 'Camino del Molino', 'track', paso=200, curva=0.3, principal=0, hasta_nodo=c_norte[len(c_norte) // 2])
camino(c_molinos[-1], 0, 0, 'Camino de la Dehesa', 'track', paso=220, curva=0.3, principal=0, hasta_nodo=c_vega[-1])

# ---------------------------------------------------------------- PEDANÍA DE LOS POZUELOS
px0, py0 = nodos[c_pozuelos[-1]]
nombres_pz = ['Calle Mayor', 'Calle de la Iglesia', 'Calle del Pozo', 'Calle de las Eras', 'Calle Nueva']
grid = {}
for i in range(4):
    for j in range(4):
        if i == 0 and j == 0:
            grid[(i, j)] = c_pozuelos[-1]
        else:
            grid[(i, j)] = nuevo_nodo(px0 - i * 130 + random.uniform(-12, 12), py0 + j * 120 + random.uniform(-12, 12))
for i in range(4):
    nombre = nombres_pz[i] + ' (Los Pozuelos)'
    ci = calle(nombre); pts = []
    for j in range(4):
        pts += nodos[grid[(i, j)]]
        if j > 0: tramos.append([grid[(i, j - 1)], grid[(i, j)], ci, 0])
    vias.append({'tipo': 'residential', 'nombre': nombre, 'puntos': pts})
for j in range(4):
    nombre = (nombres_pz[4] if j == 0 else 'Travesía %d' % j) + ' (Los Pozuelos)'
    ci = calle(nombre); pts = []
    for i in range(4):
        pts += nodos[grid[(i, j)]]
        if i > 0: tramos.append([grid[(i - 1, j)], grid[(i, j)], ci, 0])
    vias.append({'tipo': 'residential', 'nombre': nombre, 'puntos': pts})
xs = [nodos[n][0] for n in grid.values()]; ys = [nodos[n][1] for n in grid.values()]
zonas.append({'tipo': 'residencial', 'puntos': rect((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, max(xs) - min(xs) + 160, max(ys) - min(ys) + 160)})
for (i, j), n in grid.items():
    if i < 3 and j < 3:
        x, y = nodos[n]
        for k in range(2):
            edificios.append(rect(x - 40 - k * 50, y + 55, 34, 30, random.uniform(-0.1, 0.1)))
gx, gy = nodos[grid[(1, 1)]]
zonas.append({'tipo': 'plaza', 'puntos': rect(gx - 65, gy + 60, 80, 70)})
lugar('Plaza de Los Pozuelos', 'plaza', gx - 65, gy + 60, grid[(1, 1)])
lugar('Iglesia de Los Pozuelos', 'iglesia', nodos[grid[(1, 2)]][0] - 50, nodos[grid[(1, 2)]][1] + 40, grid[(1, 2)])
lugar('Bar El Cruce (Los Pozuelos)', 'bar', nodos[grid[(0, 1)]][0] - 40, nodos[grid[(0, 1)]][1] + 30, grid[(0, 1)])
lugar('Consultorio de Los Pozuelos', 'pedania', nodos[grid[(2, 1)]][0] - 40, nodos[grid[(2, 1)]][1] + 30, grid[(2, 1)])
lugar('Colegio rural de Los Pozuelos', 'colegio', nodos[grid[(3, 2)]][0] - 40, nodos[grid[(3, 2)]][1] + 30, grid[(3, 2)])

# ---------------------------------------------------------------- MONTE DE SAN ISIDRO
mx, my = nodos[c_monte[-1]]
zonas.append({'tipo': 'parque', 'puntos': poligono(mx + 600, my - 200, 1500, 14, 0.25)})
zonas.append({'tipo': 'parque', 'puntos': poligono(mx - 900, my + 500, 700, 10, 0.3)})
sendero = camino(c_monte[-1], mx + 1600, my - 900, 'Sendero del Monte', 'path', paso=180, curva=0.6, principal=0)
lugar('el Monte de San Isidro', 'monte', mx + 300, my - 150, c_monte[-1])
lugar('Área recreativa de San Isidro', 'monte', mx - 60, my + 40, c_monte[-2])
lugar('Mirador del Monte', 'monte', nodos[sendero[-1]][0], nodos[sendero[-1]][1], sendero[-1])
lugar('Ermita de San Isidro', 'iglesia', nodos[sendero[len(sendero) // 2]][0] + 30, nodos[sendero[len(sendero) // 2]][1], sendero[len(sendero) // 2])

# ---------------------------------------------------------------- EMBALSE
ex, ey = nodos[c_embalse[-1]]
zonas.append({'tipo': 'agua', 'puntos': poligono(ex - 500, ey - 200, 650, 12, 0.25)})
lugar('Embalse del Vado', 'embalse', ex - 120, ey - 60, c_embalse[-1])
lugar('Merendero del embalse', 'embalse', nodos[c_embalse[-3]][0], nodos[c_embalse[-3]][1], c_embalse[-3])

# ---------------------------------------------------------------- CANTERA Y GRANJAS
qx, qy = nodos[c_molinos[-1]]
zonas.append({'tipo': 'industrial', 'puntos': poligono(qx + 250, qy - 250, 330, 8, 0.2)})
lugar('Cantera de Las Peñas', 'cantera', qx + 200, qy - 200, c_molinos[-1])

fincas = [
    ('Finca El Encinar', c_vega, 0.45), ('Cortijo La Vega', c_vega, 0.8), ('Granja Los Álamos', c_molinos, 0.4),
    ('Finca Las Viñas', c_molinos, 0.7), ('Bodega El Lagar', c_pozuelos, 0.5), ('Cortijo del Pozo', c_embalse, 0.55),
    ('Granja avícola San Marcos', c_norte, 0.75), ('Finca La Dehesilla', c_monte, 0.5), ('Cortijo de las Huertas', c_norte, 0.4),
    ('Finca Los Olivos', c_pozuelos, 0.75),
]
for nombre, via, t in fincas:
    n_via = via[int(len(via) * t)]
    vx, vy = nodos[n_via]
    ang = random.uniform(0, math.pi * 2)
    fx, fy = vx + math.cos(ang) * 420, vy + math.sin(ang) * 420
    acceso = camino(n_via, fx, fy, 'Camino de ' + nombre, 'track', paso=160, curva=0.4, principal=0)
    ax, ay = nodos[acceso[-1]]
    for k in range(3):
        edificios.append(rect(ax + 30 + k * 45, ay + random.uniform(-30, 30), 38, 24, ang))
    zonas.append({'tipo': 'campo', 'puntos': rect(ax, ay, 700, 500, ang)})
    lugar(nombre, 'finca', ax + 40, ay, acceso[-1])

# Área de servicio en la carretera de Ciudad Real y gasolinera
ar = carretera_cr[len(carretera_cr) // 2]
lugar('Área de descanso La Venta', 'carretera', nodos[ar][0], nodos[ar][1] + 40, ar)
edificios.append(rect(nodos[ar][0], nodos[ar][1] + 70, 60, 30))
for via, t, nombre in [(c_molinos, 0.55, 'Cruce de los Molinos'), (c_vega, 0.6, 'Curva de la Vega'), (c_pozuelos, 0.35, 'Puente del arroyo'),
                        (c_monte, 0.4, 'Recta del Monte'), (c_embalse, 0.3, 'Cruce del Embalse')]:
    n = via[int(len(via) * t)]
    lugar(nombre, 'carretera', nodos[n][0], nodos[n][1], n)

# Campos de cultivo repartidos
for _ in range(40):
    x, y = random.uniform(400, W - 400), random.uniform(400, H - 400)
    if OX - 300 < x < OX + d['tamano'][0] + 300 and OY - 300 < y < OY + d['tamano'][1] + 300:
        continue
    zonas.append({'tipo': 'campo', 'puntos': rect(x, y, random.uniform(500, 1200), random.uniform(400, 900), random.uniform(0, 3.14))})

# Helipuerto a las afueras, junto a la carretera de Ciudad Real
hp = carretera_cr[2]
lugar('Helipuerto de Miguelturra', 'helipuerto', nodos[hp][0], nodos[hp][1] - 60, hp)
zonas.append({'tipo': 'aparcamiento', 'puntos': rect(nodos[hp][0], nodos[hp][1] - 70, 120, 90)})

out = dict(d)
out.update({'tamano': [W, H], 'nodos': nodos, 'tramos': tramos, 'calles': calles, 'vias': vias,
    'edificios': edificios, 'zonas': zonas, 'tren': tren, 'lugares': lugares,
    'salida': salida, 'nodos_pueblo': n_pueblo, 'desplazamiento': [OX, OY],
    'pueblo_rect': [OX, OY, d['tamano'][0], d['tamano'][1]], 'zonas_pueblo': len(d['zonas']),
    'fuente': d['fuente'] + ' · Término municipal ampliado e inventado para el juego'})
json.dump(out, open(os.path.join(BASE, '..', 'data', 'map', 'miguelturra.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
print('nodos', len(nodos), 'de los que', n_pueblo, 'son del pueblo; tramos', len(tramos), 'lugares', len(lugares), 'tamaño', W, H)
