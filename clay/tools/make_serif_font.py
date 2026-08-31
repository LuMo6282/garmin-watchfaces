"""Generate a Connect IQ bitmap font from a system serif, subset to the
11 glyphs a clock needs: 0123456789 and colon.

Garmin takes BMFont's text .fnt plus a single-channel greyscale .png,
where white is the area that gets painted in whatever colour the app
sets. Subsetting to 11 glyphs is what keeps the sheet inside the watch
face memory cap — a full Latin set at this size would not fit.

    python tools/make_serif_font.py --size 168 --name serif_time
    python tools/make_serif_font.py --size 38  --name serif_small

Regenerate one size per screen resolution rather than scaling a bitmap
at runtime; scaled bitmap text looks visibly rough.
"""
import argparse, os
from PIL import Image, ImageFont, ImageDraw

# The clock only ever needs figures; the label font also carries the
# words the face sets (weekday, unit names) so the whole design sits on
# one typeface instead of mixing a serif time with Garmin's Roboto.
TIME = "0123456789:"
# The stat figures also set separators and unit marks, so they carry a
# little punctuation the time font has no use for, plus the 'k' that
# abbreviates a step count. A glyph missing from this set renders as a
# tofu box on the watch, not as nothing.
FIGURES = "0123456789:,. %°·k"
LABEL = (" ABCDEFGHIJKLMNOPQRSTUVWXYZ"
         "abcdefghijklmnopqrstuvwxyz"
         "0123456789.,:;'\"!?-–/()%°·+")
PAD = 2          # transparent gutter so neighbouring glyphs never bleed


def build(font_path, px, name, out_dir, tracking=0, glyphs=TIME):
    font = ImageFont.truetype(font_path, px)

    # Render each glyph tightly and remember where its ink sits relative
    # to the text origin, so the .fnt can put it back in the right place.
    cells = []
    for ch in glyphs:
        box = font.getbbox(ch)                     # (x0, y0, x1, y1)
        w, h = box[2] - box[0], box[3] - box[1]
        img = Image.new("L", (max(w, 1) + PAD * 2, max(h, 1) + PAD * 2), 0)
        ImageDraw.Draw(img).text((PAD - box[0], PAD - box[1]), ch, font=font, fill=255)
        advance = round(font.getlength(ch)) + tracking
        cells.append({
            "ch": ch, "img": img,
            "xoff": box[0], "yoff": box[1] - PAD,
            "adv": advance,
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
    # Digits sit on the baseline with no descender, so the line box is
    # kept tight to the ink. The renderers centre on getFontHeight() and
    # find the baseline with getFontAscent(); slack here becomes a
    # visible offset on the face.
    ink_top = min(c["yoff"] + PAD for c in cells)
    ink_bot = max(c["yoff"] + PAD + c["img"].size[1] - PAD * 2 for c in cells)
    base = ascent
    line_height = max(ink_bot, base) + 1

    png_name = f"{name}.png"
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, png_name), optimize=True)

    lines = [
        f'info face="{os.path.basename(font_path)}" size={px} bold=0 italic=0 '
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

    sample = sum(next(x for x in cells if x["ch"] == g)["adv"] for g in "11:08")
    print(f"{name}: {len(cells)} glyphs, sheet {sheet_w}x{sheet_h} "
          f"({sheet_w * sheet_h:,} px), base={base} lineHeight={line_height}, "
          f"'11:08' = {sample}px")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", default=r"C:\Windows\Fonts\pala.ttf")
    ap.add_argument("--size", type=int, required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--tracking", type=int, default=0)
    ap.add_argument("--out", default="resources/fonts")
    ap.add_argument("--glyphs", choices=("time", "figures", "label"), default="time",
                    help="time = 0-9 and ':'; figures = adds separators and "
                         "unit marks; label = full text set")
    a = ap.parse_args()
    build(a.font, a.size, a.name, a.out, a.tracking,
          {"time": TIME, "figures": FIGURES, "label": LABEL}[a.glyphs])
