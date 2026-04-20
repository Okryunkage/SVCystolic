`timescale 1ns/1ps

module uartTOP#(
	parameter boardCLK   =150_000_000,
	parameter oversample =20,
	parameter baudrate   =1_000_000,
	parameter ACCwidth   =24
)(
	input clk,
	input rst,
	input mode,

	input uartRX,
	input uartTX,

	input TXstart,
	input Txitem,

	output TXdone,
	output TXbusy,

	output[7:0] RXout,
	output RXdone,
	output RXbusy,
	output RXerror
);
	wire RXtick, TXtick;
	baudtickgen #(.CLK(boardCLK),.oversample(oversample),.baudrate(baudrate),.ACCwidth(ACCwidth)) baudGen(.clk(clk),.rst(rst),.ostick(RXtick),.baudtick(TXtick));
	transmit #(.bits(8)) TX(.clk(clk),.tick(TXtick),.en(mode),.start(TXstart),.in(TXitem),.out(uartTX),.done(TXdone),.busy(TXbusy));
	receive  #(.bits(8)) RX(.clk(clk),.tick(RXtick),.en(!mode),.in(uartRX),.rst(rst),.out(RXout),.done(RXdone),.busy(RXbusy),.error(RXerror));
endmodule
