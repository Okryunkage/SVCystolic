`timescale 1ns/1ps

module proposed_bka#(
	parameter integer size=4)(
	clk,preclk,
	weight, in,
	result);
	localparam integer bussize=size+16;
	localparam integer busize=bussize-1;
	input clk;
	input preclk;
	input wire [(8*size-1):0] weight;
	input wire [(8*size-1):0] in;
	output wire [(size*bussize-1):0] result;
	//------------------------------
	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j=0;j<size;j=j+1)begin:r
				wire [7:0] weightP;
				wire [7:0] inP;
				wire [busize:0] psum0P;
				wire [busize:0] psum1P;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:column
			pe #(size) PE(clk,preclk,
				weight[i*8+:8],
				in[i*8+:8],
				{bussize{1'b0}},
				{bussize{1'b0}},
				c[i].r[0].weightP,
				c[i].r[0].inP,
				c[i].r[0].psum0P,
				c[i].r[0].psum1P);
			for(j=1;j<size;j=j+1)begin:row
				pe #(size) PE(clk,preclk,
					c[i].r[j-1].weightP,
					c[(i+size/2+1)%size].r[j-1].inP,
					c[i].r[j-1].psum0P,
					c[i].r[j-1].psum1P,
					c[i].r[j].weightP,
					c[i].r[j].inP,
					c[i].r[j].psum0P,
					c[i].r[j].psum1P);
			end
			bkaS #(bussize) finaladder(
				c[i].r[size-1].psum0P,
				c[i].r[size-1].psum1P,
				result[i*bussize+:bussize]);
		end
	endgenerate
endmodule
