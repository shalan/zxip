# OpenSTA script — sky130 HD SS liberty + post-yosys netlist
set LIB  /work/sky130/hd_120e_ss.lib
set NET  /work/synth/zxip_top_sky130_ss.v
set SDC  /work/sta/zxip_top.sdc
set RPT  /work/sta/reports

file mkdir $RPT

puts "==== Read liberty (SS) ===="
read_liberty $LIB

puts "==== Read netlist ===="
read_verilog $NET
link_design zxip_top

puts "==== Read SDC ===="
read_sdc $SDC

puts "==== Reports ===="
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

# Area / cells if available
catch { report_design_area > $RPT/design_area.rpt }
catch { report_cell_usage  > $RPT/cell_usage.rpt }

puts "==== Key results (stdout) ===="
report_wns
report_tns
report_worst_slack -max
report_worst_slack -min
report_checks -path_delay max -digits 3 -group_path_count 5
report_checks -path_delay min -digits 3 -group_path_count 3

puts "Reports written under $RPT"
exit
