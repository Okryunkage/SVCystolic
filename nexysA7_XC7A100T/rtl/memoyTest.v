`timescale 1ns/1ps

module memoryTest(
	input wire boardCLK,
	output wire UARTRX,
	input wire UARTTX,
	input wire TXen,
	input wire button,
	output reg LED8,
//	output reg LED15,
	output reg[7:0] LEDarr,
	input wire[7:0] switch,

	output wire[7:0] segSel,
	output wire[6:0] seg,
	output wire      segDot,

	input wire reset
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
	reg[26:0] address;
	memoryRW memRW(.sysclk(boardCLK),.sysrst(reset),.address)
	baudtickgen #(.CLK(150_000_000),.baudrate(1_000_000),.oversample(20),.ACCwidth(24)) baudGen(clk200,{1'b0},RXclk,TXclk);
	tickgen #(.CLK(150_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(clk200,{1'b0},segCLK);