#!/usr/bin/env bash
# Build every generated LEF/filler file that P&R and def2gds need (syn/, PDK-derived: gitignored). Run before scripts/run_pnr.sh.
set -e
cd "$(dirname "$0")/.."; mkdir -p syn
REF=$(ls -d pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d)
# cells whose signal pins keep metal1 access: with metal2 only, TritonRoute fails pin access (DRT-0073)
export PIN_FALLBACK=${PIN_FALLBACK-ADNR01,AND201,AND301,AND401,AND501,AOI401,DFCL11,INVR01,NND201,NND300,NND401,NND501,NOR200,NOR300,NOR601,OR2101,OR3101,OR4101,ORND01,XNR201,XOR201}
python3 scripts/snap_lef.py "$REF/lef/core_c1d.lef" syn/core_snapped.lef "$REF/lef/tech_c1d.lef" syn/tech_snapped.lef
klayout -b -r scripts/mkfill.py
klayout -b -r scripts/lef_obs.py   # edits core_snapped.lef, so must follow snap_lef.py
