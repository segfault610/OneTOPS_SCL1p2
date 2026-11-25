#!/bin/bash
# scripts/drc.sh <gds> <topcell> [report.lyrdb]: vendor KLayout DRC; prints category counts
cd "$(dirname "$0")/.."
DECK=$(ls pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.tech/klayout/tech/drc/c1d_digital.drc)
R=$(realpath -m "${3:-/tmp/drc_$$.lyrdb}"); IN=$(realpath "$1")
klayout -b -r "$DECK" -rd input="$IN" -rd top_cell="$2" -rd report1="$R" >/dev/null 2>&1
python3 - "$R" <<'PY'
import sys,re,collections
t=open(sys.argv[1]).read()
cats=re.findall(r"<category>\s*<name>(.*?)</name>",t,re.S)
items=re.findall(r"<item>.*?<category>(.*?)</category>",t,re.S)
c=collections.Counter(items)
print("TOTAL",sum(c.values()))
for k,v in c.most_common(): print(v,k.replace("&amp;","&"))
PY
