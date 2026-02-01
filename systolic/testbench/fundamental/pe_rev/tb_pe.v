`include "adder.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator_rev.v"
`include "pe_rev.v"
`include "ceillog2.vh"
`timescale 1ns/1ps

module tb_pe;
	localparam size=4;
	localparam bussize=ceillog2(size)+16;
	localparam busize=bussize-1;
	reg clk, preclk;
	reg [7:0] weight, in;
	reg [busize:0] psum0, psum1;
	wire [7:0] weightO, inO;
	wire [busize:0] psumO0, psumO1;
	wire [bussize:0] out;
	wire [busize:0] finalout;
	pe_rev #(size) pe0(clk,preclk,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
	cpa #(bussize) finaladder(psumO0,psumO1,out);
	assign finalout = out[busize:0];
	//----------
	task test(
		input signed [7:0] t_weight,
		input signed [7:0] t_in,
		input signed [(7+bussize/2):0] t_psum0,
		input signed [(7+bussize/2):0] t_psum1);
		begin
			weight = t_weight;
			preclk = 1'b1; #1;
			psum0 = {{(bussize/2){t_psum0[7+bussize/2]}},t_psum0};
			psum1 = {{(bussize/2){t_psum1[7+bussize/2]}},t_psum1};
			in = t_in;
			preclk = 1'b0;
			#1;
			#4;
		end
	endtask
	//----------
	integer i;
	reg [7:0] i0, i1;
	reg [(7+bussize/2):0] i2, i3;
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_pe);
		clk = 1'b0;
		preclk = 1'b0;
		for (i=0; i<100; i=i+1) begin
			i0 = $random;
			i1 = $random;
			i2 = $random;
			i3 = $random;
			test(i0,i1,i2,i3);
		end
		#10;
		$finish;
	end
	always begin
		clk = ~clk;
		#1;
	end
endmodule


