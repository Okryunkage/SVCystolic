`timescale 1ns/1ps

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