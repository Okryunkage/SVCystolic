`timescale 1ns/1ps

module pe_cvt#(
	parameter integer size=16)(
	clk, preclk,
	weight, in, psum,
	weightO, inO, psumO);
	localparam integer buswire=ceillog2(size)+16;
	localparam integer bussize=buswire-1;
	input clk;
	input preclk;
	input [7:0] weight;
	input [7:0] in;
	input [bussize:0] psum;
	output reg [7:0] weightO;
	output reg [7:0] inO;
	output wire [bussize:0] psumO;
	reg [bussize:0] psumreg;
	always@(posedge preclk) weightO <=weight;
	wire [11:0] encbus;
	booth_encoder #(8) encoder(weightO, encbus);
	wire [35:0] ppbus;
	wire [6:0] corbus;
	ppgen #(8) ppgen(encbus, inO, ppbus, corbus);
	wire [15:0] out0, out1;
	dadda8 reduc(ppbus, corbus, out0, out1);
	wire [16:0] mulResult;
	reg [16:0] treeReg;
	//cpaS #(17) mulACC({out0[15],out0}, {out1[15],out1}, mulResult);
	assign mulResult =$signed({out0[15],out0})+$signed({out1[15],out1});
	always@(posedge clk)begin
		inO <=in;
		psumreg <=psum;
		treeReg <=mulResult;
	end
	//cpaS #(buswire) finalacc({{(buswire-17){treeReg[16]}},treeReg},psumreg,psumO);
	assign psumO = $signed(treeReg) + $signed(psumreg);
endmodule