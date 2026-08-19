## =========================================================
## Nexys A7-100T (xc7a100tcsg324-1) XDC
## Ports: clk_100m, SW0, BTNC, UART_TX
## =========================================================

## ---- Clock -----------------------------------------------
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk_100m }]
create_clock -name clk_100m -period 10.000 [get_ports { clk_100m }]

## ---- BTNC (시작 트리거) ---------------------------------
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { BTNC }]

## ---- UART TX --------------------------------------------
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports { UART_TX }]

## ---- Config voltage -------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ---- Ring Oscillator combinational loop 허용 ------------
set_property ALLOW_COMBINATORIAL_LOOPS TRUE \
  [get_nets -hierarchical -filter {NAME =~ "*GEN_RO*u_ro*"}]
