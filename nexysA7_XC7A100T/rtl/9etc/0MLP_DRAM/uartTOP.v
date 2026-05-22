`timescale 1ns/1ps

module uartTOP#(
	parameter integer boardCLK   =150_000_000,
	parameter integer oversample =20,
	parameter integer baudrate   =1_000_000,
	parameter integer ACCwidth   =24
)(
	input  wire clk,
	input  wire rst,

	input  wire uartRX,
	output wire uartTX,

	input  wire       TXstart,
	input  wire [7:0] TXitem,

	output wire TXdone,
	output wire TXbusy,

	output wire [7:0] RXout,
	output wire RXdone,
	output wire RXbusy,
	output wire RXerror);

	wire RXtick, TXtick;
	baudtickgen #(.CLK(boardCLK),.oversample(oversample),.baudrate(baudrate),.ACCwidth(ACCwidth)) baudGen(.clk(clk),.rst(rst),.ostick(RXtick),.baudtick(TXtick));
	transmit #(.bits(8)) TX(.clk(clk),.tick(TXtick),.en(1'b1),.start(TXstart),.in(TXitem),.out(uartTX),.done(TXdone),.busy(TXbusy));
	receive #(.bits(8),.oversample(oversample)) RX(.clk(clk),.tick(RXtick),.en(1'b1),.in(uartRX),.rst(rst),.out(RXout),.done(RXdone),.busy(RXbusy),.error(RXerror));

endmodule