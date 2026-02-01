`timescale 1ns/1ps

module pe_rev#(
	parameter integer size=16)(
	clk, preclk,
	weight, in, psum0, psum1,
	weightO, inO, psumO0, psumO1);
	localparam integer buswire=ceillog2(size)+16;
	localparam integer bussize=buswire-1;
	input clk;
	input preclk;
	input [7:0] weight;
	input [7:0] in;
	input [bussize:0] psum0, psum1;
	output reg [7:0] weightO;
	output reg [7:0] inO;
	output wire [bussize:0] psumO0, psumO1;
	reg [bussize:0] psumreg0, psumreg1;
	//weight preload register
	always @(posedge preclk) weightO <= weight;
	//PPGen & ReductionTree
	wire [11:0] encbus;
	booth_encoder #(8) encoder(weightO, encbus);
	wire [35:0] ppbus;
	wire [6:0] corbus;
	ppgen #(8) ppgen(encbus, inO, ppbus, corbus);
	wire [15:0] out0, out1;
	reg [15:0] treereg0, treereg1;
	dadda8 reduc(ppbus, corbus, out0, out1);
	//pipeline-stage register
	always @(posedge clk)begin
		inO <= in;
		psumreg0 <= psum0;
		psumreg1 <= psum1;
		treereg0 <= out0;
		treereg1 <= out1;
	end
	accumulator_rev #(size) acc(treereg0, treereg1, psumreg0, psumreg1, psumO0, psumO1);
endmodule
