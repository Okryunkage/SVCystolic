/*
IOs
	-imgLoadDone LED: after receiving all the flatten MNIST data, imgLoadDone flag up & LED on
	-start Button   : after imgLoadDone, mnistTOPbram wait start signal to operate
	-8seg LED       : after inference all done, display expected digit to 8seg
	-reset Button   : reset the whole system
*/

`timescale 1ns/1ps

module top(
	input  wire boardCLK,

	output wire UARTRX,
	input  wire UARTTX,

	input  wire buttonC,
	input  wire buttonB,

	output reg[3:0] LEDarr,

	output wire[7:0] segSel,
	output wire[6:0] seg,
	output wire      segDot);

	//##############################
	//##           CLK            ##
	//##############################
	wire clk200;
	wire locked;
	wire segtick;
	mmcm200 clkmcmm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(clk200));
	tickgen #(.CLK(200_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(clk200,{1'b0},segtick);

	//##############################
	//##         Button           ##
	//##############################
	wire resetSYNC;
	SYNCff#(.width(1)) resetBuff(.clk(clk200),.rst(1'b0),.in(buttonB),.out(resetSYNC));
	wire startSYNC, startPULSE;
	SYNCff#(.width(1)) startBuff(.clk(clk200),.rst(resetSYNC),.in(buttonC),.out(startSYNC));
	SYNCpulse startPgen(.clk(clk200),.rst(resetSYNC),.signal(startSYNC),.SYNCsig(startPULSE));

	//##############################
	//##           UART           ##
	//##############################
	wire[7:0] RXout;
	wire     RXdone,donePulse,RXbusy;
	uartTOP#(.boardCLK(200_000_000),.oversample(20),.baudrate(1_000_000),.ACCwidth(24))
		uart(.clk(clk200),.rst(resetSYNC),
			 .uartRX(UARTTX),.uartTX(UARTRX),
			 .TXstart(1'b0),.TXitem(8'b0),//TX not used in this module
			 .TXdone(),.TXbusy(),
			 .RXout(RXout),.RXdone(RXdone),.RXbusy(RXbusy),.RXerror());
	SYNCpulse donePgen(.clk(clk200),.rst(resetSYNC),.signal(RXdone),.SYNCsig(donePulse));
	wire[(784*8-1):0] imgFlat;
	wire              imgLoadDone, NNstart;
	imgUARTloader#(.inNum(784),.inWidth(8)) loader(.clk(clk200),.rst(resetSYNC),.rxData(RXout),.rxValid(donePulse),.imgFlat(imgFlat),.imgLoadDone(imgLoadDone));
	SYNCff#(.width(1)) NNstartBuff(.clk(clk200),.rst(resetSYNC),.in(imgLoadDone),.out(NNstart));

	//##############################
	//##           MLP            ##
	//##############################
	wire      NNbusy,NNdone;
	wire[3:0] predDigit;
	//wire      NNstart;
	//assign NNstart =startPULSE;
	//&imgLoadDone;
	mnistTOPbram model(.clk(clk200),.rst(resetSYNC),.start(NNstart),.imgFlat(imgFlat),.busy(NNbusy),.done(NNdone),.predDigit(predDigit));
	
	//##############################
	//##           8seg           ##
	//##############################
	wire[7:0]  asciiFlat;
	bin2decASCII#(.binWidth(4),.digits(1)) ASCIIconverter(.bin(predDigit),.asciiFlat(asciiFlat));
	wire[63:0] asciiData;
	assign asciiData ={56'b0,asciiFlat};
	seg8Ascii ascii(.clk(clk200),.rst(resetSYNC),.scanTick(segtick),.asciiData(asciiData),.an(segSel),.seg(seg),.dp(segDot));

	//##############################
	//##            LED           ##
	//##############################
	/*
	always@(posedge clk200)begin
		if(segtick) LEDarr <={{2'b0},{imgLoadDone},{NNdone}};
	end
	*/
endmodule