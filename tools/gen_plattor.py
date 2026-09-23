"""Rumsplattor: miljöbilder från en extern bildmodell, per tema, med samma efterbehandling och samma
grindar som rutorna.

VARFÖR PLATTOR OCH INTE RUTOR. Mätt i research/09: referensen har 14 fasta rumsplattor per biom och
rut-prefabs i 33-51 varianter — upprepningen sker på rumsskalan, inte på rutskalan. Våra rutor är
32x32 px per 0,5 m (64 px/m) mot Grimrocks 1024 px per 3x3 m (341 px/m), alltså sex gånger tätare
upprepning, och M21-M23 visade att fler varianter inte botar det: generatorn MÅLAR en oval båge i
varje ruta, och en igenkännbar form som upprepas är det ögat låser på.

En platta är 4x4 m i en enda bild (1 px = 3 cm). Inom ett rum finns då INGEN upprepning alls.

KVOTEN. Bildmodellen ger ca 9 bilder per 5 timmar (mätt: 429 på båda gemini-rutterna, 402 på
OpenRouter utan köpta krediter). Fem teman x 3 plattor = 15 bilder = två kvotfönster. Därför är
verktyget byggt för att köras om och om: det hoppar över plattor som redan finns och redovisar vad
som återstår. Kör `--torrkörning` först.

    python3 tools/gen_plattor.py --torrkörning     # plan + kvotläge, hämtar inget
    python3 tools/gen_plattor.py --granska FIL     # kör grindarna på en befintlig bild
    python3 tools/gen_plattor.py --tema grotta     # hämta det som saknas för ett tema
"""
import argparse
import base64
import io
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import gen_art  # anslutning, modellkedja och palett — samma fil som korten använder

ROOT = Path(__file__).resolve().parent.parent
UT = ROOT / "game" / "assets" / "plattor"
PLATTA = 512      # modellens bild
# Spelets storlek. 512, inte 128: en platta är 4x4 m, alltså 128 px/m — samma täthet som rutorna
# får när de går från 32 till 64 px per 0,5 m. Att skala ned modellens 512 till 128 gav 32 px/m,
# alltså HALVA ruttätheten, och en platta som är slöare än rutorna den ska ersätta är ingen vinst.
# Vid 512 behövs ingen omskalning alls: modellen ritar i exakt den storlek spelet vill ha.
SLUT = 512

## Instruktionen om nivån. Det som står sist i varje rad är dagens mätning omsatt i ord: inga motiv.
## "no distinct shapes" är inte smaksak — det är kravet som M23 visade att generatorn bröt mot.
GEMENSAMT = ("seamless tileable texture, flat top-down view, pixel art, 16 colour dark palette, "
             "evenly lit, no shadows, no light sources, no objects, no distinct shapes, no symbols, "
             "no border, no frame, no vignette, no text")
TEMA_PROMPT = {
    "asklunden": "ash grove floor of soot-blackened flagstones with grey ash drifts and a few charred "
                 "twigs, cold grey light",
    "krypta":    "crypt floor of old grey stone slabs with mortar lines, dust in the seams, faint "
                 "reddish rust stains",
    "grotta":    "cave floor, dark grey wet limestone with fine grit and small rounded pebbles",
    "tunnel":    "packed dirt floor of a mine tunnel with scattered gravel and a few dry straw "
                 "strands, brown and ochre",
    "bro":       "worn wooden bridge decking seen from above, boards along the length, gaps between "
                 "boards showing darkness below, splinters and nail heads",
}

## Grindarna. Samma två som gen_tiles.py använder för rutor (skarv mot inre kant, ljushet), plus en
## tredje som rutorna inte hade och som hade fångat dagens fel: största sammanhängande FLÄCK.
## En ruta som målar en oval båge ger en stor fläck; en ruta med bara korn ger små.
SKARV_ÖVER = 2.0     # skarven får sticka så många gråsteg över rutans egen värsta inre kant
FLÄCK_TAK = 0.06     # största sammanhängande fläck i andel av plattan


def hämta(prompt: str) -> tuple:
    """Returnerar (bild, modell). Rutorna i kedjan provas i tur och ordning: en kvot som är slut
    (429) eller en rutt utan krediter (402) ska inte stoppa körningen."""
    for model in gen_art.MODEL_CHAIN:
        body = {"prompt": prompt, "n": 1, "size": f"{PLATTA}x{PLATTA}", "response_format": "b64_json"}
        req = urllib.request.Request(
            f"{gen_art.API}/images/generations",
            data=json.dumps(dict(body, model=model)).encode(),
            headers={"Authorization": f"Bearer {gen_art.KEY}", "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                svar = json.load(r)
        except urllib.error.HTTPError as e:
            print("      rutt %-46s HTTP %s" % (model, e.code))
            continue
        except Exception as e:
            print("      rutt %-46s %s" % (model, e))
            continue
        poster = svar.get("data") or svar.get("images") or []
        if not poster:
            print("      rutt %-46s tomt svar" % model)
            continue
        if poster[0].get("b64_json"):
            return Image.open(io.BytesIO(base64.b64decode(poster[0]["b64_json"]))), model
        with urllib.request.urlopen(poster[0]["url"], timeout=120) as r:
            return Image.open(io.BytesIO(r.read())), model
    raise RuntimeError("ingen rutt svarade (kvot eller krediter)")


def kvantisera(img: Image.Image) -> Image.Image:
    """Närmaste granne till spelstorleken + palett, samma väg som korten (tools/gen_art.py) men utan
    bakgrundsborttagning: en platta är ogenomskinlig."""
    img = img.convert("RGB").resize((SLUT, SLUT), Image.NEAREST)
    pal = Image.new("P", (1, 1))
    flat = [k for c in gen_art.PALETTE for k in c]
    pal.putpalette(flat + list(gen_art.PALETTE[-1]) * ((768 - len(flat)) // 3))
    return img.quantize(palette=pal, dither=Image.NONE).convert("RGB")


def gör_sömlös(img: Image.Image) -> Image.Image:
    """Rullar ett halvt varv och smälter sömmen några pixlar. Billigare än att be modellen om
    sömlöshet, och den går att mäta direkt: efteråt ska kanten se ut som en kant inuti bilden."""
    a = np.asarray(img, dtype=float)
    a = np.roll(np.roll(a, a.shape[0] // 2, 0), a.shape[1] // 2, 1)
    for _ in range(4):
        a[0] = (a[0] + a[-1] + a[1]) / 3
        a[-1] = (a[-1] + a[-2] + a[0]) / 3
        a[:, 0] = (a[:, 0] + a[:, -1] + a[:, 1]) / 3
        a[:, -1] = (a[:, -1] + a[:, -2] + a[:, 0]) / 3
    return Image.fromarray(a.astype(np.uint8))


def största_fläck(indices: np.ndarray) -> float:
    """Största sammanhängande område av EN palettfärg, i andel av plattan.

    Det här är dagens fel mätt i stället för tyckt: en ruta som målar en oval båge får en stor fläck,
    en ruta med bara korn får små. Fyra grannar (inte åtta) — en diagonal rad av enstaka pixlar är
    korn, inte en form.
    """
    h, w = indices.shape
    sedd = np.zeros((h, w), dtype=bool)
    störst = 0
    for y0 in range(h):
        for x0 in range(w):
            if sedd[y0, x0]:
                continue
            färg = indices[y0, x0]
            stack, storlek = [(y0, x0)], 0
            sedd[y0, x0] = True
            while stack:
                y, x = stack.pop()
                storlek += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and not sedd[ny, nx] and indices[ny, nx] == färg:
                        sedd[ny, nx] = True
                        stack.append((ny, nx))
            störst = max(störst, storlek)
    return störst / float(h * w)


def granska(img: Image.Image, namn: str = "") -> dict:
    grå = np.asarray(img.convert("L"), dtype=float)
    kant = float(np.mean(np.abs(grå[0] - grå[-1])) + np.mean(np.abs(grå[:, 0] - grå[:, -1]))) / 2
    inre = float(np.mean(np.abs(grå[1:] - grå[:-1])) + np.mean(np.abs(grå[:, 1:] - grå[:, :-1]))) / 2
    # Färgindex per pixel: palettens närmaste färg. Fläckmåttet ska handla om FÄRG, inte ljushet —
    # två närliggande gråa toner är korn, men en sammanhängande fläck av samma färg är en form.
    pix = np.asarray(img.convert("RGB"), dtype=int).reshape(-1, 3)
    pal = np.array(gen_art.PALETTE)
    index = (((pix[:, None, :] - pal[None, :, :]) ** 2).sum(2)).argmin(1).reshape(grå.shape)
    fläck = största_fläck(index)
    ut = {"namn": namn, "skarv": round(kant, 2), "inre_kant": round(inre, 2),
          "ljushet": round(float(grå.mean()), 1), "fläck": round(fläck, 4),
          "ok": kant <= inre + SKARV_ÖVER and 12 < float(grå.mean()) < 200 and fläck <= FLÄCK_TAK}
    print("  %-28s %s  skarv %5.2f/%5.2f  ljushet %5.1f  största fläck %5.2f %%"
        % (namn, "ok " if ut["ok"] else "FEL", kant, inre, ut["ljushet"], fläck * 100))
    return ut


def torrkörning() -> int:
    print("plattor: %d teman x 3 ytor = %d bilder (1 golv, 1 vägg, 1 tak/bakgrund per tema)"
        % (len(TEMA_PROMPT), len(TEMA_PROMPT) * 3))
    saknas = []
    for tema in TEMA_PROMPT:
        for yta in ("golv", "vägg", "bakgrund"):
            if not (UT / tema / f"{yta}.png").exists():
                saknas.append(f"{tema}/{yta}")
    print("finns: %d, saknas: %d %s" % (len(TEMA_PROMPT) * 3 - len(saknas), len(saknas),
        ("(t.ex. %s)" % ", ".join(saknas[:3])) if saknas else ""))
    if not gen_art.KEY:
        print("FEL: OMNIROUTE_API_KEY är inte satt — ingen bild kan hämtas")
        return 1
    try:
        req = urllib.request.Request(f"{gen_art.API}/models",
            headers={"Authorization": f"Bearer {gen_art.KEY}"})
        with urllib.request.urlopen(req, timeout=10) as r:
            print("bildrutt: svarar %s" % r.status)
    except urllib.error.HTTPError as e:
        print("bildrutt: HTTP %s (429 = kvoten är slut just nu, 401 = nyckeln)" % e.code)
    except Exception as e:
        print("bildrutt: %s" % e)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--torrkörning", action="store_true", help="plan och kvotläge, hämtar inget")
    ap.add_argument("--granska", metavar="FIL", help="kör grindarna på en befintlig bild")
    ap.add_argument("--tema", help="hämta det som saknas för ett tema")
    ap.add_argument("--yta", default="golv", choices=["golv", "vägg", "bakgrund"])
    args = ap.parse_args()
    if args.torrkörning:
        return torrkörning()
    if args.granska:
        granska(Image.open(args.granska), Path(args.granska).name)
        return 0
    teman = [args.tema] if args.tema else list(TEMA_PROMPT)
    for tema in teman:
        if tema not in TEMA_PROMPT:
            print("okänt tema: %s" % tema)
            return 1
        ut = UT / tema / f"{args.yta}.png"
        if ut.exists():
            print("  %s/%s finns redan" % (tema, args.yta))
            continue
        print("  hämtar %s/%s ..." % (tema, args.yta))
        try:
            rå, model = hämta("%s, %s" % (TEMA_PROMPT[tema], GEMENSAMT))
        except RuntimeError as e:
            print("  avbrutet: %s" % e)
            return 1
        platta = gör_sömlös(kvantisera(rå))
        ut.parent.mkdir(parents=True, exist_ok=True)
        platta.save(ut)
        print("  %s (%s)" % (ut.relative_to(ROOT), model))
        if not granska(platta, f"{tema}/{args.yta}")["ok"]:
            trasig = ut.with_suffix(".fel.png")
            ut.rename(trasig)
            print("  flyttad till %s — en platta som inte klarar grindarna får inte ligga i spelet"
                % trasig.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
