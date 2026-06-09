`timescale 1ns/1ps

module input_reg #(
	parameter integer size=16,
	parameter integer width=16)(
	clk,en,dataIn,dataOut);
	input clk;
	input [(size*8/width-1):0] en;
	input [(size*8/width-1):0] dataIn;
	output wire [(size*8-1):0] dataOut;
	genvar i;
	generate
		for(i=0;i<(size*8/width);i=i+1)begin:reg_in
			sipo #(width) reg_in(clk,en[i],dataIn[i],dataOut[i*width+:width]);
		end
	endgenerate
endmodule

module output_reg #(
	parameter integer size=16,
	parameter integer width=16)(
	clk,en,dataIn,dataOut);
	localparam integer bussize =size+16;
	localparam integer regnum =bussize/width;
	input clk;
	input [(size-1):0] en;
	input [(bussize*size-1):0] dataIn;
	output wire [(size*regnum-1):0] dataOut;
	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:reg_out
			for(j=0;j<regnum;j=j+1)begin:num_each	
				piso #(width) reg_out(clk,en[i],dataIn[(i*bussize+j*width)+:width],dataOut[i*regnum+j]);
			end
		end
	endgenerate
endmodule
