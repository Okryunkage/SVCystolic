`timescale 1ns/1ps

module receive#(
	parameter bits =8)(
	tick, en, in,
	out, done, busy, error);
	localparam bitsWidth =$clog2(bits);
	localparam reset     =3'd0;
	localparam idle      =3'd1;
	localparam startBit  =3'd2;
	localparam dataBits  =3'd3;
	localparam stopBit   =3'd4;

	input wire tick, en, start;
	output reg [(bits-1):0] out;
	output reg done, busy, error;

	reg [2:0] state =reset;
	reg [(bits-1):0] data ='0;

	reg [(bitsWidth-1):0] bitIndex ='0;

	//Two registers for mitigating Metastability
	reg inFF0 =1'b1, inFF1 =1'b1;
	wire rx =inFF1;

	always@(posedge tick)begin
		case(state)
			reset:begin
				out <='0;
				done <=1'b0;
				busy <=1'b0;
				error <=1'b0;
			end
			idle:begin
				busy <=1'b0;
				bitIndex <='0;
				data <='0;
				error <=1'b0;
				if(en&(~rx))begin
					busy <=1'b1;
					state <=startBit;
				end
			end
			startBit:begin



