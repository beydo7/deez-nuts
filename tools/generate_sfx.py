"""Erzeugt alle Soundeffekte, die Musik und die Atmo von Deez Nuts! als WAV-Dateien in sounds/.

Aufruf (aus dem Repo-Ordner):  python tools/generate_sfx.py
Braucht nur numpy. Alles ist synthetisch erzeugt, es gibt keine fremden Aufnahmen.
Der Zufall ist fest eingestellt (Saat 7), dadurch entstehen jedes Mal exakt dieselben Dateien.
"""
import math
import os
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(7)
ZIEL = os.path.join(os.path.dirname(__file__), "..", "sounds")


# --- Grundbausteine -------------------------------------------------------------
def t(dauer, sr=SR):
    return np.arange(int(sr * dauer)) / sr


def huelle(n, attack=0.002, decay=0.1, sr=SR):
    x = np.arange(n) / sr
    a = np.clip(x / max(attack, 1e-5), 0, 1)
    return a * np.exp(-x / max(decay, 1e-5))


def rauschen(dauer, sr=SR):
    return RNG.uniform(-1, 1, int(sr * dauer))


def biquad(x, b, a):
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    a1, a2 = a
    for i in range(len(x)):
        v = x[i]
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, o
        y[i] = o
    return y


def bandpass(x, f, q=4.0, sr=SR):
    w = 2 * math.pi * f / sr
    al = math.sin(w) / (2 * q)
    a0 = 1 + al
    return biquad(x, (al / a0, 0.0, -al / a0), (-2 * math.cos(w) / a0, (1 - al) / a0))


def tiefpass(x, f, q=0.707, sr=SR):
    w = 2 * math.pi * f / sr
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + al
    return biquad(x, ((1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0), (-2 * c / a0, (1 - al) / a0))


def hochpass(x, f, q=0.707, sr=SR):
    w = 2 * math.pi * f / sr
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + al
    return biquad(x, ((1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0), (-2 * c / a0, (1 - al) / a0))


def mix(*teile):
    n = max(len(p) for p in teile)
    aus = np.zeros(n)
    for p in teile:
        aus[: len(p)] += p
    return aus


def versetzt(x, sek, sr=SR):
    return np.concatenate([np.zeros(int(sr * sek)), x])


def ton(f, dauer, attack=0.002, decay=0.2, obert=(1.0,), sr=SR):
    x = t(dauer, sr)
    s = np.zeros(len(x))
    for i, amp in enumerate(obert):
        s += amp * np.sin(2 * np.pi * f * (i + 1) * x) * np.exp(-x * (i * 1.5) / max(decay, 1e-4))
    return s * huelle(len(x), attack, decay, sr)


def sweep(f0, f1, dauer, sr=SR):
    x = t(dauer, sr)
    f = f0 + (f1 - f0) * x / dauer
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def klick(dauer=0.01, hell=4000.0):
    n = rauschen(dauer)
    return hochpass(n, hell) * huelle(len(n), 0.0002, dauer * 0.3)


def speichern(name, x, laut=0.9, sr=SR):
    x = np.asarray(x, dtype=np.float64)
    spitze = np.max(np.abs(x)) or 1.0
    x = x / spitze * laut
    ende = int(sr * 0.004)
    if len(x) > ende:
        x[-ende:] *= np.linspace(1, 0, ende)
    daten = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(ZIEL, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(daten.tobytes())


# --- Knacken -------------------------------------------------------------------
def knack_perfekt():
    # scharfer Bruch + hohler Schalenkörper + Splitter + kleiner Wumms
    bruch = klick(0.03, 2500) * 1.6
    koerper = bandpass(rauschen(0.14), 950, 5) * huelle(int(SR * 0.14), 0.0005, 0.035) * 3.0
    koerper2 = bandpass(rauschen(0.12), 1700, 6) * huelle(int(SR * 0.12), 0.0005, 0.025) * 2.0
    wumms = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 60, int(SR * 0.12))) / SR) * huelle(int(SR * 0.12), 0.001, 0.04) * 0.7
    splitter = np.zeros(int(SR * 0.25))
    for _ in range(9):
        s = int(SR * RNG.uniform(0.015, 0.18))
        k = bandpass(rauschen(0.012), RNG.uniform(2500, 6000), 3) * huelle(int(SR * 0.012), 0.0002, 0.003)
        splitter[s:s + len(k)] += k * RNG.uniform(0.6, 1.4) * 2.5
    glanz = ton(2350, 0.4, 0.004, 0.12, (1.0, 0.0, 0.25)) * 0.18
    return mix(bruch, koerper, koerper2, wumms, splitter, versetzt(glanz, 0.02))


def knack_riss():
    return mix(klick(0.02, 3000) * 1.2, bandpass(rauschen(0.04), 1400, 6) * huelle(int(SR * 0.04), 0.0003, 0.01) * 2.5)


def knistern():
    aus = np.zeros(int(SR * 0.05))
    for _ in range(3):
        s = int(SR * RNG.uniform(0, 0.035))
        k = bandpass(rauschen(0.008), RNG.uniform(3000, 7000), 4) * huelle(int(SR * 0.008), 0.0001, 0.002)
        aus[s:s + len(k)] += k
    return aus


def knirschen():
    aus = np.zeros(int(SR * 0.35))
    for _ in range(22):
        s = int(SR * RNG.uniform(0, 0.28))
        k = bandpass(rauschen(0.02), RNG.uniform(900, 3500), 3) * huelle(int(SR * 0.02), 0.0003, 0.005)
        aus[s:s + len(k)] += k * RNG.uniform(0.4, 1.0)
    return mix(aus * 2.0, klick(0.03, 1500))


def matsch():
    n = tiefpass(rauschen(0.4), 700)
    x = t(0.4)
    wobble = 1 + 0.6 * np.sin(2 * np.pi * 16 * x)
    return mix(n * wobble * huelle(len(n), 0.005, 0.12), knirschen() * 0.4)


def knarzen():
    d = 0.16
    x = t(d)
    f = 140 + 30 * np.sin(2 * np.pi * 6 * x)
    phase = np.cumsum(f) / SR
    saege = 2 * (phase % 1) - 1
    flatter = (np.sin(2 * np.pi * 45 * x) > 0.1).astype(float) * 0.7 + 0.3
    return bandpass(saege * flatter, 600, 1.5) * huelle(len(x), 0.01, 0.07)


def ausholen():
    n = rauschen(0.18)
    x = t(0.18)
    return bandpass(n, 900, 1.0) * np.sin(np.pi * x / 0.18) ** 2


def hammer():
    wumms = np.sin(2 * np.pi * np.cumsum(np.linspace(140, 45, int(SR * 0.2))) / SR) * huelle(int(SR * 0.2), 0.001, 0.07)
    klong = ton(820, 0.35, 0.001, 0.09, (1.0, 0.4, 0.3)) * 0.4
    return mix(wumms * 1.2, klick(0.02, 1200) * 1.2, klong)


# --- Hantieren -------------------------------------------------------------------
def greifen():
    return mix(bandpass(rauschen(0.06), 2200, 2) * huelle(int(SR * 0.06), 0.002, 0.015) * 2, ton(700, 0.05, 0.001, 0.015) * 0.2)


def ablegen():
    x = t(0.15)
    return mix(np.sin(2 * np.pi * 110 * x) * huelle(len(x), 0.001, 0.04), bandpass(rauschen(0.15), 700, 2) * huelle(len(x), 0.001, 0.03) * 1.5)


def werfen():
    n = rauschen(0.3)
    x = t(0.3)
    return bandpass(n, 1200, 0.8) * np.sin(np.pi * x / 0.3) ** 2


def einwurf():
    x = t(0.25)
    tink = np.sin(2 * np.pi * 1650 * x) * huelle(len(x), 0.001, 0.06)
    tink2 = np.sin(2 * np.pi * 2480 * x) * huelle(len(x), 0.001, 0.04) * 0.5
    return mix(tink, tink2, klick(0.01, 2000) * 0.5)


def plopp():
    # Kern landet im Glas: weiches Tock + Glas-Kling
    x = t(0.3)
    tock = np.sin(2 * np.pi * np.cumsum(np.linspace(420, 200, len(x))) / SR) * huelle(len(x), 0.001, 0.025)
    kling = ton(2900, 0.3, 0.001, 0.08, (1.0, 0.0, 0.3)) * 0.22
    kling2 = ton(4100, 0.25, 0.001, 0.05) * 0.1
    return mix(tock, kling, kling2)


def schritt():
    x = t(0.14)
    dumpf = tiefpass(rauschen(0.14), 300) * huelle(len(x), 0.002, 0.03) * 3
    holz = bandpass(rauschen(0.14), 420, 4) * huelle(len(x), 0.001, 0.025) * 2
    return mix(dumpf, holz)


def hinsetzen():
    knarz = bandpass(sweep(260, 180, 0.3) * (np.sin(2 * np.pi * 30 * t(0.3)) > 0), 500, 2) * huelle(int(SR * 0.3), 0.02, 0.12)
    stoff = bandpass(rauschen(0.2), 1800, 1.2) * np.sin(np.pi * t(0.2) / 0.2)
    return mix(stoff * 0.6, versetzt(knarz, 0.08))


def wischen():
    n = rauschen(0.35)
    x = t(0.35)
    form = np.sin(np.pi * x / 0.35) ** 1.5
    kratz = bandpass(n, 2500, 0.9) * form
    rassel = np.zeros(len(x))
    for _ in range(8):
        s = int(SR * RNG.uniform(0.05, 0.3))
        k = bandpass(rauschen(0.01), RNG.uniform(1500, 3500), 3) * huelle(int(SR * 0.01), 0.0002, 0.003)
        rassel[s:s + len(k)] += k * 2
    return mix(kratz, rassel)


def hebel():
    klack = mix(klick(0.03, 1500) * 1.5, ton(320, 0.12, 0.001, 0.03, (1.0, 0.5)) * 0.5)
    feder = ton(160, 0.4, 0.002, 0.15) * (1 + 0.5 * np.sin(2 * np.pi * 22 * t(0.4))) * 0.3
    return mix(klack, versetzt(feder, 0.05))


def rollen():
    aus = np.zeros(int(SR * 0.25))
    for i in range(5):
        s = int(SR * (i * 0.04 + RNG.uniform(0, 0.015)))
        k = ton(RNG.uniform(900, 1400), 0.05, 0.0005, 0.012, (1.0, 0.6, 0.3))
        aus[s:s + len(k)] += k * RNG.uniform(0.5, 1.0)
    return aus


def rutsch():
    aus = np.zeros(int(SR * 0.9))
    for _ in range(24):
        s = int(SR * RNG.uniform(0.0, 0.75))
        k = mix(bandpass(rauschen(0.02), RNG.uniform(500, 1200), 3) * huelle(int(SR * 0.02), 0.0003, 0.006) * 2,
                ton(RNG.uniform(250, 450), 0.05, 0.0005, 0.012) * 0.4)
        aus[s:s + len(k)] += k * RNG.uniform(0.4, 1.0)
    return aus


def schaufeln():
    # Kratzen in losen Nüssen + Geklapper
    x = t(0.22)
    kratz = bandpass(rauschen(0.22), 1400, 1.2) * np.sin(np.pi * x / 0.22) ** 1.5 * 0.8
    klapper = np.zeros(len(x))
    for _ in range(10):
        s = int(SR * RNG.uniform(0.02, 0.18))
        k = mix(bandpass(rauschen(0.015), RNG.uniform(700, 1600), 3) * huelle(int(SR * 0.015), 0.0002, 0.004) * 2,
                ton(RNG.uniform(350, 650), 0.04, 0.0005, 0.01) * 0.5)
        klapper[s:s + len(k)] += k[: len(klapper) - s] * RNG.uniform(0.4, 1.0)
    return mix(kratz, klapper)


def sog():
    x = t(0.18)
    brumm = np.sin(2 * np.pi * 95 * x) * 0.4 + np.sin(2 * np.pi * 190 * x) * 0.2
    zisch = bandpass(rauschen(0.18), 1800, 0.9)
    klapper = np.zeros(len(x))
    for _ in range(4):
        s = int(SR * RNG.uniform(0.0, 0.15))
        k = ton(RNG.uniform(900, 1500), 0.03, 0.0005, 0.008) * 0.4
        klapper[s:s + len(k)] += k[: len(klapper) - s]
    return mix(brumm + zisch * 0.7, klapper) * np.sin(np.pi * x / 0.18) ** 0.5


# --- Geld und Belohnung -----------------------------------------------------------
def muenze_einzeln(f):
    return mix(ton(f, 0.5, 0.0005, 0.18, (1.0, 0.0, 0.0, 0.0, 0.35)), klick(0.008, 5000) * 0.3)


def muenzen():
    return mix(muenze_einzeln(2637), versetzt(muenze_einzeln(3520) * 0.8, 0.06))


def kasse():
    klingel = mix(ton(1568, 0.8, 0.001, 0.3, (1.0, 0.0, 0.3)), versetzt(ton(2093, 0.8, 0.001, 0.3, (1.0, 0.0, 0.3)), 0.09))
    ratter = knirschen() * 0.25
    return mix(ratter, versetzt(klingel * 0.6, 0.05))


def verkauf():
    aus = np.zeros(int(SR * 1.0))
    for i in range(10):
        s = int(SR * (0.02 + i * 0.055 + RNG.uniform(0, 0.02)))
        m = muenze_einzeln(RNG.choice([2349, 2637, 3136, 3520])) * RNG.uniform(0.4, 0.8)
        aus[s:s + len(m)] += m[: len(aus) - s]
    return mix(aus, kasse() * 0.6)


def glocke():
    return mix(ton(1760, 1.4, 0.001, 0.45, (1.0, 0.0, 0.5, 0.0, 0.0, 0.2)), ton(1760 * 2.76, 0.6, 0.001, 0.15) * 0.15)


def arpeggio(noten, abstand, dauer, decay, obert=(1.0, 0.3)):
    aus = np.zeros(int(SR * (abstand * len(noten) + dauer)))
    for i, f in enumerate(noten):
        s = ton(f, dauer, 0.004, decay, obert)
        st = int(SR * abstand * i)
        aus[st:st + len(s)] += s
    return aus


def gold():
    a = arpeggio([1047, 1319, 1568, 2093, 2637, 3136], 0.05, 0.7, 0.3, (1.0, 0.0, 0.3))
    schimmer = np.zeros(len(a))
    for _ in range(30):
        s = int(SR * RNG.uniform(0.05, 0.6))
        k = ton(RNG.uniform(4000, 7000), 0.08, 0.001, 0.02) * 0.15
        schimmer[s:s + len(k)] += k
    return mix(a, schimmer)


def ziel():
    return arpeggio([784, 988, 1175, 1568], 0.08, 0.5, 0.2, (1.0, 0.0, 0.25))


def voll():
    return mix(ton(1319, 0.6, 0.002, 0.25, (1.0, 0.0, 0.3)), versetzt(ton(1047, 0.8, 0.002, 0.3, (1.0, 0.0, 0.3)), 0.18))


def rohrpost():
    n = rauschen(0.6)
    x = t(0.6)
    zisch = mix(bandpass(n, 900, 1.0) * (1 - x / 0.6), bandpass(rauschen(0.6), 2600, 1.0) * (x / 0.6)) * np.sin(np.pi * x / 0.6) ** 2
    plopp = ton(220, 0.15, 0.001, 0.04) * 0.8
    return mix(zisch * 1.5, versetzt(plopp, 0.5))


# --- Tiere und Sonstiges ----------------------------------------------------------
def eichhorn():
    aus = np.zeros(int(SR * 0.45))
    for i in range(6):
        x = t(0.04)
        f = 3200 + 1400 * np.sin(np.pi * x / 0.04) + RNG.uniform(-300, 300)
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * huelle(len(x), 0.002, 0.015)
        start = int(SR * (i * 0.065 + RNG.uniform(0, 0.01)))
        aus[start:start + len(s)] += s
    return aus


def miau():
    d = 0.55
    x = t(d)
    f = 520 + 260 * np.sin(np.pi * x / d) + 12 * np.sin(2 * np.pi * 6 * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
    return bandpass(s, 900, 0.8) * np.sin(np.pi * x / d) ** 1.5


def fehler():
    return mix(ton(220, 0.18, 0.003, 0.08, (1.0, 0.5, 0.3)), versetzt(ton(185, 0.2, 0.003, 0.08, (1.0, 0.5, 0.3)), 0.09))


def maschine():
    x = t(0.25)
    return mix(tiefpass(rauschen(0.25), 500) * huelle(len(x), 0.002, 0.07) * 2, np.sin(2 * np.pi * 70 * x) * huelle(len(x), 0.002, 0.08))


def stinken():
    n = tiefpass(rauschen(0.5), 500)
    x = t(0.5)
    return n * np.sin(np.pi * x / 0.5) * (1 + 0.6 * np.sin(2 * np.pi * 9 * x)) * 2


def warnung():
    x = t(0.9)
    f = np.where((x % 0.3) < 0.15, 660, 520)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return tiefpass(np.sign(np.sin(ph)), 2000) * huelle(len(x), 0.01, 0.6)


# --- Musik ------------------------------------------------------------------------
MSR = 32000
NOTEN = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "H": 2, "B": 1}


def hz(name):
    """'G3', 'F#4' -> Frequenz"""
    ton_ = name[0]
    rest = name[1:]
    vz = 0
    if rest.startswith("#"):
        vz = 1
        rest = rest[1:]
    okt = int(rest)
    halbton = NOTEN[ton_] + vz + (okt - 4) * 12
    return 440.0 * 2 ** (halbton / 12)


def zupf(f, dauer, laut=1.0, hell=1.0):
    """Gezupfter, warmer Ton (Kalimba/Gitarre-ähnlich), schnell mit numpy."""
    x = t(dauer, MSR)
    s = (np.sin(2 * np.pi * f * x) * np.exp(-x * 2.2)
         + 0.45 * hell * np.sin(2 * np.pi * f * 2.0 * x) * np.exp(-x * 4.5)
         + 0.2 * hell * np.sin(2 * np.pi * f * 3.01 * x) * np.exp(-x * 7.0)
         + 0.08 * hell * np.sin(2 * np.pi * f * 4.2 * x) * np.exp(-x * 12.0))
    a = np.clip(x / 0.004, 0, 1)
    return s * a * laut


def piano(f, dauer, laut=1.0):
    x = t(dauer, MSR)
    trem = 1 + 0.05 * np.sin(2 * np.pi * 4.5 * x)
    s = (np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * 2 * f * x) * np.exp(-x * 3) + 0.06 * np.sin(2 * np.pi * 7 * f * x) * np.exp(-x * 20))
    a = np.clip(x / 0.015, 0, 1) * np.exp(-x * 0.9)
    return s * a * trem * laut


def bass(f, dauer, laut=1.0):
    x = t(dauer, MSR)
    s = np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * 2 * f * x) * np.exp(-x * 6)
    a = np.clip(x / 0.006, 0, 1) * np.exp(-x * 2.6)
    return s * a * laut


def musik():
    bpm = 84.0
    schlag = 60.0 / bpm
    takte = [
        ("G", ["G3", "B3", "D4"], "G2"), ("Em", ["E3", "G3", "B3"], "E2"), ("C", ["C3", "E3", "G3"], "C2"), ("D", ["D3", "F#3", "A3"], "D2"),
        ("G", ["G3", "B3", "D4"], "G2"), ("Em", ["E3", "G3", "B3"], "E2"), ("C", ["C3", "E3", "G3"], "C2"), ("D", ["D3", "F#3", "A3"], "D2"),
        ("C", ["C3", "E3", "G3"], "C2"), ("D", ["D3", "F#3", "A3"], "D2"), ("Hm", ["H2", "D3", "F#3"], "H1"), ("Em", ["E3", "G3", "B3"], "E2"),
        ("C", ["C3", "E3", "G3"], "C2"), ("D", ["D3", "F#3", "A3"], "D2"), ("G", ["G3", "B3", "D4"], "G2"), ("G", ["G3", "B3", "D4"], "G2"),
    ]
    # Melodie: (Takt, Schlag, Note, Länge in Schlägen)
    melodie = [
        (0, 0, "D5", 1), (0, 1, "B4", 1), (0, 2, "G4", 1.5), (0, 3.5, "A4", 0.5),
        (1, 0, "B4", 1.5), (1, 1.5, "G4", 0.5), (1, 2, "E4", 2),
        (2, 0, "E4", 1), (2, 1, "G4", 1), (2, 2, "C5", 1), (2, 3, "B4", 1),
        (3, 0, "A4", 3), (3, 3, "D4", 1),
        (4, 0, "D5", 1), (4, 1, "B4", 1), (4, 2, "G4", 1), (4, 3, "B4", 1),
        (5, 0, "E5", 1.5), (5, 1.5, "D5", 0.5), (5, 2, "B4", 2),
        (6, 0, "C5", 1), (6, 1, "E5", 1), (6, 2, "D5", 1), (6, 3, "C5", 1),
        (7, 0, "A4", 2), (7, 2, "F#4", 1), (7, 3, "A4", 1),
        (8, 0, "G4", 1), (8, 1, "E4", 1), (8, 2, "G4", 1), (8, 3, "C5", 1),
        (9, 0, "A4", 1.5), (9, 1.5, "F#4", 0.5), (9, 2, "D4", 2),
        (10, 0, "F#4", 1), (10, 1, "A4", 1), (10, 2, "D5", 2),
        (11, 0, "B4", 1), (11, 1, "G4", 1), (11, 2, "E4", 2),
        (12, 0, "E4", 0.5), (12, 0.5, "G4", 0.5), (12, 1, "C5", 1), (12, 2, "E5", 1), (12, 3, "D5", 1),
        (13, 0, "C5", 1), (13, 1, "A4", 1), (13, 2, "F#4", 1), (13, 3, "A4", 1),
        (14, 0, "G4", 1), (14, 1, "B4", 1), (14, 2, "D5", 2),
        (15, 0, "G4", 3),
    ]
    takt_dauer = 4 * schlag
    n = int(MSR * takt_dauer * len(takte))
    aus = np.zeros(n + MSR * 3)

    def setze(sig, sek):
        s = int(MSR * sek)
        aus[s:s + len(sig)] += sig

    for i, (_, akkord, grund) in enumerate(takte):
        t0 = i * takt_dauer
        # weiche Akkorde (zweimal pro Takt angeschlagen)
        for halb in (0, 2):
            for j, nte in enumerate(akkord):
                setze(piano(hz(nte), 2.6, 0.16), t0 + halb * schlag + j * 0.012)
        # Bass auf 1 und 3, auf 3 die Quinte
        setze(bass(hz(grund), 1.2, 0.55), t0)
        quinte = hz(grund) * 1.5
        setze(bass(quinte, 1.0, 0.4), t0 + 2 * schlag)
        # gezupfte Begleitung auf den Achteln
        for e in range(8):
            if e % 2 == 1:
                nte = akkord[(e // 2) % len(akkord)]
                setze(zupf(hz(nte) * 2, 0.6, 0.09, 0.6), t0 + e * schlag * 0.5)
        # Besen und leise Trommel
        for b in range(4):
            sh = tiefpass(hochpass(rauschen(0.12, MSR), 5000, sr=MSR), 9000, sr=MSR) * huelle(int(MSR * 0.12), 0.01, 0.04, MSR)
            setze(sh * (0.05 if b % 2 == 0 else 0.08), t0 + b * schlag + schlag * 0.5)
            if b % 2 == 0:
                kick = np.sin(2 * np.pi * np.cumsum(np.linspace(110, 45, int(MSR * 0.18))) / MSR) * huelle(int(MSR * 0.18), 0.002, 0.06, MSR)
                setze(kick * 0.35, t0 + b * schlag)
            else:
                rim = bandpass(rauschen(0.04, MSR), 1800, 4, sr=MSR) * huelle(int(MSR * 0.04), 0.0005, 0.01, MSR)
                setze(rim * 0.25, t0 + b * schlag)
    for (takt, sch, nte, laenge) in melodie:
        setze(zupf(hz(nte), max(1.2, laenge * schlag * 1.6), 0.32, 1.0), takt * takt_dauer + sch * schlag)
    # Ausklang ans Ende anhängen und an den Anfang falten (nahtlose Schleife)
    rest = aus[n:]
    aus = aus[:n]
    aus[: len(rest)] += rest
    return tiefpass(aus, 7000, sr=MSR)


def atmo():
    """Vogelgezwitscher und leiser Wind, 24 s Schleife."""
    sr = 22050
    d = 24.0
    n = int(sr * d)
    wind = tiefpass(RNG.uniform(-1, 1, n), 400, sr=sr)
    wind *= 0.25 * (1 + 0.5 * np.sin(2 * np.pi * np.arange(n) / sr / 7.0))
    aus = wind * 0.6
    for _ in range(26):
        st = RNG.uniform(0, d - 1.5)
        art = RNG.integers(0, 3)
        for k in range(RNG.integers(2, 6)):
            x = np.arange(int(sr * 0.09)) / sr
            if art == 0:
                f = 3800 + 1200 * np.sin(np.pi * x / 0.09)
            elif art == 1:
                f = 2600 + 1800 * x / 0.09
            else:
                f = 4500 - 1500 * x / 0.09 + 200 * np.sin(2 * np.pi * 40 * x)
            s = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.sin(np.pi * x / 0.09) ** 2
            p = int(sr * (st + k * RNG.uniform(0.11, 0.16)))
            aus[p:p + len(s)] += s * RNG.uniform(0.08, 0.2)
    ein = int(sr * 0.5)
    aus[:ein] = aus[:ein] * np.linspace(0, 1, ein) + aus[-ein:] * np.linspace(1, 0, ein)
    return aus[: n - ein]


def bach():
    """Plätschernder Bach, 12 s Schleife (eigener Zufall, damit die anderen Dateien gleich bleiben)."""
    rng = np.random.default_rng(31)
    sr = 22050
    d = 12.0
    n = int(sr * d)
    grund = bandpass(rng.uniform(-1, 1, n), 900, q=0.6, sr=sr) * 0.35
    grund += tiefpass(rng.uniform(-1, 1, n), 300, sr=sr) * 0.25
    aus = grund * (1 + 0.25 * np.sin(2 * np.pi * np.arange(n) / sr / 3.1))
    # einzelne Gluckser: kurze, aufsteigende Töne
    for _ in range(140):
        st = rng.uniform(0, d - 0.1)
        dauer = rng.uniform(0.015, 0.05)
        x = np.arange(int(sr * dauer)) / sr
        f0 = rng.uniform(400, 1400)
        f = f0 * (1 + 2.5 * x / dauer)
        g = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.sin(np.pi * x / dauer) ** 2
        p = int(sr * st)
        aus[p:p + len(g)] += g * rng.uniform(0.05, 0.18)
    ein = int(sr * 0.5)
    aus[:ein] = aus[:ein] * np.linspace(0, 1, ein) + aus[-ein:] * np.linspace(1, 0, ein)
    return aus[: n - ein]


def wasserfall():
    """Rauschen eines kleinen Wasserfalls, 10 s Schleife."""
    rng = np.random.default_rng(32)
    sr = 22050
    d = 10.0
    n = int(sr * d)
    r = rng.uniform(-1, 1, n)
    aus = tiefpass(r, 2500, sr=sr) * 0.5 + bandpass(r, 600, q=0.5, sr=sr) * 0.5
    aus *= 1 + 0.15 * np.sin(2 * np.pi * np.arange(n) / sr / 1.7) + 0.1 * np.sin(2 * np.pi * np.arange(n) / sr / 0.43)
    ein = int(sr * 0.5)
    aus[:ein] = aus[:ein] * np.linspace(0, 1, ein) + aus[-ein:] * np.linspace(1, 0, ein)
    return aus[: n - ein]


def main():
    os.makedirs(ZIEL, exist_ok=True)
    sounds = {
        "knack_perfekt": knack_perfekt(),
        "knack_riss": knack_riss(),
        "knistern": knistern(),
        "knirschen": knirschen(),
        "matsch": matsch(),
        "knarzen": knarzen(),
        "ausholen": ausholen(),
        "hammer": hammer(),
        "greifen": greifen(),
        "ablegen": ablegen(),
        "werfen": werfen(),
        "einwurf": einwurf(),
        "plopp": plopp(),
        "schritt": schritt(),
        "hinsetzen": hinsetzen(),
        "muenzen": muenzen(),
        "kasse": kasse(),
        "verkauf": verkauf(),
        "glocke": glocke(),
        "freischalten": arpeggio([523, 659, 784, 1047], 0.11, 0.5, 0.25),
        "meilenstein": arpeggio([1047, 1319, 1568, 2093], 0.06, 0.35, 0.12),
        "gold": gold(),
        "ziel": ziel(),
        "voll": voll(),
        "rohrpost": rohrpost(),
        "eichhorn": eichhorn(),
        "miau": miau(),
        "fehler": fehler(),
        "maschine": maschine(),
        "wischen": wischen(),
        "hebel": hebel(),
        "rollen": rollen(),
        "rutsch": rutsch(),
        "schaufeln": schaufeln(),
        "sog": sog(),
        "stinken": stinken(),
        "warnung": warnung(),
    }
    for name, daten in sounds.items():
        speichern(name, daten)
    speichern("musik", musik(), 0.8, MSR)
    speichern("atmo", atmo(), 0.7, 22050)
    speichern("bach", bach(), 0.7, 22050)
    speichern("wasserfall", wasserfall(), 0.8, 22050)
    print(f"{len(sounds) + 4} Sounds erzeugt in {os.path.abspath(ZIEL)}")


if __name__ == "__main__":
    main()
