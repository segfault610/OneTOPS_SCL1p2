# OpenROAD flow for accel_top on SCL 1.2um (C1D): floorplan -> PDN -> place -> CTS -> fill -> route.
# Modelled on the vendor scripts_template/*.tcl (alternate rows removed, 2 metal layers). Run inside the
# librelane container via scripts/run_pnr.sh. Env: DIE (um, square side), CLK_NS, STAGE (fp|place|cts|route)
set root /work
set pdk [glob $root/pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d]
set die  [expr {[info exists ::env(DIE)] ? $::env(DIE) : 5000}]
set clk  [expr {[info exists ::env(CLK_NS)] ? $::env(CLK_NS) : 40.0}]
set out  $root/pnr/out; file mkdir $out

read_liberty $pdk/lib/nldm_tt_27_1p5.lib
read_lef $pdk/lef/tech_c1d.lef
read_lef $pdk/lef/core_c1d.lef
read_verilog $root/syn/accel_net.v
link_design accel_top
create_clock -name clk -period $clk [get_ports clk]
set_input_delay  [expr {$clk*0.2}] -clock clk [lsearch -inline -all -not -exact [all_inputs] [get_ports clk]]
set_output_delay [expr {$clk*0.2}] -clock clk [all_outputs]

initialize_floorplan -site CORE -die_area "0 0 $die $die" -core_area "30 30 [expr {$die-30}] [expr {$die-30}]"
# vendor style: no row flipping, drop every other row so rails never overlap
set n 0
foreach row [[ord::get_db_block] getRows] { if {$n % 2 != 0} { odb::dbRow_destroy $row }; incr n }
make_tracks metal1 -x_offset 0.0 -x_pitch 4.0 -y_offset 0.0 -y_pitch 4.0
make_tracks metal2 -x_offset 0.0 -x_pitch 4.2 -y_offset 0.0 -y_pitch 4.2
place_pins -hor_layers metal1 -ver_layers metal2
write_db $out/fp.odb

add_global_connection -net VDD -pin_pattern VDD -power
add_global_connection -net VSS -pin_pattern VSS -ground
global_connect
set_voltage_domain -name CORE -power VDD -ground VSS
define_pdn_grid -name Core_1 -voltage_domain CORE -pins metal2
add_pdn_stripe -grid Core_1 -layer metal1 -width 9.0 -followpins -extend_to_core_ring
add_pdn_connect -grid Core_1 -layers {metal1 metal2}
add_pdn_ring -grid Core_1 -layer {metal1 metal2} -widths "3 3" -spacings "3 3" -core_offsets "10 10"
pdngen
write_db $out/pdn.odb
if {[info exists ::env(STAGE)] && $::env(STAGE) eq "fp"} { exit }

global_placement -density 0.3
detailed_placement
check_placement -verbose
write_db $out/place.odb
if {[info exists ::env(STAGE)] && $::env(STAGE) eq "place"} { report_design_area; exit }

set_propagated_clock [all_clocks]
clock_tree_synthesis -root_buf INVR01 -buf_list "INVR01" -sink_clustering_enable
repair_clock_nets
detailed_placement
filler_placement -prefix FILLER [list FILLER5 FILLER4 FILLER3 FILLER2 FILLER1]
write_db $out/cts.odb
if {[info exists ::env(STAGE)] && $::env(STAGE) eq "cts"} { report_design_area; exit }

set_routing_layers -signal metal1-metal2 -clock metal1-metal2
global_route -allow_congestion -verbose
detailed_route -top_routing_layer metal2 -via_in_pin_bottom_layer metal1 -via_in_pin_top_layer metal2 -output_drc $out/drc.rpt
write_db $out/route.odb
write_def $out/accel_top.def
report_design_area
