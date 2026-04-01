`timescale 1ns/1ps

module UARTtest(
	input wire boardCLK,
	output wire UARTRX,
	input wire UARTTX,
	input wire TXen,
	input wire button,
	output reg LED8,
//	output reg LED15,
	output reg[7:0] LEDarr,
	input wire[7:0] switch,
	output reg[7:0] segSel,
	output reg[6:0] seg,
	output reg      segDot
);
	wire RXclk, TXclk;
	wire done, busy;
	wire doneRX, busyRX, errorRX;
	reg[7:0] sendITEM;
	wire[7:0] RXout;
	reg buttonReg0, buttonReg1, start, buttonPrev;

	wire clk200;
	wire locked;
	wire segCLK;
	mmcm200 clkmcmm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(clk200));
	baudtickgen #(.CLK(200_000_000),.baudrate(1_000_000),.oversample(20),.ACCwidth(24)) baudGen(clk200,{1'b0},RXclk,TXclk);
	tickgen #(.CLK(200_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(clk200,{1'b0},segCLK);

	reg[63:0] asciiData;
	seg8Ascii(clk200,{1'b0},asciiData,segSel,seg,segDot);

    transmit #(.bits(8)) TX(.clk(clk200),.tick(TXclk),.en(TXen),.start(start),.in(sendITEM),.out(UARTRX),.done(done),.busy(busy),.cts({1'b1}));
	receive #(.bits(8),.oversample(20)) RX(.clk(clk200),.tick(RXclk),.en(!TXen),.in(UARTTX),.rst({1'b0}),.out(RXout),.done(doneRX),.busy(busyRX),.error(errorRX));
	always@(posedge boardCLK)begin
		if(TXclk)begin
			buttonReg0 <=button;
			buttonReg1 <=buttonReg0;

			sendITEM <=switch;

			start <=1'b0;
			if(TXen&buttonReg1&(!buttonPrev)) start <=1'b1;
			buttonPrev <=buttonReg1;

			if(TXen) LEDarr <=switch;
			else LEDarr <=RXout;
			
			if(TXen) LED8 <=1'b1;
			else LED8 <=1'b0;
		end
	end
endmodule