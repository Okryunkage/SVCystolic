`include "parameter.vh"
`include "transmit.v"
`include "tickgen.v"
`include "baudrategen.v"
`include "receive_rev.v"
`timescale 1ns/1ps

module tb_receive_rev;
	parameter integer clock =`clk500MHz;
	parameter integer latency = (1_000_000_000/(2*clock));
	parameter integer baudrate =`baud_fast;
	parameter integer bitwidth =`bitwidth8;
	parameter integer oversample =16;

	localparam integer clockTick =(clock/baudrate)*2*latency;

	reg clk =1'b0;
	wire RXclk, TXclk;
	
	reg TXen =1'b1;
	reg TXstart =0;
	reg [(bitwidth-1):0] in ='0;

	wire TXout;
	wire TXdone;
	wire TXbusy;
	
	reg RXen =1'b1;
	reg RXrst =1'b0;
	wire [(bitwidth-1):0] RXout;
	wire RXdone, RXbusy, RXerror;
	
	wire rts;

	wire RXclk1, TXclk1;

	tickgen #(clock,baudrate,oversample,24) tickgen(clk, {1'b0}, RXclk, TXclk);
	baudrategen #(clock,baudrate,oversample) baudgen(clk, RXclk1, TXclk1);

	transmit #(bitwidth) transmit0(TXclk, TXen, TXstart, in, TXout, TXdone, TXbusy, rts);
	receive  #(bitwidth) receive0(RXclk, RXen, TXout, RXrst, RXout, RXdone, RXbusy, RXerror, rts, {1'b1});

	task test;
		input [(bitwidth-1):0] in_t;
		in <= in_t;
		#clockTick TXstart <=1'b1;
		#clockTick TXstart <=1'b0;
		#clockTick;
		#(bitwidth*clockTick);
		#clockTick;
		#clockTick;
	endtask
	
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_receive_rev);
		#500;
		test(8'h55);
		test(8'h96);
		test(8'h47);
		test(8'h0c);
		$finish;
	end
	always #latency clk =~clk;
endmodule
