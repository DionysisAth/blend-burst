"""Builds the Play Store graphics from the raw captures.

  flutter test tool/store/shots_test.dart --update-goldens
  flutter test tool/icon/icon_test.dart
  python3 tool/store/compose.py

Writes store/screenshots/*.png (1080x1920 with captions), store/feature.png
(1024x500) and store/icon-512-alpha.png (the store icon, 32-bit).
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'tool/store/raw')
OUT = os.path.join(ROOT, 'store')
FONT = os.path.join(ROOT, 'assets/fonts/LilitaOne-Regular.ttf')

SHOTS = [
    ('1_map', '120 colorful levels', 'across 8 painted worlds'),
    ('2_specials', 'Make blasters, bombs', 'and rainbow prisms'),
    ('3_cascade', 'Set off huge combos!', 'chain reactions everywhere'),
    ('4_obstacles', 'Beat ink, glass', 'and chains'),
    ('6_pass', 'Daily gifts & events', 'plus a season pass'),
]


def gradient(w, h, top, bottom):
    g = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def text(draw, xy, s, size, fill, stroke, anchor='mm', width=None):
    f = ImageFont.truetype(FONT, size)
    draw.text(xy, s, font=f, fill=fill, stroke_width=width or max(4, size // 9),
              stroke_fill=stroke, anchor=anchor)


def rounded(im, r):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), r, fill=255)
    out = Image.new('RGBA', im.size)
    out.paste(im, (0, 0), m)
    return out


def screenshot(name, title, sub):
    W, H = 1080, 1920
    bg = gradient(W, H, (122, 51, 214), (255, 110, 196)).convert('RGBA')
    # Soft rays.
    rays = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(rays)
    import math
    cx, cy = W / 2, 160
    for i in range(18):
        a = i * math.pi * 2 / 18
        d.polygon([(cx, cy),
                   (cx + math.cos(a - 0.08) * 2500, cy + math.sin(a - 0.08) * 2500),
                   (cx + math.cos(a + 0.08) * 2500, cy + math.sin(a + 0.08) * 2500)],
                  fill=(255, 255, 255, 22))
    bg = Image.alpha_composite(bg, rays)
    d = ImageDraw.Draw(bg)
    text(d, (W / 2, 120), title, 92, (255, 255, 255), (74, 22, 120))
    text(d, (W / 2, 225), sub, 58, (255, 226, 122), (74, 22, 120))
    shot = Image.open(os.path.join(RAW, name + '.png')).convert('RGB')
    sw = 860
    sh = int(shot.height * sw / shot.width)
    shot = rounded(shot.resize((sw, sh), Image.LANCZOS), 48)
    top = 310
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        ((W - sw) // 2 - 6, top + 14, (W + sw) // 2 + 6, top + sh + 22), 54, fill=(40, 10, 70, 140))
    bg = Image.alpha_composite(bg, shadow.filter(ImageFilter.GaussianBlur(18)))
    frame = Image.new('RGBA', (sw + 20, sh + 20), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, sw + 19, sh + 19), 56, fill=(255, 255, 255, 255))
    bg.alpha_composite(frame, ((W - sw) // 2 - 10, top - 10))
    bg.alpha_composite(shot, ((W - sw) // 2, top))
    os.makedirs(os.path.join(OUT, 'screenshots'), exist_ok=True)
    bg.convert('RGB').save(os.path.join(OUT, 'screenshots', name + '.png'))


def feature():
    base = Image.open(os.path.join(ROOT, 'tool/store/feature_base.png')).convert('RGBA')
    d = ImageDraw.Draw(base)
    text(d, (300, 205), 'Blend', 150, (255, 255, 255), (74, 22, 120), width=12)
    text(d, (300, 335), 'Burst', 150, (255, 214, 61), (74, 22, 120), width=12)
    text(d, (300, 440), 'Match • Blend • Burst', 40, (255, 255, 255), (74, 22, 120), width=6)
    base.convert('RGB').save(os.path.join(OUT, 'feature.png'))


def icon():
    Image.open(os.path.join(OUT, 'icon-512.png')).convert('RGBA').save(
        os.path.join(OUT, 'icon-512-alpha.png'))


if __name__ == '__main__':
    for s in SHOTS:
        screenshot(*s)
    feature()
    icon()
    print('Wrote store/screenshots, store/feature.png, store/icon-512-alpha.png')
