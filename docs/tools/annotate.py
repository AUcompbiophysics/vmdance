"""The window's picture with its parts numbered (docs/_static/figures/
window_annotated.png), from capture.tcl's window.png and the places of the
parts it wrote (window_parts.txt: name x y width height, in pixels).

The numbers are in white margins beside the window, each joined to its
part's outline by a line, so that none covers a control. The quick-start
guide's picture is numbered the same way (quickstart-guide/annotate.py).

    python3 docs/tools/annotate.py <VMDANCE_OUT>/window_parts.txt
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FIGS = os.path.join(os.path.dirname(HERE), "_static", "figures")
# the order the docs number them in
ORDER = ["toolbar", "panes", "plots", "plot", "options", "readout", "status"]
# the side of the window each number is on: the parts along the left edge on
# the left, those of the plots' side on the right
SIDE = {"toolbar": "left", "panes": "left", "status": "left",
        "plots": "right", "options": "right", "plot": "right", "readout": "right"}
COLOUR = (163, 72, 59)
EDGE = (222, 222, 222)  # the window's edge on the white (the pages' hairline)
R = 15                  # a number's radius, in pixels
GAP = 14                # from a number to the window's edge
MARGIN = GAP + 2 * R + 8  # the white margin each side
PAD = 10                  # above and below the window
APART = 2 * R + 6         # the least distance between two numbers' centres


def font(size):
    for f in ("/usr/share/fonts/opentype/inter/Inter-Bold.otf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf", "/System/Library/Fonts/HelveticaNeue.ttc"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1) if f.endswith(".ttc") else ImageFont.truetype(f, size)
    return ImageFont.load_default()


def spread(wanted, least):
    """Centres as near the wanted ones (sorted) as can be, least apart: the
    numbers of thin rows next to each other (the plots' tabs and the plot's
    options) are moved apart, each group about its middle."""
    groups = []  # [first centre, count, sum of the wanted]
    for y in wanted:
        groups.append([y, 1, y])
        while len(groups) > 1:
            a, b = groups[-2], groups[-1]
            if a[0] + a[1] * least <= b[0]:
                break
            n, total = a[1] + b[1], a[2] + b[2]
            groups[-2:] = [[total / n - (n - 1) * least / 2, n, total]]
    return [g[0] + k * least for g in groups for k in range(g[1])]


def round_corners(img, r=6):
    """The corners that show what was under the window made transparent:
    Windows 11 rounds the window's bottom corners, and the capture copies
    the screen's area. A corner is rounded only where its pixel is far from
    the window's colour beside it (the top corners here are square)."""
    w, h = img.size
    big = Image.new("L", (4 * w, 4 * h), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, 4 * w - 1, 4 * h - 1], radius=4 * r, fill=255)
    mask = big.resize((w, h), Image.LANCZOS)
    rgb = img.convert("RGB")
    for (cx, cy), (ix, iy) in (((0, 0), (r, r)), ((w - 1, 0), (w - 1 - r, r)),
                               ((0, h - 1), (r, h - 1 - r)), ((w - 1, h - 1), (w - 1 - r, h - 1 - r))):
        if max(abs(p - q) for p, q in zip(rgb.getpixel((cx, cy)), rgb.getpixel((ix, iy)))) < 60:
            mask.paste(255, (min(cx, ix), min(cy, iy), max(cx, ix) + 1, max(cy, iy) + 1))
    img.putalpha(ImageChops.darker(img.getchannel("A"), mask))
    return img


def main(parts_file):
    parts = {}
    with open(parts_file) as fh:
        for line in fh:
            w = line.split()
            if len(w) == 5:
                parts[w[0]] = tuple(int(v) for v in w[1:])
    # (3) is the plots' tabs: the row above the plot's options, not the
    # whole notebook (which held (4) and (5) inside its outline)
    if "plots" in parts and "options" in parts:
        x, y, w, h = parts["plots"]
        parts["plots"] = (x, y, w, parts["options"][1] - y)
    img = round_corners(Image.open(os.path.join(FIGS, "window.png")).convert("RGBA"))
    m = MARGIN
    canvas = Image.new("RGB", (img.width + 2 * m, img.height + 2 * PAD), (255, 255, 255))
    canvas.paste(img, (m, PAD), img)
    over = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle([m - 1, PAD - 1, m + img.width, PAD + img.height], outline=EDGE + (255,))
    f = font(18)
    ink = COLOUR + (235,)
    # each part: its outline, the middle of its edge on its side (where its
    # line ends, with a dot), and its number's place in the margin
    marks = []
    for i, name in enumerate(ORDER, 1):
        if name not in parts:
            continue
        x, y, w, h = parts[name]
        x += m
        y += PAD
        d.rounded_rectangle([x + 1, y + 1, x + w - 2, y + h - 2], radius=5, outline=ink, width=2)
        edge = x + 2 if SIDE[name] == "left" else x + w - 3
        marks.append((SIDE[name], y + h / 2, edge, i))
    for side in ("left", "right"):
        these = sorted(k for k in marks if k[0] == side)
        if side == "left":
            cx, out_x = m - GAP - R, m - 5
        else:
            cx, out_x = m + img.width + GAP + R, m + img.width + 4
        for (_, py, edge, i), cy in zip(these, spread([k[1] for k in these], APART)):
            # straight out of the window, then to the number (bent only where
            # it was moved)
            d.line([(edge, py), (out_x, py), (cx, cy)], fill=ink, width=2, joint="curve")
            d.ellipse([edge - 3, py - 3, edge + 3, py + 3], fill=ink)
            d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=COLOUR + (255,))
            d.text((cx, cy), str(i), font=f, fill=(255, 255, 255, 255), anchor="mm")
    out = Image.alpha_composite(canvas.convert("RGBA"), over).convert("RGB")
    out.save(os.path.join(FIGS, "window_annotated.png"), optimize=True)
    print("wrote window_annotated.png")


if __name__ == "__main__":
    main(sys.argv[1])
