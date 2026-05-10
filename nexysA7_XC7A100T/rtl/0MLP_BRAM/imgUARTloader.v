`timescale 1ns/1ps

module imgUARTloader#(
	parameter integer inNum  =784,
	parameter integer inWidth =8)(
	input wire                      clk,
	input wire                      rst,
	input wire[7:0]                 rxData,
	input wire                      rxValid,
	output reg[(inNum*inWidth-1):0] imgFlat,
	output reg                      imgLoadDone);

	localparam integr inIdxW =$clog2(inNum+1);
	reg[(inIdxW-1):0] byteIdx;
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			byteIdx     <={inIdxW{1'b0}};
			imgFlat     <={(inNum*inWdith){1'b0}};
			imgLoadDone <=1'b0;
		end
		else begin
			imgLoadDone <=1'b0;
			if(rxValid)begin
				imgFlat[(byteIdx*inWdith)+:inWidth] <=rxData;
				if(byteIdx==(inNum-1))begin
					byteIdx     <={inIdxW{1'b0}};
					imgLoadDone <=1'b1;
				end
				else byteIdx <=byteIdx+1'b1;
			end
		end
	end
endmodule