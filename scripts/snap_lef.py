#!/usr/bin/env python3
"""Snap the vendor core LEF to the 0.005 um manufacturing grid (TritonRoute rejects its off-grid pin rects).
Usage: snap_lef.py core.lef core_out.lef [tech.lef tech_out.lef]   (output is PDK-derived: keep it out of git)"""
import os, re, sys
FALLBACK = set(os.environ.get("PIN_FALLBACK", "").split(","))   # CELL or CELL/PIN entries that keep metal1 as a second access (pin access fails on metal2 alone); other pins stay metal2-only
g = 0.005
def snap(m): return f"{round(float(m.group()) / g) * g:.3f}"
# Every signal pin of the vendor cells already carries a built-in via1 + metal2 pad over its metal1 rectangle.
# A router-placed via1 next to it breaks the via-to-contact/poly rules, so declare signal pins on metal2 only
# (metal1 becomes obstruction; PIN_FALLBACK pins keep it as a pin) so the router lands on the existing pad.
pin = None; in_pin_port = False; pend = []; have_obs = False
out = []
for l in open(sys.argv[1]):
    t = l.split(); k = t[0].upper() if t else ""
    if k == "MACRO": pend, have_obs, pin, MAC = [], False, None, t[1]
    elif k == "PIN": pin = t[1]; sig = True; MODE = "fallback" if MAC in FALLBACK or MAC + "/" + pin in FALLBACK else "obs"
    elif k in ("USE",) and t[1] in ("POWER", "GROUND"): sig = False
    elif k == "OBS": pin = None; have_obs = True
    if pin and sig and k == "LAYER" and t[1] == "metal1":
        # signal pin (USE is declared before PORT for power pins; signal pins have none)
        l = l.replace("metal1", "metal2"); in_pin_port = True
    elif pin and k == "RECT" and in_pin_port:
        pend.append(re.sub(r"-?\d+\.\d+", snap, l.strip().split(";")[0]))
    if k == "END" and len(t) == 1 and in_pin_port and pend and MODE == "fallback":   # close of PORT: metal1 stays as fallback access
        out.append("      LAYER metal1 ;\n"); out += ["        %s ;\n" % r for r in pend]; pend = []; in_pin_port = False
    elif k == "END" and len(t) == 1 and have_obs and pend:           # close of OBS: pin metal1 becomes obstruction
        out.append("      LAYER metal1 ;\n"); out += ["        %s ;\n" % r for r in pend]; pend = []
    if k == "END" and len(t) == 2 and t[1] == pin: in_pin_port = False
    out.append(re.sub(r"-?\d+\.\d+", snap, l) if k in ("RECT", "POLYGON", "SIZE", "FOREIGN") else l)
open(sys.argv[2], "w").write("".join(out))

# Optional: widen the CORE site to 4.2 um (all cell widths are multiples of it) so placement leaves no sliver gaps;
# gaps are then tiled with scripts/mkfill.py fillers (the vendor 8/4/2/1/0.01 um fillers cannot tile 4.2 um multiples).
if len(sys.argv) > 3:
    s = open(sys.argv[3]).read()
    n = re.sub(r"(SITE\s+CORE\s*\n(?:.*\n)*?\s*SIZE\s+)0\.01(\s+BY\s+48\.700)", r"\g<1>4.2\2", s, count=1)
    assert n != s, "CORE site not found"
    open(sys.argv[4], "w").write(n)
