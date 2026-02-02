`include "parameter.vh"
`include "transmit.v"
`timescale 1ns/1ps

module tb_transmitter();
	parameter integer clock =`clk100MHz;
	parameter integer baudrate =`baud_slow;
	parameter integer bitwidth =`bitwidth8;

	localparam integer maxRateTX =clock/(2*baudrate);
	localparam integer clockTX =2*maxRateTX;
	
	reg TXclk =0;
	reg en =1;
	reg start =0;
	reg [(bitwidth-1):0] in =0;

	wire out;
	wire done;
	wire busy;
	
	transmit #(bitwidth) transmit0(TXclk, en, start, in, out, done, busy);

	task test;
		input [(bitwidth-1):0] in_t;
		in <= in_t;
		#clockTX start <=1'b1;
		#clockTX start <=1'b0;
		#clockTX;
		#(bitwidth*clockTX);
		#clockTX;
		#clockTX;
	endtask
	
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_transmitter);
		test(8'h55);
		test(8'h96);
		$finish;
	end
	always #maxRateTX TXclk =~TXclk;
endmodule
