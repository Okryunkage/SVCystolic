`timescale 1ns/1ps

module labelReader#(
	parameter addrWidth =27,
	parameter [(addrWidth-1):0] addrStride =27'd8,
	parameter byte0LSB =1)(//byte0 is located in ddrData[7:0] (little endian)
	input wire clk,
	input wire rst,
	input wire start,
	input wire [(addrWidth-1):0] labelBaseAddr,
	input wire [31:0] labelIndex,
	output reg [(addrWidth-1):0] ddrAddr,
	output reg ddrRstrobe,
	input wire [127:0] ddrData,
	input wire ddrReady,
	input wire ddrTranComp,
	output reg busy,
	output reg done,
	output reg [7:0] label);

	reg [1:0] state;
	localparam IDLEs =2'd0;
	localparam REQs  =2'd1;
	localparam WAITs =2'd2;
	localparam DONEs =2'd3;

	wire [31:0] labelLine =labelIndex>>4;//equals to labelIndex/16 | value for what line of DDR that include target label
	wire [3:0]  byteIndex =labelIndex[3:0];//value for what location in line that include target label

	function [7:0] getByte128;
		input [127:0] word;
		input [3:0] idx;begin
			if(byte0LSB) getByte128 =word[idx*8+:8];
			else         getByte128 =word[(15-idx)*8+:8];
		end
	endfunction

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLEs;
			ddrAddr <={addrWidth{1'b0}};
			ddrRstrobe <=1'b0;
			busy <=1'b0;
			done <=1'b0;
			label <=8'd0;
		end
		else begin
			ddrRstrobe <=1'b0;
			done <=1'b0;
			case(state)
				IDLEs:begin
					busy <=1'b0;
					if(start)begin
						busy <=1'b1;
						state <=REQs;
					end
				end
				REQs:begin
					if(ddrReady)begin
						ddrAddr <=labelBaseAddr+(labelLine*addrStride);
						ddrRstrobe <=1'b1;
						state <=WAITs;
					end
				end
				WAITs:begin
					if(ddrTranComp)begin
						label <=getByte128(ddrData,byteIndex);
						state <=DONEs;
					end
				end
				DONEs:begin
					busy <=1'b0;
					done <=1'b1;
					state <=IDLEs;
				end
				default:state <=IDLEs;
			endcase
		end
	end
endmodule
