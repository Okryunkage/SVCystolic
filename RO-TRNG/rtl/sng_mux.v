`timescale 1ns/1ps
`default_nettype none

module sng_mux(
	input wire clk, rst, rawBit,
	input wire [3:0] probability,
	output reg randomBit   =1'b0,
	output reg randomValid =1'b0);

	reg[3:0]  sampleShift =4'b0000;
	reg[1:0]  sampleCount =2'b00;
	wire[3:0] sampleWord  ={sampleShift[2:0],rawBit};

	wire MUXstage1 =sampleWord[1]?(sampleWord[0] &probability[0]):probability[1];
	wire MUXstage2 =sampleWord[2]?probability[2]:MUXstage1;
	wire MUXoutput =sampleWord[3]?probability[3]:MUXstage2;

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
				randomBit   <=MUXoutput;
				randomValid <=1'b1;
			end
			else begin
				sampleCount <=sampleCount+1'b1;
			end
		end
	end
endmodule
`default_nettype wire
