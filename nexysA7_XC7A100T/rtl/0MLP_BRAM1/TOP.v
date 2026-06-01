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
	wire segtick;
	tickgen #(.CLK(100_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(boardCLK,{1'b0},segtick);

	//##############################
	//##         Button           ##
	//##############################
	wire resetSYNC;
	SYNCff#(.width(1)) resetBuff(.clk(boardCLK),.rst(1'b0),.in(buttonB),.out(resetSYNC));
	wire startSYNC, startPULSE;
	SYNCff#(.width(1)) startBuff(.clk(boardCLK),.rst(resetSYNC),.in(buttonC),.out(startSYNC));
	SYNCpulse startPgen(.clk(boardCLK),.rst(resetSYNC),.signal(startSYNC),.SYNCsig(startPULSE));

	//##############################
	//##           UART           ##
	//##############################
	wire[7:0] RXout;
	wire     RXdone,donePulse,RXbusy;

	reg[7:0] TXitem;
	reg      TXstart;
	wire     TXdone,TXbusy;

	uartTOP#(.boardCLK(100_000_000),.oversample(20),.baudrate(1_000_000),.ACCwidth(24))
		uart(.clk(boardCLK),.rst(resetSYNC),
			 .uartRX(UARTTX),.uartTX(UARTRX),
			 .TXstart(TXstart),.TXitem(TXitem),
			 .TXdone(TXdone),.TXbusy(TXbusy),
			 .RXout(RXout),.RXdone(RXdone),.RXbusy(RXbusy),.RXerror());
	SYNCpulse donePgen(.clk(boardCLK),.rst(resetSYNC),.signal(RXdone),.SYNCsig(donePulse));
	wire[(784*8-1):0] imgFlat;
	wire              imgLoadDone;
	imgUARTloader#(.inNum(784),.inWidth(8))
		loader(.clk(boardCLK),.rst(resetSYNC),.rxData(RXout),.rxValid(donePulse),.imgFlat(imgFlat),.imgLoadDone(imgLoadDone));

	//##############################
	//##           MLP            ##
	//##############################
	wire      NNbusy,NNdone;
	wire[3:0] predDigit;
	wire      NNstart =startPULSE&imgLoadDone&(~NNbusy);
	mnistTOPbram model(.clk(boardCLK),.rst(resetSYNC),.start(NNstart),.imgFlat(imgFlat),.busy(NNbusy),.done(NNdone),.predDigit(predDigit));

	//##############################
	//##        UART TX OUT       ##
	//##############################
	reg      NNdoneD;
	wire     NNdonePULSE;
	reg      txPending;
	reg[3:0] predDigitREG;

	assign NNdonePULSE =NNdone&(~NNdoneD);

	always@(posedge boardCLK or posedge resetSYNC)begin
		if(resetSYNC)begin
			NNdoneD      <=1'b0;
			TXstart      <=1'b0;
			TXitem       <=8'd0;
			txPending    <=1'b0;
			predDigitREG <=4'd0;
		end
		else begin
			NNdoneD <=NNdone;
			TXstart <=1'b0;
			if(NNdonePULSE)begin
				txPending    <=1'b1;
				predDigitREG <=predDigit;
			end
			if(txPending&(~TXbusy))begin
				TXitem    <=8'h30+{4'b0,predDigitREG};
				TXstart   <=1'b1;
				txPending <=1'b0;
			end
		end
	end

	//##############################
	//##           8seg           ##
	//##############################
	wire[7:0]  asciiFlat;
	bin2decASCII#(.binWidth(4),.digits(1)) ASCIIconverter(.bin(predDigit),.asciiFlat(asciiFlat));
	wire[63:0] asciiData ={56'b0,asciiFlat};
	seg8Ascii ascii(.clk(boardCLK),.rst(resetSYNC),.scanTick(segtick),.asciiData(asciiData),.an(segSel),.seg(seg),.dp(segDot));

	//##############################
	//##            LED           ##
	//##############################
	always@(posedge boardCLK or posedge resetSYNC)begin
		if(resetSYNC) LEDarr <=4'b0000;
		else if(segtick) LEDarr <={imgLoadDone,NNbusy,NNdone,TXbusy};
	end

endmodule