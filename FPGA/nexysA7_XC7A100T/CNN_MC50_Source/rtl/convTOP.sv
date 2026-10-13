`timescale 1ns/1ps

module convTOP#(
	parameter int tile =8,inChannels =1,outChannels =8,inHeight =28,inWidth =28,
	parameter int inputLanes =1,
	parameter int kernelH =3,kernelW =3,strideH =1,strideW =1,padH =1,padW =1,
	parameter int dataWidth =8,wWidth =8,bWidth =8,accWidth =32,actWidth =8,
	parameter int biasShift =0,requantShift =10,
	parameter bit inSigned =1'b0,
	parameter int poolKernelSize =2,poolStride =2,
	parameter wInitFile ="conv_w_tile.mem",bInitFile ="conv_b_tile.mem",
	parameter int convHeight =(inHeight+2*padH-kernelH)/strideH+1,
	parameter int convWidth =(inWidth+2*padW-kernelW)/strideW+1,
	parameter int outHeight =(convHeight-poolKernelSize)/poolStride+1,
	parameter int outWidth =(convWidth-poolKernelSize)/poolStride+1,
	parameter int inputDepth =((inChannels+inputLanes-1)/inputLanes)*inHeight*inWidth,
	parameter int inputAddrW =(inputDepth>1)?$clog2(inputDepth):1,
	parameter int outDepth =(outChannels/tile)*outHeight*outWidth,
	parameter int outAddrW =(outDepth>1)?$clog2(outDepth):1)(
	input logic clk,rst,start,
	input logic[outChannels-1:0] channelMask,
	output wire logic busy,done,
	output wire logic inReadEnable,
	output wire logic[inputAddrW-1:0] inReadAddress,
	input logic inReadValid,
	input logic[dataWidth-1:0] inReadData[0:inputLanes-1],
	input logic readEnable,
	input logic[outAddrW-1:0] readAddress,
	output wire logic readValid,
	output wire logic[actWidth-1:0] readData[0:tile-1]);

	localparam int numTile =outChannels/tile,kernelTerms =inChannels*kernelH*kernelW;
	localparam int wDepth =numTile*kernelTerms;
	localparam int wAddrW =(wDepth>1)?$clog2(wDepth):1;
	localparam int bAddrW =(numTile>1)?$clog2(numTile):1;
	localparam int termIdxW =(kernelTerms>1)?$clog2(kernelTerms):1;
	localparam int rowW =(convHeight>1)?$clog2(convHeight):1;
	localparam int colW =(convWidth>1)?$clog2(convWidth):1;
	localparam int wordWidth =tile*actWidth;
	localparam int memoryDepth =(outDepth>1)?outDepth:2;
	wire coreStart =start && !busy && !rst;
	wire[wAddrW-1:0] waddr;
	wire[bAddrW-1:0] baddr;
	wire signed[tile-1:0][wWidth-1:0] wdata;
	wire signed[tile-1:0][bWidth-1:0] bdata;
	wire requestEnable,inputValid;
	wire[termIdxW-1:0] requestTerm;
	wire[rowW-1:0] requestRow;
	wire[colW-1:0] requestColumn;
	wire[dataWidth-1:0] inputData[0:0];
	wire outWriteEnable;
	wire[outAddrW-1:0] outWriteAddress;
	wire[actWidth-1:0] outData[0:tile-1];
	wire[wordWidth-1:0] writeWord,readWord;
	wire writeRequest =outWriteEnable && !rst;
	wire readRequest =readEnable && !rst && !busy && !start && !writeRequest && readAddress<outDepth;
	wire[outAddrW-1:0] memoryAddress =writeRequest?outWriteAddress:readAddress;
	logic[1:0] readValidPipeline;
	assign readValid =readValidPipeline[1] && !rst;
	for(genvar lane =0;lane<tile;lane =lane+1)begin:MEMORY_LANES
		assign writeWord[lane*actWidth+:actWidth] =outData[lane];
		assign readData[lane] =readWord[lane*actWidth+:actWidth];
	end
	always_ff@(posedge clk)begin
		if(rst) readValidPipeline <='0;
		else readValidPipeline <={readValidPipeline[0],readRequest};
	end

	convInputReader#(.inChannels(inChannels),.inHeight(inHeight),.inWidth(inWidth),
		.inputLanes(inputLanes),.dataWidth(dataWidth),.kernelH(kernelH),.kernelW(kernelW),
		.strideH(strideH),.strideW(strideW),.padH(padH),.padW(padW)) reader(
		.clk(clk),.rst(rst),.requestEnable(requestEnable),.requestTerm(requestTerm),
		.requestRow(requestRow),.requestColumn(requestColumn),
		.readEnable(inReadEnable),.readAddress(inReadAddress),
		.readValid(inReadValid),.readData(inReadData),.outValid(inputValid),.outData(inputData));
	convMEM#(.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.kernelH(kernelH),.kernelW(kernelW),.wWidth(wWidth),.bWidth(bWidth),
		.wInitFile(wInitFile),.bInitFile(bInitFile)) memory(
		.clk(clk),.waddr(waddr),.baddr(baddr),.wdata(wdata),.bdata(bdata));
	convCore#(.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.inHeight(inHeight),.inWidth(inWidth),.kernelH(kernelH),.kernelW(kernelW),
		.strideH(strideH),.strideW(strideW),.padH(padH),.padW(padW),
		.dataWidth(dataWidth),.wWidth(wWidth),.bWidth(bWidth),.accWidth(accWidth),
		.actWidth(actWidth),.biasShift(biasShift),.requantShift(requantShift),.inSigned(inSigned),
		.poolKernelSize(poolKernelSize),.poolStride(poolStride)) core(
		.clk(clk),.rst(rst),.start(coreStart),.channelMask(channelMask),
		.requestEnable(requestEnable),.requestTerm(requestTerm),.requestRow(requestRow),.requestColumn(requestColumn),
		.inValid(inputValid),.inData(inputData),.wdata(wdata),.bdata(bdata),.waddr(waddr),.baddr(baddr),
		.busy(busy),.done(done),.outWriteEnable(outWriteEnable),.outWriteAddress(outWriteAddress),.outData(outData));

	xpm_memory_spram#(
		.ADDR_WIDTH_A(outAddrW),.BYTE_WRITE_WIDTH_A(wordWidth),.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_PRIMITIVE("block"),
		.MEMORY_SIZE(wordWidth*memoryDepth),.READ_DATA_WIDTH_A(wordWidth),.READ_LATENCY_A(2),
		.READ_RESET_VALUE_A("0"),.RST_MODE_A("SYNC"),.USE_MEM_INIT(0),
		.WRITE_DATA_WIDTH_A(wordWidth),.WRITE_MODE_A("read_first")) outputMemory(
		.clka(clk),.ena(writeRequest || readRequest),.wea(writeRequest),
		.addra(memoryAddress),.dina(writeWord),.douta(readWord),.regcea(1'b1),.rsta(rst),
		.sleep(1'b0),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.sbiterra(),.dbiterra());
		
	`ifndef SYNTHESIS
	always@(posedge clk)begin
		if(!rst && readEnable && !readRequest) $fatal(1,"convTOP output memory read not accepted");
		if(!rst && writeRequest && outWriteAddress>=outDepth) $fatal(1,"convTOP write out of range");
	end
	`endif
endmodule
