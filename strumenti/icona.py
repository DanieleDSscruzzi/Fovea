#!/usr/bin/env python3
"""
Icona Velo — v3.

v1: righe sottili, alone d'ottone → codice a barre a 60 px.
v2: pulita ma leggeva come un pulsante hamburger. Tre righe in un cerchio
    sono un menu, non un documento.
v5 (Fovea): la dissolvenza diventa il soggetto. Un gradiente diagonale trasforma le righe
    da nitide a illeggibili scendendo verso destra: è letteralmente la
    funzione dell'app, e nessun menu si comporta così.
"""
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 2048
INK_TOP, INK_BOT = (28, 31, 38), (11, 13, 17)
WINDOW = (36, 40, 49)
PAPER = (236, 234, 229)
BRASS = (200, 162, 74)
CX, CY, R = S // 2, S // 2, int(S * 0.325)

solid = lambda rgb: Image.new("RGB", (S, S), rgb)
blank = lambda: Image.new("L", (S, S), 0)

# ---------------------------------------------------------------- fondo
bg = Image.new("RGB", (S, S))
d = ImageDraw.Draw(bg)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)],
           fill=tuple(int(INK_TOP[i] + (INK_BOT[i] - INK_TOP[i]) * t) for i in range(3)))

disc = blank()
ImageDraw.Draw(disc).ellipse([CX - R, CY - R, CX + R, CY + R], fill=255)

# ---------------------------------------------------------------- il testo
# Cinque righe di lunghezza irregolare: un paragrafo, non un elenco.
BAR_H, STEP = int(S * 0.062), int(S * 0.093)
rows = [(0.26, 0.74), (0.26, 0.70), (0.26, 0.755), (0.26, 0.665), (0.26, 0.58)]
lines = blank()
dl = ImageDraw.Draw(lines)
for i, (x0, x1) in enumerate(rows):
    y = int(S * 0.315) + i * STEP
    dl.rounded_rectangle([int(S * x0), y, int(S * x1), y + BAR_H],
                         radius=BAR_H // 2, fill=255)

# ---------------------------------------------------------------- il velo
# Gradiente diagonale: 0 in alto a sinistra (in chiaro), 1 in basso a destra
# (coperto). Governa sfocatura, luminosità e persino l'anello, così il velo
# sembra uno strato fisico appoggiato sopra tutto il resto.
xs = np.linspace(0, 1, S)[None, :]
ys = np.linspace(0, 1, S)[:, None]
# Distanza dal centro, normalizzata sul raggio della lente.
rr = np.sqrt((xs * S - CX) ** 2 + (ys * S - CY) ** 2) / R
g = np.clip((rr - 0.52) / 0.58, 0, 1)
g = g * g * (3 - 2 * g)          # smoothstep: nitido al centro, sfatto fuori
veil = Image.fromarray((g * 255).astype(np.uint8), "L")

# ---------------------------------------------------------------- pagina
page = bg.copy()
page.paste(solid(WINDOW), (0, 0), disc)

sharp = page.copy()
sharp.paste(solid(PAPER), (0, 0), ImageChops.multiply(lines, disc))

soft = page.copy()
soft.paste(solid(PAPER), (0, 0),
           ImageChops.multiply(lines, disc)
           .filter(ImageFilter.GaussianBlur(int(S * 0.036)))
           .point(lambda v: int(v * 0.38)))

icon = Image.composite(soft, sharp, veil)
# Sotto il velo cala anche la luce.
icon = Image.composite(Image.blend(icon, solid((10, 11, 15)), 0.88), icon, veil)

# ---------------------------------------------------------------- anello
ring = blank()
ImageDraw.Draw(ring).ellipse([CX - R, CY - R, CX + R, CY + R],
                             outline=255, width=int(S * 0.0105))
ring = ImageChops.multiply(ring, veil.point(lambda v: 255 - int(v * 0.55)))
icon.paste(solid(BRASS), (0, 0), ring)

icon = icon.resize((1024, 1024), Image.LANCZOS)
icon.save("/home/claude/build/Fovea/Fovea/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

strip = Image.new("RGB", (1100, 220), (22, 24, 29))
x = 40
for size in (180, 120, 87, 60, 40, 29):
    strip.paste(icon.resize((size, size), Image.LANCZOS), (x, 110 - size // 2))
    x += size + 36
strip.save("/home/claude/build/anteprima.png")
print("fatto")
