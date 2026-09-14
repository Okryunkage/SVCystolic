`timescale 1ns/1ps

module requantUsign#(
	parameter integer number   =128,
	parameter integer inWidth  =32,
	parameter integer outWidth =12,
	//shift to match the scale of fixed-point parameter
	parameter integer shift    =10)(
	input wire signed[(number*inWidth-1):0] inFlat,
	output reg       [(number*outWidth-1):0] outFlat);

	integer n;
	reg signed[(inWidth-1):0] inElement;
	reg signed[(inWidth-1):0] shifted;
	reg       [(outWidth-1):0] clipped;

	always@(*)begin
		for(n=0;n<number;n=n+1)begin
			inElement =$signed(inFlat[(n*inWidth)+:inWidth]);
			if(inElement<=0) shifted =0;
			//>> : logical shift
			//>>>: arithmetic shift
			else shifted =(inElement+(1<<(shift-1)))>>>shift;
			//(inElement+(1<<(shift-1))) for rounding, then shift right
			if(shifted<0) clipped ={outWidth{1'b0}};
			else if(shifted>((1<<outWidth)-1)) clipped ={outWidth{1'b1}};
			else clipped =shifted[(outWidth-1):0];
			outFlat[(n*outWidth)+:outWidth] =clipped;
		end
	end
endmodule

module requantSign#(
	parameter integer number   =128,
	parameter integer inWidth  =32,
	parameter integer outWidth =12,
	parameter integer shift    =10)(
	input wire signed[(number*inWidth-1):0] inFlat,
	output reg       [(number*outWidth-1):0] outFlat);

	integer n;
	reg signed[(inWidth-1):0] inElement;
	reg signed[(inWidth-1):0] shifted;

	localparam integer postiveShift =(shift>0)?shift:0;
	localparam signed[(outWidth-1):0] outMax ={1'b0,{(outWidth-1){1'b0}}};
	localparam signed[(outWidth-1):0] outMin ={1'b1,{(outWidth-1){1'b0}}};
	localparam signed[(inWidth-1):0]  roundValue =(postiveShift>0)?({{(inWidth-1){1'b0}},1'b1}<<(postiveShift-1)):{inWidth{1'b0}};

	function signed[(inWidth-1):0] shiftRound;
		input signed[(inWidth-1):0] x;
		reg   signed[(inWidth-1):0] absx;
		begin
			if(shift==0) shiftRound =x;
			else if(shift<0) shiftRound =(x<<<(-shift));
			else begin
				if(x>=0) shiftRound =((x+roundValue)>>>shift);
				else begin
					absx =-x;
					shiftRound =-((absx+roundValue)>>>shift);
				end
			end
		end
	endfunction

	always@(*)begin
		for(n=0;n<number;n=n+1)begin
			inElement =$signed(inFlat[(n*inWidth)+:inWidth]);
			shifted =shiftRound(inElement);
			if(shifted>$signed(outMax)) outFlat[(n*outWidth)+:outWidth] =outMax;
			else if(shifted<$signed(outMin)) outFlat[(n*outWidth)+:outWidth] =outMin;
			else outFlat[(n*outWidth)+:outWidth] =shifted[(outWidth-1):0];
		end
	end
endmodule