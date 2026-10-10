"""Procedural sound design for Blend Burst.

Regenerate all game audio (sound effects and music loops) with:

    python3 tool/audio/synth.py assets/audio

Everything is synthesized from scratch (no samples), so the output is free
to ship. Requires numpy and scipy.
"""
import math
import os
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100          # sound effects
MUSIC_SR = 32000    # music loops (mono, keeps the APK small)
RNG = np.random.default_rng(7)


# --------------------------------------------------------------- helpers

def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def note_hz(name):
    """'C5', 'F#4', 'Bb3' -> frequency."""
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    n = names[name[0]]
    i = 1
    if name[1] == '#':
        n += 1
        i = 2
    elif name[1] == 'b':
        n -= 1
        i = 2
    octave = int(name[i:])
    midi = 12 * (octave + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, sr, a=0.005, d=0.05, s=0.6, r=0.1, hold=None):
    total = n / sr
    hold = total - a - d - r if hold is None else hold
    hold = max(0.0, hold)
    parts = [
        np.linspace(0, 1, max(1, int(a * sr)), endpoint=False),
        np.linspace(1, s, max(1, int(d * sr)), endpoint=False),
        np.full(max(0, int(hold * sr)), s),
        np.linspace(s, 0, max(1, int(r * sr))),
    ]
    e = np.concatenate(parts)
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def exp_decay(n, sr, tau):
    return np.exp(-np.arange(n) / sr / tau)


def lowpass(x, cutoff, sr=SR, order=2):
    b, a = signal.butter(order, min(cutoff / (sr / 2), 0.99), 'low')
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, sr=SR, order=2):
    b, a = signal.butter(order, cutoff / (sr / 2), 'high')
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, sr=SR, order=2):
    b, a = signal.butter(order, [lo / (sr / 2), min(hi / (sr / 2), 0.99)], 'band')
    return signal.lfilter(b, a, x)


def sweep_phase(f0, f1, n, sr, curve=1.0):
    """Phase of a frequency glide from f0 to f1 (curve > 1 = slow start)."""
    k = np.linspace(0, 1, n) ** curve
    f = f0 + (f1 - f0) * k
    return 2 * np.pi * np.cumsum(f) / sr


def exp_sweep_phase(f0, f1, n, sr):
    f = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return 2 * np.pi * np.cumsum(f) / sr


def make_ir(sr, length=1.6, t60=1.3, bright=6000, predelay=0.012):
    n = int(length * sr)
    t = np.arange(n) / sr
    ir = RNG.standard_normal(n) * np.exp(-6.9 * t / t60)
    ir = lowpass(ir, bright, sr)
    # Darker tail: blend in a more filtered copy over time.
    dark = lowpass(ir, bright / 3, sr)
    mix = np.clip(t / length, 0, 1)
    ir = ir * (1 - mix) + dark * mix
    pd = np.zeros(int(predelay * sr))
    ir = np.concatenate([pd, ir])
    return ir / np.sqrt(np.sum(ir ** 2))


IR_SFX = make_ir(SR, length=1.2, t60=0.9)
IR_MUSIC = make_ir(MUSIC_SR, length=2.2, t60=1.8, bright=5000)


def reverb(x, wet=0.25, sr=SR, ir=None, tail=True):
    ir = (IR_SFX if sr == SR else IR_MUSIC) if ir is None else ir
    x = fade(x, 0.0005, 0.015, sr)  # never feed an abrupt end into the reverb
    w = signal.fftconvolve(x, ir)[: len(x) + (len(ir) if tail else 0)]
    dry = np.pad(x, (0, len(w) - len(x)))
    return dry * (1 - wet * 0.5) + w * wet


def fade(x, fin=0.002, fout=0.02, sr=SR):
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def normalize(x, peak_db=-1.0):
    p = np.max(np.abs(x)) or 1.0
    return x / p * 10 ** (peak_db / 20)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, x, at, sr=SR):
    i = int(at * sr)
    end = min(len(buf), i + len(x))
    if end > i:
        buf[i:end] += x[: end - i]


def trim_tail(x, sr, floor_db=-54):
    """Drops the near-silent end of a sound (keeps files small)."""
    env = lowpass(np.abs(x), 30, sr, 1)
    thr = np.max(env) * 10 ** (floor_db / 20)
    idx = np.nonzero(env > thr)[0]
    end = min(len(x), (idx[-1] if len(idx) else len(x)) + int(0.03 * sr))
    return x[:end]


def save(path, x, sr=SR, peak_db=-1.0, trim=True):
    if trim:
        x = trim_tail(x, sr)
    x = normalize(fade(x, sr=sr, fout=0.04), peak_db)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


# ----------------------------------------------------------- instruments

def bell(freq, dur, sr=SR, decay=0.6, bright=1.0):
    """Glassy bell / celesta."""
    t = t_axis(dur, sr)
    out = np.zeros_like(t)
    partials = [(1, 1.0, 1.0), (2.0, 0.45 * bright, 0.55), (3.01, 0.22 * bright, 0.35),
                (4.2, 0.12 * bright, 0.25), (5.43, 0.06 * bright, 0.18)]
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f > sr / 2.2:
            continue
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * dk))
    attack = np.minimum(1, t / 0.002)
    return fade(out * attack, 0, 0.02, sr)


def marimba(freq, dur, sr=SR, decay=0.35):
    t = t_axis(dur, sr)
    out = (np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)
           + 0.35 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / (decay * 0.18))
           + 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / (decay * 0.06)))
    return fade(out * np.minimum(1, t / 0.0015), 0, 0.02, sr)


def pluck(freq, dur, sr=SR, damp=0.996, bright=0.5):
    """Karplus-Strong plucked string."""
    n = int(dur * sr)
    p = max(2, int(sr / freq))
    buf = RNG.uniform(-1, 1, p)
    buf = lowpass(buf, 2000 + 8000 * bright, sr, 1)
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % p]
        out[i] = v
        buf[i % p] = damp * 0.5 * (v + buf[(i + 1) % p])
    return fade(out, 0.001, 0.03, sr)


def saw(freq, t):
    return 2 * ((freq * t) % 1.0) - 1


def pad(freqs, dur, sr=MUSIC_SR, cutoff=1800):
    t = t_axis(dur, sr)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.0, 0.11):
            out += saw(f * 2 ** (det / 12), t + RNG.uniform(0, 1))
    out = lowpass(out, cutoff, sr, 2)
    return out * env_adsr(len(t), sr, a=0.35, d=0.4, s=0.8, r=0.6) / (len(freqs) * 3)


def sub_bass(freq, dur, sr=MUSIC_SR):
    t = t_axis(dur, sr)
    x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)
    return x * env_adsr(len(t), sr, a=0.004, d=0.12, s=0.7, r=0.08)


def kick(sr=MUSIC_SR):
    t = t_axis(0.35, sr)
    ph = exp_sweep_phase(140, 45, len(t), sr)
    return np.sin(ph) * np.exp(-t / 0.12) + 0.3 * RNG.standard_normal(len(t)) * np.exp(-t / 0.004)


def snare(sr=MUSIC_SR, soft=1.0):
    t = t_axis(0.25, sr)
    noise = bandpass(RNG.standard_normal(len(t)), 1200, 9000, sr) * np.exp(-t / 0.06)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    return (noise * 0.8 + tone * 0.5) * soft


def clap(sr=MUSIC_SR):
    t = t_axis(0.3, sr)
    n = bandpass(RNG.standard_normal(len(t)), 900, 5000, sr)
    e = np.zeros_like(t)
    for k, off in enumerate((0, 0.011, 0.022)):
        i = int(off * sr)
        e[i:] += np.exp(-(t[: len(t) - i]) / (0.008 if k < 2 else 0.09))
    return n * e * 0.7


def hat(sr=MUSIC_SR, open_=False):
    t = t_axis(0.12 if not open_ else 0.3, sr)
    n = highpass(RNG.standard_normal(len(t)), 7000, sr)
    return n * np.exp(-t / (0.018 if not open_ else 0.08)) * 0.35


def shaker(sr=MUSIC_SR):
    t = t_axis(0.09, sr)
    n = bandpass(RNG.standard_normal(len(t)), 5000, 12000, sr)
    e = np.minimum(1, t / 0.02) * np.exp(-t / 0.03)
    return n * e * 0.3


def noise(dur, sr=SR):
    return RNG.standard_normal(int(dur * sr))


# --------------------------------------------------------- sound effects

PENTA = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6']


def sfx_pop(freq):
    """Bubbly, juicy match pop."""
    dur = 0.32
    t = t_axis(dur)
    n = len(t)
    ph = sweep_phase(freq * 0.55, freq * 1.04, n, SR, curve=0.25)
    body = np.sin(ph) * np.exp(-t / 0.075)
    blip = np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / 0.03) * 0.35
    ring = bell(freq * 2, dur, decay=0.25) * 0.18
    click = bandpass(noise(dur), 2000, 8000) * np.exp(-t / 0.004) * 0.25
    return reverb(body + blip + ring + click, wet=0.18)


def sfx_swap():
    dur = 0.18
    t = t_axis(dur)
    n = noise(dur)
    sweep = np.zeros_like(n)
    # Moving band-pass whoosh.
    for i, (lo, hi) in enumerate([(500, 1500), (900, 2600), (1600, 4200)]):
        seg = bandpass(n, lo, hi) * np.exp(-((t - 0.04 * (i + 1)) ** 2) / 0.0012)
        sweep += seg
    tick = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.01) * 0.25
    return sweep * 0.8 + tick


def sfx_invalid():
    out = np.zeros(int(0.42 * SR))
    for at, f in ((0.0, 330), (0.13, 247)):
        t = t_axis(0.2)
        knock = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t)) * np.exp(-t / 0.045)
        knock += bandpass(noise(0.2), 400, 2500) * np.exp(-t / 0.006) * 0.4
        place(out, knock, at)
    return lowpass(out, 3000)


def sfx_blend():
    """Swirly paint mix that squishes into a new color."""
    dur = 0.55
    t = t_axis(dur)
    n = len(t)
    wob = 1 + 0.06 * np.sin(2 * np.pi * 9 * t)
    a = np.sin(sweep_phase(520, 330, n, SR) * wob)
    b = np.sin(sweep_phase(260, 330, n, SR) * wob)
    swirl = (a + b) * env_adsr(n, SR, a=0.03, d=0.1, s=0.7, r=0.25) * 0.5
    goo = lowpass(noise(dur), 900) * env_adsr(n, SR, a=0.08, d=0.2, s=0.4, r=0.2) * 0.6
    out = swirl + goo
    squish = sfx_pop(note_hz('G5')) * 0.8
    place(out := np.pad(out, (0, len(squish))), squish, 0.36)
    return reverb(out, wet=0.22)


def sfx_special_create():
    out = np.zeros(int(1.2 * SR))
    for i, nm in enumerate(['C6', 'E6', 'G6', 'C7']):
        place(out, bell(note_hz(nm), 0.9, decay=0.5) * (0.9 - 0.1 * i), 0.055 * i)
    sparkle = highpass(noise(0.5), 6000) * exp_decay(int(0.5 * SR), SR, 0.12) * 0.15
    place(out, sparkle, 0.05)
    return reverb(out, wet=0.3)


def sfx_line():
    """Laser zap across a row."""
    dur = 0.5
    t = t_axis(dur)
    n = len(t)
    ph = exp_sweep_phase(2400, 180, n, SR)
    zap = signal.sawtooth(ph) * np.exp(-t / 0.16)
    zap = bandpass(zap, 200, 7000)
    sizzle = bandpass(noise(dur), 3000, 9000) * np.exp(-t / 0.06) * 0.18
    whoosh = bandpass(noise(dur), 300, 1500) * env_adsr(n, SR, a=0.03, d=0.1, s=0.5, r=0.3) * 0.4
    return reverb(zap * 0.7 + sizzle + whoosh, wet=0.25)


def sfx_bomb():
    dur = 1.1
    t = t_axis(dur)
    n = len(t)
    thump = np.sin(exp_sweep_phase(160, 38, n, SR)) * np.exp(-t / 0.22)
    blast = lowpass(noise(dur), 1800) * np.exp(-t / 0.18)
    grains = lowpass((RNG.random(n) > 0.992) * RNG.standard_normal(n), 3000)
    crackle = bandpass(grains, 800, 4000) * np.exp(-t / 0.3) * 4
    splat = sfx_pop(note_hz('C4')) * 0.5
    out = mix(thump * 1.1 + blast * 0.9 + crackle * 0.3, splat)
    return reverb(out, wet=0.3)


def sfx_prism():
    out = np.zeros(int(1.6 * SR))
    scale = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96, 98]
    for i, m in enumerate(scale):
        place(out, bell(midi_hz(m), 0.8, decay=0.45) * (0.5 + 0.04 * i), 0.035 * i)
    swell = highpass(noise(1.0), 5000) * env_adsr(int(1.0 * SR), SR, a=0.3, d=0.2, s=0.3, r=0.4) * 0.12
    place(out, swell, 0.0)
    return reverb(out, wet=0.4)


def sfx_whiteburst():
    dur = 1.8
    out = np.zeros(int(dur * SR))
    for nm in ['C5', 'E5', 'G5', 'D6', 'G6']:
        place(out, bell(note_hz(nm), 1.6, decay=0.9) * 0.6, 0.0)
    t = t_axis(dur)
    boom = np.sin(exp_sweep_phase(120, 50, len(t), SR)) * np.exp(-t / 0.25) * 0.8
    shimmer = highpass(noise(dur), 6000) * env_adsr(len(t), SR, a=0.01, d=0.3, s=0.25, r=1.0) * 0.2
    return reverb(out + boom + shimmer, wet=0.4)


def sfx_combo():
    return mix(sfx_bomb(), sfx_line() * 0.8, np.pad(sfx_prism() * 0.6, (int(0.05 * SR), 0)))


def sfx_glass():
    dur = 0.6
    out = np.zeros(int(dur * SR))
    for i in range(7):
        f = RNG.uniform(2600, 7200)
        d = RNG.uniform(0.05, 0.22)
        t = t_axis(dur)
        place(out, np.sin(2 * np.pi * f * t) * np.exp(-t / d) * RNG.uniform(0.3, 0.7), RNG.uniform(0, 0.07))
    t = t_axis(dur)
    crack = highpass(noise(dur), 2500) * np.exp(-t / 0.025) * 0.8
    return reverb(out + crack, wet=0.25)


def sfx_stain():
    dur = 0.35
    t = t_axis(dur)
    splat = lowpass(noise(dur), 1400) * np.exp(-t / 0.05)
    blop = np.sin(sweep_phase(300, 160, len(t), SR)) * np.exp(-t / 0.07) * 0.8
    return reverb(splat + blop, wet=0.15)


def sfx_gravity():
    dur = 1.0
    t = t_axis(dur)
    n = len(t)
    tone = np.sin(sweep_phase(220, 660, n, SR, curve=1.5)) * env_adsr(n, SR, a=0.1, d=0.2, s=0.6, r=0.4) * 0.4
    tone += np.sin(sweep_phase(330, 990, n, SR, curve=1.5)) * env_adsr(n, SR, a=0.15, d=0.2, s=0.5, r=0.4) * 0.25
    w = noise(dur)
    whoosh = np.zeros(n)
    for k in range(8):
        c = 400 * 2 ** (k / 2.2)
        seg = bandpass(w, c * 0.8, min(c * 1.3, 18000))
        whoosh += seg * np.exp(-((t - 0.1 - k * 0.09) ** 2) / 0.006)
    return reverb(tone + whoosh * 0.5, wet=0.35)


def sfx_shuffle():
    out = np.zeros(int(0.9 * SR))
    for i in range(5):
        place(out, sfx_swap() * 0.6, 0.12 * i)
    return reverb(out, wet=0.2)


def sfx_star(i):
    out = np.zeros(int(1.2 * SR))
    base = ['E6', 'G6', 'C7'][i]
    place(out, bell(note_hz(base), 1.1, decay=0.7) * 0.9, 0)
    place(out, bell(note_hz(base) * 1.5, 0.8, decay=0.4) * 0.3, 0.02)
    sparkle = highpass(noise(0.4), 7000) * exp_decay(int(0.4 * SR), SR, 0.1) * 0.12
    place(out, sparkle, 0)
    return reverb(out, wet=0.35)


def sfx_win():
    """Cheerful fanfare."""
    out = np.zeros(int(2.8 * SR))
    melody = [('C5', 0.0, 0.14), ('E5', 0.14, 0.14), ('G5', 0.28, 0.14), ('C6', 0.42, 0.42),
              ('A5', 0.9, 0.14), ('C6', 1.04, 0.14), ('E6', 1.18, 0.9)]
    for nm, at, d in melody:
        place(out, marimba(note_hz(nm), d + 0.5, decay=0.4) * 0.8, at)
        place(out, bell(note_hz(nm) * 2, d + 0.6, decay=0.5) * 0.25, at)
    for nm in ['C4', 'G4', 'E5']:
        place(out, pad([note_hz(nm)], 1.6, sr=SR, cutoff=2500) * 2.0, 1.18)
    for at in (0.0, 0.42, 1.18):
        place(out, highpass(noise(0.3), 6000) * exp_decay(int(0.3 * SR), SR, 0.07) * 0.2, at)
    return reverb(out, wet=0.3)


def sfx_lose():
    out = np.zeros(int(2.2 * SR))
    for k, (nm, at) in enumerate([('G4', 0.0), ('F#4', 0.35), ('F4', 0.7), ('E4', 1.05)]):
        d = 0.5 if k < 3 else 1.0
        t = t_axis(d)
        f = note_hz(nm)
        vib = 1 + 0.01 * np.sin(2 * np.pi * 5 * t) * (t / d)
        tone = (np.sin(2 * np.pi * f * t * vib) + 0.3 * np.sin(4 * np.pi * f * t * vib))
        tone = lowpass(tone, 2000) * env_adsr(len(t), SR, a=0.02, d=0.1, s=0.7, r=0.25)
        place(out, tone * 0.6, at)
    return reverb(out, wet=0.3)


def sfx_click():
    dur = 0.08
    t = t_axis(dur)
    tone = np.sin(sweep_phase(1400, 900, len(t), SR)) * np.exp(-t / 0.015)
    return tone + bandpass(noise(dur), 2000, 6000) * np.exp(-t / 0.003) * 0.3


def sfx_coin():
    out = np.zeros(int(0.9 * SR))
    place(out, bell(note_hz('B6'), 0.3, decay=0.12, bright=0.6), 0)
    place(out, bell(note_hz('E7'), 0.8, decay=0.4, bright=0.6), 0.07)
    return reverb(out, wet=0.25)


def sfx_booster():
    dur = 0.9
    t = t_axis(dur)
    up = np.sin(sweep_phase(400, 1600, len(t), SR, curve=0.6)) * env_adsr(len(t), SR, a=0.02, d=0.2, s=0.3, r=0.4) * 0.3
    out = up + highpass(noise(dur), 5000) * env_adsr(len(t), SR, a=0.05, d=0.2, s=0.2, r=0.4) * 0.15
    place(out, bell(note_hz('A6'), 0.6, decay=0.35) * 0.6, 0.18)
    return reverb(out, wet=0.35)


def sfx_praise():
    """Big cascade 'Great!' sparkle."""
    out = np.zeros(int(1.6 * SR))
    for i, nm in enumerate(['G5', 'C6', 'E6', 'G6', 'C7', 'E7']):
        place(out, bell(note_hz(nm), 0.8, decay=0.45) * 0.7, 0.045 * i)
    for nm in ['C5', 'E5', 'G5']:
        place(out, marimba(note_hz(nm), 0.6) * 0.4, 0.0)
    return reverb(out, wet=0.4)


def sfx_level_start():
    out = np.zeros(int(1.2 * SR))
    for i, nm in enumerate(['G5', 'D6']):
        place(out, marimba(note_hz(nm), 0.6) * 0.8, 0.12 * i)
    t = t_axis(0.5)
    place(out, bandpass(noise(0.5), 600, 3000) * env_adsr(len(t), SR, a=0.15, d=0.1, s=0.4, r=0.2) * 0.3, 0)
    return reverb(out, wet=0.3)


# ------------------------------------------------------------------ music

def render_song(bpm, bars, chords, melody, sr=MUSIC_SR, style='map'):
    """chords: list of (bar, [midi notes]); melody: list of (beat, midi, beats)."""
    beat = 60.0 / bpm
    length = bars * 4 * beat
    n = int(length * sr)
    music = np.zeros(n)
    drums = np.zeros(n)
    k, s, h, c, sh = kick(sr), snare(sr, 0.7), hat(sr), clap(sr), shaker(sr)

    for bar, notes in chords:
        start = bar * 4 * beat
        # Pad
        place(music, pad([midi_hz(m) for m in notes], 4 * beat + 0.6, sr,
                         cutoff=1500 if style == 'map' else 2200) * 0.55, start, sr)
        # Bass: root on 1 and 3 (with a passing octave)
        root = midi_hz(notes[0] - 12)
        pattern = [(0, 1.5, 1.0), (1.5, 0.5, 2.0), (2, 1.5, 1.0), (3.5, 0.5, 1.5)] if style == 'game' \
            else [(0, 2, 1.0), (2, 2, 1.0)]
        for at, d, mul in pattern:
            place(music, sub_bass(root * (2 if mul == 2.0 else 1) * (1.5 if mul == 1.5 else 1),
                                  d * beat * 0.95, sr) * 0.5, start + at * beat, sr)
        # Arpeggio
        arp_notes = notes + [notes[1] + 12, notes[2] + 12]
        step = 0.5
        for i in range(int(4 / step)):
            m = arp_notes[[0, 2, 1, 3, 2, 4, 3, 1][i % 8]] + 12
            inst = marimba(midi_hz(m), 0.6, sr, decay=0.25) if style == 'map' else \
                pluck(midi_hz(m), 0.45, sr, damp=0.993, bright=0.6) * 0.9
            place(music, inst * (0.22 if i % 2 else 0.28), start + i * step * beat, sr)

    for b in range(bars):
        start = b * 4 * beat
        if style == 'map':
            for q in range(4):
                place(drums, k * (0.6 if q in (0, 2) else 0.0), start + q * beat, sr)
            place(drums, s * 0.45, start + 1 * beat, sr)
            place(drums, s * 0.45, start + 3 * beat, sr)
            for e in range(8):
                place(drums, sh * (0.6 if e % 2 else 0.35), start + e * 0.5 * beat, sr)
        else:
            for at in (0, 1.5, 2, 2.75):
                place(drums, k * 0.75, start + at * beat, sr)
            place(drums, c * 0.6, start + 1 * beat, sr)
            place(drums, c * 0.6, start + 3 * beat, sr)
            for e in range(16):
                place(drums, h * (0.55 if e % 2 else 0.3), start + e * 0.25 * beat, sr)

    lead = np.zeros(n)
    for at, m, d in melody:
        dur = d * beat
        if style == 'map':
            x = mix(bell(midi_hz(m), dur + 0.4, sr, decay=0.5, bright=0.6) * 0.5,
                    marimba(midi_hz(m), dur + 0.3, sr, decay=0.3) * 0.35)
        else:
            t = t_axis(dur + 0.15, sr)
            f = midi_hz(m)
            x = (signal.square(2 * np.pi * f * t, 0.3) * 0.25 + np.sin(2 * np.pi * f * t) * 0.6)
            x = lowpass(x, 3500, sr) * env_adsr(len(t), sr, a=0.01, d=0.08, s=0.6, r=0.12)
            x *= 0.55
        place(lead, x, at * beat, sr)

    song = music + reverb(lead, wet=0.35, sr=sr, tail=False)[:n] * 0.8
    song = reverb(song, wet=0.2, sr=sr, tail=True)
    drums_wet = reverb(drums, wet=0.12, sr=sr, tail=True)
    total = mix(song, drums_wet * 0.8)
    # Make it loop seamlessly: fold the reverb tail back onto the start.
    loop = total[:n].copy()
    tail = total[n:]
    loop[: len(tail)] += tail[: n]
    # Gentle glue compression.
    env = np.abs(signal.hilbert(loop))
    env = lowpass(env, 8, sr, 1)
    gain = np.minimum(1.0, 0.55 / np.maximum(env, 1e-4)) ** 0.5
    return loop * gain


def song_map():
    # F major, 96 bpm, I - vi - IV - V (x2), then ii - V - I - IV, IV - V - I - I
    F, Dm, Bb, C, Gm, Am = [53, 57, 60], [50, 53, 57], [46, 50, 53], [48, 52, 55], [43, 46, 50], [45, 48, 52]
    prog = [F, Dm, Bb, C, F, Dm, Bb, C, Gm, C, F, Bb, Gm, Am, Bb, C]
    chords = [(i, [n + 12 for n in c]) for i, c in enumerate(prog)]
    # Melody in F major pentatonic (F G A C D), beats.
    phrase_a = [(0, 77, 1), (1, 76, 0.5), (1.5, 74, 0.5), (2, 72, 1.5), (4, 74, 1), (5, 72, 0.5), (5.5, 69, 0.5),
                (6, 70, 2), (8, 72, 1), (9, 74, 0.5), (9.5, 77, 0.5), (10, 79, 1.5), (12, 77, 1), (13, 76, 1),
                (14, 72, 2)]
    phrase_b = [(0, 81, 1), (1, 79, 0.5), (1.5, 77, 0.5), (2, 79, 1.5), (4, 77, 1), (5, 74, 1), (6, 72, 2),
                (8, 74, 1), (9, 76, 1), (10, 77, 1), (11, 79, 1), (12, 81, 2), (14, 77, 2)]
    mel = []
    for base, ph in ((0, phrase_a), (16, phrase_b), (32, phrase_a), (48, phrase_b)):
        mel += [(base + a, m, d) for a, m, d in ph]
    return render_song(96, 16, chords, mel, style='map')


def song_game():
    # C major, 116 bpm, vi - IV - I - V
    Am, F, C, G, Em, Dm = [57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62], [52, 55, 59], [50, 53, 57]
    prog = [Am, F, C, G, Am, F, C, G, F, G, Em, Am, Dm, G, C, G]
    chords = [(i, c) for i, c in enumerate(prog)]
    a = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 81, 1), (2, 79, 0.5), (2.5, 76, 0.5), (3, 74, 1),
         (4, 72, 0.5), (4.5, 74, 0.5), (5, 76, 1), (6, 74, 1), (7, 72, 1),
         (8, 72, 0.5), (8.5, 74, 0.5), (9, 76, 1), (10, 79, 1), (11, 76, 1),
         (12, 74, 1.5), (13.5, 72, 0.5), (14, 74, 2)]
    b = [(0, 84, 1), (1, 81, 0.5), (1.5, 79, 0.5), (2, 81, 1), (3, 79, 1),
         (4, 76, 1), (5, 79, 0.5), (5.5, 81, 0.5), (6, 79, 2),
         (8, 77, 1), (9, 79, 0.5), (9.5, 81, 0.5), (10, 84, 1), (11, 81, 1),
         (12, 79, 1), (13, 76, 1), (14, 74, 1), (15, 79, 1)]
    mel = []
    for base, ph in ((0, a), (16, a), (32, b), (48, b)):
        mel += [(base + x, m, d) for x, m, d in ph]
    return render_song(116, 16, chords, mel, style='game')




# Episode tracks: (name, key root midi, mode, bpm, style, progression, seed).
# Progressions are scale degrees (0-based) of the key's diatonic triads.
EPISODE_SONGS = [
    ('music_garden', 55, 'major', 104, 'map', [0, 4, 5, 3, 0, 4, 3, 4, 5, 3, 0, 4, 5, 1, 3, 4], 11),
    ('music_factory', 50, 'minor', 120, 'game', [0, 5, 2, 6, 0, 5, 2, 6, 3, 4, 0, 5, 3, 6, 4, 4], 12),
    ('music_sky', 51, 'major', 92, 'map', [0, 2, 3, 4, 0, 2, 3, 4, 5, 3, 0, 4, 1, 4, 0, 4], 13),
    ('music_lagoon', 57, 'minor', 100, 'map', [0, 5, 2, 6, 0, 5, 2, 6, 3, 0, 5, 6, 3, 4, 0, 6], 14),
    ('music_peaks', 52, 'major', 110, 'game', [0, 5, 3, 4, 0, 5, 3, 4, 1, 4, 0, 5, 3, 4, 0, 4], 15),
    ('music_brigade', 58, 'major', 124, 'game', [0, 3, 4, 3, 0, 3, 4, 4, 5, 3, 0, 4, 5, 3, 4, 4], 16),
    ('music_galaxy', 54, 'minor', 108, 'game', [0, 5, 6, 0, 0, 5, 6, 4, 3, 5, 6, 0, 3, 4, 0, 6], 17),
]

SCALES = {'major': [0, 2, 4, 5, 7, 9, 11], 'minor': [0, 2, 3, 5, 7, 8, 10]}


def triad(root, mode, degree):
    sc = SCALES[mode]
    notes = []
    for k in (0, 2, 4):
        d = degree + k
        notes.append(root + sc[d % 7] + 12 * (d // 7))
    return notes


def compose(root, mode, prog, seed):
    """A singable lead: pentatonic notes, chord tones on strong beats,
    mostly stepwise, phrases A A' B A."""
    rng = np.random.default_rng(seed)
    sc = SCALES[mode]
    penta = [0, 2, 4, 7, 9] if mode == 'major' else [0, 3, 5, 7, 10]
    pool = [root + 12 + o + 12 * k for k in (0, 1) for o in penta] + [root + 36]
    rhythms = [
        [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5)],
        [(0, 0.5), (0.5, 0.5), (1, 1), (2, 1), (3, 1)],
        [(0, 1.5), (1.5, 0.5), (2, 2)],
        [(0, 1), (1, 1), (2, 0.5), (2.5, 0.5), (3, 1)],
    ]

    def phrase(bars, start_idx, end_on_root):
        out = []
        idx = start_idx
        for b, deg in enumerate(bars):
            chord = [n % 12 for n in triad(root, mode, deg)]
            cells = rhythms[rng.integers(len(rhythms))]
            for j, (at, d) in enumerate(cells):
                strong = at in (0, 2)
                step = rng.choice([-2, -1, -1, 1, 1, 2])
                idx = int(np.clip(idx + step, 0, len(pool) - 1))
                if strong:
                    # Snap to the nearest chord tone.
                    best = min(range(len(pool)), key=lambda q: (pool[q] % 12 not in chord, abs(q - idx)))
                    idx = best
                if end_on_root and b == len(bars) - 1 and j == len(cells) - 1:
                    idx = min(range(len(pool)), key=lambda q: (pool[q] % 12 != root % 12, abs(q - idx)))
                out.append((b * 4 + at, pool[idx], d))
        return out, idx

    a, i1 = phrase(prog[0:4], 4, False)
    a2, i2 = phrase(prog[4:8], i1, True)
    b, i3 = phrase(prog[8:12], min(i2 + 2, len(pool) - 1), False)
    a3, _ = phrase(prog[12:16], i3, True)
    mel = []
    for base, ph in ((0, a), (16, a2), (32, b), (48, a3)):
        mel += [(base + x, m, d) for x, m, d in ph]
    return mel


def song_episode(spec):
    name, root, mode, bpm, style, prog, seed = spec
    chords = [(i, triad(root, mode, d)) for i, d in enumerate(prog)]
    return render_song(bpm, 16, chords, compose(root, mode, prog, seed), style=style)


def sfx_chain():
    """A chain snapping: metallic clank partials and a click."""
    dur = 0.7
    t = t_axis(dur)
    out = np.zeros(len(t))
    for f, a, d in ((1180, 0.5, 0.18), (1730, 0.35, 0.12), (2610, 0.3, 0.09), (3920, 0.2, 0.06)):
        out += np.sin(2 * np.pi * f * t) * np.exp(-t / d) * a
    second = np.zeros(len(t))
    for f, a, d in ((1420, 0.35, 0.14), (2240, 0.25, 0.08)):
        second += np.sin(2 * np.pi * f * t) * np.exp(-t / d) * a
    place(out, second[: int(0.5 * SR)], 0.06)
    click = highpass(noise(dur), 3000) * np.exp(-t / 0.008) * 0.7
    return reverb(out + click, wet=0.22)


def sfx_ink():
    """Thick ink: two low gloopy bubbles."""
    dur = 0.5
    out = np.zeros(int(dur * SR))
    for at, f0, f1 in ((0.0, 180, 420), (0.11, 140, 360)):
        d = 0.16
        t = t_axis(d)
        blop = np.sin(sweep_phase(f0, f1, len(t), SR, curve=0.7)) * np.exp(-t / 0.05)
        place(out, blop * 0.8, at)
    t = t_axis(dur)
    out += lowpass(noise(dur), 700) * np.exp(-t / 0.04) * 0.4
    return reverb(out, wet=0.18)


def sfx_drop():
    """A paint bucket reaching the exit: whoosh down, then a bright chime."""
    out = np.zeros(int(1.2 * SR))
    d = 0.3
    t = t_axis(d)
    whoosh = bandpass(noise(d), 600, 3000) * np.sin(np.pi * t / d) * 0.4
    place(out, whoosh, 0)
    for i, nm in enumerate(['C6', 'E6', 'G6', 'C7']):
        place(out, bell(note_hz(nm), 0.7, decay=0.35) * 0.6, 0.18 + 0.06 * i)
    place(out, sfx_coin() * 0.5, 0.2)
    return reverb(out, wet=0.3)


SFX = {
    'swap': sfx_swap,
    'invalid': sfx_invalid,
    'blend': sfx_blend,
    'special': sfx_special_create,
    'line': sfx_line,
    'bomb': sfx_bomb,
    'prism': sfx_prism,
    'whiteburst': sfx_whiteburst,
    'combo': sfx_combo,
    'glass': sfx_glass,
    'stain': sfx_stain,
    'gravity': sfx_gravity,
    'shuffle': sfx_shuffle,
    'win': sfx_win,
    'lose': sfx_lose,
    'click': sfx_click,
    'coin': sfx_coin,
    'booster': sfx_booster,
    'praise': sfx_praise,
    'start': sfx_level_start,
    'chain': sfx_chain,
    'ink': sfx_ink,
    'drop': sfx_drop,
}


def to_ogg(wav_path, quality):
    """Encodes a WAV to Ogg Vorbis next to it (ffmpeg) and removes the WAV."""
    ogg = wav_path[:-4] + '.ogg'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav_path,
                    '-c:a', 'libvorbis', '-q:a', str(quality), ogg], check=True)
    os.remove(wav_path)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for i, nm in enumerate(PENTA):
        save(os.path.join(out_dir, f'pop{i}.wav'), sfx_pop(note_hz(nm)), peak_db=-3)
    for i in range(3):
        save(os.path.join(out_dir, f'star{i}.wav'), sfx_star(i), peak_db=-3)
    for name, fn in SFX.items():
        save(os.path.join(out_dir, f'{name}.wav'), fn(), peak_db=-2)
    # Loops must keep their exact length and must not be faded.
    songs = [('music_map', song_map()), ('music_studio', song_game())]
    songs += [(spec[0], song_episode(spec)) for spec in EPISODE_SONGS]
    for name, song in songs:
        x = normalize(song, -3)
        data = (np.clip(x, -1, 1) * 32767).astype('<i2')
        with wave.open(os.path.join(out_dir, f'{name}.wav'), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(MUSIC_SR)
            w.writeframes(data.tobytes())
    # Ship Ogg Vorbis: about a tenth of the size of the WAVs.
    for f in sorted(os.listdir(out_dir)):
        if f.endswith('.wav'):
            to_ogg(os.path.join(out_dir, f), 4 if f.startswith('music_') else 6)
    print('wrote', len(os.listdir(out_dir)), 'files to', out_dir)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/audio')
