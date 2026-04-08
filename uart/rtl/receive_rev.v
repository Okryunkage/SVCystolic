`timescale 1ns/1ps

//valid register for indicating whether the byte is all received.
//if valid==1, it only updated to 0 when read input goes high in <stopbit>
//case.
//It means, receive module will only resume receiving when the other logic connected to receive module done reading the received output.

module receive#(
	parameter bits =8,
	parameter oversample =16)(
	clk, en, in, rst,
	out, done, busy, error,
	rts, read);
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
//	output reg valid;
	reg valid;
	output wire rts;
	input wire read;

	reg [2:0]             state       =reset;
	reg [(bits-1):0]      data        =1'd0;
	reg [(bitsWidth-1):0] bitIndex    =1'd0;
	reg [(osrWidth-1):0]  sampleCount =1'd0;

	//Two registers for mitigating Metastability
	//reg inFF0 =1'b1, inFF1 =1'b1;
	reg rxPrev =1'b1;
	//wire rx =inFF1;
	reg rx =1'b1;
	wire rxFall =rxPrev&&(!rx);

	assign rts =en&&(state==idle)&&(!valid);

	always@(posedge clk)begin
		
		//inFF0 <= in;
		//inFF1 <= inFF0;
		rx <=in;

		done <=1'b0;
		error <=1'b0;

		if (rst)begin
			state <=idle;
			out   <=1'd0;
//			done  <=1'b0;
			busy  <=1'b0;
//			error <=1'b0;
			data  <=1'd0;
			sampleCount <=1'd0;
			bitIndex <=1'd0;
			valid <=1'b0;
		end
		else begin
			case(state)
				reset:begin
					out   <=1'd0;
					done  <=1'b0;
					busy  <=1'b0;
					error <=1'b0;
					data  <=1'd0;
					state <=idle;
					valid <=1'b0;
				end
				idle:begin
					busy     <=1'b0;
					bitIndex <=1'd0;
					data     <=1'd0;
//					error    <=1'b0;
//					done     <=1'b0;
					sampleCount <=1'd0;
					if(read) valid <=1'b0;
					if(en&&(!valid)&&(rxFall))begin
					//if(en&(~rx))begin
						busy <=1'b1;
						state <=startBit;
					end
				end
				startBit:begin
					busy <=1'b1;
					if(sampleCount==(osrHalf-1))begin
						sampleCount <=1'd0;
						if(~rx)begin
							bitIndex <=1'd0;
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
					busy <=1'b1;
					if(sampleCount==(oversample-1))begin
						sampleCount <=1'd0;
						data[bitIndex] <=rx;
						if(bitIndex==last)begin
							state <=stopBit;
						end
						else bitIndex <=(bitIndex+1'b1);
					end
					else sampleCount <=(sampleCount+1'b1);
				end
				stopBit:begin
					busy <=1'b1;
					if(sampleCount==(oversample-1))begin
						sampleCount <=1'd0;
						busy <=1'b0;
						if(!rx) error <=1'b1;
						else if(valid) error <=1'b1;
						else begin
							out <=data;
							done <=1'b1;
							valid <=1'b1;
						end
						state<=idle;
					end
					else sampleCount <=(sampleCount+1'b1);
				end
				default: state <=idle;
			endcase
		end
	end
endmodule
