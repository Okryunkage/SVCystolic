`timescale 1ns/1ps

// Compile as SystemVerilog: each unpacked array element is one lane.

module requantUsign#(
	parameter int number =128,
	parameter int inWidth =32,
	parameter int outWidth =12,
	//shift to match the scale of fixed-point parameter
	parameter int shift =10)(
	input wire logic signed[inWidth-1:0] inData[0:number-1],
	output logic[outWidth-1:0] outData[0:number-1]);

	integer n;
	logic signed[(inWidth-1):0] inElement;
	logic signed[(inWidth-1):0] shifted;
	logic       [(outWidth-1):0] clipped;

	always_comb begin
		for(n =0;n<number;n =n+1)begin
			inElement =inData[n];
			if(inElement <=0) shifted =0;
			//>> : logical shift
			//>>>: arithmetic shift
			else shifted =(inElement+(1<<(shift-1)))>>>shift;
			//(inElement+(1<<(shift-1))) for rounding, then shift right
			if(shifted<0) clipped ={outWidth{1'b0}};
			else if(shifted>((1<<outWidth)-1)) clipped ={outWidth{1'b1}};
			else clipped =shifted[(outWidth-1):0];
			outData[n] =clipped;
		end
	end
endmodule

module requantSign#(
	parameter int number =128,
	parameter int inWidth =32,
	parameter int outWidth =12,
	parameter int shift =10)(
	input wire logic signed[inWidth-1:0] inData[0:number-1],
	output logic signed[outWidth-1:0] outData[0:number-1]);

	integer n;
	logic signed[(inWidth-1):0] inElement;
	logic signed[(inWidth-1):0] shifted;

	localparam int postiveShift =(shift>0)?shift:0;
	localparam signed[(outWidth-1):0] outMax ={1'b0,{(outWidth-1){1'b0}}};
	localparam signed[(outWidth-1):0] outMin ={1'b1,{(outWidth-1){1'b0}}};
	localparam signed[(inWidth-1):0]  roundValue =(postiveShift>0)?({{(inWidth-1){1'b0}},1'b1}<<(postiveShift-1)):{inWidth{1'b0}};

	function signed[(inWidth-1):0] shiftRound;
		input signed[(inWidth-1):0] x;
		logic   signed[(inWidth-1):0] absx;
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

	always_comb begin
		for(n =0;n<number;n =n+1)begin
			inElement =inData[n];
			shifted =shiftRound(inElement);
			if(shifted>$signed(outMax)) outData[n] =outMax;
			else if(shifted<$signed(outMin)) outData[n] =outMin;
			else outData[n] =shifted[(outWidth-1):0];
		end
	end
endmodule
