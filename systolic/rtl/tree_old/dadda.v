`timescale 1ns/1ps
//d_(k+1) = floor(3/2 * d_k), d_1 =2
//d_2=3, d_3=4, d_4=6, d_5=9 ...
module dadda_i5c(
	input [35:0] pp,
	input [7:0] cor,
	output [14:0] out0,
	output [13:0] out1);
    localparam integer ppWidth = 9;
    wire [14:0] in0 = {pp[(4*ppWidth-1) -:2], pp[(3*ppWidth-1) -:2], pp[(2*ppWidth-1) -:2],pp[ppWidth-1],cor};
    wire [12:0] in1 = {pp[(4*ppWidth-3) -:2], pp[(3*ppWidth-3) -:2], pp[(2*ppWidth-3) -:1],pp[(ppWidth-2) -:8]};
    wire [8:0] in2 = {pp[(4*ppWidth-5) -:2], pp[(3*ppWidth-5) -:1], pp[(2*ppWidth-4):ppWidth]};
    wire [4:0] in3 = {pp[(4*ppWidth-7) -:1], pp[(3*ppWidth-6):(2*ppWidth)]}; 
    wire [1:0] in4 = pp[(4*ppWidth-8):(3*ppWidth)];
	//----------Stage0----------
    wire [14:0] stage00;
    wire [12:0] stage01;
    wire [8:0] stage02;
    wire [5:0] stage03;
    halfadder ha00(in0[6], in1[6], stage00[6], stage01[7]);
    fulladder fa0(in0[7], in1[7], in2[5], stage00[7], stage01[8]);
    halfadder ha01(in0[8], in1[8], stage00[8], stage03[5]);
    assign {stage00[14:9],stage00[5:0]} = {in0[14:9],in0[5:0]}; 
    assign {stage01[12:9],stage01[6:0]} = {in1[12:9],in4[0],in1[5:0]};
    assign stage02 = {in2[8:6],in4[1],in2[4:0]};
    assign stage03[4:0] = in3;
	//----------Stage1----------
    wire [14:0] stage10;
    wire [12:0] stage11;
    wire [9:0] stage12;
    halfadder ha10(stage00[4],stage01[4],stage10[4],stage11[5]);
    csa #(5) csa1(stage00[5 +:5], stage01[5 +:5], stage02[3 +:5], stage10[5 +:5], stage11[6 +:5]);
    halfadder ha11(stage00[10],stage01[10],stage10[10],stage12[9]);
    assign {stage10[14 -:4],stage10[3:0]} = {stage00[14 -:4],stage00[3:0]};
    assign {stage11[12 -:2],stage11[4:0]} = {stage01[12 -:2],stage03[0],stage01[3:0]};
    assign stage12[8:0] = {stage02[8],stage03[5:1],stage02[2:0]};
    //----------Stage2----------
    wire[14:0] stage20;
    wire[13:0] stage21;
    halfadder ha20(stage10[2],stage11[2],stage20[2],stage21[3]);
    csa #(9) csa2(stage10[3 +:9], stage11[3 +:9], stage12[1 +:9], stage20[3 +:9], stage21[4 +:9]);
    halfadder ha21(stage10[12],stage11[12],stage20[12],stage21[13]);
    assign stage20[1:0] = stage10[1:0];
    assign stage20[14:13] = stage10[14:13];
    assign stage21[2:0] = {stage12[0],stage11[1:0]};
	//----------Final-----------
    assign out0 = stage20;
    assign out1 = stage21;
endmodule

module dadda_i9c(
	input [135:0] pp,
	input [15:0] cor,
	output [30:0] out0,
	output [29:0] out1);
    localparam integer ppWidth = 17;
    wire [30:0] in0 = {pp[(8*ppWidth-1) -:2], pp[(7*ppWidth-1) -:2], pp[(6*ppWidth-1) -:2], pp[(5*ppWidth-1) -:2],
        pp[(4*ppWidth-1) -:2], pp[(3*ppWidth-1) -:2], pp[(2*ppWidth-1) -:2], pp[ppWidth-1],cor};
    wire [28:0] in1 = {pp[(8*ppWidth-3) -:2], pp[(7*ppWidth-3) -:2], pp[(6*ppWidth-3) -:2], pp[(5*ppWidth-3) -:2],
        pp[(4*ppWidth-3) -:2], pp[(3*ppWidth-3) -:2], pp[(2*ppWidth-3) -:1], pp[(ppWidth-2):0]};
    wire [24:0] in2 = {pp[(8*ppWidth-5) -:2], pp[(7*ppWidth-5) -:2], pp[(6*ppWidth-5) -:2], pp[(5*ppWidth-5) -:2],
        pp[(4*ppWidth-5) -:2], pp[(3*ppWidth-5) -:1], pp[(2*ppWidth-4):ppWidth]};
    wire [20:0] in3 = {pp[(8*ppWidth-7) -:2], pp[(7*ppWidth-7) -:2], pp[(6*ppWidth-7) -:2], pp[(5*ppWidth-7) -:2],
        pp[(4*ppWidth-7) -:1], pp[(3*ppWidth-6):(2*ppWidth)]};
    wire [16:0] in4 = {pp[(8*ppWidth-9) -:2], pp[(7*ppWidth-9) -:2], pp[(6*ppWidth-9) -:2], pp[(5*ppWidth-9) -:1], pp[(4*ppWidth-8):(3*ppWidth)]};
    wire [12:0] in5 = {pp[(8*ppWidth-11) -:2], pp[(7*ppWidth-11) -:2], pp[(6*ppWidth-11) -:1], pp[(5*ppWidth-10):(4*ppWidth)]};
    wire [8:0] in6 = {pp[(8*ppWidth-13) -:2], pp[(7*ppWidth-13) -:1], pp[(6*ppWidth-12):(5*ppWidth)]};
    wire [4:0] in7 = {pp[(8*ppWidth-15) -:1], pp[(7*ppWidth-14):(6*ppWidth)]};
    wire [1:0] in8 = pp[(8*ppWidth-15) -:2];
	//----------Stage0----------
    wire [30:0] stage00;
    wire [28:0] stage01;
    wire [24:0] stage02;
    wire [20:0] stage03;
    wire [16:0] stage04;
    wire [13:0] stage05;
        //--------------------------
    halfadder ha00(in0[10], in1[10], stage00[10], stage01[11]);
    csa #(9) csa00(in0[11 +:9], in1[11 +:9], in2[9 +:9], stage00[11 +:9], stage01[12 +:9]);
    halfadder ha01(in0[20], in1[20], stage00[20], stage05[13]);
        //--------------------------
    halfadder ha02(in3[8], in4[6], stage03[8], stage04[7]);
    csa #(5) csa01(in3[9 +:5], in4[7 +:5], in5[5 +:5], stage03[9 +:5], stage04[8 +:5]);
    halfadder ha03(in3[14], in4[12], stage03[14], stage02[17]);
        //--------------------------
    wire [8:0] tempbus6;
    wire [4:0] tempbus7;
    halfadder ha04(in6[4], in7[2], tempbus6[4], tempbus7[3]);
    csa #(1) csa02(in6[5], in7[3], in8[1], tempbus6[5], tempbus7[4]);
    halfadder ha05(in6[6], in7[4], tempbus6[6], stage05[9]);
        //--------------------------
    assign {tempbus6[8:7], tempbus6[3:0]} = {in6[8:7],in6[3:0]};
    assign tempbus7[2:0] = {in8[0],in7[1:0]};
    assign {stage02[16 -:8],stage01[10]} = tempbus6;
    assign {stage05[8 -:4],stage04[6]} = tempbus7;
    //-------------------------
    assign {stage00[21 +:10], stage00[9:0]} = {in0[30:21], in0[9:0]};
    assign {stage01[28 -:8], stage01[0 +:10]} = {in1[28 -:8], in1[0 +:10]};
    assign {stage02[24 -:7], stage02[8 -:9]} = {in2[24 -:7], in2[0 +:9]};
    assign {stage03[20 -:6], stage03[7:0]} = {in3[20 -:6], in3[7:0]};
    assign {stage04[16 -:4], stage04[5:0]} = {in4[16 -:4], in4[5:0]};
    assign {stage05[12 -:3], stage05[4:0]} = {in5[12 -:3], in5[4:0]};
	//----------Stage1----------
    wire [30:0] stage10;
    wire [28:0] stage11;
    wire [24:0] stage12;
    wire [21:0] stage13;
        //--------------------------
    halfadder ha10(stage00[6], stage01[6], stage10[6], stage11[7]);
    csa #(17) csa10(stage00[7 +:17], stage01[7 +:17], stage02[5 +:17], stage10[7 +:17], stage11[8 +:17]);
    halfadder ha11(stage00[24], stage01[24], stage10[24], stage13[21]);
        //--------------------------
    wire [16:0] tempbus4;
    halfadder ha12(stage03[4], stage04[2], stage13[4], tempbus4[3]);
    csa #(13) csa11(stage03[5 +:13], stage04[3 +:13], stage05[1 +:13], stage13[5 +:13], tempbus4[4 +:13]);
    halfadder ha13(stage03[18], stage04[16], stage13[18], stage12[21]);
        //--------------------------
    assign tempbus4[2:0] = stage04[2:0];
    assign {stage12[20:5],stage11[6]} = tempbus4;
    //-------------------------
    assign {stage10[30 -:6], stage10[0 +:6]} = {stage00[30 -:6],stage00[0 +:6]};
    assign {stage11[28 -:4], stage11[0 +:6]} = {stage01[28 -:4],stage01[0 +:6]};
    assign {stage12[24-:3], stage12[0 +:5]} = {stage02[24-:3],stage02[0+:5]};
    assign {stage13[20-:2], stage13[0+:4]} = {stage03[20-:2],stage03[0+:4]};
	//----------Stage2----------
    wire [30:0] stage20;
    wire [28:0] stage21;
    wire [25:0] stage22;
    halfadder ha20(stage10[4], stage11[4], stage20[4], stage21[5]);
    csa #(21) csa20(stage10[5 +:21], stage11[5 +:21], stage12[3 +:21], stage20[5 +:21], stage21[6 +:21]);
    halfadder ha21(stage10[26], stage11[26], stage20[26], stage22[25]);
    assign {stage20[30-:4],stage20[0+:4]} = {stage10[30-:4],stage10[0+:4]};
    assign {stage21[28-:2],stage21[0+:4]} = {stage11[28-:2],stage11[0+:4]};
    assign stage22[24] = stage12[24];
    assign {stage22[23:3],stage21[4]} = stage13;
	//----------Stage3----------
    wire [30:0] stage30;
    wire [29:0] stage31;
    halfadder ha30(stage20[2], stage21[2], stage30[2], stage31[3]);
    csa #(25) csa30(stage20[3 +:25], stage21[3 +:25], stage22[1 +:25], stage30[3 +:25], stage31[4 +:25]);
    halfadder ha31(stage20[28], stage21[28], stage30[28], stage31[29]);
    assign {stage30[30:29],stage30[1:0]} = {stage20[30:29],stage20[1:0]};
    assign stage31[2:0] = {stage22[0],stage21[1:0]};
	//----------Final-----------
    assign out0 = stage30;
    assign out1 = stage31;
endmodule
