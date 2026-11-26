"""The guide's large icons: the window's own (vmdance/icons/make_icons.py)
drawn again at 128 px, for the tables of buttons and plots. Writes
figures/icons/<name>.png; the plugin's icons are not touched.

    cd quickstart-guide && python3 icons.py
Requires Pillow.
"""
import importlib.util
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "figures" / "icons"
SIZE = 128

spec = importlib.util.spec_from_file_location(
    "make_icons", HERE.parent / "vmdance" / "icons" / "make_icons.py")
mi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mi)


def save(self, name):
    # (drawn at 16x the 32-unit grid: 512 px, brought down to SIZE)
    self.img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}.png")


mi.Canvas.save = save
OUT.mkdir(parents=True, exist_ok=True)
drawn = [f for n, f in vars(mi).items()
         if callable(f) and (n.startswith("tab_") or n.startswith("act_") or n.startswith("pane_")
                             or n.startswith("panel_"))]
for f in drawn:
    f()
print(f"{len(drawn)} icons in {OUT}")
