`timescale 1ns/1ps

module fpgaTOP(
	input  wire[15:8] switch,
	output reg [15:0] LEDarr,
	output wire [6:0] seg,
	output wire       segDot,
	output wire [7:0] segSel,
	input  wire       buttonC,
	input  wire       boardCLK);

	reg[63:0] segReg =64'd0;
	wire      segtick;
	tickgen#(.CLK(100_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(boardCLK,{1'b0},segtick);
	seg8Ascii ascii(boardCLK,{1'b0},segtick,segReg,segSel,seg,segDot);

	wire run0, run1;
	SYNCff#(1) runBuff(boardCLK,{1'b0},buttonC,run0);
	SYNCpulse  runPulse(boardCLK,segtick,{1'b0},run0,run1);

	wire[15:0] asciiDEC0, asciiDEC1, asciiDEC2;
	wire[4:0] out;
	bin2decASCII#(.binWidth(4),.digits(2)) decConverter0(switch[11:8],asciiDEC0[15:0]);
	bin2decASCII#(.binWidth(4),.digits(2)) decConverter1(switch[15:12],asciiDEC1[15:0]);
	bin2decASCII#(.binWidth(5),.digits(2)) decConverter2(out,asciiDEC2[15:0]);

	reg[3:0] a,b;
	always@(posedge boardCLK)begin
		if(segtick)begin
			if(run1)begin
				a <=switch[11:8];
				b <=switch[15:12];
			end
			segReg <={asciiDEC1,asciiDEC0,{16{1'b0}},asciiDEC2};
			LEDarr <={switch[15:8],{3'b0},out};
		end
	end

	adderTOPmlp#(
		.inNum(8),.hidNum(32),.outNum(5),
		.inWidth(1),.wWidth(8),
		.b1Width(16),.b2Width(32),
		.hidWidth(20),.outWidth(32))
		NNmodel(.a(a),.b(b),.out(out));
endmodule