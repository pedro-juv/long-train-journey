"""Efeitos sonoros originais, sintetizados do zero."""
import numpy as np, wave, sys, os
from scipy.signal import butter, sosfilt
SR = 44100
rng = np.random.default_rng(3)
def bp(x, lo, hi): return sosfilt(butter(2, [lo, hi], 'band', fs=SR, output='sos'), x)
def lp(x, fc): return sosfilt(butter(2, fc, 'low', fs=SR, output='sos'), x)
def save(name, x, peak=0.8):
    x = x / np.max(np.abs(x)) * peak
    fade = int(0.005 * SR); x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, f"{len(x)/SR:.2f}s")

# Clique: pá de carvão (pedra batendo + baque)
n = int(0.12 * SR); t = np.arange(n) / SR
clk = bp(rng.standard_normal(n), 900, 4500) * np.exp(-t * 45) + 0.8 * np.sin(2*np.pi*95*t) * np.exp(-t * 35)
save('click.wav', clk, 0.6)

# Compra: sino de latão "ka-ching"
n = int(0.7 * SR); t = np.arange(n) / SR
def bell(f, start, a=1.0):
    tt = np.clip(t - start, 0, None); on = (t >= start)
    return on * a * sum(g*np.sin(2*np.pi*f*r*tt)*np.exp(-tt*d) for r, g, d in [(1, 1, 6), (2.76, .5, 9), (5.4, .25, 14)])
buy = bell(1318.5, 0) + bell(1975.5, 0.07, 0.9) + 0.3 * bp(rng.standard_normal(n), 3000, 8000) * np.exp(-t * 60)
save('buy.wav', buy, 0.55)

# Apito a vapor: acorde de três tubos + sopro
n = int(1.8 * SR); t = np.arange(n) / SR
env = np.minimum(1, t / 0.12) * np.clip((1.8 - t) / 0.35, 0, 1)
bend = 1 - 0.03 * np.exp(-t * 8)
wh = 0
for f in (523.25, 659.25, 783.99):
    ph = np.cumsum(f * bend * (1 + 0.003*np.sin(2*np.pi*6*t))) / SR
    wh = wh + np.sin(2*np.pi*ph) + 0.3*np.sin(4*np.pi*ph)
wh = lp(wh, 3500) + 0.6 * bp(rng.standard_normal(n), 1500, 6000)
save('whistle.wav', wh * env, 0.7)

# Chuff: uma baforada da locomotiva
n = int(0.22 * SR); t = np.arange(n) / SR
ch = bp(rng.standard_normal(n), 250, 2400) * (np.minimum(1, t / 0.01) * np.exp(-t * 16))
save('chuff.wav', ch, 0.7)

# Marco/estação: fanfarra curta de metais (arpejo maior)
n = int(1.0 * SR); t = np.arange(n) / SR
fan = 0
for i, f in enumerate((293.66, 369.99, 440.0, 587.33)):
    st = i * 0.11; tt = np.clip(t - st, 0, None); on = t >= st
    ph = f * tt; saw = 2 * (ph - np.floor(ph + 0.5))
    fan = fan + on * lp(saw, 1800) * np.minimum(1, tt / 0.03) * np.exp(-tt * (2.5 if i == 3 else 7))
save('fanfare.wav', fan, 0.6)

# Quebra (Fase 1B): batida metálica + chiado de vapor escapando
n = int(1.3 * SR); t = np.arange(n) / SR
clang = sum(a*np.sin(2*np.pi*f*t)*np.exp(-t*d) for f, a, d in [(310, 1, 7), (587, .7, 9), (1043, .5, 12), (1660, .35, 16)])
thud = np.sin(2*np.pi*70*t) * np.exp(-t * 18)
steam = bp(rng.standard_normal(n), 2500, 9000) * np.clip(np.minimum(t / 0.05, (1.3 - t) / 0.6), 0, 1) * 0.6
save('failure.wav', clang * 0.6 + thud + steam, 0.75)

# Reparo (Fase 1B): catraca rápida + duas marteladas
n = int(0.75 * SR); t = np.arange(n) / SR
rep = np.zeros(n)
for i in range(7):  # catraca
    st = int((0.02 + i * 0.045) * SR); m = int(0.012 * SR)
    rep[st:st + m] += bp(rng.standard_normal(m), 3000, 8000) * np.exp(-np.arange(m) / SR * 300)
for st_s in (0.42, 0.6):  # marteladas
    st = int(st_s * SR); tt = np.arange(n - st) / SR
    rep[st:] += (np.sin(2*np.pi*880*tt) * 0.6 + np.sin(2*np.pi*1390*tt) * 0.4) * np.exp(-tt * 22)
save('repair.wav', rep, 0.6)
