`timescale 1ns/1ps

module predSender #(
	parameter integer BATCH_SIZE  =100,
	parameter integer ADDR_WIDTH  =16,
	parameter integer SEND_HEADER =1,
	parameter [7:0] HEADER0 =8'hCC,
	parameter [7:0] HEADER1 =8'h33
)(
	input  wire clk,
	input  wire rst,
	input  wire start,

	output reg  [ADDR_WIDTH-1:0] predReadImage,
	input  wire [3:0]            predReadData,

	output reg        txStart,
	output reg [7:0]  txItem,
	input  wire       txDone,
	input  wire       txBusy,

	output reg busy,
	output reg done,

	output reg [ADDR_WIDTH-1:0] dbgSendIndex,
	output reg [3:0]            dbgState
);

	localparam [3:0] S_IDLE       =4'd0;
	localparam [3:0] S_HEADER0    =4'd1;
	localparam [3:0] S_HEADER1    =4'd2;
	localparam [3:0] S_BATCH      =4'd3;
	localparam [3:0] S_PRED_ADDR  =4'd4;
	localparam [3:0] S_PRED_WAIT1 =4'd5;
	localparam [3:0] S_PRED_WAIT2 =4'd6;
	localparam [3:0] S_TX_HOLD    =4'd7;
	localparam [3:0] S_TX_WAIT    =4'd8;
	localparam [3:0] S_AFTER_TX   =4'd9;
	localparam [3:0] S_DONE       =4'd10;

	localparam [1:0] KIND_H0   =2'd0;
	localparam [1:0] KIND_H1   =2'd1;
	localparam [1:0] KIND_BSZ  =2'd2;
	localparam [1:0] KIND_PRED =2'd3;

	reg [3:0] state;
	reg [1:0] sentKind;

	reg [ADDR_WIDTH-1:0] sendIndex;

	reg txDoneD;
	wire txDoneRise =txDone & ~txDoneD;

	always@(posedge clk)begin
		if(rst)begin
			state <=S_IDLE;
			sentKind <=KIND_H0;

			predReadImage <=0;

			txStart <=1'b0;
			txItem <=8'd0;
			txDoneD <=1'b0;

			busy <=1'b0;
			done <=1'b0;

			sendIndex <=0;
			dbgSendIndex <=0;
			dbgState <=0;
		end
		else begin
			txDoneD <=txDone;

			done <=1'b0;
			dbgSendIndex <=sendIndex;
			dbgState <=state;

			case(state)
				S_IDLE:begin
					busy <=1'b0;
					txStart <=1'b0;
					sendIndex <=0;
					predReadImage <=0;

					if(start)begin
						busy <=1'b1;
						if(SEND_HEADER !=0)
							state <=S_HEADER0;
						else
							state <=S_PRED_ADDR;
					end
				end

				S_HEADER0:begin
					txItem <=HEADER0;
					sentKind <=KIND_H0;
					txStart <=1'b1;
					state <=S_TX_HOLD;
				end

				S_HEADER1:begin
					txItem <=HEADER1;
					sentKind <=KIND_H1;
					txStart <=1'b1;
					state <=S_TX_HOLD;
				end

				S_BATCH:begin
					txItem <=BATCH_SIZE[7:0];
					sentKind <=KIND_BSZ;
					txStart <=1'b1;
					state <=S_TX_HOLD;
				end

				S_PRED_ADDR:begin
					predReadImage <=sendIndex;
					state <=S_PRED_WAIT1;
				end

				S_PRED_WAIT1:begin
					// linear10Engine_regacc predReadData is synchronous.
					// Address was just applied in previous state.
					state <=S_PRED_WAIT2;
				end

				S_PRED_WAIT2:begin
					txItem <= {4'b0000,predReadData};
					sentKind <=KIND_PRED;
					txStart <=1'b1;
					state <=S_TX_HOLD;
				end

				S_TX_HOLD:begin
					// uart transmit samples start only on TX baud tick.
					// Therefore keep txStart high until txBusy becomes 1.
					txStart <=1'b1;

					if(txBusy)begin
						txStart <=1'b0;
						state <=S_TX_WAIT;
					end
				end

				S_TX_WAIT:begin
					txStart <=1'b0;

					if(txDoneRise)begin
						state <=S_AFTER_TX;
					end
				end

				S_AFTER_TX:begin
					txStart <=1'b0;

					case(sentKind)
						KIND_H0:begin
							state <=S_HEADER1;
						end

						KIND_H1:begin
							state <=S_BATCH;
						end

						KIND_BSZ:begin
							sendIndex <=0;
							state <=S_PRED_ADDR;
						end

						KIND_PRED:begin
							if(sendIndex ==BATCH_SIZE-1)begin
								state <=S_DONE;
							end
							else begin
								sendIndex <=sendIndex +1'b1;
								state <=S_PRED_ADDR;
							end
						end

						default:begin
							state <=S_DONE;
						end
					endcase
				end

				S_DONE:begin
					busy <=1'b0;
					done <=1'b1;
					txStart <=1'b0;
					state <=S_IDLE;
				end

				default:begin
					state <=S_IDLE;
				end
			endcase
		end
	end

endmodule