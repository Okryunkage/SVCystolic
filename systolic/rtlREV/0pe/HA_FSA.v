`timescale 1ns/1ps

module HA_FSA_enc#(
	parameter integer size=16,
	parameter integer k   =4)(
	//k should be greater than 2
	clk, en,
	enc, in, psum0, psum1,
	encO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire clk, en;
	input wire[7:0] in;
	input wire[11:0] enc;
	input wire[(buswire-k):0] psum0;
	input wire[buswire:0] psum1;
	output reg[7:0] inO;
	output reg[11:0] encO;
	output wire[buswire:0] psumO1;
	output wire[(buswire-k):0] psumO0;
	reg[buswire:0] psumreg1;
	reg[(buswire-k):0] psumreg0;
	always@(posedge clk)begin
		if(en) encO <=enc;
		else begin
			inO <=in;
			psumreg0 <=psum0;
			psumreg1 <=psum1;
		end
	end
	wire[15:0] result0, result1;
	mulTOPenc mul(.encbus(encO),.multiplicant(inO),.result0(result0),.result1(result1));
	wire[buswire:0] psumS, psumC;
	csa#(17) csa0(.A({~result0[15],result0}),.B({~result1[15],result1}),.C(psumreg1[16:0]),.sum(psumS[16:0]),.cout(psumC[16:0]));
	halfcsa#(bussize-17) hcsa0(.A({(bussize-17){1'b1}}),.B(psumreg1[buswire:17]),.sum(psumS[buswire:17]),.cout(psumC[buswire:17]));
	cpa#(k) cpa0(.A(psumS[(k-1):0]),.B({psumC[(k-2):0],{1'b0}}),.sum({psumO0[0],psumO1[(k-1):0]}));
	wire[(buswire-k):0] coutW;
	csa#(bussize-k) csa1(.A(psumreg0),.B(psumC[(buswire-1)-:(bussize-k)]),.C(psumS[buswire-:(bussize-k)]),.sum(psumO1[buswire:k]),.cout(coutW));
	assign psumO0[(buswire-k):1] =coutW[(buswire-k-1):0];
endmodule

module HA_FSA#(
	parameter integer size=16,
	parameter integer k   =4)(
	//k should be greater than 2
	clk, en,
	weight, in, psum0, psum1,
	weightO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire clk, en;
	input wire[7:0] in, weight;
	input wire[(buswire-k):0] psum0;
	input wire[buswire:0] psum1;
	output reg[7:0] inO, weightO;
	output wire[buswire:0] psumO1;
	output wire[(buswire-k):0] psumO0;
	reg[buswire:0] psumreg1;
	reg[(buswire-k):0] psumreg0;
	always@(posedge clk)begin
		if(en) weightO <=weight;
		else begin
			inO <=in;
			psumreg0 <=psum0;
			psumreg1 <=psum1;
		end
	end
	wire[15:0] result0, result1;
	mulTOP mul0(.multiplier(weightO),.multiplicant(inO),.result0(result0),.result1(result1));
	wire[buswire:0] psumS, psumC;
	csa#(17) csa0(.A({~result0[15],result0}),.B({~result1[15],result1}),.C(psumreg1[16:0]),.sum(psumS[16:0]),.cout(psumC[16:0]));
	halfcsa#(bussize-17) hcsa0(.A({(bussize-17){1'b1}}),.B(psumreg1[buswire:17]),.sum(psumS[buswire:17]),.cout(psumC[buswire:17]));
	cpa#(k) cpa0(.A(psumS[(k-1):0]),.B({psumC[(k-2):0],{1'b0}}),.sum({psumO0[0],psumO1[(k-1):0]}));
	wire[(buswire-k):0] coutW;
	csa#(bussize-k) csa1(.A(psumreg0),.B(psumC[(buswire-1)-:(bussize-k)]),.C(psumS[buswire-:(bussize-k)]),.sum(psumO1[buswire:k]),.cout(coutW));
	assign psumO0[(buswire-k):1] =coutW[(buswire-k-1):0];
endmodule