`timescale 1ns/1ps

module receive#(
	parameter bits =8,
	parameter oversample =16)(
	clk, en, in, rst,
	out, done, busy, error);
	localparam bitsWidth =$clog2(bits);
	localparam osrWidth  =$clog2(oversample);
	localparam osrHalf   =oversample/2;

	localparam reset     =3'd0;
	localparam idle      =3'd1;
	localparam startBit  =3'd2;
	localparam dataBits  =3'd3;
	localparam stopBit   =3'd4;

	localparam [(bitsWidth-1):0] last =(bits-1);

	input wire clk, en, in, rst;
	output reg [(bits-1):0] out;
	output reg done, busy, error;

	reg [2:0]             state       =reset;
	reg [(bits-1):0]      data        ='0;
	reg [(bitsWidth-1):0] bitIndex    ='0;
	reg [(osrWidth-1):0]  sampleCount ='0;

	//Two registers for mitigating Metastability
	reg inFF0 =1'b1, inFF1 =1'b1;
	wire rx =inFF1;

	always@(posedge clk)begin
		
		inFF0 <= in;
		inFF1 <= inFF0;

		if (rst)begin
			state <=idle;
			out   <='0;
			done  <=1'b0;
			busy  <=1'b0;
			error <=1'b0;
			data  <='0;
			sampleCount <='0;
			bitIndex <='0;
		end
		else begin
			case(state)
				/*
				reset:begin
					out   <='0;
					done  <=1'b0;
					busy  <=1'b0;
					error <=1'b0;
					data  <='0;
					state <=idle;
				end
				*/
				idle:begin
					busy     <=1'b0;
					bitIndex <='0;
					data     <='0;
					error    <=1'b0;
					sampleCount <='0;
					if(en&(~rx))begin
						busy <=1'b1;
						state <=startBit;
					end
				end
				startBit:begin
					if(sampleCount==(osrHalf-1))begin
						sampleCount <='0;
						if(~rx)begin
							bitIndex <='0;
							state    <=dataBits;
						end
						else begin
							busy  <=1'b0;
							state <=idle;
						end
					end
					else sampleCount <=(sampleCount+1'b1);
				end
				dataBits:begin
					if(sampleCount==(oversample-1))begin
						sampleCount <='0;
						data[bitIndex] <=rx;
						if(bitIndex==last)begin
							state <=stopBit;
						end
						else bitIndex <=(bitIndex+1'b1);
					end
					else sampleCount <=(sampleCount+1'b1);
				end
				stopBit:begin
					if(sampleCount==(oversample-1))begin
						sampleCount <='0;
						if(!rx) error <=1'b1;
						out <=data;
						done <=1'b1;
						busy <=1'b0;
						state<=idle;
					end
					else sampleCount <=(sampleCount+1'b1);
				end
				default: state <=idle;
			endcase
		end
	end
endmodule
