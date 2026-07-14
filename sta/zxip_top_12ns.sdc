# SDC for zxip_top — 12 ns period, pre-P&R STA
# I/O external delay: 4.0 ns (same absolute budget as 10 ns SDC)

create_clock -name hclk -period 12.0 [get_ports hclk]
create_clock -name pclk -period 12.0 [get_ports pclk]

set_clock_groups -asynchronous -group {hclk} -group {pclk}

set_false_path -from [get_ports hresetn]
set_false_path -from [get_ports presetn]

set ahb_in  [get_ports {haddr[*] htrans[*] hwrite hsize[*] hsel hready hwdata[*]}]
set page_in [get_ports {phys_valid phys_i[*] fixed_page[*] page_sel[*] page_is_flash}]
set apb_in  [get_ports {paddr[*] psel penable pwrite pwdata[*]}]

set_input_delay  -clock hclk -max 4.0 $ahb_in
set_input_delay  -clock hclk -min 0.0 $ahb_in
set_input_delay  -clock hclk -max 4.0 $page_in
set_input_delay  -clock hclk -min 0.0 $page_in
set_input_delay  -clock pclk -max 4.0 $apb_in
set_input_delay  -clock pclk -min 0.0 $apb_in

set_output_delay -clock hclk -max 4.0 [get_ports {hrdata[*] hreadyout hresp}]
set_output_delay -clock hclk -min 0.0 [get_ports {hrdata[*] hreadyout hresp}]
set_output_delay -clock pclk -max 4.0 [get_ports {prdata[*] pready pslverr}]
set_output_delay -clock pclk -min 0.0 [get_ports {prdata[*] pready pslverr}]
set_output_delay -clock hclk -max 4.0 [get_ports {spi_sck spi_cs_n spi_reset_n}]
set_output_delay -clock hclk -min 0.0 [get_ports {spi_sck spi_cs_n spi_reset_n}]

set_load 0.05 [all_outputs]
