`timescale 1ns/1ps

module mnistTOPbram(
	input  wire                      clk,
	input  wire                      rst,
	input  wire                      start,
	input  wire[(784*8-1):0]         imgFlat,
	output reg                       busy,
	output reg                       done,
	output reg[3:0]                  predDigit);

	localparam integer inNum     =784;
	localparam integer hidNum    =64;
	localparam integer outNum    =10;
	localparam integer inWidth   =8;
	localparam integer w1Width   =8;
	localparam integer b1Width   =32;
	localparam integer acc1Width =32;
	localparam integer a1Width   =8;
	localparam integer w2Width   =8;
	localparam integer b2Width   =32;
	localparam integer outWidth  =32;
	localparam integer fc1Tile   =8;
	localparam integer fc2Tile   =5;

	localparam[2:0] idleS       =3'd0;
	localparam[2:0] fc1startS   =3'd1;
	localparam[2:0] fc1waitS    =3'd2;
	localparam[2:0] fc2startS   =3'd3;
	localparam[2:0] fc2waitS    =3'd4;
	localparam[2:0] doneS       =3'd5;

	reg[2:0] state;

	reg  fc1start,fc2start;
	wire fc1busy,fc1done;
	wire fc2busy,fc2done;

	wire signed[(hidNum*acc1Width-1):0] acc1Flat;
	wire signed[(hidNum*acc1Width-1):0] relu1Flat;
	wire       [(hidNum*a1Width-1):0]   act1Flat;
	wire signed[(outNum*outWidth-1):0]  acc2Flat;

	wire[3:0] predDigitWIRE;

	fc1BRAM fc1(.clk(clk),.rst(rst),.start(fc1start),.inFlat(imgFlat),.busy(fc1busy),.done(fc1done),.outFlat(acc1Flat));
	relu#(.number(hidNum),.width(acc1Width)) relu1(.inFlat(acc1Flat),.outFlat(relu1Flat));

	requantUsign#(.number(hidNum),.inWidth(acc1Width),.outWidth(a1Width),.shift(10))
		rq1(.inFlat(relu1Flat),.outFlat(act1Flat));
	
	fc2BRAM fc2(.clk(clk),.rst(rst),.start(fc2start),.inFlat(act1Flat),.busy(fc2busy),.done(fc2done),.outFlat(acc2Flat));
	argmax#(.number(outNum),.width(outWidth)) argmax0(.inFlat(acc2Flat),.outIndex(predDigitWIRE));

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state     <=idleS;
			fc1start  <=1'b0;
			fc2start  <=1'b0;
			busy      <=1'b0;
			done      <=1'b0;
			predDigit <=4'd0;
		end
		else begin
			fc1start <=1'b0;
			fc2start <=1'b0;
			done     <=1'b0;
			case(state)
				idleS:begin
					busy <=1'b0;
					if(start)begin
						busy  <=1'b1;
						state <=fc1startS;
					end
				end
				fc1startS:begin
					fc1start <=1'b1;
					state    <=fc1waitS;
				end
				fc1waitS: if(fc1done) state <=fc2startS;
				fc2startS:begin
					fc2start <=1'b1;
					state    <=fc2waitS;
				end
				fc2waitS: if(fc2done) state <=doneS;
				doneS:begin
					busy      <=1'b0;
					done      <=1'b1;
					predDigit <=predDigitWIRE;
					state     <=idleS;
				end
				default: state <=idleS;
			endcase
		end
	end
endmodule