"""Import the 4 approved offhand regens (SHEET_offhand_regen) as ADDITIONAL _b
sprites - originals untouched, code refs swap (GM must be CLOSED). Reuses the
.yy template + yyp registration from import_icons_0815."""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location(
    "icons0815", os.path.join(os.path.dirname(os.path.abspath(__file__)), "import_icons_0815.py"))
mod = importlib.util.module_from_spec(spec)
# Neutralize its own import list so loading the module doesn't re-run 08-15 batch.
sys.modules["icons0815"] = mod
src = open(spec.origin, encoding="utf-8").read()
src = src.replace("made = []", "IMPORTS = []\nmade = []")  # clear list before the run loop
exec(compile(src, spec.origin, "exec"), mod.__dict__)

REV = mod.REV.replace("icons_batch_0815", "offhand_clean_0815")
mod.REV = REV
NEW = [
    ("spr_icon_offhand_shield_b",  "regen_0.png"),
    ("spr_icon_offhand_bulwark_b", "regen_1.png"),
    ("spr_icon_offhand_focus_b",   "regen_2.png"),
    ("spr_icon_offhand_stone_b",   "regen_3.png"),
]
made = []
for name, png in NEW:
    if mod.make_sprite(name, png):
        made.append(name)
        print("imported", name)
mod.register_yyp([n for n, _ in NEW])
print(f"{len(made)} offhand _b sprites created + registered")
