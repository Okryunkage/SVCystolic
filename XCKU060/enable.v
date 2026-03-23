`timescale 1ns/1ps

module clockEnable#(
	parameter integer inputFreq  =1_000_000,
	parameter integer targetFreq =  500_000)(
	input wire clk,
	output reg ce =1'd0);
	`include "ceillog2.vh"
	localparam integer accWidth =ceillog2(inputFreq+targetFreq);
	reg[(accWidth-1):0] acc=1'd0;
	always@(posedge clk)begin
		if((acc+targetFreq)>=inputFreq)begin
			acc<=acc+targetFreq-inputFreq;
			ce <=1'b1;
		end
		else begin
			acc<=acc+targetFreq;
			ce <=1'd0;
		end
	end
endmodule
