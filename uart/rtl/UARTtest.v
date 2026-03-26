//`include "ascii.vh"
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
	input wire[7:0] switch
);
	wire RXclk, TXclk;
	wire done, busy;
	wire doneRX, busyRX, errorRX;
	reg[7:0] sendITEM;
	wire[7:0] RXout;
	reg buttonReg0, buttonReg1, start, buttonPrev;
	tickgen #(.CLK(100_000_000), .baudrate(1_000_000), .oversample(20), .ACCwidth(24)) baudGen(boardCLK,{1'b0},RXclk,TXclk);
    transmit #(.bits(8)) TX(.clk(boardCLK),.tick(TXclk),.en(TXen),.start(start),.in(sendITEM),.out(UARTRX),.done(done),.busy(busy),.cts({1'b1}));
	receive #(.bits(8),.oversample(20)) RX(.clk(boardCLK),.tick(RXclk),.en(!TXen),.in(UARTTX),.rst({1'b0}),.out(RXout),.done(doneRX),.busy(busyRX),.error(errorRX));
	always@(posedge boardclk)begin
        if(TXclk)begin
            buttonReg0 <=button;
            buttonReg1 <=buttonReg0;

            sendITEM <=switch;

            start <=1'b0;
            if(TXen&buttonReg1*(!buttonPrev)) start <=1'b1;
            buttonPrev <=buttonReg1;

            if(TXen) LEDarr <=switch;
            else LEDarr <=RXout;
            
            if(TXen) LED8 <=1'b1;
            else LED8 <=1'b0;
        end
	end
endmodule
