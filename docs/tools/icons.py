"""The window's icons drawn large, for the documentation's and the quick-start
guide's tables of buttons and plots: the plugin's own
(vmdance/icons/make_icons.py) drawn again at 128 px. Writes
docs/_static/icons/<name>.png; the plugin's icons are not touched.

    cd <VMDance> && python3 docs/tools/icons.py
Requires Pillow.
"""
import importlib.util
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "_static" / "icons"
SIZE = 128

spec = importlib.util.spec_from_file_location(
    "make_icons", ROOT / "vmdance" / "icons" / "make_icons.py")
mi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mi)


def save(self, name):
    # (only the icons the plugin ships: two of its drawings are not used)
    if not (ROOT / "vmdance" / "icons" / f"{name}_32.png").exists():
        return
    # (drawn at 16x the 32-unit grid: 512 px, brought down to SIZE)
    self.img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}.png")
    made.append(name)


made = []
mi.Canvas.save = save
OUT.mkdir(parents=True, exist_ok=True)
drawn = [f for n, f in vars(mi).items()
         if callable(f) and (n.startswith("tab_") or n.startswith("act_") or n.startswith("pane_")
                             or n.startswith("panel_"))]
for f in drawn:
    f()
print(f"{len(made)} icons in {OUT}")
