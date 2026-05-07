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