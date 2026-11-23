# klayout -b -r scripts/def2gds.py : routed DEF + SCL std-cell GDS -> pnr/out/accel_top.gds
import glob, os, pya
root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
kit = glob.glob(root + "/pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d")[0]
ref, tech = kit + "/libs.ref/digital_c1d", kit + "/libs.tech/klayout/tech"
opt = pya.LoadLayoutOptions()
ld = opt.lefdef_config
ld.map_file = tech + "/scl_c1d.map"
ld.lef_files = [ref + "/lef/tech_c1d.lef", ref + "/lef/core_c1d.lef"]
ld.read_lef_with_def = False
ld.macro_resolution_mode = 1          # produce empty macro cells; real geometry comes from the GDS below
ly = pya.Layout()
ly.read(root + "/pnr/out/accel_top.def", opt)
gopt = pya.LoadLayoutOptions()
gopt.cell_conflict_resolution = pya.LoadLayoutOptions.CellConflictResolution.OverwriteCell
ly.read(ref + "/gds/core_c1d.gds", gopt)
top = [c for c in ly.top_cells() if c.name == "accel_top"][0]
empty = [c.name for c in ly.each_cell() if c.is_empty() and c.name != "accel_top" and not c.is_proxy()]
print("empty cells (unresolved):", empty[:10], len(empty))
top.write(root + "/pnr/out/accel_top.gds")
bb = top.dbbox()
print("top:", top.name, "bbox um:", bb.width(), bb.height(), "cells:", ly.cells())
