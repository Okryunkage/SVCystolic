`timescale 1ns/1ps

module register #(
	parameter integer size=8)(
	input clk, input en, input [(size-1):0] dataIn,
	output reg [(size-1):0] dataOut);
	always@(posedge clk)begin
		if(en) dataOut <= dataIn;
	end
endmodule

module sipo #(
	parameter integer size=8)(
	input clk, input en, input dataIn,
	output reg [(size-1):0] dataOut);
	always@(posedge clk)begin
		if(!en) dataOut <= {dataOut[(size-2):0],dataIn};
	end
endmodule

module piso #(
	parameter integer size=8)(
	clk,en,dataIn,dataOut);
	input clk,en;
	input [(size-1):0] dataIn;
	reg [(size-1):0] data_reg;
	output wire dataOut;
	always @(posedge clk)begin
		if(en) data_reg <= dataIn;
		else data_reg <= data_reg <<1;
	end
	assign dataOut=data_reg[size-1];
endmodule
