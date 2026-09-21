`timescale 1ns/1ps

module convMEM#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int kernelH=3, kernelW=3,
	parameter int wWidth=8,
	parameter int bWidth=8,
	parameter     wInitFile="conv_w_tile.mem",
	parameter     bInitFile="conv_b_tile.mem",
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	parameter int wDepth=numTile*kernelTerms,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk,
	input logic[wAddrW-1:0] waddr,
	input logic[bAddrW-1:0] baddr,
	output logic signed[tile-1:0][wWidth-1:0] wdata,
	output logic signed[tile-1:0][bWidth-1:0] bdata);

	localparam int wWordWidth =tile*wWidth;
	localparam int bWordWidth =tile*bWidth;
	localparam int bMemoryDepth =(numTile>1)?numTile:2;
	//XPM requires a memory to contain at least two addressable words.
	logic[wWordWidth-1:0] weightWord;
	logic[bWordWidth-1:0] biasWord;

	assign wdata=weightWord;
	assign bdata=biasWord;

	xpm_memory_spram #(
		.ADDR_WIDTH_A(wAddrW),
		.AUTO_SLEEP_TIME(0),
		.BYTE_WRITE_WIDTH_A(wWordWidth),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE(wInitFile),
		.MEMORY_INIT_PARAM(""),
		.MEMORY_OPTIMIZATION("true"),
		.MEMORY_PRIMITIVE("block"),
		.MEMORY_SIZE(wWordWidth*wDepth),
		.MESSAGE_CONTROL(0),
		.READ_DATA_WIDTH_A(wWordWidth),
		.READ_LATENCY_A(2),
		.READ_RESET_VALUE_A("0"),
		.RST_MODE_A("SYNC"),
		.USE_MEM_INIT(1),
		.WAKEUP_TIME("disable_sleep"),
		.WRITE_DATA_WIDTH_A(wWordWidth),
		.WRITE_MODE_A("read_first")) weightMemory(
		.clka(clk),
		.ena(1'b1),
		.wea(1'b0),
		.addra(waddr),
		.dina('0),
		.douta(weightWord),
		.rsta(1'b0),
		.regcea(1'b1),
		.sleep(1'b0),
		.injectsbiterra(1'b0),
		.injectdbiterra(1'b0),
		.sbiterra(),
		.dbiterra());

	xpm_memory_spram #(
		.ADDR_WIDTH_A(bAddrW),
		.AUTO_SLEEP_TIME(0),
		.BYTE_WRITE_WIDTH_A(bWordWidth),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE(bInitFile),
		.MEMORY_INIT_PARAM(""),
		.MEMORY_OPTIMIZATION("true"),
		.MEMORY_PRIMITIVE("block"),
		.MEMORY_SIZE(bWordWidth*bMemoryDepth),
		.MESSAGE_CONTROL(0),
		.READ_DATA_WIDTH_A(bWordWidth),
		.READ_LATENCY_A(2),
		.READ_RESET_VALUE_A("0"),
		.RST_MODE_A("SYNC"),
		.USE_MEM_INIT(1),
		.WAKEUP_TIME("disable_sleep"),
		.WRITE_DATA_WIDTH_A(bWordWidth),
		.WRITE_MODE_A("read_first")) biasMemory(
		.clka(clk),
		.ena(1'b1),
		.wea(1'b0),
		.addra(baddr),
		.dina('0),
		.douta(biasWord),
		.rsta(1'b0),
		.regcea(1'b1),
		.sleep(1'b0),
		.injectsbiterra(1'b0),
		.injectdbiterra(1'b0),
		.sbiterra(),
		.dbiterra());

endmodule
