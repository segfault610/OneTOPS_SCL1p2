# Routing-only restart from pnr/out/cts.odb (see flow.tcl). Tie-cell nets are typed SIGNAL so TritonRoute routes them.
set root /work
set pdk [glob $root/pdk_kit/digital/my_dtech/*/open_source_scl_c1d/open_pdks/sclc1d/libs.ref/digital_c1d]
set out $root/pnr/out
read_liberty $pdk/lib/nldm_tt_27_1p5.lib
read_lef $pdk/lef/tech_c1d.lef
read_lef $root/syn/core_snapped.lef
read_db $out/cts.odb
foreach nm {zero_ one_} { set n [[ord::get_db_block] findNet $nm]; if {$n ne "NULL"} { $n setSigType SIGNAL } }
set_routing_layers -signal metal1-metal2 -clock metal1-metal2
global_route -allow_congestion
detailed_route -via_in_pin_bottom_layer metal1 -via_in_pin_top_layer metal2 -output_drc $out/drc.rpt
write_db $out/route.odb
write_def $out/accel_top.def
report_design_area
