`timescale 1ns/1ps

module sa#(
	parameter size=4)(
	clk, preclk,
	weight, in,
	result);
	localparam bussize=size+16;
	localparam busize=bussize-1;
	input clk;
	input preclk;
	input wire [7:0] weight [(size-1):0]; //system-verilog type
	input wire [7:0] in [(size-1):0]; //system-verilog type
	output wire [busize:0] result [(size-1):0]; //system-verilog type
	//--------------------------------------------------
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
				weight[i],
				in[i],
				{bussize{1'b0}},
				{bussize{1'b0}},
				c[i].r[0].weightP,
				c[i].r[0].inP,
				c[i].r[0].psum0P,
				c[i].r[0].psum1P);
			for(j=1;j<size;j=j+1)begin:row
				pe #(size) PE(clk,preclk,
					c[i].r[j-1].weightP,
					c[(i+1)%size].r[j-1].inP,
					c[i].r[j-1].psum0P,
					c[i].r[j-1].psum1P,
					c[i].r[j].weightP,
					c[i].r[j].inP,
					c[i].r[j].psum0P,
					c[i].r[j].psum1P);
			end
			cpaS #(bussize) finaladder(
				c[i].r[size-1].psum0P,
				c[i].r[size-1].psum1P,
				result[i]);	
		end
	endgenerate
endmodule

module sa1#(
	parameter size=4)(
	clk,data_sel,data,result);
	localparam bussize=size+16;
	localparam busize=bussize-1;
	input clk, data_sel;
	input wire [(8*size-1):0] data;
	output wire [(size*bussize-1):0] result;
	//------------------------------
	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j=0;j<size;j=j+1)begin:r
				wire [7:0] dataP;
				wire [busize:0] psum0P;
				wire [busize:0] psum1P;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:column
			pe1 #(size) PE1(clk,data_sel,
				data[i*8+:8],
				{bussize{1'b0}},
				{bussize{1'b0}},
				c[i].r[0].dataP,
				c[i].r[0].psum0P,
				c[i].r[0].psum1P);
			for(j=1;j<size;j=j+1)begin:row
				pe1 #(size) PE1(clk,data_sel,
					c[(i+1)%size].r[j-1].dataP,
					c[i].r[j-1].psum0P,
					c[i].r[j-1].psum1P,
					c[i].r[j].dataP,
					c[i].r[j].psum0P,
					c[i].r[j].psum1P);
			end
			cpaS #(bussize) finaladder(
				c[i].r[size-1].psum0P,
				c[i].r[size-1].psum1P,
				result[i*bussize+:bussize]);
		end
	endgenerate
endmodule
