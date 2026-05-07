`timescale 1ns/1ps

module mnistTOPmlpTile#(
	parameter integer inNum     =784,
	parameter integer hidNum    =128,
	parameter integer outNum    =10,
	parameter integer inWidth   =8,
	parameter integer w1Width   =8,
	parameter integer b1Width   =32,
	parameter integer acc1Width =32,
	parameter integer a1Width   =12,
	parameter integer w2Width   =8,
	parameter integer b2Width   =32,
	parameter integer outWidth  =32,
	parameter integer fc1Tile   =8,
	parameter integer fc2Tile   =5)(
	input  wire                      clk,
	input  wire                      rst,
	input  wire                      start,
	input  wire[(inNum*inWidth-1):0] imgFlat,
	output reg                       busy,
	output reg                       done,
	output wire[3:0]                 predDigit);

	localparam[2:0] idle        =3'd0;
	localparam[2:0] fc1start    =3'd1;
	localparam[2:0] fc1wait     =3'd2;
	localparam[2:0] fc2start    =3'd3;
	localparam[2:0] fc2wait     =3'd4;
	localparam[2:0] done        =3'd5;

	reg[2:0] state;

	reg  fc1start,fc2start;
	wire fc1busy,fc1done;
	wire fc2busy,fc2done;

	wire signed[(hidNum*acc1Width-1):0] acc1Flat;
	wire signed[(hidNum*acc1Width-1):0] relu1Flat;
	wire       [(hidNum*a1Width-1):0]   act1Flat;
	wire signed[(outNum*outWidth-1):0]  acc2Flat;

	`include "mnist_fixed_mlp_params.vh"

	fcBRAM#(
		.tile(fc1Tile),
		.inNum(inNum),.outNum(hidNum),
		.inWidth(inWidth),.wWidth(w1Width),.bWidth(b1Width),.accWidth(acc1Width),
		.inSigned(0),
		.wMEMfile("fc1_w_tile.mem"),.bMEMfile("fc1_b_tile.mem"))
		fc1seq(.clk(clk),.rst(rst),.start(fc1_start),.inFlat(imgFlat),.busy(fc1busy),.done(fc1done),.outFlat(acc1Flat));
	relu#(.number(hidNum),.width(acc1Width)) relu1(.inFlat(acc1Flat),.outFlat(relu1Flat));
	requantUsign#(.number(hidNum),.inWidth(acc1Width),.outWidth(a1Width),.shift(B1_FRAC_FILE-A1_FRAC_FILE))
		rq1(.inFlat(relu1Flat),outFlat(act1Flat));
	
	fcBRAM#(
		.tile(fc2Tile),
		.inNum(hidNum),.outNum(outNum),
		.inWidth(a1Width),.wWidth(w2Width),.bWidth(b2Width),.accWidth(outWidth),
		.inSigned(0),
		.wMEMfile("fc2_w_tile.mem"),.bMEMfile("fc2_b_tile.mem"))
		fc2seq(.clk(clk),.rst(rst),.start(fc2_start),.inFlat(act1Flat),.busy(fc2busy),.done(fc2done),.outFlat(acc2Flat));
	argmax#(.number(outNum),.width(outWidth)) argmax0(.inFlat(acc2Flat),.outIndex(predDigit));

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state    <=idle;
			fc1start <=1'b0;
			fc2start <=1'b0;
			busy     <=1'b0;
			done     <=1'b0;
		end
		else begin
			fc1start <=1'b0;
			fc2start <=1'b0;
			done     <=1'b0;
			case(state)
				idle:begin
					busy <=1'b0;
					if(start)begin
						busy  <=1'b1;
						state <=fc1start;
					end
				end
				fc1start:begin
					fc1start <=1'b1;
					state    <=fc1wait;
				end
				fc1wait: if(fc1done) state <=fc2start;
				fc2start:begin
					fc2start <=1'b1;
					state    <=fc2wait;
				end
				fc2wait: if(fc2done) state <=done;
				done:begin
					busy  <=1'b0;
					done  <=1'b1;
					state <=idle;
				end
				default: state <=idle;
			endcase
		end
	end
endmodule