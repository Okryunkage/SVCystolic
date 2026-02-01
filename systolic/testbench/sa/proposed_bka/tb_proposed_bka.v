`include "adder.v"
`include "bka.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator.v"
`include "pe.v"
`include "proposed_bka.v"
`timescale 1ns/1ps

module tb_proposed;
	localparam size=16;
	localparam bussize=size+16;
	localparam busize=bussize-1;
	reg clk,preclk;
	reg [(8*size*size-1):0] weight;
	reg [(8*size*size-1):0] in;
	wire [(size*bussize-1):0] result;
	reg [(8*size-1):0] weight_in;
	reg [(8*size-1):0] in_in;
	proposed_bka #(size) pe0(clk,preclk,weight_in,in_in,result);
	//--------------------
	genvar c,d;
	generate
		for(c=0;c<size;c=c+1)begin:weight_col
			for(d=0;d<size;d=d+1)begin:weight_row
				wire [7:0] weight8;
				assign weight8 =weight[((8*size*c)+8*(d+1)-1)-:8];
			end
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:in_col
			for(d=0;d<size;d=d+1)begin:in_row
				wire [7:0] in8;
				assign in8 =in[((8*size*c)+8*(d+1)-1)-:8];
			end
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:weight_in_col
			wire [7:0] weight_in8;
			assign weight_in8 =weight_in[8*c+:8];
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:in_in_col
			wire [7:0] in_in8;
			assign in_in8 =in_in[8*c+:8];
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:result_col
			wire [busize:0] result8;
			assign result8 =result[bussize*c+:bussize];
		end
	endgenerate
	//--------------------
	task weight_upshift(
		input integer i,
		inout [(8*size-1):0] weightbuff);
		integer sh;
		reg [(8*size-1):0] temp;
		begin
			sh =8*i;
			if(sh==0) temp=weightbuff;
			else temp = (weightbuff>>sh)|(weightbuff<<(8*size-sh));
			weightbuff=temp;
		end
	endtask
	task weight_exchange(
		input integer i,
		inout [(8*size-1):0] weightbuff);
		integer j;
		reg [(8*size-1):0] temp;
		begin
			for(j=0;j<i;j=j+1)begin
				if((j%2)==0) temp[j*8+:8]=weightbuff[j*8+:8];
				else temp[j*8+:8]=weightbuff[((j+i/2)%i)*8+:8];
			end
			weightbuff=temp;
		end
	endtask
	integer a,b;
	integer ww =0;
	integer ii =0;
	integer i,j,k;
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_proposed);
		clk=1'b0;
		preclk=1'b0;
		for(a=0;a<size;a=a+1)begin
			for(b=0;b<size;b=b+1)begin
				ww = ww+1;
				ii = ii-1;
				weight[((8*size*b)+8*(a+1)-1)-:8] =ww;
				in[((8*size*b)+8*(a+1)-1)-:8] =ii;
			end
		end
		#5;
		for(i=0;i<size;i=i+1)begin
			weight_upshift(i,weight[(8*size*(i+1)-1)-:8*size]);
		end
		#5;
		for(i=0;i<size;i=i+1)begin
			weight_exchange(size,weight[(8*size*(i+1)-1)-:8*size]);
		end
		for(i=0;i<size;i=i+1)begin
			for(j=0;j<size;j=j+1)begin
				for(k=0;k<8;k=k+1) weight_in[j*8+k] =weight[8*size*j+8*(size-i-1)+k];
			end
			#1; preclk=1'b1;
			#1; preclk=1'b0;
		end
		for(i=0;i<size;i=i+1)begin
			for(j=0;j<size;j=j+1)begin
				for(k=0;k<8;k=k+1) in_in[j*8+k] =in[8*size*j+8*i+k];
			end
			#2;
		end
		#100;
		$finish;
	end
	always begin
		#1;
		clk=~clk;
	end
endmodule
