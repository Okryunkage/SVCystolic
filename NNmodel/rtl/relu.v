`timescale 1ns/1ps

module relu#(
	parameter number =16,
	parameter width =20)(
	input wire signed[(number*width-1):0] inFlat,
	output reg signed[(number*width-1):0] outFlat);

	integer n;
	reg signed[(width-1):0] inElement;

	always@*begin
		for(n=0;n<number;n=n+1)begin
			inElement =inFlat[(n*width)+:width];

			if(inElement[width-1]==1'b1) outFlat ={width{1'b0}};
			else outFlat =inElement;
		end
	end
endmodule