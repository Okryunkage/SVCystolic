`timescale 1ns/1ps

module conventl_SA#(
	parameter size=4)(
	clk, data_sel, data, result);
	localparam bussize=size+16;
	localparam busize=bussize-1;
	input clk, data_sel;
	input wire [(8*size-1):0] data;
	output wire [(size*bussize-1):0] result;
