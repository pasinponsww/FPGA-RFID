## XDC example (Xilinx) - EDIT PINS/CLK FREQUENCY
## UART
set_property PACKAGE_PIN <PIN_RX> [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]
set_property PACKAGE_PIN <PIN_TX> [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]

## LEDs
//set_property PACKAGE_PIN <PIN_GRANT_LED> [get_ports {grant_led}]
//set_property IOSTANDARD LVCMOS33 [get_ports {grant_led}]
set_property PACKAGE_PIN <PIN_DENY_LED> [get_ports {deny_led}]
set_property IOSTANDARD LVCMOS33 [get_ports {deny_led}]

## Clock
set_property PACKAGE_PIN <PIN_CLK> [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]
create_clock -period 20.000 -name sys_clk [get_ports {clk}]  # 50 MHz
