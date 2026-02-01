`timescale 1ns/1ps

module accumulator_rev#(
	parameter integer arraysize=16)(
	result0,result1,
	psum0,psum1,
	psumO0,psumO1);
	localparam integer bussize=ceillog2(arraysize)+16;
	localparam integer busize=bussize-1;
	localparam integer busadd=ceillog2(arraysize)-1;
	input [15:0] result0;
	input [15:0] result1;
	input [busize:0] psum0;
	input [busize:0] psum1;
	output [busize:0] psumO0;
	output [busize:0] psumO1;
	wire [16:0] result00 = {~result0[15],result0};
	wire [busize:0] result11 = {{(arraysize-1){1'b1}},~result1[15],result1};
	//----------Stage0----------
	wire [busize:0] stage00, stage01;
	halfadder ha0(psum0[0],psum1[0],stage00[0],stage01[1]);
	wire drop0;
	csa #(busize) csa0(psum0[1+:busize],psum1[1+:busize],result11[1+:busize],stage00[1+:busize],{drop0,stage01[2+:(busize-1)]});
	assign stage01[0] = result11[0];
	//----------Stage1----------
	wire [busize:0] stage10, stage11;
	halfadder ha10(stage00[0],stage01[0],stage10[0],stage11[1]);
	assign stage11[0] = result00[0];
	csa #(16) csa1(stage00[1+:16],stage01[1+:16],result00[1+:16],stage10[1+:16],stage11[2+:16]);
	generate
		if(busadd>1)begin:HAwide
			wire drop1;
			halfcsa #(busadd) ha11(
				stage00[17+:busadd],
				stage01[17+:busadd],
				stage10[17+:busadd],
				{drop1, stage11[18+:(busadd-1)]});
		end
		else if(busadd==1)begin:HAone
			wire drop1;
			halfadder ha11(stage00[17],stage01[17],stage10[17],drop1);
		end
		else begin:HAx
		end
	endgenerate
	//----------Final----------
	assign psumO0 = stage10;
	assign psumO1 = stage11;
endmodule
