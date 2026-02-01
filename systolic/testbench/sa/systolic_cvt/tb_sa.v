`include "adder.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator.v"
`include "pe.v"
`include "sa.v"
`timescale 1ns/1ps

module tb_sa;
	localparam size=4;
	localparam bussize=size+16;
	localparam busize=bussize-1;
	reg clk, preclk;
	reg [7:0] weight [(size-1):0][(size-1):0];
	reg [7:0] in [(size-1):0][(size-1):0];
	wire [busize:0] result [(size-1):0];
	reg [7:0] weight_in[(size-1):0];
	reg [7:0] in_in[(size-1):0];
	sa #(size) pe0(clk,preclk,weight_in,in_in,result);
	//----------
	integer a,b;
	integer ww =0;
	integer ii =0;
	integer i;
	integer j;
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_sa);
		clk = 1'b0;
		preclk = 1'b0;
		for(a=0;a<size;a=a+1)begin
			for(b=0;b<size;b=b+1)begin
				ww = ww+1;
				weight[a][b] =ww; 
			end
		end
		for(a=0;a<size;a=a+1)begin
			for(b=0;b<size;b=b+1)begin
				ii =ii-1;
				in[a][b] =ii;
			end
		end
		for(i=0;i<size;i=i+1)begin
			for(j=0;j<size;j=j+1) weight_in[j] = weight[i][j];
			#1; preclk = 1'b1;
			#1; preclk = 1'b0;
		end
		#1;
		for(i=0;i<size;i=i+1)begin
			for(j=0;j<size;j=j+1) in_in[j] = in[i][j];
			#2;
		end
		#100;
		$finish;
	end
	always begin
		#1;
		clk = ~clk;
	end
endmodule

