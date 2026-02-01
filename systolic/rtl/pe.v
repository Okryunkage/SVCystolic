`timescale 1ns/1ps

module pe#(
	parameter integer size=16)(
	clk, preclk,
	weight, in, psum0, psum1,
	weightO, inO, psumO0, psumO1);
	localparam integer bussize=size+16;
	localparam integer busize=bussize-1;
	input clk;
	input preclk;
	input [7:0] weight;
	input [7:0] in;
	input [busize:0] psum0, psum1;
	output reg [7:0] weightO;
	output reg [7:0] inO;
	output wire [busize:0] psumO0, psumO1;
	reg [busize:0] psumreg0, psumreg1;
	//weight_preload register
	always @(posedge preclk) weightO <= weight;
	//PPsGen&Reduction_Tree
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
	accumulator #(size) acc(treereg0,treereg1,psumreg0,psumreg1,psumO0,psumO1);
endmodule

module pe1#(
	parameter size=16)(
		clk,data_sel,
		data,psum0,psum1,
		dataO,psumO0,psumO1);
		localparam bussize =size+16;
		localparam busize =bussize-1;
		input clk, data_sel;
		input [7:0] data;
		input [busize:0] psum0, psum1;
		reg [7:0] weight, in;
		output wire [7:0] dataO;
		reg [busize:0] psumreg0, psumreg1;
		output wire [busize:0] psumO0, psumO1;
		//PPsGen & Reduction tree
		wire [11:0] encbus;
		booth_encoder #(8) encoder(weight,encbus);
		wire [35:0] ppbus;
		wire [6:0] corbus;
		ppgen #(8) ppgen(encbus,in,ppbus,corbus);
		wire [15:0] out0, out1;
		reg [15:0] treereg0, treereg1;
		dadda8 reduc(ppbus,corbus,out0,out1);
		//pipeline stage register
		always @(posedge clk)begin
			if(!data_sel) weight<=data;
			else begin
				in <=data;
				psumreg0 <=psum0;
				psumreg1 <=psum1;
				treereg0 <=out0;
				treereg1 <=out1;
			end
		end
		accumulator #(size) acc(treereg0,treereg1,psumreg0,psumreg1,psumO0,psumO1);
		assign dataO =data_sel?in:weight;
endmodule
