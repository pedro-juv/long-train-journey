"""Trilha original 'Engrenagens do Trem' — valsa steampunk, com uma variação por estação.

Composta e sintetizada do zero (sem samples de terceiros).
A melodia e a harmonia são as mesmas em todos os temas; mudam o andamento,
o tom, os instrumentos e a ambientação:

  inicio     ré menor, 108 BPM   caixinha de música, acordeão, metais, relojoaria
  primavera  mi menor, 114 BPM   flauta e caixinha, triângulo, passarinhos
  verao      fá menor, 120 BPM   metais na frente, chocalho e pandeiro
  outono     dó menor,  98 BPM   violoncelo e acordeão, vento, sem bigorna
  inverno    si menor,  90 BPM   celesta e cordas, guizos de trenó, eco longo

Uso:  python compor_musica.py <tema> saida.wav
      ffmpeg -i saida.wav -c:a libvorbis -q:a 5 musica_<tema>.ogg
(O tema "inicio" é o arquivo musica_steampunk.ogg do jogo.)
"""
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100

THEMES = {
    "inicio": dict(bpm=108, transpose=0, seed=7,
                   leads=["box", "box+acc", "brass", "all"],
                   tick=1.0, anvil=True, hiss=True, echo=[(0.083, 0.18), (0.157, 0.10)]),
    "primavera": dict(bpm=114, transpose=2, seed=11,
                      leads=["box+flute", "flute+acc", "flute+box", "spring_all"],
                      tick=0.7, anvil=False, triangle=True, birds=True, hiss=False,
                      comp_gain=0.8, echo=[(0.083, 0.18), (0.157, 0.10)]),
    "verao": dict(bpm=120, transpose=3, seed=13,
                  leads=["brass", "box+acc", "brass+acc", "all"],
                  tick=1.0, anvil=True, shaker=True, hiss=True, echo=[(0.083, 0.16), (0.157, 0.08)]),
    "outono": dict(bpm=98, transpose=-2, seed=17,
                   leads=["cello", "cello+box", "cello+acc", "autumn_all"],
                   tick=0.55, anvil=False, wind=0.035, hiss=False, comp_gain=0.85,
                   echo=[(0.11, 0.2), (0.21, 0.13), (0.33, 0.07)]),
    "inverno": dict(bpm=90, transpose=-3, seed=19,
                    leads=["celesta", "celesta+pad", "pad+box", "winter_all"],
                    tick=0.0, anvil=False, sleigh=True, wind=0.05, hiss=False, comp_gain=0.6, pad_chords=True,
                    echo=[(0.12, 0.24), (0.25, 0.17), (0.38, 0.12), (0.52, 0.07)]),
}

# Quais instrumentos tocam a melodia em cada tipo de seção:
# (instrumento, deslocamento de oitava em semitons, ganho, pan)
LEADS = {
    "box": [("box", 0, 0.9, 0.25)],
    "box+acc": [("box", 0, 0.9, 0.25), ("acc", -12, 1.0, -0.2)],
    "brass": [("brass", -12, 1.0, 0.1)],
    "brass+acc": [("brass", -12, 1.0, 0.1), ("acc", -12, 0.7, -0.25)],
    "all": [("box", 0, 0.6, 0.25), ("acc", -12, 1.0, -0.2), ("brass", -12, 0.8, 0.1)],
    "box+flute": [("box", 0, 0.7, 0.25), ("flute", 0, 0.8, -0.1)],
    "flute+acc": [("flute", 0, 1.0, 0.1), ("acc", -12, 0.7, -0.25)],
    "flute+box": [("flute", 0, 1.0, -0.1), ("box", 12, 0.35, 0.3)],
    "spring_all": [("flute", 0, 0.9, 0.0), ("box", 0, 0.6, 0.3), ("acc", -12, 0.8, -0.25)],
    "cello": [("cello", -12, 1.0, -0.1)],
    "cello+box": [("cello", -12, 0.9, -0.1), ("box", 0, 0.45, 0.3)],
    "cello+acc": [("cello", -12, 1.0, -0.1), ("acc", -12, 0.6, 0.2)],
    "autumn_all": [("cello", -12, 1.0, -0.1), ("acc", -12, 0.7, 0.2), ("box", 0, 0.4, 0.3)],
    "celesta": [("celesta", 0, 1.0, 0.15)],
    "celesta+pad": [("celesta", 0, 1.0, 0.15), ("pad", -12, 0.8, -0.15)],
    "pad+box": [("pad", 0, 0.9, 0.0), ("box", 0, 0.45, 0.3)],
    "winter_all": [("celesta", 0, 1.0, 0.15), ("pad", -12, 0.8, -0.15), ("celesta", 12, 0.3, 0.35)],
}

# ----- partitura (em ré menor; cada tema transpõe) -----
# Melodias: (início em tempos dentro do compasso, duração em tempos, nota MIDI)
A = [
    [(0, 1, 69), (1, 1, 74), (2, 1, 77)], [(0, 2, 76), (2, 1, 74)], [(0, 1, 74), (1, 1, 79), (2, 1, 82)], [(0, 2, 81), (2, .5, 79), (2.5, .5, 77)],
    [(0, 1, 76), (1, 1, 77), (2, 1, 81)], [(0, 2, 86), (2, 1, 84)], [(0, 1, 82), (1, 1, 81), (2, 1, 79)], [(0, 3, 81)],
]
A_END = A[:7] + [[(0, 3, 74)]]
B = [
    [(0, 1, 72), (1, 1, 77), (2, 1, 81)], [(0, 2, 79), (2, 1, 76)], [(0, 1, 77), (1, 1, 81), (2, 1, 86)], [(0, 2, 85), (2, 1, 81)],
    [(0, 1, 82), (1, 1, 81), (2, 1, 79)], [(0, 1.5, 81), (1.5, .5, 77), (2, 1, 72)], [(0, 1, 74), (1, 1, 79), (2, 1, 82)], [(0, 2, 81), (2, 1, 73)],
]
# Acordes (raiz do baixo, notas do acorde)
Dm = (38, [62, 65, 69]); Gm = (43, [62, 67, 70]); A7 = (45, [61, 64, 67]); Bb = (46, [62, 65, 70])
F = (41, [60, 65, 69]); C = (36, [60, 64, 67]); Am = (45, [61, 64, 69])
CH_A = [Dm, Dm, Gm, A7, Dm, Bb, Gm, A7]
CH_A_END = [Dm, Dm, Gm, A7, Dm, Bb, Gm, Dm]
CH_B = [F, C, Dm, Am, Bb, F, Gm, A7]
SECTIONS = [(A, CH_A), (A_END, CH_A_END), (B, CH_B), (A_END, CH_A_END)]


def compose(theme_name: str, out_path: str) -> None:
    T = THEMES[theme_name]
    rng = np.random.default_rng(T["seed"])
    beat = 60.0 / T["bpm"]
    bar = 3 * beat
    tr = T["transpose"]

    def hz(m): return 440.0 * 2 ** ((m + tr - 69) / 12)
    def lp(x, fc, order=2): return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x)
    def hp(x, fc, order=2): return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), x)
    def bp(x, lo, hi, order=2): return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)

    def adsr(n, a, d, s, r):
        t = np.arange(n) / SR; dur = n / SR
        e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
        return e * np.clip((dur - t) / max(r, 1e-4), 0, 1)

    def saw(f, t, detune=0.0):
        ph = (f * (1 + detune)) * t
        return 2 * (ph - np.floor(ph + 0.5))

    # ----- instrumentos -----
    def music_box(m, dur):
        n = int((dur + 1.2) * SR); t = np.arange(n) / SR; f = hz(m)
        x = (np.sin(2*np.pi*f*t) + 0.35*np.sin(2*np.pi*f*2.0*t)*np.exp(-t*6) + 0.18*np.sin(2*np.pi*f*5.43*t)*np.exp(-t*12))
        return x * np.exp(-t * 2.6) * np.minimum(1, t / 0.002) * 0.5

    def celesta(m, dur):
        n = int((dur + 2.2) * SR); t = np.arange(n) / SR; f = hz(m)
        x = np.sin(2*np.pi*f*t) + 0.25*np.sin(2*np.pi*f*3.0*t)*np.exp(-t*5) + 0.12*np.sin(2*np.pi*f*4.0*t)*np.exp(-t*9)
        return x * np.exp(-t * 1.5) * np.minimum(1, t / 0.004) * 0.42

    def accordion(m, dur, vol=0.16):
        n = int((dur + 0.08) * SR); t = np.arange(n) / SR; f = hz(m)
        x = saw(f, t, -0.003) + saw(f, t, 0.004) + 0.5*saw(f*2, t, 0.002)
        return lp(x, 2200) * (1 + 0.12 * np.sin(2*np.pi*5.5*t)) * adsr(n, 0.03, 0.2, 0.75, 0.08) * vol

    def brass(m, dur, vol=0.22):
        n = int((dur + 0.15) * SR); t = np.arange(n) / SR; f = hz(m)
        vib = 1 + 0.004 * np.sin(2*np.pi*5.2*t) * np.minimum(1, t / 0.4)
        ph = np.cumsum(f * vib) / SR
        x = 2 * (ph - np.floor(ph + 0.5))
        bright = np.minimum(1, t / 0.08)
        x = lp(x, 900) * (1 - 0.5*bright) + lp(x, 3200) * 0.5 * bright
        return x * adsr(n, 0.06, 0.3, 0.8, 0.12) * vol

    def flute(m, dur, vol=0.2):
        n = int((dur + 0.12) * SR); t = np.arange(n) / SR; f = hz(m)
        vib = 1 + 0.006 * np.sin(2*np.pi*5.0*t) * np.minimum(1, t / 0.25)
        ph = np.cumsum(f * vib) / SR
        x = np.sin(2*np.pi*ph) + 0.22*np.sin(4*np.pi*ph) + 0.07*np.sin(6*np.pi*ph)
        breath = bp(rng.standard_normal(n), 1500, 6000) * 0.05
        return (x + breath) * adsr(n, 0.05, 0.2, 0.85, 0.1) * vol

    def cello(m, dur, vol=0.26):
        n = int((dur + 0.2) * SR); t = np.arange(n) / SR; f = hz(m)
        vib = 1 + 0.005 * np.sin(2*np.pi*4.6*t) * np.minimum(1, t / 0.35)
        ph = np.cumsum(f * vib) / SR
        x = 2 * (ph - np.floor(ph + 0.5)) + 0.5 * (2 * (ph * 1.003 - np.floor(ph * 1.003 + 0.5)))
        return lp(x, 1300) * adsr(n, 0.12, 0.3, 0.85, 0.18) * vol

    def pad(m, dur, vol=0.13):
        n = int((dur + 0.5) * SR); t = np.arange(n) / SR; f = hz(m)
        x = saw(f, t, -0.004) + saw(f, t, 0.005) + saw(f, t, 0.0) + 0.4 * np.sin(2*np.pi*f*2*t)
        return lp(x, 1500) * adsr(n, 0.25, 0.4, 0.9, 0.45) * vol

    def tuba(m, dur, vol=0.42):
        n = int((dur + 0.1) * SR); t = np.arange(n) / SR; f = hz(m)
        x = np.sin(2*np.pi*f*t) + 0.5*np.sin(2*np.pi*2*f*t) + 0.25*saw(f, t)
        return lp(x, 700) * adsr(n, 0.015, 0.25, 0.55, 0.08) * vol

    def tick(high=True):
        n = int(0.05 * SR); t = np.arange(n) / SR
        x = rng.standard_normal(n)
        x = bp(x, 3500, 9000) if high else bp(x, 1800, 5000)
        return x * np.exp(-t * 140) * (0.06 if high else 0.05)

    def anvil():
        n = int(0.9 * SR); t = np.arange(n) / SR
        x = sum(a*np.sin(2*np.pi*f*t)*np.exp(-t*d) for f, a, d in [(830, 1, 5), (1420, .6, 8), (2310, .4, 11), (3480, .25, 15)])
        return x * 0.09

    def triangle():
        n = int(1.2 * SR); t = np.arange(n) / SR
        x = sum(a*np.sin(2*np.pi*f*t) for f, a in [(4200, 1), (6350, .6), (8900, .35)])
        return x * np.exp(-t * 4.5) * 0.035

    def hiss(dur, vol=0.05):
        n = int(dur * SR); t = np.arange(n) / SR
        return hp(rng.standard_normal(n), 3000) * np.sin(np.pi * t / dur) ** 2 * vol

    def shaker(vol=0.035):
        n = int(0.07 * SR); t = np.arange(n) / SR
        return hp(rng.standard_normal(n), 5000) * np.minimum(1, t / 0.008) * np.exp(-t * 60) * vol

    def tambourine():
        n = int(0.25 * SR); t = np.arange(n) / SR
        x = bp(rng.standard_normal(n), 6000, 12000) * np.exp(-t * 22)
        x += 0.3 * np.sin(2*np.pi*7300*t) * np.exp(-t * 30)
        return x * 0.05

    def sleigh():
        n = int(0.35 * SR); t = np.arange(n) / SR
        x = sum(np.sin(2*np.pi*f*t + rng.uniform(0, 6)) for f in (5200, 6100, 7400, 8800))
        x = x * (0.6 + 0.4 * np.sin(2*np.pi*38*t)) + bp(rng.standard_normal(n), 6000, 12000) * 0.8
        return x * np.exp(-t * 16) * 0.012

    def bird():
        notes = rng.integers(2, 5)
        out = np.zeros(int(0.9 * SR))
        base = rng.uniform(2600, 3800)
        for k in range(notes):
            n = int(rng.uniform(0.06, 0.11) * SR); t = np.arange(n) / SR
            f = base * (1 + rng.uniform(-0.15, 0.25)) * (1 + rng.uniform(-0.25, 0.25) * t / t[-1])
            ch = np.sin(2*np.pi*np.cumsum(f)/SR) * np.sin(np.pi * t / t[-1]) ** 2
            st = int(k * rng.uniform(0.11, 0.16) * SR)
            out[st:st + n] += ch[: len(out) - st][:n]
        return out * 0.03

    INSTR = {"box": music_box, "celesta": celesta, "acc": accordion, "brass": brass,
             "flute": flute, "cello": cello, "pad": pad}

    n_bars = sum(len(s[0]) for s in SECTIONS)
    loop_len = int(round(n_bars * bar * SR))
    total = loop_len + int(4 * SR)  # cauda que será dobrada para o início
    L = np.zeros(total); R = np.zeros(total)

    def add(sig, start_s, pan=0.0, gain=1.0):
        i = int(round(start_s * SR)); j = min(total, i + len(sig))
        if j <= i or i < 0:
            return
        s = sig[: j - i] * gain
        L[i:j] += s * np.sqrt(0.5 * (1 - pan)) * 1.414
        R[i:j] += s * np.sqrt(0.5 * (1 + pan)) * 1.414

    comp_gain = T.get("comp_gain", 1.0)
    bar_i = 0
    for (melody, chords), lead in zip(SECTIONS, T["leads"]):
        for b in range(len(melody)):
            t0 = bar_i * bar
            root, notes = chords[b]
            # acompanhamento oom-pa-pa
            add(tuba(root, beat * 0.9), t0, gain=comp_gain)
            if b % 2 == 1:
                add(tuba(root + 7, beat * 0.5), t0 + 2.5 * beat, gain=0.5 * comp_gain)
            if T.get("pad_chords"):
                for nn in notes:
                    add(pad(nn, bar * 0.95, vol=0.05), t0, pan=-0.3)
            else:
                for k in (1, 2):
                    for nn in notes:
                        add(accordion(nn, beat * 0.55, vol=0.07), t0 + k * beat, pan=-0.35, gain=comp_gain)
            # percussão e ambientação
            if T["tick"] > 0:
                for k in range(3):
                    add(tick(high=(k == 0)), t0 + k * beat, pan=0.5, gain=T["tick"])
                add(tick(False), t0 + 1.5 * beat, pan=0.6, gain=0.6 * T["tick"])
            if T.get("anvil") and bar_i % 4 == 0:
                add(anvil(), t0, pan=0.3)
            if T.get("triangle") and bar_i % 2 == 0:
                add(triangle(), t0, pan=0.4)
            if T.get("hiss") and b == len(melody) - 1:
                add(hiss(bar * 0.9), t0 + bar * 0.1)
            if T.get("shaker"):
                for k in range(6):
                    add(shaker(0.035 if k % 2 == 0 else 0.02), t0 + k * beat / 2, pan=-0.5)
                add(tambourine(), t0 + beat, pan=0.55)
                add(tambourine(), t0 + 2 * beat, pan=0.55, gain=0.8)
            if T.get("sleigh"):
                for k in range(3):
                    add(sleigh(), t0 + k * beat, pan=0.45, gain=1.0 if k == 0 else 0.6)
            if T.get("birds") and bar_i % 3 == 1:
                add(bird(), t0 + rng.uniform(0, bar * 0.6), pan=rng.uniform(-0.7, 0.7))
            # melodia
            for (st, du, m) in melody[b]:
                for (name, shift, gain, pan) in LEADS[lead]:
                    d = du * beat * (1.0 if name in ("box", "celesta") else 0.95)
                    add(INSTR[name](m + shift, d), t0 + st * beat, pan=pan, gain=gain)
            bar_i += 1

    if T.get("wind"):
        n = total
        w = lp(rng.standard_normal(n), 500) * 6.0
        swell = 0.55 + 0.45 * np.sin(2*np.pi*np.arange(n) / loop_len * 5 + 1.0)  # 5 ciclos inteiros: emenda limpa
        fade = SR  # 1 s de crossfade do fim para o início: o vento também emenda
        ramp = np.linspace(0.0, 1.0, fade)
        w[:fade] = w[:fade] * ramp + w[loop_len:loop_len + fade] * (1.0 - ramp)
        w = w[:loop_len] * swell[:loop_len] * T["wind"]
        L[:loop_len] += w; R[:loop_len] += np.roll(w, 9000)

    # Dobra a cauda sobre o início para o loop não ter emenda
    L[: total - loop_len] += L[loop_len:]; R[: total - loop_len] += R[loop_len:]
    L = L[:loop_len]; R = R[:loop_len]

    # "Sala": ecos cruzados (circulares, para não quebrar o loop)
    L0, R0 = L.copy(), R.copy()
    for d, g in T["echo"]:
        k = int(d * SR)
        L += np.roll(R0, k) * g; R += np.roll(L0, k) * g * 0.9

    mix = np.stack([L, R], axis=1)
    mix = np.tanh(mix / np.max(np.abs(mix)) * 1.1) / np.tanh(1.1) * 0.89  # pico ~ -1 dBFS
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())
    rms = 20 * np.log10(np.sqrt((mix.mean(1) ** 2).mean()))
    seam = np.abs(mix[0] - mix[-1]).max()
    print(f"{theme_name}: compassos={n_bars} duracao={loop_len/SR:.2f}s pico={np.max(np.abs(mix)):.3f} rms={rms:.1f}dBFS emenda={seam:.4f}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in THEMES:
        sys.exit("uso: python compor_musica.py <%s> saida.wav" % "|".join(THEMES))
    compose(sys.argv[1], sys.argv[2])
