`timescale 1ns/1ps

module SA_IOr#(
	parameter integer size=16)(
	clk,preclk,
	weight,in,result);
	localparam integer buswire =ceillog2(size)+16;
	localparam integer bussize =buswire-1;
	input clk, preclk;
	input  wire [(8*size-1):0] weight;
	input  wire [(8*size-1):0] in;
	output wire [(buswire*size-1):0] result;
	wire        [(buswire*size-1):0] resultX;
	wire        [(8*size-1):0] inX;
	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:inoutReg
			for(j=0;j<i;j=j+1)begin:step
				reg[7:0] in;
				reg[bussize:0] result;
			end
			for(j=i;j>1;j=j-1)begin
				always@(posedge clk)begin
					step[j-1].in <=step[j-2].in;
				end
			end
			for(j=1;j<i;j=j+1)begin
					always@(posedge clk) step[j-1].result <=step[j].result;
			end
			if(i==0)begin
				assign inX[8*i+:8] =in[8*i+:8];
				assign result[buswire*(size-1-i)+:buswire] =resultX[buswire*(size-1-i)+:buswire];
			end
			else begin
				assign inX[8*i+:8] =step[i-1].in;
				always@(posedge clk) step[i-1].result <=resultX[buswire*(size-1-i)+:buswire];
				always@(posedge clk) step[0].in <= in[8*i+:8];
				assign result[buswire*(size-1-i)+:buswire] =step[0].result;
			end
		end
	endgenerate

    SA_cvt #(size) SA(clk, preclk, weight, inX, resultX);
endmodule