`timescale 1ns/1ps

module CPA_FSA_pip#(
	parameter integer size=16)(
	clk, en,
	weight, in, psum0, psum1,
	weightO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire             clk, en;
	input wire[7:0]        weight, in;
	input wire[buswire:0]  psum0, psum1;
	output reg[7:0]        weightO, inO;
	output wire[buswire:0] psumO0, psumO1;
	reg[buswire:0] psumreg0, psumreg1;
	always@(posedge clk)begin
		if(en) weightO <=weight;
		else begin
			inO <=in;
			psumreg0 <=psum0;
			psumreg1 <=psum1;
		end
	end
	wire[15:0] out0,out1;
	mulTOPpip mul(.clk(clk),.multiplier(weightO),.multiplicant(inO),.result0(out0),.result1(out1));
	accumulator#(size) acc(out0,out1,psumreg0,psumreg1,psumO0,psumO1);
endmodule

module CPA_FSA#(
	parameter integer size=16)(
	clk, en,
	weight, in, psum0, psum1,
	weightO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire             clk, en;
	input wire [7:0]       weight, in;
	input wire [buswire:0] psum0, psum1;
	output reg [7:0]       weightO, inO;
	output wire[buswire:0] psumO0, psumO1;
	reg[buswire:0] psumreg0, psumreg1;
	always@(posedge clk)begin
		if(en) weightO <=weight;
		else begin
			inO <=in;
			psumreg0 <=psum0;
			psumreg1 <=psum1;
		end
	end
	wire[15:0] result0, result1;
	mulTOP mul(.multiplier(weightO),.multiplicant(inO),.result0(result0),.result1(result1));
	accumulator#(size) acc(result0,result1,psumreg0,psumreg1,psumO0,psumO1);
endmodule

module CPA_FSA_enc#(
	parameter integer size=16)(
	clk, en,
	enc, in, psum0, psum1,
	encO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire             clk, en;
	input wire [7:0]       in;
	input wire [11:0]      enc;
	input wire [buswire:0] psum0, psum1;
	output reg [7:0]       inO;
	output reg [11:0]      encO;
	output wire[buswire:0] psumO0, psumO1;
	reg[buswire:0] psumreg0, psumreg1;
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
	accumulator#(size) acc(result0,result1,psumreg0,psumreg1,psumO0,psumO1);
endmodule

module CPA_FSA_epp#(
	parameter integer size=16)(
	clk, en,
	enc, in, psum0, psum1,
	encO, inO, psumO0, psumO1);
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	input wire             clk, en;
	input wire [7:0]       in;
	input wire [11:0]      enc;
	input wire [buswire:0] psum0, psum1;
	output reg [7:0]       inO;
	output reg [11:0]      encO;
	output wire[buswire:0] psumO0, psumO1;
	reg[buswire:0] psumreg0, psumreg1;
	always@(posedge clk)begin
		if(en) encO <=enc;
		else begin
			inO <=in;
			psumreg0 <=psum0;
			psumreg1 <=psum1;
		end
	end
	wire[15:0] result0, result1;
	mulTOPepp mul(.clk(clk),.encbus(encO),.multiplicant(inO),.result0(result0),.result1(result1));
	accumulator#(size) acc(result0,result1,psumreg0,psumreg1,psumO0,psumO1);
endmodule