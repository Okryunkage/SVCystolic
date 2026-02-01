`timescale 1ns/1ps

module proposed_IOr#(
	parameter integer size=16,
	parameter integer inwidth=16,
	parameter integer outwidth=16)(
	clk,preclk,in_clk,out_clk,
	en_in,en_out,data_in,data_out);
	localparam integer bussize=size+16;
	localparam integer busize=bussize-1;
	input clk, preclk, in_clk, out_clk;
	input [(size*8/inwidth-1):0] en_in;
	input en_out;
	input [(size*8/inwidth-1):0] data_in;
	output wire [(bussize-1):0] data_out;
	wire [(8*size-1):0] in_reg;
	wire [(bussize*size-1):0] out_reg;
	input_reg #(size,inwidth) input_reg(in_clk,en_in,data_in,in_reg);
	proposed_bka #(size) sapp(clk,preclk,in_reg,in_reg,out_reg);
	output_reg #(size,outwidth) output_reg(out_clk,{size{en_out}},out_reg,data_out);
endmodule
