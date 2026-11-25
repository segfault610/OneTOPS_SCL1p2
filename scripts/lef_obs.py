#!/usr/bin/env python3
# klayout -b -r scripts/lef_obs.py : add GDS metal1 that the vendor abstract omits (seen under NND201 IN2) to
# syn/core_snapped.lef as OBS, so the router cannot drop a via1 on it next to a contact (9.3.1/9.4.1). Run after snap_lef.py.
import glob, os, re, pya
root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ref = glob.glob(root + "/pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d")[0]
gds = pya.Layout(); gds.read(ref + "/gds/core_c1d.gds")
m1 = gds.layer(8, 0); dbu = gds.dbu
fn = root + "/syn/core_snapped.lef"; txt = open(fn).read()
def fix(mm):
    name, body = mm.group(1), mm.group(2)
    cell = gds.cell(name)
    if cell is None: return mm.group(0)
    have = pya.Region()
    for lay in re.finditer(r"LAYER (\w+) ;((?:\s*RECT [^;]*;)*)", body):
        if lay.group(1) == "metal1":
            for r in re.finditer(r"RECT\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)", lay.group(2)):
                x1, y1, x2, y2 = (round(float(v) / dbu) for v in r.groups()); have.insert(pya.Box(x1, y1, x2, y2))
    miss = (pya.Region(cell.begin_shapes_rec(m1)).merged() - have.merged())
    rects = [t.bbox() for p in miss.each_merged() for t in p.decompose_trapezoids()]
    if not rects: return mm.group(0)
    add = "      LAYER metal1 ;\n" + "".join("        RECT %.3f %.3f %.3f %.3f ;\n" % tuple(v * dbu for v in (b.left, b.bottom, b.right, b.top)) for b in rects)
    i = body.rfind("\n  END")   # closing END of the OBS block (last macro-level END)
    if "OBS" not in body or i < 0: return mm.group(0)
    i += 1
    return mm.group(0).replace(body, body[:i] + add + body[i:])
txt2, n = re.subn(r"(?<=\n)macro (\w+)\b(.*?)(?=\nEND \1\b)", lambda m: fix(m), txt, flags=re.S | re.I)
open(fn, "w").write(txt2); print("macros processed", n)
