#!/usr/bin/env python3
"""Kortgeneratorn: ett kort i data/ -> en pixelart-bild i assets/cards/.

Bilden hämtas från OmniRoute (bildmodellerna som redan är inkopplade) och körs genom samma
efterbehandling varje gång: ner till 64x64 med närmaste granne, kvantiserad mot spelets palett,
och bakgrunden borttagen. Det är efterbehandlingen som gör att 39 olika bilder ser ut som ETT
spel — modellen får bara bestämma formen.

    python3 tools/gen_art.py --only lash          # ett kort (första gången: billigt prov)
    python3 tools/gen_art.py --dry                # visa prompterna, rör inga pengar
    python3 tools/gen_art.py --all                # hela paketet
    python3 tools/gen_art.py --sheet              # kontaktkopia att döma kvaliteten på

Paletten och promptmallen ligger HÄR, inte i kortdatan: formen på konsten är en designfråga,
inte en kortegenskap.
"""
import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CARDS = ROOT / "game" / "data" / "cards"
OUT = ROOT / "game" / "assets" / "cards"

API = os.environ.get("OMNIROUTE_BASE_URL", "http://localhost:20128/v1")
KEY = os.environ.get("OMNIROUTE_API_KEY", "")
MODEL = os.environ.get("VC_ART_MODEL", "antigravity/gemini-3.1-flash-image")
## Flera rutter i kedja: taket (429) slår till snabbt när man batchar, och en modell som är
## limiterad ska inte stoppa körningen — nästa rutt tar kortet. Mätt: med bara en rutt blev
## 31 av 39 kort utan bild.
MODEL_CHAIN = [m for m in dict.fromkeys([
    MODEL,
    "gemini-3.1-flash-image",              # namnformen som rutten faktiskt svarar på
    "antigravity/gemini-3.1-flash-image",
    "openrouter/google/gemini-3.1-flash-image",
])]
SIZE = 64

## 16 färger, mörk och dov med varma accenter — samma hållning som referensens mätta skärmbilder.
## Paletten ligger i game/assets/palette.json och läses härifrån: generatorn och testet som
## granskar bilderna måste läsa SAMMA lista, annars driver de isär utan att någon märker det.
## Svart finns med som egen färg: konturen ska vara ett beslut, inte något som slank in.
PALETTE = [tuple(c) for c in json.loads((ROOT / "game" / "assets" / "palette.json").read_text())]

## Hur ett korts data blir en bildbeskrivning. Motiv nycklas på kortets EGNA ord (id, namn,
## nyckelord) först — annars blir "Ember Tome" en flaska, vilket den blev i första försöket.
MOTIF = {
    "attack": "a weapon striking",
    "item": "a worn protective charm",
    "mana": "a glass vial of glowing liquid",
    "wild": "a cracked chalk circle glowing",
    "crawler": "a small hooded companion creature",
}
## Objektet i namnet slår effekttypen: ett kort som heter Tome ska vara en bok.
OBJECT_WORDS = {
    "tome": "a heavy closed spellbook with a glowing clasp",
    "dagger": "a single dagger pointing up",
    "axe": "a broad battle axe",
    "lash": "a coiled leather whip",
    "bell": "a small brass hand bell",
    "lantern": "a hooded iron lantern",
    "ring": "a plain metal ring",
    "vial": "a small glass vial",
    "salve": "a small clay pot of ointment",
    "pebble": "a jagged stone",
    "knuckles": "a brass knuckle weapon",
    "hook": "a curved iron hook",
    "flail": "a spiked flail head on a chain",
    "hand": "an open hand",
    "draught": "a clay bottle of dark liquid",
    "chalk": "a chalk stub drawing a rune",
    "hourglass": "a brass hourglass",
    "choir": "a cracked funeral mask",
    "winter": "a shard of black ice",
    "ripper": "a thin curved seam ripper",
    "frost": "a single snowflake of ice",
    "arc": "a crackling arc of lightning",
    "veil": "a torn black veil",
    "rat": "a hooded rat companion",
    "claw": "a curved beast claw",
    "fang": "a long fang",
    "bone": "a bleached bone",
    "ember": "a burning ember",
}
CARD_ART = {
    "damage": "aggressive stance",
    "armor": "solid and defensive",
    "heal": "soft and warm",
    "draw": "knowledge, scrolls",
    "mana": "raw arcane energy",
}


def motif_for(card: dict) -> str:
    words = (card["id"] + " " + card.get("name", "")).lower()
    for key, desc in OBJECT_WORDS.items():
        if key in words:
            return desc
    return MOTIF.get(card.get("type", "item"), "an occult object")


def prompt_for(card: dict) -> str:
    hint = ""
    for eff in card.get("effects", []):
        if eff.get("op") in CARD_ART:
            hint = CARD_ART[eff["op"]]
            break
    keywords = ", ".join(card.get("keywords", []))
    return (
        f"Pixel art game icon, 16-bit, dark fantasy dungeon crawler. "
        f"Motif: {motif_for(card)}{', ' + hint if hint else ''}. "
        f"ONE isolated object, centered, filling most of the frame, clear readable silhouette. "
        f"1-pixel black outline around the whole object. Flat shading, no dithering, no gradients. "
        f"Palette: black, charcoal, ash grey, bone white, blood red, burnt orange, amber. "
        f"Background: one single flat magenta RGB(255,0,255) covering everything behind the object. "
        f"NO motion trails, NO slash effects, NO particles, NO glow, NO rays, NO text, NO frame, "
        f"no ground shadow, no orphan pixels. Crisp single-pixel detail, 64x64 sprite. "
        f"If the object is long and thin, angle it diagonally at 45 degrees so it fills the frame. "
        f"({card['name']}{', keywords: ' + keywords if keywords else ''})"
    )


def quantize(img: Image.Image) -> Image.Image:
    """Närmaste granne till 64x64 + palett + borttagen bakgrund. Ponytail: en global palett räcker
    så länge konsten är 16-bit; byt till per-kort-ramper om nyanserna blir för få."""
    img = img.convert("RGBA").resize((SIZE, SIZE), Image.NEAREST)
    rgb = img.convert("RGB")
    pal_img = Image.new("P", (1, 1))
    flat = [c for color in PALETTE for c in color]
    # Fyll resten av palettens 256 platser med den LJUSASTE färgen, inte med nollor: tomma
    # platser är svarta i PIL, och då kan kvantiseringen smyga in svart som inte finns i paletten.
    last = PALETTE[-1]
    pal_img.putpalette(flat + list(last) * ((768 - len(flat)) // 3))
    quant = rgb.quantize(palette=pal_img, dither=Image.NONE).convert("RGB")

    # bakgrunden: färgen i hörnet blir genomskinlig
    corner = quant.getpixel((0, 0))
    out = Image.new("RGBA", quant.size)
    px_in, px_out = quant.load(), out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            p = px_in[x, y]
            near = sum(abs(a - b) for a, b in zip(p, corner)) < 40
            px_out[x, y] = (0, 0, 0, 0) if near else (p[0], p[1], p[2], 255)
    return out


def normalize(img: Image.Image) -> Image.Image:
    """Beskär till objektet och skala upp med HELTAL så det fyller rutan. Utan det här hamnar
    varje ikon i olika storlek (mätt: yxan flöt litet till vänster i sin ruta) — modellen
    bestämmer formen, koden bestämmer ramen. Returnerar också hur stor del av rutan objektet tar."""
    bbox = img.getbbox()
    if bbox is None:
        return img
    obj = img.crop(bbox)
    if obj.width == 0 or obj.height == 0:
        return img
    scale = max(1, min(int(SIZE * 0.92 // obj.width), int(SIZE * 0.92 // obj.height)))
    obj = obj.resize((obj.width * scale, obj.height * scale), Image.NEAREST)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(obj, ((SIZE - obj.width) // 2, (SIZE - obj.height) // 2))
    return canvas


def fill_fraction(img: Image.Image) -> float:
    bbox = img.getbbox()
    if bbox is None:
        return 0.0
    return (bbox[2] - bbox[0]) * (bbox[3] - bbox[1]) / float(SIZE * SIZE)


def generate(card: dict, prompt: str, attempts: int = 3) -> tuple:
    """Returnerar (bild, modell). Provar rutterna i tur och ordning; en rutt som svarar 429
    får vänta en gång, sedan tar nästa rutt över."""
    body_base = {"prompt": prompt, "n": 1, "size": f"{SIZE}x{SIZE}", "response_format": "b64_json"}
    errors = []
    for model in MODEL_CHAIN:
        for attempt in range(attempts):
            body = json.dumps(dict(body_base, model=model)).encode()
            req = urllib.request.Request(
                f"{API}/images/generations", data=body,
                headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    payload = json.load(r)
                item = payload["data"][0]
                if item.get("b64_json"):
                    raw = base64.b64decode(item["b64_json"])
                else:
                    with urllib.request.urlopen(item["url"], timeout=120) as r:
                        raw = r.read()
                tmp = Path("/tmp/vc_art_raw.png")
                tmp.write_bytes(raw)
                return Image.open(tmp), model
            except urllib.error.HTTPError as e:
                reason = e.read()[:200].decode("utf-8", "replace")
                errors.append(f"{model}: HTTP {e.code} {reason}")
                if e.code != 429:
                    break                                   # annat fel: byt rutt direkt
                if "quota will reset after" in reason:
                    break            # veckokvot, inte ett tillfälligt tak: att vänta 12 s hjälper inte
                wait = 12 * (attempt + 1)
                print(f"  429 från {model}: väntar {wait}s", file=sys.stderr, flush=True)
                time.sleep(wait)
            except Exception as e:                          # timeout, DNS, skräpsvar
                errors.append(f"{model}: {type(e).__name__}: {e}")
                break
    # Alla rutters svar redovisas: annars ser ett slut på krediter ut som ett trasigt script.
    raise RuntimeError(" | ".join(errors) if errors else "ingen rutt svarade")


def cards_by_id() -> dict:
    out = {}
    for f in sorted(CARDS.glob("*.json")):
        for row in json.loads(f.read_text()):
            out[row["id"]] = row
    return out


def contact_sheet(ids: list) -> Path:
    cols = 8
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * SIZE, rows * SIZE), (18, 16, 22, 255))
    for i, cid in enumerate(ids):
        p = OUT / f"{cid}.png"
        if p.exists():
            sheet.alpha_composite(Image.open(p), ((i % cols) * SIZE, (i // cols) * SIZE))
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(OUT / "_contact_sheet.png")
    return OUT / "_contact_sheet.png"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--missing", action="store_true", help="bara kort som saknar bild (efter 429-strul)")
    ap.add_argument("--delay", type=float, default=4.0, help="paus mellan anropen, sekunder")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    cards = cards_by_id()
    if args.sheet:
        print(contact_sheet(sorted(cards)))
        return 0
    if not (args.only or args.all or args.missing):
        ap.error("välj --only <id>, --all, --missing eller --sheet")

    if args.missing:
        ids = sorted(cid for cid in cards if not (OUT / f"{cid}.png").exists())
    else:
        ids = sorted(cards) if args.all else [args.only]
    if args.limit:
        ids = ids[: args.limit]
    OUT.mkdir(parents=True, exist_ok=True)

    skrivna = 0
    missar = 0
    for cid in ids:
        if cid not in cards:
            print(f"hoppar över okänt kort: {cid}", file=sys.stderr)
            continue
        prompt = prompt_for(cards[cid])
        if args.dry:
            print(f"--- {cid}\n{prompt}\n")
            continue
        try:
            raw, model = generate(cards[cid], prompt)
            img = normalize(quantize(raw))
        except Exception as e:                          # nätet ska ge ett tydligt besked
            missar += 1
            print(f"FEL {cid}: {type(e).__name__}: {e}", file=sys.stderr, flush=True)
            ## Kvoten är slut, inte kortet: tre misslyckanden i rad betyder att resten bara
            ## bränner ~90 sekunder var på 429-väntor. Mätt: 27 kort kvar = 40 minuters tomgång
            ## efter att kvoten tog slut 06:47. Avbryt i stället och låt nästa körning ta resten.
            if missar >= 3:
                print(f"avbryter: {missar} kort i rad misslyckades, {len(ids) - skrivna - missar} kvar",
                      file=sys.stderr, flush=True)
                break
            continue
        skrivna += 1
        missar = 0
        img.save(OUT / f"{cid}.png")
        fill = fill_fraction(img)
        flag = "" if 0.15 <= fill <= 1.0 else "  ← för liten/tom, kolla bilden"
        print(f"skrev {(OUT / (cid + '.png')).relative_to(ROOT)}  ({model}, fyller {fill:.0%}){flag}",
              flush=True)
        if args.delay:
            time.sleep(args.delay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
