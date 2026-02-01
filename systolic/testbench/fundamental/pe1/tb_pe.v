`include "adder.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator.v"
`include "pe.v"
`timescale 1ns/1ps

module tb_pe;
	localparam size=4;
	localparam bussize=size+16;
	localparam busize=bussize-1;
	reg clk, preclk;
	reg [7:0] weight, in;
	reg [busize:0] psum0, psum1;
	wire [7:0] weightO, inO;
	wire [busize:0] psumO0, psumO1;
	wire [bussize:0] out;
	wire [busize:0] finalout;
	pe #(size) pe0(clk,preclk,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
	cpa #(bussize) finaladder(psumO0,psumO1,out);
	assign finalout = out[busize:0];
	//----------
	task test(
		input signed [7:0] t_in,
		input signed [(15+size/2):0] t_psum0,
		input signed [(15+size/2):0] t_psum1);
		begin
			psum0 = {{(size/2){t_psum0[15+size/2]}},t_psum0};
			psum1 = {{(size/2){t_psum1[15+size/2]}},t_psum1};
			in = t_in;
			#2;
		end
	endtask
	//----------
	integer i;
	reg [7:0] i0, i1;
	reg [(15+size/2):0] i2, i3;
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_pe);
		clk = 1'b0;
		i0 = $random;
		weight = i0;
		preclk = 1'b0; #1;
		preclk = 1'b1; #1;
		preclk = 1'b0;
		for (i=0; i<100; i=i+1) begin
			i1 = $random;
			i2 = $random;
			i3 = $random;
			test(i1,i2,i3);
		end
		#10;
		$finish;
	end
	always begin
		#1;
		clk = ~clk;
	end
endmodule

