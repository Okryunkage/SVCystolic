`timescale 1ns/1ps

module adderTOPmlp#(
	parameter integer inNum    =784,
	parameter integer hidNum   =128,
	parameter integer outNum   =10,
	parameter integer inWidth  =8,
	parameter integer wWidth   =8,
	parameter integer b1Width  =32,
	parameter integer b2Width  =32,
	parameter integer hidWidth =20,
	parameter integer outWidth= 32)(
	input  wire[3:0] a,
	input  wire[3:0] b,
	output wire[4:0] out);

	wire [(inNum*inWidth-1):0] inFlat;
	assign inFlat ={b[3],b[2],b[1],b[0],a[3],a[2],a[1],a[0]};

	localparam integer fc1wWidth =hidNum*inNum*wWidth;
	localparam integer fc1bWidth =hidNum*b1Width;
	localparam integer fc2wWidth =outNum*hidNum*wWidth;
	localparam integer fc2bWidth =outNum*b2Width;
	
	`include "mlp_params_flat.vh"
	
	wire signed[(hidNum*hidWidth-1):0] z1_flat;
	wire signed[(hidNum*hidWidth-1):0] h1_flat;
	wire signed[(outNum*outWidth-1):0] z2_flat;

	fc#(.inNum(inNum),.outNum(hidNum),
		.inWidth(inWidth),.wWidth(wWidth),
		.bWidth(b1Width),.outWidth(hidWidth),
		.inSigned(0))
		fc1(.inFlat(inFlat),.wFlat(fc1_w_flat),.bFlat(fc1_b_flat),.outFlat(z1_flat));
	relu#(.number(hidNum),.width(hidWidth)) relu1(.inFlat(z1_flat),.outFlat(h1_flat));

	fc#(.inNum(hidNum),.outNum(outNum),
		.inWidth(hidWidth),.wWidth(wWidth),
		.bWidth(b2Width),.outWidth(outWidth),
		.inSigned(1))
		fc2(.inFlat(h1_flat),.wFlat(fc2_w_flat),.bFlat(fc2_b_flat),.outFlat(z2_flat));

	sign#(.number(outNum),.width(outWidth)) sign(.inFlat(z2_flat),.outBits(out));

endmodule