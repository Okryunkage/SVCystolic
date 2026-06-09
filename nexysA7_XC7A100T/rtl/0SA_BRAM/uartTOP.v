`timescale 1ns/1ps

module receive#(
	parameter bits =8,
	parameter oversample =16)(
	clk, tick, en, in, rst,
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

	input wire clk, tick, en, in, rst;
	output reg [(bits-1):0] out;
	output reg done, busy, error;

	reg [2:0]             state       =reset;
	reg [(bits-1):0]      data        =1'd0;
	reg [(bitsWidth-1):0] bitIndex    =1'd0;
	reg [(osrWidth-1):0]  sampleCount =1'd0;

	//Two registers for mitigating Metastability
	reg rx =1'b1;
	reg rxPrev =1'b1;

	always@(posedge clk)begin
		if(tick)begin
			rx <= in;
			rxPrev <=rx;

			if (rst)begin
				state <=idle;
				out   <=1'd0;
				done  <=1'b0;
				busy  <=1'b0;
				error <=1'b0;
				data  <=1'd0;
				sampleCount <=1'd0;
				bitIndex <=1'd0;
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
						bitIndex <=1'd0;
						data     <=1'd0;
						error    <=1'b0;
						done     <=1'b0;
						sampleCount <=1'd0;
						if(en&rxPrev&&(!rx))begin
							busy <=1'b1;
							state <=startBit;
						end
					end
					startBit:begin
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
						if(sampleCount==(oversample-1))begin
							sampleCount <=1'd0;
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
	end
endmodule

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

module tickgen#(
	parameter integer CLK    =100_000_000,
	parameter integer TICK   =1_000_000,
	parameter integer ACCwidth =24)(
	input  wire clk,
	input  wire rst,
	output reg  tick);

	localparam [63:0] SCALE =(64'd1 << ACCwidth);
	localparam [63:0] INC   =((TICK*SCALE)+(CLK/2))/CLK;

	reg  [ACCwidth-1:0] acc ={ACCwidth{1'b0}};
	wire [ACCwidth:0]   sum ={1'b0,acc}+INC[ACCwidth:0];

	always@(posedge clk) begin
		if (rst) begin
			acc  <={ACCwidth{1'b0}};
			tick <=1'b0;
		end
		else {tick, acc} <= sum;
	end
endmodule

module baudtickgen#(
    parameter integer CLK        =100_000_000,
    parameter integer baudrate   =1_000_000,
    parameter integer oversample =20,
    parameter integer ACCwidth   =24)(
    input  wire clk,
    input  wire rst,
    output wire ostick,
    output wire baudtick
);
    tickgen #(.CLK(CLK),.TICK(baudrate),.ACCwidth(ACCwidth)) baudtickgen(.clk(clk),.rst(rst),.tick(baudtick));
    tickgen #(.CLK(CLK),.TICK(baudrate*oversample),.ACCwidth(ACCwidth)) ostickgen(.clk(clk),.rst(rst),.tick(ostick));
endmodule

module uartTOP#(
	parameter integer boardCLK   =100_000_000,
	parameter integer oversample =20,
	parameter integer baudrate   =1_000_000,
	parameter integer ACCwidth   =24
)(
	input  wire clk,
	input  wire rst,

	input  wire uartRX,
	output wire uartTX,

	input  wire       TXstart,
	input  wire [7:0] TXitem,

	output wire TXdone,
	output wire TXbusy,

	output wire [7:0] RXout,
	output wire RXdone,
	output wire RXbusy,
	output wire RXerror);

	wire RXtick, TXtick;
	baudtickgen #(.CLK(boardCLK),.oversample(oversample),.baudrate(baudrate),.ACCwidth(ACCwidth)) baudGen(.clk(clk),.rst(rst),.ostick(RXtick),.baudtick(TXtick));
	transmit #(.bits(8)) TX(.clk(clk),.tick(TXtick),.en(1'b1),.start(TXstart),.in(TXitem),.out(uartTX),.done(TXdone),.busy(TXbusy));
	receive #(.bits(8),.oversample(oversample)) RX(.clk(clk),.tick(RXtick),.en(1'b1),.in(uartRX),.rst(rst),.out(RXout),.done(RXdone),.busy(RXbusy),.error(RXerror));

endmodule