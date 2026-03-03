`timescale 1ns/1ps

module dip#(
	parameter size=4)(
	clk, preclk,
	weight, in,
	result);
	localparam buswire=ceillog2(size)+16;
	localparam bussize=buswire-1;
	input clk, preclk;
	input wire [(8*size-1):0] weight;
	input wire [(8*size-1):0] in;
	output wire [(size*buswire-1):0] result;

	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j=0;j<size;j=j+1)begin:r
				wire [7:0] weightP;
				wire [7:0] inP;
				wire [bussize:0] psumP;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:column
			pe_cvt #(size) PE(clk, preclk,
				weight[i*8+:8],
				in[i*8+:8],
				{buswire{1'b0}},
				c[i].r[0].weightP,
				c[i].r[0].inP,
				c[i].r[0].psumP);
			for(j=1;j<size;j=j+1)begin:row
				pe_cvt #(size) PE(clk, preclk,
					c[i].r[j-1].weightP,
					c[(i+1)%size].r[j-1].inP,
					c[i].r[j-1].psumP,
					c[i].r[j].weightP,
					c[i].r[j].inP,
					c[i].r[j].psumP);
			end
		end
		for(i=0;i<size;i=i+1) assign result[i*buswire+:buswire] =c[i].r[size-1].psumP;
	endgenerate
endmodule