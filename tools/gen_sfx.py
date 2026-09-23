#!/usr/bin/env python3
"""Ljudgeneratorn: alla spelljud syntetiseras här, inte laddas ner.

Skäl: ett pixelspel behöver korta, torra ljud (20-500 ms) — precis den sorts ljud som är
tråkigast att leta efter och lättast att räkna fram. Inga licenser att hålla reda på, ingen
fil att tappa bort, och samma kommando ger samma ljud (bruset är seedat).

    python3 tools/gen_sfx.py                 # skriver till game/assets/sfx/
    python3 tools/gen_sfx.py --check         # mäter att filerna finns och är rimliga

Ponytail: allt är en oscillator + ett hölje. Lägg till filter/EQ när något ljud bevisligen
låter fel i spelet — inte innan.
"""
import argparse
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "sfx"


def t(dur: float) -> np.ndarray:
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur: float, phase: float = 0.0) -> np.ndarray:
    f = np.full_like(t(dur), float(freq)) if np.isscalar(freq) else freq
    tt = t(dur)
    return np.sin(2 * np.pi * f * tt + phase)


def square(freq, dur: float) -> np.ndarray:
    return np.sign(sine(freq, dur))


def noise(dur: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * dur))


def env(x: np.ndarray, attack: float = 0.004, release: float = 0.02) -> np.ndarray:
    """Kort attack, exponentiellt fall — så låter slag, inte toner."""
    n = len(x)
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.linspace(0, 6, n - a))
    return x * e


def lowpass(x: np.ndarray, width: int) -> np.ndarray:
    if width < 2:
        return x
    return np.convolve(x, np.ones(width) / width, mode="same")


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def sweep(f0: float, f1: float, dur: float) -> np.ndarray:
    f = np.linspace(f0, f1, int(SR * dur), endpoint=False)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def bank() -> dict:
    """Ljuden spelet faktiskt använder, ett per händelse i eventströmmen."""
    return {
        # spelaren slår: dov smäll + låg ton
        "hit": env(mix(0.8 * lowpass(noise(0.14, 1), 12), 0.6 * sine(90, 0.14)), 0.002) * 0.8,
        # combo: ljusare, längre, hörs igenom smällen
        "crit": env(mix(0.7 * lowpass(noise(0.22, 2), 6), 0.5 * sine(150, 0.22),
                        0.3 * square(300, 0.22)), 0.002) * 0.9,
        # guld
        "coin": env(mix(0.4 * square(1046, 0.05), 0.4 * np.concatenate(
            [np.zeros(int(SR * 0.05)), square(1568, 0.09)])), 0.002) * 0.5,
        # kort spelas
        "card": env(mix(0.35 * lowpass(noise(0.09, 3), 4), sweep(700, 1400, 0.09) * 0.25), 0.001) * 0.7,
        # steg
        "step": env(lowpass(noise(0.05, 4), 20), 0.001) * 0.25,
        # kortval: uppåtgående
        "pick": env(mix(sweep(400, 900, 0.12), 0.3 * square(880, 0.12)), 0.003) * 0.6,
        # level up: tre toner uppåt
        "level_up": env(np.concatenate([sine(523, 0.08), sine(659, 0.08), sine(784, 0.22)]), 0.004) * 0.6,
        # nedstigning
        "descend": env(sweep(220, 70, 0.5), 0.01) * 0.7,
        # körningen slut
        "death": env(mix(sweep(200, 45, 0.9), 0.3 * sine(55, 0.9)), 0.005) * 0.8,
    }


def write_wav(path: Path, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples))) or 1.0
    data = (samples / peak * 0.85 * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    if args.check:
        bad = 0
        for name in sorted(bank()):
            p = OUT / f"{name}.wav"
            if not p.exists():
                print(f"SAKNAS {p.name}")
                bad += 1
                continue
            with wave.open(str(p), "rb") as w:
                frames, rate = w.getnframes(), w.getframerate()
            dur = frames / rate
            ok = 0.02 <= dur <= 1.5 and rate == SR and frames > 100
            print(f"{'ok  ' if ok else 'FEL '} {p.name:12s} {dur * 1000:6.0f} ms  {p.stat().st_size / 1024:5.1f} kB")
            bad += 0 if ok else 1
        print(f"{len(bank())} ljud, {bad} fel")
        return 1 if bad else 0

    for name, samples in bank().items():
        write_wav(OUT / f"{name}.wav", samples)
        print(f"skrev {(OUT / (name + '.wav')).relative_to(ROOT)}  ({len(samples) / SR * 1000:.0f} ms)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
