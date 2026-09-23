#!/usr/bin/env python3
"""Mäter normalprovets bilder, per pixel, i numpy.

Provet i spelet (`tools/play.sh -- normalprov=0`) tar fyra bilder i SAMMA körning med samma kamera:

  a: normal_scale 0,0   b: 1,0 (spelets eget värde)   c: 8,0   d: 0,0 igen

Två körningar går inte att jämföra: ljuset varierar mellan dem (samma bygge gav medel-RGB 73 i en
körning och 31 i en annan). Därför tas alla bilderna i en körning, och därför finns `d`: |a−d| är den
skillnad slumpen kan åstadkomma (fladdrande facklor, temporal GI). Ett |a−b| i den storleken betyder
ingen skillnad — hur grön än en flagga ser ut.

    python3 tools/normalprov.py ~/.local/share/godot/app_userdata/HellCrawler/normalprov-*.png

Med `--relief` mäts också om kartans bidrag FÖRSTÄRKER eller MOTVERKAR albedons målade högdagrar:
korrelationen mellan (nolläge − kartläge) och nollägrets egen högfrekvens. Positiv = reliefen lägger
skuggan där konsten redan målat den (den syns); negativ = de tar ut varandra (ytan läser platt trots
att kartan är stark). Mätt i asklunden: +0,29 till +0,46.

    python3 tools/normalprov.py --relief normalprov-01-0.0.png normalprov-02-1.0.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def läs(p: Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)


def skillnad(a: np.ndarray, b: np.ndarray) -> tuple[float, float]:
    """(medel, 99-percentil) av |a−b| per pixel, räknat över alla kanaler."""
    d = np.abs(a - b)
    return float(d.mean()), float(np.percentile(d, 99))


def högfrekvens(x: np.ndarray, radie: int = 2) -> np.ndarray:
    """Bilden minus sin egen suddiga version: det målade strecket, inte rummets ljus."""
    grå = x.mean(axis=2)
    kärna = np.ones((radie * 2 + 1, radie * 2 + 1), dtype=np.float32)
    kärna /= kärna.sum()
    från = np.pad(grå, radie, mode="edge")
    fönster = np.lib.stride_tricks.sliding_window_view(från, kärna.shape)
    return grå - (fönster * kärna).sum(axis=(2, 3))


def relief_rad(noll: np.ndarray, karta: np.ndarray) -> tuple[float, float, float]:
    """(korrelation, reliefens spridning, den målade konstens spridning)."""
    mål = högfrekvens(noll)
    relief = (noll.mean(axis=2) - karta.mean(axis=2))
    a = relief - relief.mean()
    b = mål - mål.mean()
    korr = float((a * b).sum() / np.sqrt((a * a).sum() * (b * b).sum() + 1e-9))
    return korr, float(relief.std()), float(mål.std())


def vyns_ruta(bredd: int, höjd: int) -> tuple[int, int, int, int] | None:
    """(x, y, w, h) för spelvyn i en fönsterbild, eller None om bilden ÄR spelvyn.

    Vyn är 480x270, centrerad och skalad med det största heltalet som ryms (samma räkning som
    main.gd `_placera_vy`). HUD:en och de svarta kanterna runt om ligger utanför: mäter man hela
    fönstret späds skillnaden ut av pixlar som är likadana i båda bilderna (mätt: 3,2 i hela
    fönstret mot 5,6 i själva vyn för samma par).
    """
    if bredd <= 480 and höjd <= 270:
        return None
    skala = max(1, min(bredd // 480, höjd // 270))
    w, h = 480 * skala, 270 * skala
    return ((bredd - w) // 2, (höjd - h) // 2, w, h)


def läsvy(p: Path) -> tuple[np.ndarray, np.ndarray]:
    """Hela bilden och spelvyn i den."""
    hel = läs(p)
    r = vyns_ruta(hel.shape[1], hel.shape[0])
    if r is None:
        return hel, hel
    x, y, w, h = r
    return hel, hel[y:y + h, x:x + w]


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    relief = "--relief" in argv
    filer = sorted(Path(a) for a in args)
    if len(filer) < 2:
        print("ange minst två bilder ur samma körning")
        return 1
    print("bild                medelljushet   (vyns andel av bilden)")
    for p in filer:
        hel, vy = läsvy(p)
        print("  %-18s %.4f        %.0f %%" % (p.name, float(hel.mean()) / 255.0,
            100.0 * vy.size / hel.size))
    # Två tabeller: hela fönstret och själva spelvyn. Vyn är den som går att jämföra med äldre
    # mätningar (innan HUD:en flyttade ut i kanterna var hela bilden vyn).
    bas_hel, bas_vy = läsvy(filer[0])
    for namn, nyckel in (("hela fönstret", "hel"), ("spelvyn", "vy")):
        print("\npar (%s)            |a−b| medel   99-percentil" % namn)
        for p in filer[1:]:
            hel, vy = läsvy(p)
            a = bas_hel if nyckel == "hel" else bas_vy
            b = hel if nyckel == "hel" else vy
            m, p99 = skillnad(a, b)
            print("  %-18s %8.3f   %8.3f" % ("%s mot %s" % (filer[0].stem, p.stem), m, p99))
    if relief and len(filer) >= 3:
        print("\nreliefen mot den målade konsten (spelvyn)")
        for p in filer[1:]:
            _, vy = läsvy(p)
            korr, r_st, m_st = relief_rad(bas_vy, vy)
            print("  %-18s korr %+.2f   reliefens spridning %5.1f   målade konstens %5.1f"
                  % (p.stem, korr, r_st, m_st))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
