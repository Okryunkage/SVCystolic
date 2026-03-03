`timescale 1ns/1ps

module conventl_SA#(
	parameter integer size=4)(
	clk,preclk,
	weight,in,
	result);
	localparam integer buswire=ceillog2(size)+16;
	localparam integer bussize=buswire-1;
	input clk;
	input preclk;
	input wire [(8*size-1):0] weight;
	input wire [(8*size-1):0] in;
	output wire [(size*buswire-1):0] result;
	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j=0;j<size;j=j+1)begin:r
				wire [7:0] weightP;
				wire [7:0] inP;
				wire [bussize:0] psumO;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:row
			for(j=0;j<size;j=j+1)begin:column
				wire [7:0] weightIn;
				wire [7:0] inputIn;
				wire [bussize:0] psumIn;
				if(j==0)begin:leftBoundary
					assign weightIn =weight[i*8+:8];
					assign inputIn  =in[i*8+:8];
				end
				else begin:toRight
					assign weightIn =c[j-1].r[i].weightP;
					assign inputIn =c[j-1].r[i].inP;
				end
				if(i==0)begin:topBoundary
					assign psumIn ={buswire{1'b0}};
				end
				else begin:toBottom
					assign psumIn =c[j].r[i-1].psumO;
				end
				pe_cvt #(size) PE(
					clk,preclk,weightIn,inputIn,psumIn,
					c[j].r[i].weightP,
					c[j].r[i].inP,
					c[j].r[i].psumO);
			end
		end
	endgenerate
	generate
		for(j=0;j<size;j=j+1)begin:finalout
			assign result[j*buswire+:buswire] =c[j].r[size-1].psumO;
		end
	endgenerate
endmodule