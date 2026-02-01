`timescale 1ns/1ps
/*
module wallace #(
	parameter size=8)(
	input [((size+1)*size/2-1):0] pp,
	input [(size-1):0] cor,
	output [(2*size-1):0] output0,
	output [(2*size-1):0] output1);

	localparam inputN = size/2 +1;
	function integer stage;
		input integer inputN;
		integer n;
		integer count; begin
			n =inputN;
			count =0;
			while (n>2)begin
				n =(n/3)*2+(n%3);
				count =count+1;
			end
			stage =count;
		end
	endfunction
	localparam maxStage =stage(inputN);
*/
//scalable Wallace-Tree Adder can be realized by the algorithm below
//Counting the number of bits in same digits, in the set(depth=3). If the count==2, use half-csa, else use full-csa
//Decide size of the csa by counting the width of serial same_number
//Connect the wire of csa out to the next stage of tree
//The size of next stage adder is dependant on the previous stage's output wire width
module wallace_i5c(
	input [35:0] pp,
	input [7:0] cor,
	output [13:0] out0,
	output [11:0] out1);
	//----------Stage0----------
	wire [9:0] stage00;
	wire [9:0] stage01;
	halfcsa #(2) h00(.A(cor[1:0]), .B(pp[1:0]), .sum(stage00[1:0]), .cout(stage01[1:0]));
	csa #(6) c0(.A(cor[7:2]), .B(pp[7:2]), .C(pp[14:9]), .sum(stage00[7:2]), .cout(stage01[7:2]));
	halfcsa #(1) h01(.A(pp[8]), .B(pp[15]), .sum(stage00[8]), .cout(stage01[8]));
	assign stage00[9] = pp[16];
	assign stage01[9] = pp[17];
	//----------Stage1----------
	wire [11:0] stage10;
	wire [10:0] stage11;
	halfcsa #(3) h10(.A(stage00[3:1]), .B(stage01[2:0]), .sum(stage10[2:0]), .cout(stage11[2:0]));
	csa #(6) c1(.A(stage00[9:4]), .B(stage01[8:3]), .C(pp[23:18]), .sum(stage10[8:3]), .cout(stage11[8:3]));
	halfcsa #(1) h11(.A(stage01[9]), .B(pp[24]), .sum(stage10[9]), .cout(stage11[9]));
	assign stage10[10] = pp[25];
	assign stage11[10] = pp[26];
	//----------Stage2----------
	wire [11:0] stage20;
	wire [11:0] stage21;
	halfcsa #(4) h20(.A(stage10[4:1]), .B(stage11[3:0]), .sum(stage20[3:0]), .cout(stage21[3:0]));
	csa #(6) c2(.A(stage10[10:5]), .B(stage11[9:4]), .C(pp[32:27]), .sum(stage20[9:4]), .cout(stage21[9:4]));
	halfcsa #(1) h21(.A(stage11[10]), .B(pp[33]), .sum(stage20[10]), .cout(stage21[10])); 
	assign stage20[11] = pp[34];
	assign stage21[11] = pp[35];
	//----------Final-----------
	assign out0 = {stage20,stage10[0],stage00[0]};
	assign out1 = stage21;
endmodule

module wallace_i9c(
	input [135:0] pp,
	input [15:0] cor,
	output [30:0] out0,
	output [27:0] out1);
	localparam integer ppWidth = 17;
	//----------Stage0----------
	wire [17:0] stage00;
	wire [17:0] stage01;
	halfcsa #(2) h00(.A(cor[1:0]), .B(pp[1:0]), .sum(stage00[1:0]), .cout(stage01[1:0]));
	csa #(14) c00(.A(cor[15:2]), .B(pp[15:2]), .C(pp[30:17]), .sum(stage00[15:2]), .cout(stage01[15:2]));
	halfcsa #(1) h01(.A(pp[16]), .B(pp[31]), .sum(stage00[16]), .cout(stage01[16]));
	assign stage00[17] = pp[32];
	assign stage01[17] = pp[33];
		//--------------------------
	wire [19:0] stage02;
	wire [17:0] stage03;
	assign stage02[1:0] = pp[(2*ppWidth) +:2];
	halfcsa #(2) h02(.A(pp[(2*ppWidth+2) +:2]), .B(pp[(3*ppWidth) +:2]), .sum(stage02[2 +:2]), .cout(stage03[1:0]));
	csa #(13) c01(.A(pp[(2*ppWidth+4) +:13]), .B(pp[(3*ppWidth+2) +:13]), .C(pp[(4*ppWidth) +:13]), .sum(stage02[4 +:13]), .cout(stage03[2 +:13]));
	halfcsa #(2) h03(.A(pp[(3*ppWidth+15) +:2]), .B(pp[(4*ppWidth+13) +:2]), .sum(stage02[17 +:2]), .cout(stage03[15 +:2]));
	assign stage02[19] = pp[4*ppWidth+15];
	assign stage03[17] = pp[4*ppWidth+16];
		//--------------------------
	wire [19:0] stage04;
	wire [17:0] stage05;
	assign stage04[1:0] = pp[(5*ppWidth) +:2];
	halfcsa #(2) h04(.A(pp[(5*ppWidth+2) +:2]), .B(pp[(6*ppWidth) +:2]), .sum(stage04[2 +:2]), .cout(stage05[1:0]));
	csa #(13) c02(.A(pp[(5*ppWidth+4) +:13]), .B(pp[(6*ppWidth+2) +:13]), .C(pp[(7*ppWidth) +:13]), .sum(stage04[4 +:13]), .cout(stage05[2 +:13]));
	halfcsa #(2) h05(.A(pp[(6*ppWidth+15) +:2]), .B(pp[(7*ppWidth+13) +:2]), .sum(stage04[17 +:2]), .cout(stage05[15 +:2]));
	assign stage04[19] = pp[7*ppWidth+15];
	assign stage05[17] = pp[7*ppWidth+16];
	//----------Stage1----------
	wire [19:0] stage10;
	wire [21:0] stage11;
	assign stage10[0] = stage00[0];
	halfcsa #(3) h10(.A(stage00[1 +:3]), .B(stage01[0 +:3]), .sum(stage10[1 +:3]), .cout(stage11[0 +:3]));
	csa #(14) c10(.A(stage00[4 +:14]), .B(stage01[3 +:14]), .C(stage02[0 +:14]), .sum(stage10[4 +:14]), .cout(stage11[3 +:14]));
	halfcsa #(1) h11(.A(stage01[17]), .B(stage02[14]), .sum(stage10[18]), .cout(stage11[17]));
	assign stage10[19] = stage02[15];
	assign stage11[21:18] = stage02[19:16];
		//--------------------------
	wire [23:0] stage12;
	wire [19:0] stage13;
	assign stage12[0 +:3] = stage03[0 +:3];
	halfcsa #(3) h12(.A(stage03[3 +:3]), .B(stage04[0 +:3]), .sum(stage12[3 +:3]), .cout(stage13[0 +:3]));
	csa #(12) c11(.A(stage03[6 +:12]), .B(stage04[3 +:12]), .C(stage05[0 +:12]), .sum(stage12[6 +:12]), .cout(stage13[3 +:12]));
	halfcsa #(5) h13(.A(stage04[15 +:5]), .B(stage05[12 +:5]), .sum(stage12[18 +:5]), .cout(stage13[15 +:5]));
	assign stage12[23] = stage05[17];
	//----------Stage2----------
	wire [24:0] stage20;
	wire [27:0] stage21;
	assign stage20[1:0] = stage10[1:0];
	halfcsa #(5) h20(.A(stage10[2 +:5]), .B(stage11[0 +:5]), .sum(stage20[2 +:5]), .cout(stage21[0 +:5]));
	csa #(13) c20(.A(stage10[7 +:13]), .B(stage11[5 +:13]), .C(stage12[0 +:13]), .sum(stage20[7 +:13]), .cout(stage21[5 +:13]));
	halfcsa #(4) h21(.A(stage11[18 +:4]), .B(stage12[13 +:4]), .sum(stage20[20 +:4]), .cout(stage21[18 +:4]));
	assign stage20[24] = stage12[17];
	assign stage21[27:22] = stage12[23:18];
	wire [19:0] stage22 = stage13;
	//----------Stage3----------
	wire [30:0] stage30;
	wire [27:0] stage31;
	assign stage30[2:0] = stage20[2:0];
	halfcsa #(8) h30(.A(stage20[3 +:8]), .B(stage21[0 +:8]), .sum(stage30[3 +:8]), .cout(stage31[0 +:8]));
	csa #(14) c30(.A(stage20[11 +:14]), .B(stage21[8 +:14]), .C(stage22[0 +:14]), .sum(stage30[11 +:14]), .cout(stage31[8 +:14]));
	halfcsa #(6) h31(.A(stage21[22 +:6]), .B(stage22[14 +:6]), .sum(stage30[25 +:6]), .cout(stage31[22 +:6]));
	//----------Final-----------
	assign out0 = stage30;
	assign out1 = stage31;
endmodule
