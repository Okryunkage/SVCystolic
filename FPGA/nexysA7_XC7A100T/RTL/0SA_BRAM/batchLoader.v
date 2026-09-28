`timescale 1ns/1ps

module batchLoader #(
	parameter integer BATCH_SIZE     =100,
	parameter integer IMAGE_BYTES    =784,
	parameter integer TILE_SIZE      =10,
	parameter integer INPUT_TILE_NUM =79,
	parameter integer ADDR_WIDTH     =16
)(
	input  wire clk,
	input  wire rst,
	input  wire start,

	input  wire [7:0] rxData,
	input  wire       rxDone,
	input  wire       rxError,

	output reg                    bramEn,
	output reg                    bramWe,
	output reg [ADDR_WIDTH-1:0]   bramAddr,
	output reg [8*TILE_SIZE-1:0]  bramDin,

	output reg busy,
	output reg done,
	output reg error,

	output reg [ADDR_WIDTH-1:0] dbgImageIndex,
	output reg [ADDR_WIDTH-1:0] dbgPixelIndex,
	output reg [ADDR_WIDTH-1:0] dbgWordAddr,
	output reg [3:0]            dbgByteInTile
);

	localparam [1:0] S_IDLE  =2'd0;
	localparam [1:0] S_LOAD  =2'd1;
	localparam [1:0] S_DONE  =2'd2;
	localparam [1:0] S_ERROR =2'd3;

	reg [1:0] state;

	reg rxDoneD;
	wire rxDoneRise =rxDone & ~rxDoneD;

	reg [8*TILE_SIZE-1:0] wordBuf;
	reg [3:0] byteInTile;

	reg [ADDR_WIDTH-1:0] imageIndex;
	reg [ADDR_WIDTH-1:0] pixelIndex;
	reg [ADDR_WIDTH-1:0] wordAddr;

	reg [8*TILE_SIZE-1:0] nextWord;

	always@(*)begin
		nextWord =wordBuf;
		nextWord[byteInTile*8 +: 8] =rxData;
	end

	always@(posedge clk)begin
		if(rst)begin
			state <=S_IDLE;

			rxDoneD <=1'b0;

			bramEn <=1'b0;
			bramWe <=1'b0;
			bramAddr <={ADDR_WIDTH{1'b0}};
			bramDin <={8*TILE_SIZE{1'b0}};

			busy <=1'b0;
			done <=1'b0;
			error <=1'b0;

			wordBuf <={8*TILE_SIZE{1'b0}};
			byteInTile <=4'd0;

			imageIndex <=0;
			pixelIndex <=0;
			wordAddr <=0;

			dbgImageIndex <=0;
			dbgPixelIndex <=0;
			dbgWordAddr <=0;
			dbgByteInTile <=0;
		end
		else begin
			rxDoneD <=rxDone;

			bramEn <=1'b0;
			bramWe <=1'b0;
			done <=1'b0;

			dbgImageIndex <=imageIndex;
			dbgPixelIndex <=pixelIndex;
			dbgWordAddr <=wordAddr;
			dbgByteInTile <=byteInTile;

			case(state)
				S_IDLE:begin
					busy <=1'b0;
					error <=1'b0;

					wordBuf <={8*TILE_SIZE{1'b0}};
					byteInTile <=4'd0;

					imageIndex <=0;
					pixelIndex <=0;
					wordAddr <=0;

					if(start)begin
						busy <=1'b1;
						state <=S_LOAD;
					end
				end

				S_LOAD:begin
					busy <=1'b1;

					if(rxDoneRise)begin
						if(rxError)begin
							error <=1'b1;
							busy <=1'b0;
							state <=S_ERROR;
						end
						else begin
							// PC already sends signed int8 byte.
							// Store rxData as-is.
							if((byteInTile ==TILE_SIZE-1) || (pixelIndex ==IMAGE_BYTES-1))begin
								bramEn <=1'b1;
								bramWe <=1'b1;
								bramAddr <=wordAddr;
								bramDin <=nextWord;

								wordBuf <={8*TILE_SIZE{1'b0}};
								byteInTile <=4'd0;
								wordAddr <=wordAddr +1'b1;

								if(pixelIndex ==IMAGE_BYTES-1)begin
									pixelIndex <=0;

									if(imageIndex ==BATCH_SIZE-1)begin
										imageIndex <=0;
										busy <=1'b0;
										done <=1'b1;
										state <=S_DONE;
									end
									else begin
										imageIndex <=imageIndex +1'b1;
									end
								end
								else begin
									pixelIndex <=pixelIndex +1'b1;
								end
							end
							else begin
								wordBuf <=nextWord;
								byteInTile <=byteInTile +1'b1;
								pixelIndex <=pixelIndex +1'b1;
							end
						end
					end
				end

				S_DONE:begin
					busy <=1'b0;

					// If start is asserted again, reload from image 0 / addr 0.
					if(start)begin
						wordBuf <={8*TILE_SIZE{1'b0}};
						byteInTile <=4'd0;
						imageIndex <=0;
						pixelIndex <=0;
						wordAddr <=0;
						busy <=1'b1;
						state <=S_LOAD;
					end
				end

				S_ERROR:begin
					busy <=1'b0;
					error <=1'b1;

					if(start)begin
						error <=1'b0;
						wordBuf <={8*TILE_SIZE{1'b0}};
						byteInTile <=4'd0;
						imageIndex <=0;
						pixelIndex <=0;
						wordAddr <=0;
						busy <=1'b1;
						state <=S_LOAD;
					end
				end

				default:begin
					state <=S_IDLE;
				end
			endcase
		end
	end

endmodule