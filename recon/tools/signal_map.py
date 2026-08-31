"""Render screenshots/signal-map.png - every colour the face can show,
which status raises it, and its hex.

The values are PARSED OUT OF source/Theme.mc rather than written here.
A palette sheet that keeps its own copy of the numbers is a second source
of truth and is wrong the first time anyone edits the theme, which is
exactly when you would be looking at it.

    python tools/signal_map.py
"""
import io
import re

from PIL import Image, ImageDraw, ImageFont

THEME = "source/Theme.mc"
OUT = "screenshots/signal-map.png"
FONT = r"C:\Windows\Fonts\bahnschrift.ttf"

# Which statuses each signal covers. The grouping lives in Theme.signal()
# as control flow, which cannot be read out of the source without running
# it, so this list is the one thing here that must be kept in step by
# hand - check it against Theme.signal() if the mapping ever changes.
SIGNALS = [
    ("NOMINAL", "AMBER", "AMBER_DIM",
     ["OD_LIT", "OD", "OD_DEEP", "GROUND"],
     ["NO STATUS", "MAINTAINING", "PRODUCTIVE", "PEAKING"],
     "the system is doing its job", "olive drab"),
    ("STANDBY", "STANDBY", "STANDBY_DIM",
     ["SAND_LIT", "SAND", "SAND_DEEP", "GROUND_SND"],
     ["RECOVERY", "DETRAINING", "UNPRODUCTIVE"],
     "the system is deliberately idling", "warm sand"),
    ("WARNING", "WARN", "WARN_DIM",
     ["GUN_LIT", "GUN", "GUN_DEEP", "GROUND_GUN"],
     ["STRAINED", "OVERREACHING"],
     "the system is past a limit", "cool gunmetal"),
]

# Shared across all three families. These never move.
SHARED = [
    ("BONE", "readout figures"),
    ("BONE_DIM", "sun time"),
    ("AMBIENT", "always-on time"),
]

def load_theme():
    src = io.open(THEME, encoding="utf-8").read()
    return {m.group(1): int(m.group(2), 16)
            for m in re.finditer(r"const\s+(\w+)\s*=\s*0x([0-9A-Fa-f]{6})", src)}


def rgb(n):
    return ((n >> 16) & 255, (n >> 8) & 255, n & 255)


def face(px, weight=500, width=78):
    f = ImageFont.truetype(FONT, px)
    f.set_variation_by_axes([weight, width])
    return f


def main():
    C = load_theme()
    h1, h2 = face(34, 600, 75), face(20, 600, 78)
    body, mono = face(19), face(17, 400, 85)

    W = 1000
    im = Image.new("RGB", (W, 1500), rgb(C["GROUND"]))
    d = ImageDraw.Draw(im)

    y = 42
    d.text((48, y), "RECON - SIGNAL MAP", font=h1, fill=rgb(C["BONE"]))
    y += 46
    d.text((48, y), "nine training statuses, three signals, three structure families",
           font=body, fill=rgb(C["OD_LIT"]))
    y += 52

    for name, lit, dim, family, statuses, gloss, famname in SIGNALS:
        d.rectangle([48, y, 300, y + 44], fill=rgb(C[lit]))
        d.rectangle([308, y, 388, y + 44], fill=rgb(C[dim]))
        d.text((410, y + 2), name, font=h2, fill=rgb(C[lit]))
        d.text((410, y + 26), gloss, font=mono, fill=rgb(C["OD"]))
        y += 54
        d.text((48, y), "0x%06X  lit" % C[lit], font=mono, fill=rgb(C[lit]))
        d.text((308, y), "0x%06X  spent lap" % C[dim], font=mono,
               fill=rgb(C["BONE_DIM"]))
        y += 32
        for st in statuses:
            d.rectangle([68, y + 8, 76, y + 16], fill=rgb(C[lit]))
            d.text((92, y), st, font=body, fill=rgb(C[lit]))
            y += 28

        # The structure paired with this signal. Structure opposes the
        # signal's temperature, so each family is listed against the
        # signal it serves rather than once for the whole face.
        y += 10
        d.text((68, y), "structure - " + famname, font=mono,
               fill=rgb(C[family[1]]))
        y += 26
        x = 68
        for key in family:
            d.rectangle([x, y, x + 96, y + 24], fill=rgb(C[key]),
                        outline=rgb(C["OD_DEEP"]))
            d.text((x, y + 30), "0x%06X" % C[key], font=mono,
                   fill=rgb(C["BONE_DIM"]))
            x += 108
        y += 74

    d.line([48, y, W - 48, y], fill=rgb(C["OD_DEEP"]), width=1)
    y += 26
    d.text((48, y), "SHARED - the same in every state", font=h2,
           fill=rgb(C["OD_LIT"]))
    y += 38
    for key, use in SHARED:
        d.rectangle([48, y, 200, y + 26], fill=rgb(C[key]),
                    outline=rgb(C["OD_DEEP"]))
        d.text((216, y + 3), "0x%06X" % C[key], font=mono, fill=rgb(C["BONE_DIM"]))
        d.text((340, y + 3), use, font=mono, fill=rgb(C["OD"]))
        y += 34

    im.crop((0, 0, W, y + 34)).save(OUT)
    print("%s written from %s (%d constants)" % (OUT, THEME, len(C)))


if __name__ == "__main__":
    main()
