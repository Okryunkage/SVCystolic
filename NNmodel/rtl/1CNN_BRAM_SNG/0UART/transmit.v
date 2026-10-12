`timescale 1ns/1ps

module transmit#(
	parameter bits =8)(
	clk, tick, en, start,
	in,
	out, done, busy);
	localparam bitsWidth =$clog2(bits);
	localparam reset     =3'd0;
	localparam idle      =3'd1;
	localparam startBit  =3'd2;
	localparam dataBits  =3'd3;
	localparam stopBit   =3'd4;

	input wire clk, tick, en, start;
	input wire [(bits-1):0] in;
	output reg out, done, busy;

	reg [3:0] state =reset;
	reg [(bits-1):0] data =0;

	reg [(bitsWidth-1):0] bitIndex =0; 

	always@(posedge clk)begin
		if(tick)begin
			case(state)
				reset:begin
					out <=1'b1;
					done <=1'b0;
					busy <=1'b0;
					data <=1'd0;
					bitIndex <=1'd0;
					state <= idle;
				end
				idle:begin 
					//if out becomes 0, Transmission starts
					out <=1'b1;
					done <=1'b0;
					bitIndex <=1'd0;
					data <=1'd0;
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
	end
endmodule

`timescale 1ns/1ps

module transmitREV#(
	parameter bits =8)(
	input  wire clk,
	input  wire rst,
	input  wire tick,
	input  wire en,
	input  wire start,
	input  wire [(bits-1):0] in,
	output reg  out,
	output reg  done,
	output reg  busy);

	localparam bitsWidth =$clog2(bits);
	localparam idle      =3'd0;
	localparam startBit  =3'd1;
	localparam dataBits  =3'd2;
	localparam stopBit   =3'd3;

	reg[2:0] state;
	reg[(bits-1):0] data;
	reg[(bits-1):0] dataREQ;
	reg[(bitsWidth-1):0] bitIndex;
	reg startREQ;

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state    <=idle;
			out      <=1'b1;
			done     <=1'b0;
			busy     <=1'b0;
			data     <={bits{1'b0}};
			dataREQ  <={bits{1'b0}};
			bitIndex <={bitsWidth{1'b0}};
			startREQ <=1'b0;
		end
		else begin
			done <=1'b0;

			if(start&en&(~startREQ)&(~busy))begin
				startREQ <=1'b1;
				dataREQ  <=in;
			end

			if(tick)begin
				case(state)
					idle:begin
						out      <=1'b1;
						busy     <=1'b0;
						bitIndex <={bitsWidth{1'b0}};
						if(startREQ)begin
							data     <=dataREQ;
							startREQ <=1'b0;
							state    <=startBit;
						end
					end

					startBit:begin
						out   <=1'b0;
						busy  <=1'b1;
						state <=dataBits;
					end

					dataBits:begin
						out <=data[bitIndex];
						if(bitIndex==(bits-1))begin
							bitIndex <={bitsWidth{1'b0}};
							state    <=stopBit;
						end
						else begin
							bitIndex <=bitIndex+1'b1;
						end
					end

					stopBit:begin
						out   <=1'b1;
						busy  <=1'b0;
						done  <=1'b1;
						state <=idle;
					end

					default:begin
						state <=idle;
					end
				endcase
			end
		end
	end

endmodule