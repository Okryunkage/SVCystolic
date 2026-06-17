`timescale 1ns/1ps

module B_SA#(
	parameter integer size=16)(
	clk, en,
	weight, in, psum,
	weightO, inO, psumO);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire            clk, en;
	input wire[7:0]       weight, in;
	input wire[buswire:0] psum;
	output reg[7:0]       weightO, inO;
	output reg[buswire:0] psumO;
	wire      [buswire:0] psumW;
	always@(posedge clk)begin
		if(en) weightO <=weight;
		else begin
			inO   <=in;
			psumO <=psumW;
		end
	end
	wire[15:0] result0, result1;
	mulTOP mul(.multiplier(weightO),.multiplicant(inO),.result0(result0),.result1(result1));
	wire[buswire:0] psumS, psumC;
	csa#(17) csa0(.A({~result0[15],result0}),.B({~result1[15],result1}),.C(psum[16:0]),.sum(psumS[16:0]),.cout(psumC[16:0]));
	halfcsa#(bussize-17) hcsa0(.A({(bussize-17){1'b1}}),.B(psum[buswire:17]),.sum(psumS[buswire:17]),.cout(psumC[buswire:17]));
	bka#(bussize) bka0(.a(psumS),.b({psumC[(buswire-1):0],1'b0}),.sum(psumW),.cin(1'b0));
endmodule