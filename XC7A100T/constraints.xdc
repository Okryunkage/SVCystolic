##############################
##          Clock           ##
##############################

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports boardCLK]
#-dict option can make multiple config in one set_property instruction
create_clock -add -name boardCLKpin -period 10.00 -waveform {0 5} [get_ports boardCLK]
# -waveform {0 5} means rising edge at 0 ns and falling edge at 5 ns, if not used, the default setting would be applied. (default = 50% duty cycle)
# -add tells Vivado to add this clock definition instead of overwriting

##############################
##           UART           ##
##############################

set_property PACKAGE_PIN D4 [get_ports UARTRX]
set_property PACKAGE_PIN C4 [get_ports UARTTX]
set_property PACKAGE_PIN D3 [get_ports UARTcts]
set_property PACKAGE_PIN E5 [get_ports UARTrts]
set_property IOSTANDARD  LVCMOS33 [get_ports {UARTRX UARTTX UARTcts UARTrts}]

##############################
##           LEDs           ##
##############################