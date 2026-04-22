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
	parameter integer outWidth =32)(
	input  wire[(inNum*inWidth-1):0] imgFlat,
	output wire[3:0] predDigit);
	
	`include "mnist_fixed_mlp_params.vh"

	wire signed[(hidNum*accWidth-1):0] accFlat;
	wire signed[(hidNum*accWidth-1):0] reluFlat;
	wire       [(hidNum*a1Width-1):0] actFlat;
	wire signed[(outNum*outWidth-1):0] outFlat;
	/*
	//Verification
	initial begin
		if (inNum !=IN_N_FILE)  $error("inNum mismatch");
		if (hidNum!=HID_N_FILE) $error("hidNum mismatch");
		if (outNum!=OUT_N_FILE) $error("outNum mismatch");
		if (inWidth != X_BITS_FILE)  $error("inWidth mismatch");
		if (w1Width != W1_W_FILE)    $error("w1Width mismatch");
		if (b1Width != B1_W_FILE)    $error("b1Width mismatch");
		if (a1Width != A1_BITS_FILE) $error("a1Width mismatch");
		if (w2Width != W2_W_FILE)    $error("w2Width mismatch");
		if (b2Width != B2_W_FILE)    $error("b2Width mismatch");
	end
	//...
	*/
	fc#(.inNum(inNum),.outNum(hidNum),
		.inWidth(inWidth),.wWidth(w1Width),
		.bWidth(b1Width),.outWidth(accWidth),
		.inSigned(0))
		fc1(.inFlat(imgFlat),.wFlat(fc1_w_flat),.bFlat(fc1_b_flat),.outFlat(accFlat));
	relu#(.number(hidNum),.width(accWidth)) relu1(.inFlat(accFlat),.outFlat(reluFlat));
	requantUsign#(.number(hidNum),.inWidth(accWidth),.outWidth(a1Width),.shift(B1_FRAC_FILE-A1_FRAC_FILE))
		requant(.inFlat(reluFlat),.outFlat(actFlat));

	fc#(.inNum(hidNum),.outNum(outNum),
		.inWidth(a1Width),.wWidth(w2Width),
		.bWidth(b2Width),.outWidth(outWidth),
		.inSigned(0))
		fc2(.inFlat(actFlat),.wFlat(fc2_w_flat),.bFlat(fc2_b_flat),.outFlat(outFlat));

	argmax#(.width(outWidth),.number(10)) argmax0(.inFlat(outFlat),.outIndex(predDigit));
endmodule