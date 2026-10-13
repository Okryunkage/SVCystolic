`timescale 1ns/1ps

//Uniform independent 4-bit words: reject 10..15, use uniform decimal digits.
//Drop 1/10 for layer 1 channels and 2/10 for layer 2 channels.
//This preserves the original probabilities, unlike a direct N/16 threshold.
module dropChannelMask#(
	parameter bit useLutBits =1'b0,
	parameter int channels1 =32,channels2 =64)(
	input logic clk,rst,start,
	input logic[3:0] randomWord,
	input logic randomValid,
	output wire logic randomReady,
	output logic busy,done,
	output logic[channels1-1:0] mask1,
	output logic[channels2-1:0] mask2);
	localparam int indexWidth =(channels1+channels2>1)?$clog2(channels1+channels2):1;
	logic[indexWidth-1:0] index;
	assign randomReady =busy && !rst;
	always_ff@(posedge clk)begin
		if(rst)begin
			busy <=0;
			done <=0;
			index <='0;
			mask1 <='1;
			mask2 <='1;
		end
		else begin
			done <=0;
			if(start && !busy)begin
				busy <=1;
				index <='0;
				mask1 <='1;
				mask2 <='1;
			end
			else if(busy && randomValid && (useLutBits || randomWord<10))begin
				if(index<channels1) mask1[index] <=useLutBits?!randomWord[0]:(randomWord>=1);
				else mask2[index-channels1] <=useLutBits?!randomWord[1]:(randomWord>=2);
				if(index==channels1+channels2-1)begin
					busy <=0;
					done <=1;
				end
				else index <=index+1'b1;
			end
		end
	end
	`ifndef SYNTHESIS
	initial if(channels1<1 || channels2<1) $fatal(1,"Mask channel counts must be positive");
	`endif
endmodule

//Attach the sampled bit from the existing RO source here; the RO is unchanged.
//A producer may ignore ready: unused complete words are discarded, not buffered.
module rngWord4(
	input logic clk,rst,rawBit,
	output logic[3:0] randomWord,
	output logic randomValid);
	logic[3:0] samples;
	logic[1:0] count;
	always_ff@(posedge clk)begin
		if(rst)begin
			samples <=0;
			count <=0;
			randomWord <=0;
			randomValid <=0;
		end
		else begin
			randomValid <=0;
			samples <={samples[2:0],rawBit};
			count <=count+1'b1;
			if(count==3)begin
				randomWord <={samples[2:0],rawBit};
				randomValid <=1;
			end
		end
	end
endmodule
