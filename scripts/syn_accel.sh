#!/usr/bin/env bash
# Native yosys(+slang) synthesis of accel_top onto the SCL std cells -> syn/accel_net.v (+ syn/stat_accel.txt).
# Usage: scripts/syn_accel.sh [N] [DW]      (generated files in syn/ are PDK-derived: gitignored)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"; mkdir -p syn
N=${1:-2}; DW=${2:-8}
LIB=$(ls pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d/lib/nldm_tt_27_1p5.lib)
# yosys' liberty reader needs next_state/clocked_on/clear/preset strings without padding spaces
sed -E "/(next_state|clocked_on|clear|preset) :/ s/\"[[:space:]]*([A-Za-z]+'?)[[:space:]]*\"/\"\1\"/" "$LIB" > syn/scl_tt_clean.lib
yosys -m slang -q -p "read_slang --top accel_top -G N=$N -G DW=$DW rtl/accel/accel_top.sv third_party/tiny-tpu/rtl/pe.sv third_party/tiny-tpu/rtl/systolic_array.sv
synth -top accel_top -flatten
dfflegalize -cell \$_DFF_PN0_ 01 -cell \$_DFF_P_ 01
dfflibmap -liberty syn/scl_tt_clean.lib
abc -liberty syn/scl_tt_clean.lib -dont_use MX2101 -dont_use MX201B -dont_use TBUF01 -dont_use MX4122   # off-grid widths (4.2 um site) / no metal2 pin access (MX4122 D3)
opt_clean
hilomap -singleton -hicell VDDCON OUT1 -locell VSSCON OUT1
opt_clean -purge
tee -o syn/stat_accel.txt stat -liberty syn/scl_tt_clean.lib
write_verilog -noattr -noexpr -nohex syn/accel_net.v"
grep -E "Chip area" syn/stat_accel.txt
