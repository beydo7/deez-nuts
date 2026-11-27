"""Erzeugt alle Soundeffekte von Deez Nuts! als WAV-Dateien in sounds/.

Aufruf (aus dem Repo-Ordner):  python tools/generate_sfx.py
Braucht nur numpy. Alles ist synthetisch erzeugt, es gibt keine fremden Aufnahmen.
"""
import os
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(7)
ZIEL = os.path.join(os.path.dirname(__file__), "..", "sounds")


def t(dauer):
    return np.linspace(0, dauer, int(SR * dauer), endpoint=False)


def huelle(n, attack=0.002, decay=0.1):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-5), 0, 1)
    return a * np.exp(-x / max(decay, 1e-5))


def rauschen(dauer):
    return RNG.uniform(-1, 1, int(SR * dauer))


def tiefpass(x, staerke):
    # einfacher Ein-Pol-Tiefpass, staerke 0..1 (höher = dumpfer)
    y = np.zeros_like(x)
    acc = 0.0
    k = 1.0 - staerke
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def hochpass(x, staerke):
    return x - tiefpass(x, staerke)


def mix(*teile):
    n = max(len(p) for p in teile)
    aus = np.zeros(n)
    for p in teile:
        aus[: len(p)] += p
    return aus


def speichern(name, x, laut=0.9):
    x = np.asarray(x, dtype=np.float64)
    spitze = np.max(np.abs(x)) or 1.0
    x = x / spitze * laut
    ende = int(SR * 0.004)
    if len(x) > ende:
        x[-ende:] *= np.linspace(1, 0, ende)
    daten = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(ZIEL, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(daten.tobytes())


def knack_perfekt():
    n = rauschen(0.12)
    klick = hochpass(n, 0.6) * huelle(len(n), 0.0005, 0.018)
    holz = np.sin(2 * np.pi * 900 * t(0.12)) * huelle(int(SR * 0.12), 0.001, 0.03)
    ping = np.sin(2 * np.pi * 2400 * t(0.35)) * huelle(int(SR * 0.35), 0.003, 0.12) * 0.35
    ping2 = np.sin(2 * np.pi * 3600 * t(0.3)) * huelle(int(SR * 0.3), 0.003, 0.08) * 0.15
    return mix(klick * 1.2, holz * 0.6, ping, ping2)


def knack_riss():
    n = rauschen(0.05)
    return hochpass(n, 0.7) * huelle(len(n), 0.0003, 0.008)


def knirschen():
    aus = np.zeros(int(SR * 0.3))
    for _ in range(14):
        start = RNG.integers(0, int(SR * 0.22))
        stueck = hochpass(rauschen(0.025), 0.4) * huelle(int(SR * 0.025), 0.0005, 0.006)
        aus[start:start + len(stueck)] += stueck * RNG.uniform(0.4, 1.0)
    return aus


def matsch():
    n = tiefpass(rauschen(0.35), 0.93)
    wobble = 1 + 0.5 * np.sin(2 * np.pi * 18 * t(0.35))
    return n * wobble * huelle(len(n), 0.01, 0.12)


def knarzen():
    d = 0.16
    x = t(d)
    f = 150 + 40 * np.sin(2 * np.pi * 7 * x)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saege = 2 * ((phase / (2 * np.pi)) % 1) - 1
    flatter = (np.sin(2 * np.pi * 55 * x) > 0.2).astype(float) * 0.7 + 0.3
    return tiefpass(saege * flatter, 0.5) * huelle(len(x), 0.01, 0.08)


def greifen():
    x = t(0.07)
    f = 500 + 900 * x / 0.07
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * huelle(len(x), 0.002, 0.025)


def ablegen():
    x = t(0.18)
    return (np.sin(2 * np.pi * 95 * x) + 0.3 * tiefpass(rauschen(0.18), 0.85)) * huelle(len(x), 0.001, 0.05)


def werfen():
    n = rauschen(0.3)
    x = t(0.3)
    form = np.sin(np.pi * x / 0.3) ** 2
    return hochpass(tiefpass(n, 0.7), 0.95) * form


def einwurf():
    x = t(0.25)
    tink = np.sin(2 * np.pi * 1650 * x) * huelle(len(x), 0.001, 0.06)
    tink2 = np.sin(2 * np.pi * 2480 * x) * huelle(len(x), 0.001, 0.04) * 0.5
    plop = np.sin(2 * np.pi * (300 - 500 * x) * x) * huelle(len(x), 0.001, 0.03)
    return mix(tink, tink2, plop * 0.6)


def muenzen():
    x = t(0.4)
    a = np.sin(2 * np.pi * 1975 * x) * huelle(len(x), 0.001, 0.12)
    b = np.zeros(len(x))
    v = int(SR * 0.07)
    b[v:] = np.sin(2 * np.pi * 2637 * x[: len(x) - v]) * huelle(len(x) - v, 0.001, 0.15)
    return mix(a, b)


def kasse():
    ding = muenzen()
    ratter = knirschen() * 0.35
    return mix(ratter, np.concatenate([np.zeros(int(SR * 0.08)), ding]))


def verkauf():
    aus = np.zeros(int(SR * 0.8))
    for i in range(7):
        start = int(SR * (0.03 + i * 0.07 + RNG.uniform(0, 0.03)))
        x = t(0.2)
        f = RNG.choice([1975, 2349, 2637, 3136])
        s = np.sin(2 * np.pi * f * x) * huelle(len(x), 0.001, 0.07)
        aus[start:start + len(s)] += s[: len(aus) - start] * 0.6
    return aus


def arpeggio(noten, abstand, dauer, decay):
    aus = np.zeros(int(SR * (abstand * len(noten) + dauer)))
    for i, f in enumerate(noten):
        x = t(dauer)
        s = (np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * 2 * f * x)) * huelle(len(x), 0.005, decay)
        start = int(SR * abstand * i)
        aus[start:start + len(s)] += s
    return aus


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
    ton = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
    return ton * np.sin(np.pi * x / d) ** 1.5


def fehler():
    x = t(0.22)
    quad = np.sign(np.sin(2 * np.pi * 110 * x))
    return tiefpass(quad, 0.6) * huelle(len(x), 0.005, 0.15)


def maschine():
    x = t(0.25)
    return mix(tiefpass(rauschen(0.25), 0.9) * huelle(len(x), 0.002, 0.07), np.sin(2 * np.pi * 70 * x) * huelle(len(x), 0.002, 0.08))


def wischen():
    n = rauschen(0.4)
    x = t(0.4)
    form = np.sin(np.pi * x / 0.4)
    return tiefpass(n, 0.55) * form


def hebel():
    klack = hochpass(rauschen(0.04), 0.5) * huelle(int(SR * 0.04), 0.0005, 0.01)
    aus = np.zeros(int(SR * 0.7))
    aus[: len(klack)] += klack
    for _ in range(12):
        start = int(SR * RNG.uniform(0.08, 0.55))
        x = t(0.05)
        s = np.sin(2 * np.pi * RNG.uniform(500, 900) * x) * huelle(len(x), 0.001, 0.012)
        aus[start:start + len(s)] += s * 0.5
    return aus


def stinken():
    n = tiefpass(rauschen(0.5), 0.8)
    x = t(0.5)
    return n * np.sin(np.pi * x / 0.5) * (1 + 0.6 * np.sin(2 * np.pi * 9 * x))


def warnung():
    x = t(0.9)
    f = np.where((x % 0.3) < 0.15, 660, 520)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return tiefpass(np.sign(np.sin(ph)), 0.4) * huelle(len(x), 0.01, 0.6)


def main():
    os.makedirs(ZIEL, exist_ok=True)
    sounds = {
        "knack_perfekt": knack_perfekt(),
        "knack_riss": knack_riss(),
        "knirschen": knirschen(),
        "matsch": matsch(),
        "knarzen": knarzen(),
        "greifen": greifen(),
        "ablegen": ablegen(),
        "werfen": werfen(),
        "einwurf": einwurf(),
        "muenzen": muenzen(),
        "kasse": kasse(),
        "verkauf": verkauf(),
        "freischalten": arpeggio([523, 659, 784, 1047], 0.11, 0.5, 0.25),
        "meilenstein": arpeggio([1047, 1319, 1568, 2093], 0.06, 0.35, 0.12),
        "eichhorn": eichhorn(),
        "miau": miau(),
        "fehler": fehler(),
        "maschine": maschine(),
        "wischen": wischen(),
        "hebel": hebel(),
        "stinken": stinken(),
        "warnung": warnung(),
    }
    for name, daten in sounds.items():
        speichern(name, daten)
    print(f"{len(sounds)} Sounds erzeugt in {os.path.abspath(ZIEL)}")


if __name__ == "__main__":
    main()
