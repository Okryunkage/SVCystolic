`include "parameter.vh"
`include "transmit.v"
`include "baudrategen.v"
`include "receive.v"
`timescale 1ns/1ps

module tb_transmitter();
	parameter integer clock =`clk100MHz;
	parameter integer latency = (1_000_000_000/(2*clock));
	parameter integer baudrate =`baud_slow;
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
	

	baudrategen #(clock,baudrate,16) baudgen(clk, RXclk, TXclk);

	transmit #(bitwidth) transmit0(TXclk, TXen, TXstart, in, TXout, TXdone, TXbusy);
	receive  #(bitwidth) receive0(RXclk, RXen, TXout, RXrst, RXout, RXdone, RXbusy, RXerror);

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
		$dumpvars(0,tb_transmitter);
		test(8'h55);
		test(8'h96);
		$finish;
	end
	always #latency clk =~clk;
endmodule
