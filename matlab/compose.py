import csv, json, math, sys, os
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

CSV, FR, OUTMP4 = sys.argv[1], sys.argv[2], sys.argv[3]
rows = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(CSV))]
arrows = json.load(open(os.path.join(FR, 'arrows.json')))
FPS = 24
FD = 'C:/Windows/Fonts/'
f_lab = ImageFont.truetype(FD + 'segoeui.ttf', 13)
f_val = ImageFont.truetype(FD + 'segoeui.ttf', 19)
f_leg = ImageFont.truetype(FD + 'consola.ttf', 15)
f_leg_s = ImageFont.truetype(FD + 'consola.ttf', 13)
f_bot = ImageFont.truetype(FD + 'consola.ttf', 18)
COL = {'tire': (255, 140, 0), 'grav': (140, 50, 200), 'suct': (0, 150, 255), 'sum': (255, 220, 0)}
MODE = {0: 'DRIVE', 1: 'RAMP CLIMB', 2: 'AIRBORNE', 3: 'DRIVE', 4: 'RAMP DROP', 5: 'TOUCHDOWN'}
WHITE = (235, 235, 235)


def bar(d, y, label, text, frac):
    d.text((32, y), label, font=f_lab, fill=(200, 200, 200))
    d.text((158, y - 5), text, font=f_val, fill=WHITE)
    d.rectangle([30, y + 20, 338, y + 22], fill=(70, 70, 70))
    d.rectangle([30, y + 19, 30 + max(2, int(308 * min(max(frac, 0), 1))), y + 23], fill=WHITE)


def arrow(d, a, b, col):
    ax, ay = a; bx, by = b
    L = math.hypot(bx - ax, by - ay)
    if L < 3:
        return
    ux, uy = (bx - ax) / L, (by - ay) / L
    hl = min(22, L * 0.45)
    d.line([ax, ay, bx - ux * hl * 0.6, by - uy * hl * 0.6], fill=col + (255,), width=5)
    p = [(bx, by), (bx - ux * hl + -uy * hl * 0.45, by - uy * hl + ux * hl * 0.45),
         (bx - ux * hl + uy * hl * 0.45, by - uy * hl - ux * hl * 0.45)]
    d.polygon(p, fill=col + (255,))


vw = cv2.VideoWriter(OUTMP4, cv2.VideoWriter_fourcc(*'mp4v'), FPS, (1280, 720))
for i, r in enumerate(rows):
    im = Image.open(os.path.join(FR, 'f%04d.png' % i)).convert('RGB')
    ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    mode = int(r['mode'])
    for a in arrows[i]:
        arrow(d, a['a'], a['b'], COL[a['c']])
    z, spd, gf = r['z'], r['speed_kmh'], r['g_force']
    bar(d, 32, 'DOWNFORCE', '%d kg' % round(r['downforce_kg']), r['downforce_kg'] / 8000)
    bar(d, 69, 'TILT', '%.1f deg' % r['pitch_deg'], abs(r['pitch_deg']) / 360)
    bar(d, 106, 'ALTITUDE', '%.1f ft  %.1f m' % (z * 3.28084, z), z / 40)
    bar(d, 143, 'G-FORCE', '%.2f g' % gf, gf / 3)
    bar(d, 180, 'SPEED', '%.1f km/h' % spd, spd / 150)
    # legend
    mg, fs = r['mg_kN'], r['Fsuction_kN']
    ph = math.radians(r['pitch_deg']) if mode in (1, 4) else 0.0
    tot = math.hypot(fs * math.sin(ph), mg + fs * math.cos(ph))
    items = [('tire', 'Tire road reaction', 'FL %.1f FR %.1f' % (r['N_FL_kN'], r['N_FR_kN'])),
             (None, '(normal, kN)', 'RL %.1f RR %.1f' % (r['N_RL_kN'], r['N_RR_kN'])),
             ('grav', 'Gravity m*g', '%.1f kN' % mg),
             ('suct', 'Suction downforce', '%.1f kN' % fs),
             ('sum', 'Gravity + suction', '%.1f kN' % tot)]
    y = 40
    for key, name, val in items:
        if key:
            d.rectangle([890, y, 916, y + 15], fill=COL[key] + (255,))
        d.text((934, y - 2), name, font=f_leg, fill=WHITE)
        d.text((1085, y - 2), val, font=f_leg, fill=WHITE)
        y += 30
    d.text((894, y + 4), 'Arrow length: 1 m = 10 kN', font=f_leg_s, fill=(200, 200, 200))
    label = 't = %5.2f s (simulation time)  mode: %s' % (r['t'], MODE[mode])
    w = d.textlength(label, font=f_bot)
    d.rectangle([20, 670, 20 + w + 16, 700], fill=(0, 0, 0, 170))
    d.text((28, 673), label, font=f_bot, fill=WHITE)
    out = Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB')
    vw.write(cv2.cvtColor(np.array(out), cv2.COLOR_RGB2BGR))
vw.release()
print('wrote', OUTMP4, len(rows))
