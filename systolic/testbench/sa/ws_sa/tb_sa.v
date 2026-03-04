`include "ceillog2.vh"
`include "adder.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator.v"
`include "pe_cvt.v"
`include "SA_cvt.v"
`timescale 1ns/1ps

module tb_sa;
	localparam size=4;
	localparam buswire=ceillog2(size)+16;
	localparam bussize=buswire-1;
	reg clk, preclk;
	reg [7:0] weight [(size-1):0][(size-1):0];
	reg [7:0] in [(size-1):0][(size-1):0];
	wire [(size*buswire-1):0] result;
	reg [(8*size-1):0] weight_in;
	reg [(8*size-1):0] in_in;
	SA_cvt #(size) sa0(clk,preclk,weight_in,in_in,result);
	//----------
	integer a,b;
	integer ww =0;
	integer ii =0;
	integer i;
	integer j;
	genvar aa,bb;
	generate
		for(aa=0;aa<size;aa=aa+1)begin:col
			wire [bussize:0] resultS;
			assign resultS =result[(aa*buswire)+:buswire];
		end
		for(bb=0;bb<size;bb=bb+1)begin:row
			reg [7:0] weightS;
			reg [7:0] inputS;
			assign weightS =weight_in[(bb*8)+:8];
			assign inputS  =in_in[(bb*8)+:8];
		end
	endgenerate
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
			for(j=0;j<size;j=j+1)begin
				weight_in[(j*8)+:8] = weight[i][j];
			end
			#1; preclk = 1'b1;
			#1; preclk = 1'b0;
		end
		#1;
		/*
		for(i=0;i<size;i=i+1)begin
			for(j=0;j<size;j=j+1) in_in[j] = in[i][j];
			#2;
		end
		*/
		for(i=0;i<(2*size-1);i=i+1)begin
			@(negedge clk);
			for(j=0;j<size;j=j+1)begin
				if((i>=j)&&((i-j)<size)) in_in[(j*8)+:8] =in[i-j][j];
				else in_in[(j*8)+:8] =8'sd0;
			end
		end
		#100;
		$finish;
	end
	always begin
		#1;
		clk = ~clk;
	end
endmodule

