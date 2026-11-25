"""The window's picture with its parts numbered, and the 3D view cropped to
the molecule, for the guide.

figures/window_annotated.png, from figures.tcl's window.png and
window_parts.txt (name x y width height, in Tk's points; the first line is
the window's own size). The picture can be larger than the points (a Retina
screen's two pixels a point) and taller (the title bar macOS adds above
Tk's window): both are measured from it. The numbers, and where they are,
are those of the online documentation's picture (docs/tools/annotate.py):
in white margins beside the window, each joined to its part's outline by a
line, so that none covers a control.

figures/main_3d.png, VMD's render of the representatives, is cropped to what
is drawn on its white background, with a margin: the representatives differ
with every clustering, and so does where they are.

    python3 annotate.py figures
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

ORDER = ["toolbar", "panes", "plots", "plot", "options", "readout", "status"]
# the side of the window each number is on: the parts along the left edge on
# the left, those of the plots' side on the right
SIDE = {"toolbar": "left", "panes": "left", "status": "left",
        "plots": "right", "options": "right", "plot": "right", "readout": "right"}
COLOUR = (163, 72, 59)
WINDOW = 1600  # the window's width in the guide's file, in pixels (the margins apart)
R = 15         # a number's radius, in Tk's points
GAP = 14       # from a number to the window's edge
MARGIN = GAP + 2 * R + 8  # the white margin each side
APART = 2 * R + 6         # the least distance between two numbers' centres


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


def font(size):
    for f in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size, index=1) if f.endswith(".ttc") else ImageFont.truetype(f, size)
            except OSError:
                return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def crop_3d(path, margin=20):
    img = Image.open(path).convert("RGB")
    box = ImageChops.difference(img, Image.new("RGB", img.size, (255, 255, 255))).getbbox()
    if box is None:
        return
    l, t, r, b = box
    box = (max(0, l - margin), max(0, t - margin), min(img.width, r + margin), min(img.height, b + margin))
    if box != (0, 0, img.width, img.height):
        img.crop(box).save(path, optimize=True)
        print("cropped", path, "to", box)


def main(folder):
    if os.path.exists(os.path.join(folder, "main_3d.png")):
        crop_3d(os.path.join(folder, "main_3d.png"))
    if not os.path.exists(os.path.join(folder, "window_parts.txt")):
        return
    parts = {}
    with open(os.path.join(folder, "window_parts.txt")) as fh:
        for line in fh:
            w = line.split()
            if len(w) == 5:
                parts[w[0]] = tuple(int(v) for v in w[1:])
    # (3) is the plots' tabs: the row above the plot's options, not the
    # whole notebook (which held (4) and (5) inside its outline)
    if "plots" in parts and "options" in parts:
        x, y, w, h = parts["plots"]
        parts["plots"] = (x, y, w, parts["options"][1] - y)
    # the window's rounded corners are transparent: on the page's white
    img = Image.open(os.path.join(folder, "window.png")).convert("RGBA")
    tw, th = parts["window"][2], parts["window"][3]
    s = img.width / tw
    top = img.height - th * s  # the title bar above Tk's window
    # the numbers go in white margins left and right of the window, each
    # joined by a short line to its part's outline: none is drawn over the
    # window's controls
    m = round(MARGIN * s)
    pad = round((R + 4) * s)  # below the window, for the status line's number
    canvas = Image.new("RGB", (img.width + 2 * m, img.height + pad), (255, 255, 255))
    canvas.paste(img, (m, 0), img)
    over = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    f = font(round(18 * s))
    ink = COLOUR + (235,)
    line = round(2 * s)
    # each part: its outline, the middle of its edge on its side (where its
    # line ends, with a dot), and its number's place in the margin
    marks = []
    for i, name in enumerate(ORDER, 1):
        if name not in parts:
            continue
        x, y, w, h = (v * s for v in parts[name])
        x += m
        y += top
        d.rounded_rectangle([x + s, y + s, x + w - s, y + h - s], radius=5 * s, outline=ink, width=line)
        edge = x + 1.5 * s if SIDE[name] == "left" else x + w - 1.5 * s
        marks.append((SIDE[name], y + h / 2, edge, i))
    for side in ("left", "right"):
        these = sorted(k for k in marks if k[0] == side)
        if side == "left":
            cx, out_x = m - (GAP + R) * s, m - 4 * s
        else:
            cx, out_x = m + img.width + (GAP + R) * s, m + img.width + 4 * s
        for (_, py, edge, i), cy in zip(these, spread([k[1] for k in these], APART * s)):
            # straight out of the window, then to the number (bent only where
            # it was moved)
            d.line([(edge, py), (out_x, py), (cx, cy)], fill=ink, width=line, joint="curve")
            d.ellipse([edge - 3 * s, py - 3 * s, edge + 3 * s, py + 3 * s], fill=ink)
            d.ellipse([cx - R * s, cy - R * s, cx + R * s, cy + R * s], fill=COLOUR + (255,))
            d.text((cx, cy), str(i), font=f, fill=(255, 255, 255, 255), anchor="mm")
    out = Image.alpha_composite(canvas.convert("RGBA"), over).convert("RGB")
    width = round(WINDOW * out.width / img.width)
    if out.width > width:
        out = out.resize((width, round(out.height * width / out.width)), Image.LANCZOS)
    out.save(os.path.join(folder, "window_annotated.png"), optimize=True)
    print("wrote", os.path.join(folder, "window_annotated.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "figures")
