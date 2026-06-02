`timescale 1ns/1ps

module wallace8old(
	input [35:0] ppbus, input [6:0] cor,
	output [14:0] out0, output [12:0] out1);
	localparam integer ppsize = 9;
	localparam integer corsize = ppsize-2;
	//----------Stage0----------
	wire [corsize+3:0] in0 = {4'b0,cor};
	wire [ppsize+1:0] in1 = {{2{ppbus[ppsize-1]}},ppbus[0+:9]};
	wire [ppsize-1:0] in2 = ppbus[ppsize+:9];
	wire [10:0] stage00, stage01;
	halfcsa #(2) h0(.A(in0[1:0]), .B(in1[1:0]), .sum(stage00[1:0]), .cout(stage01[1:0]));
	csa #(9) c0(in0[2+:9],in1[2+:9],in2[0+:9],stage00[2+:9],stage01[2+:9]);
	//----------Stage1----------
	wire [ppsize-1:0] in3 = ppbus[2*ppsize+:9];
	wire [11:0] stage00s, stage01s;
	assign stage00s = {{2{stage00[10]}},stage00[10-:10]};
	assign stage01s = {stage01[10],stage01};
	wire [11:0] stage10, stage11;
	halfcsa #(3) h1(stage00s[0+:3],stage01s[0+:3],stage10[0+:3],stage11[0+:3]);
	csa #(9) c1(stage00s[3+:9],stage01s[3+:9],in3,stage10[3+:9],stage11[3+:9]);
	//----------Stage2----------
	wire [ppsize-1:0] in4 = ppbus[3*ppsize+:9];
	wire [12:0] stage10s, stage11s;
	assign stage10s = {{2{stage10[11]}},stage10[11-:11]};
	assign stage11s = {stage11[11],stage11};
	wire [12:0] stage20, stage21;
	halfcsa #(4) h2(stage10s[0+:4],stage11s[0+:4],stage20[0+:4],stage21[0+:4]);
	csa #(9) c2(stage10s[4+:9],stage11s[4+:9],in4,stage20[4+:9],stage21[4+:9]);
	//----------Final----------
	assign out0 = {stage20,stage10[0],stage00[0]};
	assign out1 = stage21;
endmodule

module wallace8(
	input [35:0] ppbus, input [6:0] cor,
	output [15:0] out0, output [12:0] out1);
	localparam integer ppsize = 9;
	localparam integer corsize = ppsize-2;
	wire [11:0] in0 = {~ppbus[ppsize-1],{2{ppbus[ppsize-1]}},ppbus[0+:ppsize]};
	wire [10:0] in1 = {1'b1, ~ppbus[2*ppsize-1],ppbus[ppsize+:9]};
	wire [10:0] in2 = {1'b1, ~ppbus[3*ppsize-1],ppbus[(2*ppsize)+:9]};
	wire [9:0] in3 = {~ppbus[4*ppsize-1],ppbus[(3*ppsize)+:9]};
	//----------Stage0----------
	wire [12:0] stage00;
	wire [11:0] stage01;
	halfcsa #(2) h00(.A(cor[1:0]),.B(in0[1:0]),.sum(stage00[1:0]),.cout(stage01[1:0]));
	csa #(5) c0(cor[2+:5],in0[2+:5],in1[0+:5],stage00[2+:5],stage01[2+:5]);
	halfcsa #(5) h01(in0[7+:5],in1[5+:5],stage00[7+:5],stage01[7+:5]);
	assign stage00[12] = in1[10];
	//----------Stage1----------
	wire [13:0] stage10;
	wire [12:0] stage11;
	assign stage10[0]=stage00[0];
	halfcsa #(3) h10(stage00[3:1],stage01[2:0],stage10[3:1],stage11[2:0]);
	csa #(9) c1(stage00[4+:9],stage01[3+:9],in2[0+:9],stage10[4+:9],stage11[3+:9]);
	assign stage10[13] = in2[9];
	assign stage11[12] = in2[10];
	//----------Stage2----------
	wire [15:0] stage20;
	wire [12:0] stage21;
	assign stage20[1:0] = stage10[1:0];
	halfcsa #(4) h20(stage10[2+:4],stage11[0+:4],stage20[2+:4],stage21[0+:4]);
	csa #(8) c2(stage10[6+:8],stage11[4+:8],in3[0+:8],stage20[6+:8],stage21[4+:8]);
	halfcsa #(1) h21(stage11[12],in3[8],stage20[14],stage21[12]);
	assign stage20[15] = in3[9];
	//----------Final----------
	assign out0 = stage20;
	assign out1 = stage21;
endmodule

module dadda8(
	input [35:0] ppbus, input [6:0] cor,
	output [15:0] out0, output [15:0] out1);
	localparam integer ppsize = 9;
	localparam integer corsize = ppsize-2;
	wire [11:0] in0 = {~ppbus[ppsize-1],{2{ppbus[ppsize-1]}},ppbus[0+:ppsize]};
	wire [10:0] in1 = {1'b1, ~ppbus[2*ppsize-1],ppbus[ppsize+:9]};
	wire [10:0] in2 = {1'b1, ~ppbus[3*ppsize-1],ppbus[(2*ppsize)+:9]};
	wire [9:0] in3 = {~ppbus[4*ppsize-1],ppbus[(3*ppsize)+:9]};
	wire [15:0] in00 = {in3[9],in2[10-:2],in1[10],in0[11-:5],cor};
	wire [14:0] in11 = {in3[8-:2],in2[8],in1[9-:5],in0[6:0]};
	wire [10:0] in22 = {in3[6],in2[7-:5],in1[4:0]};
	wire [7:0] in33 = {in3[5-:5],in2[2:0]};
	wire in44 = in3[0];
	//----------Stage0----------
	wire [15:0] stage00;
	wire [14:0] stage01;
	wire [10:0] stage02 = in22;
	wire [8:0] stage03;
	assign stage03[7:0] = in33;
	assign {stage00[15:12],stage00[5:0]} = {in00[15:12],in00[5:0]};
	assign {stage01[14:12],stage01[6:0]} = {in11[14:12],in44,in11[5:0]};
	halfcsa #(6) h0(in00[6+:6],in11[6+:6],stage00[6+:6],{stage03[8],stage01[7+:5]});
	//----------Stage1----------
	wire [15:0] stage10;
	wire [14:0] stage11;
	wire [11:0] stage12;
	assign {stage10[15-:3],stage10[3:0]} = {stage00[15-:3],stage00[3:0]};
	assign {stage11[14-:2],stage11[3:0]} = {stage01[14-:2],stage01[3:0]};
	assign stage12[2:0] = stage02[2:0];
	halfcsa #(1) h1(stage00[4],stage01[4],stage10[4],stage11[5]);
	csa #(8) c1(stage00[5+:8],stage01[5+:8],stage02[3+:8],stage10[5+:8],{stage12[11],stage11[6+:7]});
	assign {stage12[10-:8],stage11[4]} = stage03;
	//----------Stage2----------
	wire [15:0] stage20, stage21;
	assign {stage20[15],stage20[1:0]} = {stage10[15],stage00[1:0]};
	assign stage21[2:0] = {stage12[0],stage11[1:0]};
	halfcsa #(1) h20(stage10[2],stage11[2],stage20[2],stage21[3]);
	csa #(11) c2(stage10[3+:11],stage11[3+:11],stage12[1+:11],stage20[3+:11],stage21[4+:11]);
	halfcsa #(1) h21(stage10[14],stage11[14],stage20[14],stage21[15]);
	//----------Final----------
	assign out0 = stage20;
	assign out1 = stage21;
endmodule
