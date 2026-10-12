`timescale 1ns/1ps

module relu#(
	parameter integer number = 16,
	parameter integer width  = 20)(
	input  wire signed[(number*width-1):0] inFlat,
	output reg  signed[(number*width-1):0] outFlat);

	integer n;
	reg signed[width-1:0] inElement;

	always @* begin
		for(n=0; n<number; n=n+1) begin
			inElement =$signed(inFlat[(n*width)+:width]);

			if(inElement[width-1]==1'b1) outFlat[(n*width)+:width] ={width{1'b0}};
			else outFlat[(n*width)+:width] =inElement;
		end
	end
endmodule

module argmax#(
	parameter integer width  =32,
	parameter integer number =10)(
	input wire signed[(number*width-1):0] inFlat,
	output reg[($clog2(number)-1):0] outIndex);

	integer i;
	reg signed[(width-1):0] maxValue;
	reg signed[(width-1):0] currentValue;

	always@(*)begin
		//comparator & MUX chain sturcture
		maxValue =$signed(inFlat[0+:width]);
		outIndex ={$clog2(number){1'b0}};
		for(i=1;i<number;i=i+1)begin
			currentValue =$signed(inFlat[(i*width)+:width]);
			if(currentValue>maxValue)begin
				maxValue =currentValue;
				outIndex =i[($clog2(number)-1):0];
			end
		end
	end
endmodule

module sign#(
	parameter number =5,
	parameter width =32)(
	input wire signed[(number*width-1):0] inFlat,
	output reg[(number-1):0] outBits);

	integer n;
	reg signed[(width-1):0] inElement;

	always@*begin
		for(n=0;n<number;n=n+1)begin
			inElement =$signed(inFlat[(n*width)+:width]);
			if(inElement>0) outBits[n] =1'b1;
			else outBits[n] =1'b0;
		end
	end
endmodule