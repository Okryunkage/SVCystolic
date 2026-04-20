`timescale 1ns/1ps

module sign#(
	parameter number =5,
	parameter width =32)(
	input wire signed[(number*width-1):0] inFlat,
	output reg[(number-1):0] outBits);

	integer n;
	reg signed[(width-1):0] inElement;

	always@*begin
		for(n=0;n<number;n=n+1)begin
			inElement =inFlat[(n*width)+:width];
			if(inElement>0) outBits[n] =1'b1;
			else outBits[n] =1'b0;
		end
	end
endmodule