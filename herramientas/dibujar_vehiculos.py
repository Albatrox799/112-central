"""Genera los dibujos de los vehículos (vista lateral, mirando a la derecha).
Se dibujan a 4x y se reducen para que queden suaves. Salida: assets/vehiculos/*.png"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math, json
S = 4
W, H = 128, 60
GROUND = 52
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'vehiculos')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
LUCES = {}

def P(pts): return [(x * S, y * S) for x, y in pts]

class Lienzo:
    def __init__(self):
        self.im = Image.new('RGBA', (W * S, H * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
    def poly(self, pts, fill, outline=(15, 20, 30, 255), w=1.2):
        self.d.polygon(P(pts), fill=fill, outline=outline, width=int(w * S))
    def rect(self, x, y, w, h, fill, r=0, outline=None, ow=1.0):
        box = [x * S, y * S, (x + w) * S, (y + h) * S]
        if r: self.d.rounded_rectangle(box, r * S, fill=fill, outline=outline, width=int(ow * S) if outline else 0)
        else: self.d.rectangle(box, fill=fill, outline=outline, width=int(ow * S) if outline else 0)
    def circ(self, x, y, r, fill, outline=None, ow=1.0):
        self.d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=fill, outline=outline, width=int(ow * S) if outline else 0)
    def line(self, pts, fill, w=1.0):
        self.d.line(P(pts), fill=fill, width=max(1, int(w * S)), joint='curve')
    def text(self, x, y, t, size, fill, anchor='mm'):
        f = ImageFont.truetype(FONT, int(size * S))
        self.d.text((x * S, y * S), t, font=f, fill=fill, anchor=anchor)
    def guardar(self, nombre, sombra=True):
        im = self.im
        if sombra:
            sh = Image.new('RGBA', im.size, (0, 0, 0, 0))
            ImageDraw.Draw(sh).ellipse([8 * S, (GROUND - 2) * S, (W - 8) * S, (GROUND + 5) * S], fill=(0, 0, 0, 110))
            sh = sh.filter(ImageFilter.GaussianBlur(3 * S))
            sh.alpha_composite(im)
            im = sh
        im = im.resize((W, H), Image.LANCZOS)
        im.save(os.path.join(OUT, nombre + '.png'))

def rueda(c, x, r=8.0, y=None):
    y = GROUND - r if y is None else y
    c.circ(x, y, r, (18, 20, 24, 255))
    c.circ(x, y, r * 0.58, (150, 156, 166, 255), outline=(60, 64, 72, 255), ow=0.8)
    c.circ(x, y, r * 0.2, (70, 74, 82, 255))
    for k in range(5):
        a = k * math.tau / 5
        c.line([(x, y), (x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.5)], (95, 100, 110, 255), 0.7)

def cuadros(c, x0, x1, y, h, a, b, filas=2, paso=6):
    """Banda de cuadros tipo Battenburg."""
    t = 0
    x = x0
    while x < x1:
        w = min(paso, x1 - x)
        for f in range(filas):
            col = a if (t + f) % 2 == 0 else b
            c.rect(x, y + f * h / filas, w, h / filas, col)
        x += paso
        t += 1

def cristal(c, pts):
    c.poly(pts, (110, 160, 210, 255), outline=(20, 28, 40, 255), w=0.9)
    # reflejo
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    c.line([(min(xs) + 2, max(ys) - 2), (min(xs) + 6, min(ys) + 2)], (220, 240, 255, 150), 1.2)

def puente_luces(c, x, y, w, col_a=(40, 110, 255, 255), col_b=(40, 110, 255, 255), nombre=None):
    c.rect(x, y, w, 3.2, (30, 34, 44, 255), r=1.2)
    c.rect(x + 0.6, y + 0.4, w / 2 - 1, 2.4, col_a, r=1)
    c.rect(x + w / 2 + 0.4, y + 0.4, w / 2 - 1, 2.4, col_b, r=1)
    if nombre:
        LUCES[nombre] = [round((x + w / 2) / W, 3), round((y + 1.5) / H, 3)]

# ------------------------------------------------------------ carrocerías
def coche(nombre, cuerpo, banda=None, texto=None, col_texto=(20, 40, 110, 255), luces=True, faros=True, techo=None):
    c = Lienzo()
    body = [(8, 44), (8, 34), (16, 30), (36, 28), (48, 17), (82, 16), (96, 28), (116, 31), (120, 37), (120, 45), (8, 45)]
    c.poly(body, cuerpo)
    cristal(c, [(51, 19), (66, 19), (66, 28), (40, 28)])
    cristal(c, [(69, 19), (81, 19), (92, 28), (69, 28)])
    c.line([(67.5, 18), (67.5, 29)], (20, 24, 32, 255), 1.6)
    if banda:
        banda(c)
    if texto:
        c.text(64, 32.2, texto, 3.9, col_texto)
    if techo:
        techo(c)
    elif luces:
        puente_luces(c, 54, 13.2, 22, nombre=nombre)
    c.line([(12, 40), (116, 40)], (0, 0, 0, 60), 0.6)
    c.rect(116, 32, 4, 3, (255, 240, 180, 255), r=1)   # faro
    c.rect(8, 33, 3, 3, (220, 40, 40, 255), r=1)       # piloto
    rueda(c, 30); rueda(c, 98)
    c.guardar(nombre)

def furgon(nombre, cuerpo, banda=None, texto=None, col_texto=(20, 40, 110, 255), luces_col=None, rejas=False):
    c = Lienzo()
    body = [(6, 45), (6, 10), (88, 9), (100, 14), (114, 28), (120, 32), (120, 45)]
    c.poly(body, cuerpo)
    cristal(c, [(90, 12), (99, 15), (110, 28), (90, 28)])
    if rejas:
        for x in (16, 34, 52, 70):
            c.rect(x, 14, 12, 9, (40, 50, 64, 255), r=1)
            for k in range(4):
                c.line([(x + 2 + k * 2.8, 14), (x + 2 + k * 2.8, 23)], (150, 160, 170, 255), 0.6)
    else:
        cristal(c, [(66, 13), (86, 13), (86, 24), (66, 24)])
    c.line([(88, 10), (88, 44)], (20, 24, 32, 255), 1.0)
    c.line([(62, 10), (62, 44)], (20, 24, 32, 150), 0.6)
    if banda: banda(c)
    if texto: c.text(36, 28.5, texto, 4.6, col_texto)
    a, b = luces_col or ((40, 110, 255, 255), (40, 110, 255, 255))
    puente_luces(c, 70, 6, 20, a, b, nombre=nombre)
    c.rect(116, 33, 4, 3, (255, 240, 180, 255), r=1)
    c.rect(6, 30, 3, 4, (220, 40, 40, 255), r=1)
    rueda(c, 26); rueda(c, 100)
    c.guardar(nombre)

def ambulancia(nombre, sva=False):
    c = Lienzo()
    amarillo = (255, 214, 0, 255)
    verde = (0, 150, 70, 255)
    c.rect(4, 6, 80, 39, amarillo, r=3, outline=(15, 20, 30, 255), ow=1.2)
    c.poly([(84, 14), (100, 14), (114, 28), (120, 33), (120, 45), (84, 45)], amarillo)
    cristal(c, [(88, 17), (99, 17), (110, 29), (88, 29)])
    cuadros(c, 4, 84, 30, 8, verde, amarillo, 2, 6)
    cuadros(c, 84, 120, 34, 4, verde, amarillo, 1, 6)
    c.rect(48, 10, 26, 14, (240, 245, 250, 255), r=1, outline=(20, 30, 40, 255), ow=0.6)
    c.rect(59, 12, 4, 10, (220, 40, 40, 255)); c.rect(56, 15, 10, 4, (220, 40, 40, 255))
    c.text(26, 17, "SVA" if sva else "SVB", 7, (0, 90, 40, 255))
    c.text(26, 25, "AMBULANCIA", 3.6, (0, 90, 40, 255))
    puente_luces(c, 30, 2.6, 26, nombre=nombre)
    puente_luces(c, 86, 10.6, 12)
    c.rect(116, 35, 4, 3, (255, 240, 180, 255), r=1)
    rueda(c, 24); rueda(c, 102)
    c.guardar(nombre)

def camion(nombre, cuerpo, banda_col=(250, 250, 250, 255), escalera=False, texto="BOMBEROS", col_texto=(255, 255, 255, 255), carga=None, luces_ok=True):
    c = Lienzo()
    c.rect(4, 13, 84, 31, cuerpo, r=2, outline=(15, 20, 30, 255), ow=1.2)
    c.poly([(88, 8), (108, 8), (118, 22), (122, 30), (122, 45), (88, 45)], cuerpo)
    cristal(c, [(92, 11), (106, 11), (114, 24), (92, 24)])
    for x in (8, 30, 52):
        c.rect(x, 16, 19, 11, tuple(max(0, v - 30) for v in cuerpo[:3]) + (255,), r=1, outline=(20, 20, 20, 200), ow=0.6)
        c.line([(x + 2, 21.5), (x + 17, 21.5)], (220, 220, 220, 180), 0.6)
    c.rect(4, 34, 118, 3.5, banda_col)
    if texto:
        c.text(40, 30.6, texto, 4.0, col_texto)
    if escalera:
        c.line([(2, 9), (96, 9)], (200, 205, 212, 255), 1.6)
        c.line([(2, 12), (96, 12)], (200, 205, 212, 255), 1.6)
        for x in range(4, 96, 5):
            c.line([(x, 9), (x, 12)], (200, 205, 212, 255), 0.8)
    elif carga:
        carga(c)
    else:
        c.rect(10, 9, 30, 4, (90, 90, 90, 255), r=1)   # mangueras en el techo
        c.circ(70, 10, 4, (230, 230, 230, 255), outline=(40, 40, 40, 255), ow=0.6)
    if luces_ok:
        puente_luces(c, 92, 4.6, 16, nombre=nombre)
    c.rect(118, 33, 4, 3, (255, 240, 180, 255), r=1)
    rueda(c, 22, 9); rueda(c, 44, 9); rueda(c, 104, 9)
    c.guardar(nombre)

def moto(nombre, color, texto_col=None, maleta=None):
    c = Lienzo()
    rueda(c, 34, 10); rueda(c, 94, 10)
    c.poly([(34, 42), (52, 28), (82, 26), (94, 42), (86, 42), (78, 32), (56, 34), (42, 42)], (40, 44, 52, 255))
    c.poly([(54, 24), (84, 20), (98, 26), (92, 32), (60, 32)], color)
    c.poly([(86, 18), (96, 8), (100, 10), (94, 24)], (150, 190, 230, 200))
    if maleta:
        c.rect(20, 18, 22, 14, maleta, r=2, outline=(15, 20, 30, 255), ow=0.8)
    # piloto
    c.poly([(62, 22), (70, 6), (80, 6), (82, 20), (74, 26)], (30, 40, 70, 255))
    c.circ(76, 4, 5.5, color, outline=(15, 20, 30, 255), ow=0.8)
    c.rect(77, 2, 5, 3, (40, 60, 90, 255), r=1)
    c.line([(80, 12), (92, 20)], (30, 40, 70, 255), 3)
    c.rect(96, 22, 4, 3, (255, 240, 180, 255), r=1)
    c.rect(66, 16, 6, 2.5, (40, 110, 255, 255), r=1)
    LUCES[nombre] = [round(69 / W, 3), round(17 / H, 3)]
    c.guardar(nombre)

def blindado(nombre, cuerpo, texto, texto_col=(230, 235, 240, 255), banda=None):
    c = Lienzo()
    c.poly([(6, 44), (6, 14), (14, 6), (90, 6), (104, 14), (118, 26), (122, 34), (122, 44)], cuerpo)
    cristal(c, [(94, 12), (102, 15), (112, 26), (94, 26)])
    for x in (20, 44, 68):
        c.rect(x, 14, 12, 5, (70, 90, 110, 255), r=1)
    c.line([(88, 7), (88, 44)], (0, 0, 0, 120), 1.0)
    for x in range(10, 120, 9):
        c.circ(x, 8.5, 0.7, (90, 95, 105, 255))
    if banda: banda(c)
    c.text(46, 27, texto, 6.5, texto_col)
    puente_luces(c, 40, 2.6, 24, nombre=nombre)
    c.rect(118, 34, 4, 3, (255, 240, 180, 255), r=1)
    rueda(c, 24, 10); rueda(c, 50, 10); rueda(c, 102, 10)
    c.guardar(nombre)

def heli(nombre, cuerpo, banda_col, texto, texto_col=(255, 255, 255, 255), cubo=False):
    c = Lienzo()
    c.line([(16, 30), (64, 30)], cuerpo, 6)
    c.poly([(8, 18), (16, 18), (20, 30), (10, 34)], cuerpo)
    c.circ(10, 30, 5, (60, 64, 72, 255)); c.line([(10, 24), (10, 36)], (200, 200, 200, 200), 0.8)
    c.d.ellipse(P([(54, 14), (118, 46)])[0] + P([(54, 14), (118, 46)])[1], fill=cuerpo, outline=(15, 20, 30, 255), width=int(1.2 * S))
    cristal(c, [(92, 18), (106, 20), (114, 30), (98, 32), (90, 26)])
    c.rect(62, 32, 38, 4, banda_col)
    c.text(76, 26, texto, 4.6, texto_col)
    c.rect(78, 10, 12, 5, (60, 64, 72, 255), r=1)
    c.line([(30, 8), (122, 8)], (40, 44, 52, 255), 1.6)
    c.circ(84, 9, 2, (40, 44, 52, 255))
    c.line([(66, 46), (110, 46)], (40, 44, 52, 255), 1.6)
    c.line([(72, 42), (70, 46)], (40, 44, 52, 255), 1.2); c.line([(104, 42), (106, 46)], (40, 44, 52, 255), 1.2)
    if cubo:
        c.line([(84, 46), (84, 52)], (40, 40, 40, 255), 0.6)
        c.poly([(79, 52), (89, 52), (87, 58), (81, 58)], (220, 60, 40, 255))
    c.rect(112, 34, 3, 2, (255, 60, 60, 255))
    LUCES[nombre] = [round(84 / W, 3), round(15 / H, 3)]
    c.guardar(nombre, sombra=False)

# ------------------------------------------------------------ libreas
AZUL = (24, 72, 170, 255); BLANCO = (245, 247, 250, 255); AMAR_FLUO = (210, 240, 30, 255)
def banda_policia(c):
    cuadros(c, 8, 120, 36, 6, AZUL, BLANCO, 2, 6)
def banda_policia_furgon(c):
    cuadros(c, 6, 120, 34, 7, AZUL, BLANCO, 2, 6)
def banda_gc(c):
    c.rect(8, 35, 112, 5, (0, 110, 60, 255)); c.rect(8, 40, 112, 1.2, (240, 200, 0, 255))
def banda_pc(c):
    cuadros(c, 6, 120, 34, 7, (255, 130, 20, 255), (30, 60, 140, 255), 2, 6)
def banda_vir(c):
    cuadros(c, 8, 120, 36, 6, (0, 150, 70, 255), (255, 214, 0, 255), 2, 6)

coche('patrulla', BLANCO, banda_policia, "POLICÍA LOCAL", AZUL)
coche('canina', BLANCO, banda_policia, "UNIDAD CANINA", AZUL)
coche('camuflado', (50, 54, 62, 255), None, None, luces=False,
      techo=lambda c: (c.circ(76, 15, 2.6, (40, 110, 255, 255), outline=(20, 20, 30, 255), ow=0.5), LUCES.__setitem__('camuflado', [round(76 / W, 3), round(15 / H, 3)])))
coche('judicial', (70, 74, 84, 255), None, None, luces=False,
      techo=lambda c: (c.circ(76, 15, 2.6, (40, 110, 255, 255), outline=(20, 20, 30, 255), ow=0.5), LUCES.__setitem__('judicial', [round(76 / W, 3), round(15 / H, 3)])))
coche('guardia_civil', BLANCO, banda_gc, "GUARDIA CIVIL", (0, 90, 50, 255))
coche('vir', (255, 214, 0, 255), banda_vir, "VIR · 112", (0, 70, 30, 255))
coche('sospechoso', (170, 30, 40, 255), None, None, luces=False, techo=lambda c: None)
coche('civil', (120, 126, 136, 255), None, None, luces=False, techo=lambda c: None)
furgon('furgon', BLANCO, banda_policia_furgon, "POLICÍA LOCAL", AZUL, rejas=True)
furgon('pc_vehiculo', BLANCO, banda_pc, "PROTECCIÓN CIVIL", (30, 60, 140, 255))
furgon('geo_antidisturbios', (35, 40, 50, 255), lambda c: c.rect(6, 36, 114, 2, (180, 190, 210, 255)), "U.I.P.", (230, 235, 240, 255), rejas=True)
furgon('geo_mando', (45, 50, 60, 255), lambda c: c.rect(6, 36, 114, 2, (180, 190, 210, 255)), "MANDO", (230, 235, 240, 255))
furgon('funeraria', (30, 32, 36, 255), lambda c: c.rect(6, 37, 114, 1.2, (190, 190, 190, 255)), "", (230, 230, 230, 255))
LUCES.pop('funeraria', None)
ambulancia('ambulancia_b'); ambulancia('ambulancia_sva', sva=True)
camion('pma', (255, 214, 0, 255), (0, 150, 70, 255), texto="P.M.A.", col_texto=(0, 90, 40, 255),
       carga=lambda c: c.rect(10, 8, 60, 5, (230, 230, 230, 255), r=1, outline=(60, 60, 60, 255), ow=0.6))
camion('autobomba', (200, 30, 30, 255)); camion('escalera', (200, 30, 30, 255), escalera=True)
camion('rescate', (200, 30, 30, 255), (250, 210, 0, 255), texto="RESCATE",
       carga=lambda c: (c.rect(10, 8, 26, 5, (240, 200, 0, 255), r=1), c.rect(44, 8, 20, 5, (90, 90, 90, 255), r=1)))
OLIVA = (110, 116, 70, 255)
camion('ume_forestal', OLIVA, (230, 180, 20, 255), texto="UME", col_texto=(250, 230, 150, 255))
camion('ume_rescate', OLIVA, (230, 180, 20, 255), texto="UME RESCATE", col_texto=(250, 230, 150, 255),
       carga=lambda c: (c.line([(10, 10), (60, 4)], (230, 180, 20, 255), 2), c.rect(8, 9, 10, 4, (80, 80, 80, 255))))
camion('ume_nrbq', OLIVA, (230, 180, 20, 255), texto="UME NRBQ", col_texto=(250, 230, 150, 255),
       carga=lambda c: c.circ(40, 10, 4, (250, 220, 0, 255), outline=(20, 20, 20, 255), ow=0.6))
camion('ume_anfibio', OLIVA, (230, 180, 20, 255), texto="UME", col_texto=(250, 230, 150, 255),
       carga=lambda c: c.poly([(8, 13), (12, 6), (70, 6), (74, 13)], (230, 120, 30, 255)))
camion('ume', OLIVA, (230, 180, 20, 255), texto="UME", col_texto=(250, 230, 150, 255))
blindado('geo_blindado', (35, 38, 46, 255), "GEO")
blindado('geo_tedax', (35, 38, 46, 255), "TEDAX", banda=lambda c: c.rect(6, 38, 116, 2.5, (240, 200, 0, 255)))
moto('moto', BLANCO, maleta=AZUL)
moto('moto_sanitaria', (255, 214, 0, 255), maleta=(0, 150, 70, 255))
heli('heli_sanitario', (255, 214, 0, 255), (0, 150, 70, 255), "112", (0, 80, 30, 255))
heli('heli_policia', (24, 72, 170, 255), BLANCO, "POLICÍA")
heli('heli_bomberos', (200, 30, 30, 255), BLANCO, "BOMBEROS", cubo=True)
# Posición de las luces (0-1) para que parpadeen en el juego
with open(os.path.join(os.path.dirname(__file__), '..', 'data', 'gestion', 'sprites.gd'), 'w') as f:
    f.write("class_name Sprites\nextends RefCounted\n## Generado por herramientas/dibujar_vehiculos.py\n\n")
    f.write("const LUCES := {\n")
    for k in sorted(LUCES):
        f.write('\t"%s": Vector2(%s, %s),\n' % (k, LUCES[k][0], LUCES[k][1]))
    f.write("}\n")
    f.write('''
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
''')
print(len(os.listdir(OUT)), 'ficheros')
