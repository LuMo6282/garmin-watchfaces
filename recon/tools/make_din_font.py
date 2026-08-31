"""Generate a Connect IQ bitmap font from Bahnschrift, subset to what the
face actually sets.

Bahnschrift is Windows' cut of DIN 1451 - the German industrial standard
face used on road signs, vehicle plates and equipment panels. That is the
whole reason it is here: it carries the engineered, issued look this face
wants, where Clay's Calibri carries a soft humanist one.

It is a VARIABLE font with two axes, Weight 300-700 and Width 75-100, so
the weight and the condensation are dialled rather than picked from a
handful of shipped cuts:

    python tools/make_din_font.py --name din_time --size 104 \
        --weight 600 --width 75 --glyphs time --tabular

Regenerate one size per screen resolution rather than scaling a bitmap at
runtime; scaled bitmap text looks visibly rough.
"""
import argparse, os
from PIL import Image, ImageFont, ImageDraw

FONT = r"C:\Windows\Fonts\bahnschrift.ttf"

# A glyph missing from a subset renders as a TOFU BOX on the watch, not
# as nothing, so each set is drawn from what the renderer can actually
# emit rather than from what looks sufficient.
TIME = "0123456789:"
# The row figures set a decimal point and the 'K' that abbreviates a step
# count. Upper case K, because every abbreviation on this face is caps.
FIGURES = "0123456789.,:%°·K-+/"
# Upper case only. Nothing on this face is set in lower case, so half the
# alphabet would be sheet area paying no rent.
LABEL = (" ABCDEFGHIJKLMNOPQRSTUVWXYZ"
         "0123456789.,:;'\"!?-/()%°·+")
SETS = {"time": TIME, "figures": FIGURES, "label": LABEL}

DIGITS = "0123456789"
PAD = 2          # transparent gutter so neighbouring glyphs never bleed


def build(px, name, out_dir, weight, width, tracking=0, glyphs=TIME, tabular=False):
    font = ImageFont.truetype(FONT, px)
    font.set_variation_by_axes([weight, width])

    # Tabular figures: every digit gets the same advance and is centred
    # in it. Bahnschrift is proportional by default - '1' is 32 units
    # against '4' at 52 - so a clock set in it visibly reshuffles as the
    # minute rolls. On a readout face the digits have to sit still.
    cell = 0
    if tabular:
        cell = max(round(font.getlength(d)) for d in DIGITS if d in glyphs)

    cells = []
    for ch in glyphs:
        box = font.getbbox(ch)                     # (x0, y0, x1, y1)
        w, h = box[2] - box[0], box[3] - box[1]
        img = Image.new("L", (max(w, 1) + PAD * 2, max(h, 1) + PAD * 2), 0)
        ImageDraw.Draw(img).text((PAD - box[0], PAD - box[1]), ch, font=font, fill=255)

        advance = round(font.getlength(ch))
        shift = 0
        if tabular and ch in DIGITS:
            shift = (cell - advance) // 2          # centre it in the cell
            advance = cell
        cells.append({
            "ch": ch, "img": img,
            "xoff": box[0] + shift, "yoff": box[1] - PAD,
            "adv": advance + tracking,
        })

    # Shelf-pack into the squarest power-of-two sheet that fits.
    sheet_w = 256
    while True:
        placed, x, y, row_h, ok = [], 0, 0, 0, True
        for c in cells:
            cw, ch_ = c["img"].size
            if cw > sheet_w:
                ok = False
                break
            if x + cw > sheet_w:
                x, y, row_h = 0, y + row_h, 0
            placed.append((c, x, y))
            x += cw
            row_h = max(row_h, ch_)
        if ok and (y + row_h) <= sheet_w * 2:
            sheet_h = y + row_h
            break
        sheet_w *= 2
        if sheet_w > 4096:
            raise SystemExit("glyphs will not pack; pick a smaller --size")

    sheet = Image.new("L", (sheet_w, sheet_h), 0)
    for c, x, y in placed:
        sheet.paste(c["img"], (x, y))

    ascent, descent = font.getmetrics()
    # The renderers centre on getFontHeight() and find the baseline with
    # getFontAscent(); slack in the line box becomes a visible offset on
    # the face, so it is kept tight to the ink.
    ink_bot = max(c["yoff"] + PAD + c["img"].size[1] - PAD * 2 for c in cells)
    base = ascent
    line_height = max(ink_bot, base) + 1

    png_name = f"{name}.png"
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, png_name), optimize=True)

    lines = [
        f'info face="bahnschrift" size={px} bold=0 italic=0 '
        f'charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={line_height} base={base} scaleW={sheet_w} scaleH={sheet_h} "
        f"pages=1 packed=0",
        f'page id=0 file="{png_name}"',
        f"chars count={len(cells)}",
    ]
    for c, x, y in placed:
        cw, ch_ = c["img"].size
        lines.append(
            f"char id={ord(c['ch'])} x={x} y={y} width={cw} height={ch_} "
            f"xoffset={c['xoff'] - PAD} yoffset={c['yoff']} xadvance={c['adv']} page=0 chnl=15"
        )
    with open(os.path.join(out_dir, f"{name}.fnt"), "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")

    cap = font.getbbox("8" if "8" in glyphs else "H")
    sample = "".join(g for g in "14:37" if g in glyphs)
    width_px = sum(next(c for c in cells if c["ch"] == g)["adv"] for g in sample)
    print(f"{name}: {len(cells)} glyphs, sheet {sheet_w}x{sheet_h} "
          f"({sheet_w * sheet_h:,} px), cap={cap[3] - cap[1]}, base={base}, "
          f"lineHeight={line_height}, '{sample}' = {width_px}px")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--weight", type=int, default=400)     # 300-700
    ap.add_argument("--width", type=int, default=100)      # 75-100
    ap.add_argument("--tracking", type=int, default=0)
    ap.add_argument("--tabular", action="store_true")
    ap.add_argument("--out", default="resources/fonts")
    ap.add_argument("--glyphs", choices=tuple(SETS), default="time")
    a = ap.parse_args()
    build(a.size, a.name, a.out, a.weight, a.width,
          tracking=a.tracking, glyphs=SETS[a.glyphs], tabular=a.tabular)
