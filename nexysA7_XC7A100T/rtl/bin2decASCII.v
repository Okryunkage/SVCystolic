`timescale 1ns/1ps

module bin2decASCII0#(
	parameter binWidth =4,
	parameter digits   =2)(
    input  wire[(binWidth-1):0] bin,
    output reg [(digits*8-1):0] asciiFlat);

	integer i;
	reg[(binWidth-1):0] value;
	reg[3:0] digit;

	always@*begin
		value =bin;
		for(i=0;i<digits;i=i+1) asciiFlat[(i*8)+:8] =`ASCII_0;
		for(i=0;i<digits;i=i+1)begin
			digit =value%10;
			asciiFlat[(i*8)+:8] =`ASCII_0+digit;
			value =value/10;
		end
	end
endmodule

module bin2decASCII1#(
	parameter binWidth =4,
	parameter digits   =2)(
    input  wire[(binWidth-1):0] bin,
    output wire[(digits*8-1):0] asciiFlat);

	function[(digits*8-1):0] toASCII;
		input[(binWidth-1):0] in;
		integer i;
		integer value;
		reg[(digits*8-1):0] result;
		reg[3:0] digit;
		begin
			value  =in;
			result ={digits{`ASCII_0}};//initialize
			for(i=0;i<digits;i=i+1)begin
				digit =value%10;
				result[(i*8)+:8] =`ASCII_0+digit;
				value =value/10;
			end
			toASCII =result;
		end
	endfunction
	assign asciiFlat =toASCII(bin);
endmodule