`timescale 1ns/1ps

module convBRAM#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int inHeight=28, inWidth=28,
	parameter int kernelH=3, kernelW=3,
	parameter int strideH=1, strideW=1, padH=1, padW=1,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter bit inSigned=1'b0,
	parameter     wInitFile="conv_w_tile.mem",
	parameter     bInitFile="conv_b_tile.mem",
	parameter int outHeight=((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int outWidth=((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	parameter int wDepth=numTile*kernelTerms,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk, rst, start,
	input logic[dataWidth-1:0]
		inData[0:inChannels-1][0:inHeight-1][0:inWidth-1],
	output logic busy, done,
	output logic signed[accWidth-1:0]
		outData[0:outChannels-1][0:outHeight-1][0:outWidth-1]);

	logic[wAddrW-1:0] waddr;
	logic[bAddrW-1:0] baddr;
	logic signed[tile-1:0][wWidth-1:0] wdata;
	logic signed[tile-1:0][bWidth-1:0] bdata;

	convMEM#(
		.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.kernelH(kernelH),.kernelW(kernelW),
		.wWidth(wWidth),.bWidth(bWidth),
		.wInitFile(wInitFile),.bInitFile(bInitFile),
		.numTile(numTile),.kernelTerms(kernelTerms),.wDepth(wDepth),
		.wAddrW(wAddrW),.bAddrW(bAddrW)) memory(
		.clk(clk),.waddr(waddr),.baddr(baddr),.wdata(wdata),.bdata(bdata));

	convCore_pipe#(
		.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.inHeight(inHeight),.inWidth(inWidth),
		.kernelH(kernelH),.kernelW(kernelW),
		.strideH(strideH),.strideW(strideW),.padH(padH),.padW(padW),
		.dataWidth(dataWidth),.wWidth(wWidth),.bWidth(bWidth),
		.accWidth(accWidth),.inSigned(inSigned),
		.outHeight(outHeight),.outWidth(outWidth),
		.numTile(numTile),.kernelTerms(kernelTerms),.wDepth(wDepth),
		.wAddrW(wAddrW),.bAddrW(bAddrW)) core(
		.clk(clk),.rst(rst),.start(start),.inData(inData),
		.wdata(wdata),.bdata(bdata),.waddr(waddr),.baddr(baddr),
		.busy(busy),.done(done),.outData(outData));

endmodule
