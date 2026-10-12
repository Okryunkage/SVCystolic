`timescale 1ns/1ps

module convTOP#(
	parameter int tile=8,inChannels=1,outChannels=8,
	parameter int inHeight=28,inWidth=28,
	parameter int kernelH=3,kernelW=3,strideH=1,strideW=1,padH=1,padW=1,
	parameter int dataWidth=8,wWidth=8,bWidth=8,accWidth=32,actWidth=8,
	parameter int biasShift=5,requantShift=7,
	parameter bit inSigned=1'b0,
	parameter wInitFile="conv_w_tile.mem",bInitFile="conv_b_tile.mem",
	parameter int poolKernelSize=2,poolStride=2,
	parameter int convHeight=(inHeight+2*padH-kernelH)/strideH+1,
	parameter int convWidth=(inWidth+2*padW-kernelW)/strideW+1,
	parameter int outHeight=(convHeight-poolKernelSize)/poolStride+1,
	parameter int outWidth=(convWidth-poolKernelSize)/poolStride+1)(
	input logic clk,rst,start,
	input logic[outChannels-1:0] channelMask,
	input logic[dataWidth-1:0] inData[0:inChannels-1][0:inHeight-1][0:inWidth-1],
	output wire logic busy,
	output wire logic done,
	output wire logic[actWidth-1:0] outData[0:outChannels-1][0:outHeight-1][0:outWidth-1]);

	localparam int numTile=outChannels/tile;
	localparam int wDepth=numTile*inChannels*kernelH*kernelW;
	localparam int wAddrW=(wDepth>1)?$clog2(wDepth):1;
	localparam int bAddrW=(numTile>1)?$clog2(numTile):1;
	wire coreStart=start && !busy && !rst;
	wire[wAddrW-1:0] waddr;
	wire[bAddrW-1:0] baddr;
	wire signed[tile-1:0][wWidth-1:0] wdata;
	wire signed[tile-1:0][bWidth-1:0] bdata;

	memory_wrapper#(.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.kernelH(kernelH),.kernelW(kernelW),.wWidth(wWidth),.bWidth(bWidth),
		.wInitFile(wInitFile),.bInitFile(bInitFile)) memory(
		.clk(clk),.waddr(waddr),.baddr(baddr),.wdata(wdata),.bdata(bdata));
	convCore#(.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.inHeight(inHeight),.inWidth(inWidth),.kernelH(kernelH),.kernelW(kernelW),
		.strideH(strideH),.strideW(strideW),.padH(padH),.padW(padW),
		.dataWidth(dataWidth),.wWidth(wWidth),.bWidth(bWidth),.accWidth(accWidth),
		.actWidth(actWidth),.biasShift(biasShift),.requantShift(requantShift),.inSigned(inSigned),
		.poolKernelSize(poolKernelSize),.poolStride(poolStride),
		.convHeight(convHeight),.convWidth(convWidth),.outHeight(outHeight),.outWidth(outWidth)) core(
		.clk(clk),.rst(rst),.start(coreStart),.channelMask(channelMask),.inData(inData),
		.wdata(wdata),.bdata(bdata),.waddr(waddr),.baddr(baddr),
		.busy(busy),.done(done),.outData(outData));
endmodule
