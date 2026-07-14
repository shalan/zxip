# Multi-corner STA for one liberty file
# Environment: CORNER=tt|ss|ff  LIB_PATH=...  NET=...  SDC=...  RPT_DIR=...

if {![info exists ::env(CORNER)]}  { set CORNER ss }
if {![info exists ::env(LIB_PATH)]} { set LIB_PATH /work/sky130/hd_120e_ss.lib }
if {![info exists ::env(NET)]}      { set NET /work/synth/zxip_top_sky130.v }
if {![info exists ::env(SDC)]}      { set SDC /work/sta/zxip_top.sdc }
if {![info exists ::env(RPT_DIR)]}  { set RPT_DIR /work/sta/reports/$::env(CORNER) }

set CORNER $::env(CORNER)
set LIB    $::env(LIB_PATH)
set NET    $::env(NET)
set SDC    $::env(SDC)
set RPT    $::env(RPT_DIR)

file mkdir $RPT

puts "========================================"
puts " OpenSTA corner: $CORNER"
puts " Liberty: $LIB"
puts " Netlist: $NET"
puts "========================================"

read_liberty $LIB
read_verilog $NET
link_design zxip_top
read_sdc $SDC

report_checks -path_delay max -fields {slew cap input_pins} -digits 4 -group_path_count 20 \
  > $RPT/setup.rpt
report_checks -path_delay min -fields {slew cap input_pins} -digits 4 -group_path_count 20 \
  > $RPT/hold.rpt
report_checks -path_delay max -digits 4 -group_path_count 10 > $RPT/setup_summary.rpt
report_checks -path_delay min -digits 4 -group_path_count 10 > $RPT/hold_summary.rpt

report_wns > $RPT/wns.rpt
report_tns > $RPT/tns.rpt
report_worst_slack -max > $RPT/worst_slack_max.rpt
report_worst_slack -min > $RPT/worst_slack_min.rpt
report_clock_properties > $RPT/clocks.rpt
catch { report_design_area > $RPT/design_area.rpt }

puts "---- $CORNER results ----"
report_wns
report_tns
report_worst_slack -max
report_worst_slack -min
report_checks -path_delay max -digits 3 -group_path_count 3

puts "Reports: $RPT"
exit
