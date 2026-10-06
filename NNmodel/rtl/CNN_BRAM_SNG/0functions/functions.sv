`timescale 1ns/1ps

module relu#(
	parameter integer number =16,
	parameter integer width  =20)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic signed[width-1:0] outData[0:number-1]);

	integer n;
	always_comb begin
		for(n=0;n<number;n=n+1)begin
			if(inData[n][width-1]) outData[n] ='0;
			else outData[n] =inData[n];
		end
	end
endmodule

module argmax#(
	parameter integer width  =32,
	parameter integer number =10)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic[((number>1)?$clog2(number):1)-1:0] outIndex);

	localparam integer indexWidth=(number>1)?$clog2(number):1;
	integer i;
	logic signed[width-1:0] maxValue;
	always_comb begin
		maxValue =inData[0];
		outIndex ='0;
		for(i=1;i<number;i=i+1)begin
			if(inData[i]>maxValue)begin
				maxValue =inData[i];
				outIndex =indexWidth'(i);
			end
		end
	end
endmodule

module sign#(
	parameter number =5,
	parameter width  =32)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic outBits[0:number-1]);

	integer n;
	always_comb begin
		for(n=0;n<number;n=n+1)begin
			if(inData[n]>0) outBits[n] =1'b1;
			else outBits[n] =1'b0;
		end
	end
endmodule
