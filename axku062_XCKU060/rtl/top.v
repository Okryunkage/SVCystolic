`timescale 1ns/1ps

module topmodule(
	input  wire boardCLKp,
	input  wire boardCLKn,
	input  wire UARTRX,
	output wire UARTTX,
	input  wire KEY1);
	wire clk;
	clockGen CLKGEN0(.boardCLKp(boardCLKp),.boardCLKn(boardCLKn),.clock(clk));
	wire rst = KEY1;
	wire       RXbusyLED;
	wire       TXbusyLED;
	wire       RXerrorLED;
	uartCommandTest #(.boardCLK(200_000_000),.oversample(20),.baudrate(1_000_000),.ACCwidth(24)) UART_TEST0(
		.clk(clk),.rst(rst),
		.uartRX(UARTRX),.uartTX(UARTTX));
endmodule