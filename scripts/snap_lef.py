#!/usr/bin/env python3
"""Snap the vendor core LEF to the 0.005 um manufacturing grid (TritonRoute rejects its off-grid pin rects).
Usage: snap_lef.py core.lef core_out.lef [tech.lef tech_out.lef]   (output is PDK-derived: keep it out of git)"""
import re, sys
g = 0.005
def snap(m): return f"{round(float(m.group()) / g) * g:.3f}"
with open(sys.argv[1]) as f, open(sys.argv[2], "w") as o:
    for l in f:
        o.write(re.sub(r"-?\d+\.\d+", snap, l) if l.strip().startswith(("RECT", "POLYGON", "SIZE", "FOREIGN")) else l)

# NOTE (tried, not used): widening the CORE site to 4.2 um breaks filler insertion (vendor fillers are 8/4/2/1/0.01 um wide).
# Placement grid: make the CORE site as wide as the metal2 pitch (all cell widths are multiples of 4.2 um) so
# cells abut exactly; the vendor 0.01 um site leaves sliver gaps between wells/boron (KLayout DRC).
if len(sys.argv) > 3:
    s = open(sys.argv[3]).read()
    n = re.sub(r"(SITE\s+CORE\s*\n(?:.*\n)*?\s*SIZE\s+)0\.01(\s+BY\s+48\.700)", r"\g<1>4.2\2", s, count=1)
    assert n != s, "CORE site not found"
    open(sys.argv[4], "w").write(n)
