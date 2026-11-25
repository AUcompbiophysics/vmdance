#!/usr/bin/env python3
"""Make VMDance's logos from the design's two SVGs: the wordmark
(docs/_static/logo/vmdance.svg) and the stacked logo (vmdance_stacked.svg),
both for a light background. They hold outlines, not text: they need no
font to show.

The logo is a mark of nine tiles and "vmdance" with v, m and d in red, green
and blue (VMD's three letters, as VMD's title is coloured) and "ance" in
navy. This script writes, in docs/_static/logo/:

- vmdance_dark.svg and vmdance_stacked_dark.svg: the same for a dark
  background ("ance" light);
- vmdance_mark.svg: the tiles alone, on a square;
- vmdance_card.svg: the wordmark on a white card, for the README's viewers
  that do not choose the dark copy by the theme (GitHub's dark theme with
  the computer's light, an app's preview): legible on any background, and
  the card unseen on a white page;
- PNGs of each (the docs' favicon is vmdance_mark_64.png; the quick-start
  guide's title page is vmdance_stacked.png);

and the window's icon, vmdance/icons/app_{16,24,32}.png with their dimmed
copies. The PNGs are drawn from the outlines with Pillow (no cairo needed).

It also makes the logo of each algorithm shown beside Setup's chooser,
vmdance/icons/algo_<algorithm>_{24,32}.png (24 and 32 px tall, the toolbar's
icon sizes) and their dimmed copies, from MDANCE's logos in
docs/_static/mdance/.

    python3 docs/tools/make_logo.py      (from the repository's root)
"""
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "docs" / "_static" / "logo"
MDANCE = ROOT / "docs" / "_static" / "mdance"
ICONS = ROOT / "vmdance" / "icons"
# the plugin's algorithms, and MDANCE's logo of each
ALGORITHMS = {"kmeans": "nani", "divine": "divine", "helm": "helm", "equal": "equal"}

# the ink of "ance", and what it is on a dark background
NAVY, LIGHT = "#0e1328", "#f2f2f2"


def read(name):
    """An SVG of the design: its width, height and paths [(fill, d)]."""
    text = (LOGO / name).read_text()
    _, _, w, h = (float(v) for v in re.search(r'viewBox="([^"]+)"', text).group(1).split())
    paths = re.findall(r'<path fill="(#[0-9a-fA-F]{6})" d="([^"]+)"\s*/>', text)
    if not paths:
        raise ValueError(f"{name}: no paths read")
    return w, h, paths


def bounds(paths):
    pts = [p for _, d in paths for c in _contours(d) for p in c]
    return min(x for x, _ in pts), min(y for _, y in pts), max(x for x, _ in pts), max(y for _, y in pts)


def svg(box, paths, title="VMDance"):
    x, y, w, h = box
    body = "".join(f'<path fill="{f}" d="{d}"/>\n' for f, d in paths)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:g} {y:g} {w:g} {h:g}" '
            f'width="{w:g}" height="{h:g}">\n<title>{title}</title>\n{body}</svg>\n')


def card(box, paths, pad=200, radius=180):
    """The paths on a white card, pad about what is drawn, in the same box
    (the same size as the other copies where a page sets the width)."""
    x, y, w, h = box
    x0, y0, x1, y1 = bounds(paths)
    rx, ry = max(x, x0 - pad), max(y, y0 - pad)
    rw, rh = min(x + w, x1 + pad) - rx, min(y + h, y1 + pad) - ry
    rect = (f'<rect x="{rx:g}" y="{ry:g}" width="{rw:g}" height="{rh:g}" rx="{radius:g}" '
            f'fill="#ffffff"/>\n')
    return svg(box, paths).replace("</title>\n", "</title>\n" + rect, 1)


def dark(paths):
    return [(LIGHT if f.lower() == NAVY else f, d) for f, d in paths]


def mark(paths):
    """The tiles, and a square about them: in the wordmark, the paths before
    the first gap from left to right (the letters come after it)."""
    spans = sorted((bounds([p]), p) for p in paths)
    tiles, right = [], None
    for (x0, _, x1, _), p in spans:
        if right is not None and x0 > right:
            break
        tiles.append(p)
        right = x1 if right is None else max(right, x1)
    x0, y0, x1, y1 = bounds(tiles)
    side = max(x1 - x0, y1 - y0) * 1.04
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return (cx - side / 2, cy - side / 2, side, side), tiles


def _contours(d):
    """An SVG path's contours as lists of points, curves flattened."""
    toks = re.findall(r"[MLHVQCZ]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d)
    out, cur, x, y, i, cmd = [], [], 0.0, 0.0, 0, None
    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
            if cmd == "Z":
                if cur:
                    out.append(cur)
                cur = []
                continue
        v = toks
        if cmd == "M":
            if cur:
                out.append(cur)
            x, y = float(v[i]), float(v[i + 1]); i += 2
            cur = [(x, y)]
            cmd = "L"
        elif cmd == "L":
            x, y = float(v[i]), float(v[i + 1]); i += 2
            cur.append((x, y))
        elif cmd == "H":
            x = float(v[i]); i += 1
            cur.append((x, y))
        elif cmd == "V":
            y = float(v[i]); i += 1
            cur.append((x, y))
        elif cmd == "Q":
            x1, y1, x2, y2 = (float(t) for t in v[i:i + 4]); i += 4
            for k in range(1, 13):
                t = k / 12
                cur.append(((1 - t) ** 2 * x + 2 * (1 - t) * t * x1 + t * t * x2,
                            (1 - t) ** 2 * y + 2 * (1 - t) * t * y1 + t * t * y2))
            x, y = x2, y2
        elif cmd == "C":
            x1, y1, x2, y2, x3, y3 = (float(t) for t in v[i:i + 6]); i += 6
            for k in range(1, 17):
                t = k / 16
                a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
                cur.append((a * x + b * x1 + c * x2 + e * x3, a * y + b * y1 + c * y2 + e * y3))
            x, y = x3, y3
        else:
            raise ValueError(f"path command {cmd!r} not drawn")
    if cur:
        out.append(cur)
    return out


def png(box, paths, width, height=None, ss=4):
    """Paths as an RGBA image width × height of the box (x, y, w, h), drawn
    ss times larger and reduced (antialiased); each path filled even-odd
    (a letter's counters are holes)."""
    x, y, w, h = box
    height = height or round(width * h / w)
    W, H = width * ss, height * ss
    sx, sy = W / w, H / h
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for fill, d in paths:
        mask = Image.new("1", (W, H), 0)
        for c in _contours(d):
            one = Image.new("1", (W, H), 0)
            ImageDraw.Draw(one).polygon([((px - x) * sx, (py - y) * sy) for px, py in c], fill=1)
            mask = ImageChops.logical_xor(mask, one)
        layer = Image.new("RGBA", (W, H), fill)
        layer.putalpha(mask.convert("L"))
        im = Image.alpha_composite(im, layer)
    return im.resize((width, height), Image.LANCZOS)


def dimmed(im):
    """As make_icons.py dims every icon, for disabled buttons."""
    r, g, b, a = im.split()
    grey = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 150 + v * 0.35)
    return Image.merge("RGBA", (grey, grey, grey, a.point(lambda v: v * 0.55)))


def write_all():
    for name, width in (("vmdance", 1200), ("vmdance_stacked", 800)):
        w, h, paths = read(f"{name}.svg")
        box = (0, 0, w, h)
        (LOGO / f"{name}_dark.svg").write_text(svg(box, dark(paths)))
        png(box, paths, width).save(LOGO / f"{name}.png", optimize=True)
        png(box, dark(paths), width).save(LOGO / f"{name}_dark.png", optimize=True)
    w, h, paths = read("vmdance.svg")
    (LOGO / "vmdance_card.svg").write_text(card((0, 0, w, h), paths))
    box, tiles = mark(paths)
    (LOGO / "vmdance_mark.svg").write_text(svg(box, tiles))
    for px in (64, 128, 256, 512):
        png(box, tiles, px, px).save(LOGO / f"vmdance_mark_{px}.png", optimize=True)
    # the window's icon: drawn 16 times larger and reduced, as the plugin's
    # other icons
    for px in (16, 24, 32):
        im = png(box, tiles, px * 16, px * 16).resize((px, px), Image.LANCZOS)
        im.save(ICONS / f"app_{px}.png")
        dimmed(im).save(ICONS / f"app_{px}_dim.png")
    # the algorithms' logos, by height (they are 3:2)
    for key, name in ALGORITHMS.items():
        src = Image.open(MDANCE / f"{name}.png").convert("RGBA")
        for px in (24, 32):
            im = src.resize((round(px * src.width / src.height), px), Image.LANCZOS)
            im.save(ICONS / f"algo_{key}_{px}.png")
            dimmed(im).save(ICONS / f"algo_{key}_{px}_dim.png")
    print("wrote", LOGO, "and", ICONS / "app_*.png", ICONS / "algo_*.png")


if __name__ == "__main__":
    write_all()
