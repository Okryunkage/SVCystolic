`timescale 1ns/1ps

module SYNCx(
	input clk,
	input rst,
	input signal,
	output reg SYNCsig
);
	reg ff0,ff1;
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			ff0 <=1'b0;
			ff1 <=1'b0;
			SYNCsig <=1'b0;
		end
		else begin
			ff0 <=signal;
			ff1 <=ff0;
			SYNCsig <=ff0&~ff1;
		end
	end
endmodule