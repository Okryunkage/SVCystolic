`timescale 1ns/1ps

module transmit #(
	parameter bits =8)(
	clk, en, start,
	in,
	out, done, busy);
	localparam bitsWidth =$clog2(bits);
	localparam reset     =3'd0;
	localparam idle      =3'd1;
	localparam startBit  =3'd2;
	localparam dataBits  =3'd3;
	localparam stopBit   =3'd4;

	input wire clk, en, start;
	input wire [(bits-1):0] in;
	output reg out, done, busy;

	reg [3:0] state =reset;
	reg [(bits-1):0] data =0;

	reg [(bitsWidth-1):0] bitIndex =0;

	always@(posedge clk)begin
		case(state)
			reset:begin
				out <=1'b1;
				done <=1'b0;
				busy <=1'b0;
				data <='0;
				bitIndex <='0;
				state <= idle;
			end
			idle:begin 
				//if out becomes 0, Transmission starts
				out <=1'b1;
				done <=1'b0;
				bitIndex <='0;
				data <='0;
				if(start&en) state <=startBit;
			end
			startBit:begin
				data <=in;
				out <=1'b0;
				busy <=1'b1;
				state <=dataBits;
			end
			dataBits:begin
				out <=data[bitIndex];
				//if(&bitIndex)begin
				if(bitIndex==(bits-1))begin
					bitIndex <=0;
					state <=stopBit;
				end
				else bitIndex <=(bitIndex+1'b1);
			end
			stopBit:begin
				done <=1'b1;
				data <='b0;
				out <=1'b1;
				busy <=1'b0;
				state <=idle;
			end
			default: state <=reset;
		endcase
	end
endmodule
