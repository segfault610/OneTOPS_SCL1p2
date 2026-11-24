#!/usr/bin/env python3
"""Generate fillers whose widths are multiples of the 4.2 um cell pitch (vendor fillers are 8/4/2/1/0.01 um, which leave
DRC slivers on a 4.2 um grid).  Geometry copied layer-for-layer from vendor FILLER2 (4.2 um physical).
Usage: klayout -b -r mkfill.py   -> syn/fill_x.lef, syn/fill_x.gds   (PDK-derived output: keep out of git)"""
import glob, os, pya
root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ref = glob.glob(root + "/pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d")[0]
src = pya.Layout(); src.read(ref + "/gds/core_c1d.gds")
tmpl = src.cell("FILLER2")
P, H = 4.2, 48.7
ly = pya.Layout(); ly.dbu = src.dbu
lef = ["VERSION 5.8 ;", "BUSBITCHARS \"[]\" ;", "DIVIDERCHAR \"/\" ;", ""]
for k in (1, 2, 4, 8):
    w = P * k
    name = f"FILLX{k}"
    c = ly.create_cell(name)
    for li in src.layer_indexes():
        info = src.get_info(li)
        r = pya.Region(tmpl.begin_shapes_rec(li))
        if r.is_empty(): continue
        out = ly.layer(info.layer, info.datatype)
        for p in r.each():
            b = p.bbox()
            # stretch: left edge stays, right edge moves by (w - 4.2) (rails & boundary end at 4.0/4.2 -> use full w)
            x1 = b.right + int(round((w - P) / src.dbu))
            if info.layer == 8: x1 = int(round(w / src.dbu)); x0 = 0     # M1 rails span the full cell
            else: x0 = b.left
            c.shapes(out).insert(pya.Box(x0, b.bottom, x1, b.top))
    lef += [f"MACRO {name}", "  CLASS CORE SPACER ;", f"  FOREIGN {name} 0.000 0.000 ;", "  ORIGIN 0.000 0.000 ;",
            f"  SIZE {w:.3f} BY {H:.3f} ;", "  SYMMETRY X Y ;", "  SITE CORE ;",
            "  PIN VSS", "    DIRECTION INOUT ;", "    USE GROUND ;", "    PORT", "      LAYER metal1 ;",
            f"        RECT 0.000 0.000 {w:.3f} 9.000 ;", "    END", "  END VSS",
            "  PIN VDD", "    DIRECTION INOUT ;", "    USE POWER ;", "    PORT", "      LAYER metal1 ;",
            f"        RECT 0.000 39.700 {w:.3f} 48.700 ;", "    END", "  END VDD", f"END {name}", ""]
lef.append("END LIBRARY")
open(root + "/syn/fill_x.lef", "w").write("\n".join(lef))
ly.write(root + "/syn/fill_x.gds")
print("wrote fill_x.lef/gds")
