`timescale 1ns/1ps

module mnistTOPmlp#(
	parameter integer inNum    =784,
	parameter integer hidNum   =128,
	parameter integer outNum   =10,
	
	parameter integer inWidth  =8,
	parameter integer w1Width  =8,
	parameter integer b1Width  =32,
	parameter integer accWidth =32,

	parameter integer a1Width  =12,
	parameter integer w2Width  =8,
	parameter integer b2Width  =32,
	parameter integer outWidth =32,
	
	parameter integer b1Frac   =14,
	parameter integer a1Frac   =4,
	
	parameter [(hidNum*inNum*w1Width)-1:0]  fc1wFlat =0,
	parameter [(hidNum*b1Width)-1:0]        fc1bFlat =0,
	parameter [(outNum*hidNum*w2Width)-1:0] fc2wFlat =0,
	parameter [(outNum*b2Width)-1:0]        fc2bFlat =0)(
		
	input  wire[(inNum*inWidth-1):0] imgFlat,
	output wire[3:0] predDigit);

	wire signed[(hidNum*accWidth-1):0] accFlat;
	wire signed[(hidNum*accWidth-1):0] reluFlat;
	wire       [(hidNum*a1Width-1):0] actFlat;
	wire signed[(outNum*outWidth-1):0] outFlat;

	fc#(.inNum(inNum),.outNum(hidNum),
		.inWidth(inWidth),.wWidth(w1Width),
		.bWidth(b1Width),.outWidth(accWidth),
		.inSigned(0))
		fc1(.inFlat(imgFlat),.wFlat(fc1wFlat),.bFlat(fc1bFlat),.outFlat(accFlat));
	relu#(.number(hidNum),.width(accWidth)) relu1(.inFlat(accFlat),.outFlat(reluFlat));
	requantUsign#(.number(hidNum),.inWidth(accWidth),.outWidth(a1Width),.shift(b1Frac-a1Frac))
		requant(.inFlat(reluFlat),.outFlat(actFlat));

	fc#(.inNum(hidNum),.outNum(outNum),
		.inWidth(a1Width),.wWidth(w2Width),
		.bWidth(b2Width),.outWidth(outWidth),
		.inSigned(0))
		fc2(.inFlat(actFlat),.wFlat(fc2wFlat),.bFlat(fc2bFlat),.outFlat(outFlat));

	argmax#(.width(outWidth),.number(10)) argmax0(.inFlat(outFlat),.outIndex(predDigit));
endmodule