##############################
##          Clock           ##
##############################

#positive CLKpin
set_property PACKAGE_PIN AK17 [get_ports boardCLKp]
#negative CLKpin
set_property PACKAGE_PIN AK16 [get_ports boardCLKn]
#LVDS : Low-Voltage Differential Signaling | IO level configuration
set_property IOSTANDARD  LVDS [get_ports {boardCLKp boardCLKn}]
#create the clock signal. This signal used in STA analysis.
create_clock -name boardCLK -period 5.000 [get_ports boardCLKp]

##############################
##           UART           ##
##############################

set_property PACKAGE_PIN AJ11 [get_ports UARTRX]
set_property PACKAGE_PIN AM9  [get_ports UARTTX]
set_property IOSTANDARD  LVCMOS33 [get_ports {UARTRX UARTTX}]

##############################
##           KEY1           ##
##############################

set_property PACKAGE_PIN N23 [get_ports KEY1]
set_property IOSTANDARD LVCMOS33 [get_ports KEY1]

##############################
##           LEDs           ##
##############################

set_property PACKAGE_PIN E12 [get_ports {LED[0]}]
set_property PACKAGE_PIN F12 [get_ports {LED[1]}]
set_property PACKAGE_PIN L9  [get_ports {LED[2]}]
set_property PACKAGE_PIN H23 [get_ports {LED[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[3:0]}]