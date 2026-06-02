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

module argmaxSeq#(
	parameter integer width  =32,
	parameter integer number =10)(
	input wire clk,
	input wire rst,
	input wire start,
	input wire signed[(number*width-1):0] inFlat,
	output reg done,
	output reg busy,
	output reg [($clog2(number)-1):0] outIndex);

	localparam integer idxWidth = $clog2(number);

	localparam [1:0] IDLEs =2'd0;
	localparam [1:0] RUNs  =2'd1;
	localparam [1:0] DONEs =2'd2;

	reg [1:0] state;

	reg [(idxWidth-1):0] idx;
	reg signed [(width-1):0] maxValue;
	reg signed [(width-1):0] currentValue;

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLEs;
			done <=1'b0;
			busy <=1'b0;
			outIndex <={idxWidth{1'b0}};
			idx <={idxWidth{1'b0}};
			maxValue <={width{1'b0}};
			currentValue <={width{1'b0}};
		end
		else begin
			done <=1'b0;

			case(state)
				IDLEs:begin
					busy <=1'b0;

					if(start)begin
						busy <=1'b1;
						idx <={{(idxWidth-1){1'b0}},1'b1};
						outIndex <={idxWidth{1'b0}};
						maxValue <=$signed(inFlat[0+:width]);
						state <=RUNs;
					end
				end

				RUNs:begin
					currentValue <=$signed(inFlat[(idx*width)+:width]);

					if($signed(inFlat[(idx*width)+:width])>maxValue)begin
						maxValue <=$signed(inFlat[(idx*width)+:width]);
						outIndex <=idx;
					end

					if(idx==(number-1))begin
						state <=DONEs;
					end
					else begin
						idx <=idx+1'b1;
					end
				end

				DONEs:begin
					busy <=1'b0;
					done <=1'b1;
					state <=IDLEs;
				end

				default:begin
					state <=IDLEs;
				end
			endcase
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