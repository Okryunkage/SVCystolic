`timescale 1ns/1ps
`default_nettype none

module sng_lut#(
	parameter integer prob0=4,
	parameter integer prob1=8,
	parameter integer prob2=12,
	parameter integer prob3=16)(

	input wire clk, rst, rawBit,
	input wire [1:0] probSel,
	output reg randomBit =1'b0,
	output reg randomValid =1'b0);

	function automatic[63:0] buildLUT_init;
		input integer probability0, probability1, probability2, probability3;
		integer address, threshold;
		reg[1:0] selectValue;
		reg[3:0] randomValue;begin
			buildLUT_init =64'b0;
			for(address=0;address<64;address=address+1)begin
				randomValue =address[3:0];
				selectValue =address[5:4];
				case(selectValue)
					2'd0: threshold=probability0;
					2'd1: threshold=probability1;
					2'd2: threshold=probability2;
					default: threshold =probability3;
				endcase
				buildLUT_init[address] =(randomValue<threshold);
			end
		end
	endfunction

	localparam[63:0] LUT_init =buildLUT_init(prob0,prob1,prob2,prob3);

	reg[3:0]  sampleShift =4'b0000;
	reg[1:0]  sampleCount =2'b00;
	wire[3:0] sampleWord  ={sampleShift[2:0],rawBit};
	wire      lutOutput;

	(*keep="true",dont_touch="true"*)
	LUT6#(.INIT(LUT_init)) sng_lut6(
		.I0(sampleWord[0]), .I1(sampleWord[1]),
		.I2(sampleWord[2]), .I3(sampleWord[3]),
		.I4(probSel[0]),    .I5(probSel[1]),
		.O(lutOutput));

	always@(posedge clk)begin
		randomValid <=1'b0;
		if(rst)begin
			sampleShift <=4'b0000;
			sampleCount <=2'b00;
			randomBit   <=1'b0;
		end
		else begin
			sampleShift <=sampleWord;
			if(sampleCount==2'd3)begin
				sampleCount <=2'd0;
				randomBit   <=lutOutput;
				randomValid <=1'b1;
			end
			else begin
				sampleCount <=sampleCount+1'b1;
			end
		end
	end
endmodule
`default_nettype wire
