# Digilent Nexys-A7-100T Master XDC pin mapping (FPGA RX=C4, TX=D4).
set_property PACKAGE_PIN E3 [get_ports clk]
set_property PACKAGE_PIN C12 [get_ports resetN]
set_property PACKAGE_PIN C4 [get_ports uartRX]
set_property PACKAGE_PIN D4 [get_ports uartTX]
set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property PACKAGE_PIN R18 [get_ports {led[4]}]
set_property PACKAGE_PIN V17 [get_ports {led[5]}]
set_property PACKAGE_PIN U17 [get_ports {led[6]}]
set_property PACKAGE_PIN U16 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports *]
create_clock -name boardClock -period 10.000 [get_ports clk]
# Only the asynchronous input to the FIRST receiver synchronizer is excluded.
set_false_path -from [get_ports uartRX] -to [get_cells -hier -filter {NAME =~ *serialPort/rxMeta_reg}]
# External reset asynchronously asserts the reset synchronizer. Its output is timed.
set_false_path -from [get_ports resetN] -to [get_cells -hier -filter {NAME =~ *resetSync_reg*}]
# UART and LEDs have no receiver clock related to boardClock.
# Bound register-to-pin propagation to 10 ns, excluding clock insertion delay.
# At 8 Mbps, one UART bit is 125 ns; this routing budget is 8% of that period.
# This constraint does not set the baud rate. Internal 100 MHz paths remain timed.
set_max_delay -datapath_only 10.0 -from [get_clocks boardClock] -to [get_ports {uartTX led[*]}]
set_min_delay 0.0 -from [get_clocks boardClock] -to [get_ports {uartTX led[*]}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
