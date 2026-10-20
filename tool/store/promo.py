"""Builds the promo video (1920x1080, music + the game's own sound effects)
and the poster pack from the captures made by tool/store/promo_test.dart.

  flutter test tool/store/promo_test.dart
  python3 tool/store/promo.py

Writes tool/store/promo/blend-burst-promo.mp4 and
tool/store/promo/blend-burst-ad-pictures.zip.
"""
import json
import math
import os
import random
import subprocess
import tempfile
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(ROOT, 'tool/store/promo')
AUDIO = os.path.join(ROOT, 'assets/audio')
FONT = os.path.join(ROOT, 'assets/fonts/LilitaOne-Regular.ttf')
BODY = os.path.join(ROOT, 'assets/fonts/Fredoka-SemiBold.ttf')
ICON = os.path.join(ROOT, 'store/icon-512-alpha.png')
INK = (74, 22, 120)
W, H = 1920, 1080
FPS = 30
RATE = 44100

# clip, start (s), length (s), title, subtitle
SEGMENTS = [
    ('map', 1.0, 4.5, '120 colorful levels', 'across 8 painted worlds'),
    ('blend', 0.0, 5.0, 'Match & blend colors', 'Red + Blue = Purple!'),
    ('specials', 0.0, 3.4, 'Fire powerful specials', 'blasters, bombs and prisms'),
    ('combo', 0.0, 5.6, 'Swipe two specials together', 'for huge combos'),
    ('spectacular', 0.0, 3.0, 'Clear the whole board!', 'Spectacular!'),
    ('win', 0.0, 9.5, 'Win stars and rewards', 'daily gifts, events and a season pass'),
]
INTRO, OUTRO = 3.0, 4.0


def font(size, body=False):
    return ImageFont.truetype(BODY if body else FONT, size)


def text(d, xy, s, size, fill=(255, 255, 255), anchor='mm', body=False, stroke=None):
    d.text(xy, s, font=font(size, body), fill=fill, anchor=anchor,
           stroke_width=stroke if stroke is not None else max(3, size // 10),
           stroke_fill=INK)


def background(w, h, seed=3):
    """Purple-to-pink gradient with soft rays and confetti."""
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    top = np.array([122, 51, 214]); bottom = np.array([255, 110, 196])
    t = np.clip(0.75 * y + 0.25 * x, 0, 1)[..., None]
    arr = (top * (1 - t) + bottom * t).astype(np.uint8)
    img = Image.fromarray(arr, 'RGB').convert('RGBA')
    rays = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(rays)
    cx, cy = w * 0.5, h * 0.45
    for i in range(20):
        a = i * math.pi * 2 / 20
        d.polygon([(cx, cy),
                   (cx + math.cos(a - 0.07) * 4000, cy + math.sin(a - 0.07) * 4000),
                   (cx + math.cos(a + 0.07) * 4000, cy + math.sin(a + 0.07) * 4000)],
                  fill=(255, 255, 255, 20))
    img = Image.alpha_composite(img, rays)
    rng = random.Random(seed)
    colors = [(255, 77, 109), (255, 159, 28), (255, 217, 61), (46, 219, 127),
              (63, 167, 255), (180, 92, 255)]
    conf = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(conf)
    for i in range(int(w * h / 26000)):
        px, py = rng.random() * w, rng.random() * h
        s = rng.uniform(5, 13) * (w / 1920 + h / 1080) / 2
        c = colors[i % len(colors)] + (200,)
        if i % 3 == 0:
            d.ellipse((px - s, py - s, px + s, py + s), fill=c)
        else:
            d.rounded_rectangle((px - s * 1.6, py - s * 0.6, px + s * 1.6, py + s * 0.6),
                                radius=s * 0.5, fill=c)
    return Image.alpha_composite(img, conf.filter(ImageFilter.GaussianBlur(0.6)))


def phone_frame(img, box, radius):
    """Draws the white phone frame and its shadow behind [box]."""
    x0, y0, x1, y1 = box
    sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x0 - 10, y0 + 6, x1 + 10, y1 + 30), radius + 14,
                                         fill=(40, 10, 70, 150))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(20)))
    ImageDraw.Draw(img).rounded_rectangle((x0 - 12, y0 - 12, x1 + 12, y1 + 12), radius + 12,
                                          fill=(255, 255, 255, 255))
    return img


def rounded(im, r):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), r, fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out, m


def wrap(s, size, width, body=False):
    words, lines, cur = s.split(), [], ''
    f = font(size, body)
    for w_ in words:
        t = (cur + ' ' + w_).strip()
        if f.getlength(t) > width and cur:
            lines.append(cur)
            cur = w_
        else:
            cur = t
    lines.append(cur)
    return lines


# ----------------------------------------------------------------- video

PH = 980                    # phone screen height in the video
PW = int(PH * 1512 / 2688) // 2 * 2
PX, PY = 250, (H - PH) // 2
RADIUS = 46


def segment_frame(title, sub):
    img = phone_frame(background(W, H), (PX, PY, PX + PW, PY + PH), RADIUS)
    d = ImageDraw.Draw(img)
    cx = (PX + PW + W) // 2 + 20
    lines = wrap(title, 104, 980)
    y = H / 2 - 70 - (len(lines) - 1) * 58
    for ln in lines:
        text(d, (cx, y), ln, 104)
        y += 118
    text(d, (cx, y + 10), sub, 54, fill=(255, 226, 122))
    icon = Image.open(ICON).convert('RGBA').resize((110, 110), Image.LANCZOS)
    icon, _ = rounded(icon, 26)
    img.alpha_composite(icon, (W - 150, H - 150))
    return img.convert('RGB')


def card(title, sub, cta=None):
    img = background(W, H, seed=9)
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert('RGBA').resize((360, 360), Image.LANCZOS)
    icon, _ = rounded(icon, 80)
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W / 2 - 300, 120, W / 2 + 300, 720), fill=(255, 255, 255, 120))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(60)))
    img.alpha_composite(icon, (W // 2 - 180, 110))
    d = ImageDraw.Draw(img)
    text(d, (W / 2, 590), title, 150, stroke=14)
    text(d, (W / 2, 720), sub, 60, fill=(255, 226, 122))
    if cta:
        bw, bh = 760, 120
        x0, y0 = W / 2 - bw / 2, 820
        d.rounded_rectangle((x0, y0 + 10, x0 + bw, y0 + bh + 10), 60, fill=(19, 121, 47))
        d.rounded_rectangle((x0, y0, x0 + bw, y0 + bh), 60, fill=(46, 196, 82))
        text(d, (W / 2, y0 + bh / 2), cta, 66, stroke=6)
    return img.convert('RGB')


def ff(*args):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *args], check=True)


def build_video(tmp):
    parts = []
    # Intro and outro cards with a gentle zoom.
    for name, im, dur in [
        ('intro', card('Blend Burst', 'Match  •  Blend  •  Burst'), INTRO),
        ('outro', card('Blend Burst', 'Free puzzle fun', 'Get it on Google Play'), OUTRO),
    ]:
        src = os.path.join(tmp, name + '.png')
        im.save(src)
        out = os.path.join(tmp, name + '.mp4')
        n = int(dur * FPS)
        ff('-loop', '1', '-framerate', str(FPS), '-i', src, '-frames:v', str(n),
           '-vf', f"scale=2*{W}:2*{H},zoompan=z='1+0.05*on/{n}':x='iw/2-iw/zoom/2':"
                  f"y='ih/2-ih/zoom/2':d=1:s={W}x{H}:fps={FPS},"
                  f"fade=t=in:st=0:d=0.5,fade=t=out:st={dur - 0.5}:d=0.5,format=yuv420p",
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', out)
        parts.append((name, out))
    mask_img = Image.new('L', (PW, PH), 0)
    ImageDraw.Draw(mask_img).rounded_rectangle((0, 0, PW - 1, PH - 1), RADIUS, fill=255)
    mask = os.path.join(tmp, 'mask.png')
    mask_img.save(mask)
    for clip, start, length, title, sub in SEGMENTS:
        bg = os.path.join(tmp, f'bg_{clip}.png')
        segment_frame(title, sub).save(bg)
        out = os.path.join(tmp, f'seg_{clip}.mp4')
        ff('-loop', '1', '-framerate', str(FPS), '-i', bg,
           '-ss', str(start), '-t', str(length), '-i', os.path.join(P, 'clips', clip + '.mp4'),
           '-loop', '1', '-i', mask,
           '-filter_complex',
           f'[1:v]scale={PW}:{PH},format=rgba[ph];[2:v]format=gray,scale={PW}:{PH}[m];'
           f'[ph][m]alphamerge[phm];[0:v][phm]overlay={PX}:{PY}:shortest=1,'
           f'fade=t=in:st=0:d=0.25,fade=t=out:st={length - 0.25}:d=0.25,format=yuv420p[v]',
           '-map', '[v]', '-frames:v', str(int(length * FPS)), '-r', str(FPS),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', out)
        parts.append((clip, out))
    order = ['intro'] + [s[0] for s in SEGMENTS] + ['outro']
    files = dict(parts)
    lst = os.path.join(tmp, 'list.txt')
    with open(lst, 'w') as f:
        for name in order:
            f.write(f"file '{files[name]}'\n")
    silent = os.path.join(tmp, 'silent.mp4')
    ff('-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', silent)
    return silent


def decode(path):
    r = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-f', 'f32le', '-ac', '2',
                        '-ar', str(RATE), '-'], capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, 2)


def build_audio(tmp):
    total = INTRO + sum(s[2] for s in SEGMENTS) + OUTRO
    n = int(total * RATE)
    mix = np.zeros((n, 2), dtype=np.float32)
    music = decode(os.path.join(AUDIO, 'music_garden.ogg'))
    reps = int(math.ceil(n / len(music)))
    m = np.tile(music, (reps, 1))[:n] * 0.55
    fade = int(1.5 * RATE)
    m[:fade] *= np.linspace(0, 1, fade)[:, None]
    m[-fade:] *= np.linspace(1, 0, fade)[:, None]
    mix += m
    events = json.load(open(os.path.join(P, 'sounds.json')))['events']
    cache = {}
    t0 = INTRO
    for clip, start, length, _, _ in SEGMENTS:
        for e in events:
            if e['clip'] != clip:
                continue
            t = e['frame'] / FPS - start
            if t < 0 or t > length - 0.1:
                continue
            path = os.path.join(AUDIO, e['file'])
            if not os.path.exists(path):
                continue
            if path not in cache:
                cache[path] = decode(path)
            snd = cache[path] * float(e['volume']) * 0.9
            i = int((t0 + t) * RATE)
            j = min(n, i + len(snd))
            mix[i:j] += snd[: j - i]
        t0 += length
    peak = np.max(np.abs(mix))
    if peak > 0.98:
        mix *= 0.98 / peak
    wav = os.path.join(tmp, 'audio.f32')
    mix.astype(np.float32).tofile(wav)
    return wav


def video():
    with tempfile.TemporaryDirectory() as tmp:
        silent = build_video(tmp)
        audio = build_audio(tmp)
        out = os.path.join(P, 'blend-burst-promo.mp4')
        ff('-i', silent, '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-i', audio,
           '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
           '-shortest', '-movflags', '+faststart', out)
        print('Wrote', out)


# --------------------------------------------------------------- pictures

STILL_CAPTIONS = [
    ('map_start', 'An adventure of colors', '120 levels to explore'),
    ('map_galaxy', '8 painted worlds', 'from the Art Studio to Gravity Galaxy'),
    ('level_blend', 'Blend colors', 'Red + Blue = Purple!'),
    ('blend_cascade', 'Chain reactions', 'cascades and combos'),
    ('specials_ready', 'Make specials', 'Line Blasters, Paint Bombs, Prisms'),
    ('specials_line', 'Blast whole rows', 'with the Line Blaster'),
    ('combo_cross', 'Huge combos', 'swipe two specials together'),
    ('spectacular_burst', 'Spectacular!', 'clear the whole board'),
    ('world_5_lagoon', 'Fresh challenges', 'ink, glass, chains and more'),
    ('world_8_galaxy', 'Gravity shifts', 'tiles fall in every direction'),
    ('win_stars', 'Collect stars', 'and win rewards'),
    ('menu_pass', 'Daily gifts & events', 'plus a season pass'),
]


def load_still(name, w=1080):
    im = Image.open(os.path.join(P, 'stills', name + '.png')).convert('RGB')
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def portrait(name, title, sub):
    Wp, Hp = 1080, 1920
    bg = background(Wp, Hp, seed=sum(map(ord, name)))
    d = ImageDraw.Draw(bg)
    text(d, (Wp / 2, 120), title, 96)
    text(d, (Wp / 2, 226), sub, 54, fill=(255, 226, 122))
    sw = 860
    shot = load_still(name, sw)
    top = 310
    bg = phone_frame(bg, ((Wp - sw) // 2, top, (Wp + sw) // 2, top + shot.height), 48)
    s, m = rounded(shot, 48)
    bg.alpha_composite(s, ((Wp - sw) // 2, top))
    return bg.convert('RGB')


def square(name, title, sub):
    S = 1080
    bg = background(S, S, seed=sum(map(ord, name)) + 7)
    d = ImageDraw.Draw(bg)
    text(d, (S / 2, 90), title, 84)
    text(d, (S / 2, 180), sub, 46, fill=(255, 226, 122))
    full = load_still(name, 1080)
    # The board sits in the middle of the screen.
    box = (0, int(full.height * 0.215), 1080, int(full.height * 0.765))
    crop = full.crop(box)
    ch = S - 240 - 50
    cw = int(crop.width * ch / crop.height)
    crop = crop.resize((cw, ch), Image.LANCZOS)
    top, left = 240, (S - cw) // 2
    bg = phone_frame(bg, (left, top, left + cw, top + ch), 40)
    c, _ = rounded(crop, 40)
    bg.alpha_composite(c, (left, top))
    return bg.convert('RGB')


def landscape(name, title, sub):
    img = Image.open(os.path.join(P, 'stills', name + '.png')).convert('RGB')
    base = segment_frame(title, sub).convert('RGBA')
    shot = img.resize((PW, PH), Image.LANCZOS)
    s, _ = rounded(shot, RADIUS)
    base.alpha_composite(s, (PX, PY))
    return base.convert('RGB')


def pictures():
    out = os.path.join(P, 'blend-burst-ad-pictures.zip')
    with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(out, 'w') as z:
        def add(im, arc):
            path = os.path.join(tmp, os.path.basename(arc))
            im.save(path, quality=92)
            z.write(path, arc)

        for i, (name, title, sub) in enumerate(STILL_CAPTIONS, 1):
            add(portrait(name, title, sub), f'posters-portrait-1080x1920/{i:02d}_{name}.png')
            add(landscape(name, title, sub), f'banners-landscape-1920x1080/{i:02d}_{name}.png')
            if not name.startswith(('map', 'menu', 'win')):
                add(square(name, title, sub), f'posts-square-1080x1080/{i:02d}_{name}.png')
        for f in sorted(os.listdir(os.path.join(P, 'stills'))):
            add(load_still(f[:-4]), f'screenshots-raw-1080x1920/{f}')
        add(card('Blend Burst', 'Match  •  Blend  •  Burst'), 'title-card-1920x1080.png')
        add(card('Blend Burst', 'Free puzzle fun', 'Get it on Google Play'),
            'end-card-1920x1080.png')
        z.write(os.path.join(ROOT, 'store/feature.png'), 'store/feature-graphic-1024x500.png')
        z.write(ICON, 'store/icon-512.png')
    print('Wrote', out)


if __name__ == '__main__':
    pictures()
    video()
