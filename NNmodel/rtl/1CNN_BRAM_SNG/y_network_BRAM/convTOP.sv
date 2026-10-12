`timescale 1ns/1ps

module convTOP#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int inHeight=28, inWidth=28,
	parameter int kernelH=3, kernelW=3,
	parameter int strideH=1, strideW=1, padH=1, padW=1,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter int actWidth=8, requantShift=10,
	parameter bit inSigned=1'b0,
	parameter     wInitFile="conv_w_tile.mem",
	parameter     bInitFile="conv_b_tile.mem",
	parameter int poolKernelSize=2, poolStride=2,
	parameter int convHeight=((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int convWidth=((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int outHeight=((convHeight-poolKernelSize)/poolStride)+1,
	parameter int outWidth=((convWidth-poolKernelSize)/poolStride)+1,
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	parameter int wDepth=numTile*kernelTerms,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1,
	parameter int outDepth=numTile*outHeight*outWidth,
	parameter int outAddrW=(outDepth>1)?$clog2(outDepth):1,
	parameter int readLatency=2,
	parameter int inTile=1, inReadLatency=2,
	parameter int inDepth=((inChannels+inTile-1)/inTile)*inHeight*inWidth,
	parameter int inAddrW=(inDepth>1)?$clog2(inDepth):1)(
	input logic clk, rst, start,
	input logic[outChannels-1:0] channelMask,
	output wire logic inReadEnable,
	output wire logic[inAddrW-1:0] inReadAddress,
	input logic inReadValid,
	input logic[dataWidth-1:0] inReadData[0:inTile-1],
	output logic busy, done,
	input logic readEnable,
	input logic[outAddrW-1:0] readAddress,
	output wire logic readValid,
	output wire logic[actWidth-1:0] readData[0:tile-1]);

	logic[wAddrW-1:0] waddr;
	logic[bAddrW-1:0] baddr;
	logic signed[tile-1:0][wWidth-1:0] wdata;
	logic signed[tile-1:0][bWidth-1:0] bdata;

	localparam int outWordWidth=tile*actWidth;
	localparam int outMemoryDepth=(outDepth>1)?outDepth:2;
	localparam int convDepth=numTile*convHeight*convWidth;
	localparam int convAddrW=(convDepth>1)?$clog2(convDepth):1;
	localparam int writeCountW=(outDepth>0)?$clog2(outDepth+1):1;
	localparam int tileCountW=(numTile>0)?$clog2(numTile+1):1;
	wire convValid,convBusy,convDone,coreStart;
	wire[convAddrW-1:0] convAddress;
	wire[actWidth-1:0] convData[0:tile-1];
	wire poolStart,poolValid,poolDone;
	wire[actWidth-1:0] poolData[0:tile-1];
	logic[writeCountW-1:0] poolWriteCount;
	logic[tileCountW-1:0] poolTiles;
	logic convFinished;
	wire[outAddrW-1:0] writeAddress;
	wire[outWordWidth-1:0] writeWord,readWord;
	wire writeRequest,readRequest;
	wire memoryEnable;
	wire[outAddrW-1:0] memoryAddress;
	logic[readLatency-1:0] readValidPipeline;
	integer stage;

	assign coreStart=start && !busy && !rst;
	//Start Pool before the first Conv sample and between complete channel tiles.
	assign poolStart=coreStart || (busy && poolDone && int'(poolTiles)<numTile-1);
	assign writeAddress=outAddrW'(poolWriteCount);
	assign writeRequest=poolValid && busy && !rst && (int'(poolWriteCount)<outDepth);
	//The complete Conv-Pool run owns the port, including final pipeline drain.
	assign readRequest =readEnable && !rst && !busy && !start &&
		!writeRequest && (readAddress<outDepth);
	assign memoryEnable=writeRequest || readRequest;
	assign memoryAddress=writeRequest ? writeAddress : readAddress;
	assign readValid=readValidPipeline[readLatency-1];

	genvar lane;
	generate
		for(lane=0;lane<tile;lane=lane+1)begin:OUTPUT_LANES
			assign writeWord[(lane*actWidth)+:actWidth]=poolData[lane];
			assign readData[lane]=readWord[(lane*actWidth)+:actWidth];
		end
	endgenerate

	always_ff@(posedge clk or posedge rst)begin
		if(rst) readValidPipeline <='0;
		else begin
			readValidPipeline[0] <=readRequest;
			for(stage=1;stage<readLatency;stage=stage+1)
				readValidPipeline[stage] <=readValidPipeline[stage-1];
		end
	end

	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			busy <=1'b0;
			done <=1'b0;
			convFinished <=1'b0;
			poolWriteCount <='0;
			poolTiles <='0;
		end
		else begin
			done <=1'b0;
			if(coreStart)begin
				busy <=1'b1;
				convFinished <=1'b0;
				poolWriteCount <='0;
				poolTiles <='0;
			end
			else if(busy)begin
				if(convDone) convFinished <=1'b1;
				if(poolDone) poolTiles <=poolTiles+1'b1;
				if(writeRequest) poolWriteCount <=poolWriteCount+1'b1;
				//Counters reflect committed writes, not newly presented Pool outputs.
				if(convFinished && int'(poolTiles)==numTile && int'(poolWriteCount)==outDepth)begin
					busy <=1'b0;
					done <=1'b1;
				end
			end
		end
	end

	convMEM#(
		.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.kernelH(kernelH),.kernelW(kernelW),
		.wWidth(wWidth),.bWidth(bWidth),
		.wInitFile(wInitFile),.bInitFile(bInitFile),
		.numTile(numTile),.kernelTerms(kernelTerms),.wDepth(wDepth),
		.wAddrW(wAddrW),.bAddrW(bAddrW)) memory(
		.clk(clk),.waddr(waddr),.baddr(baddr),.wdata(wdata),.bdata(bdata));

	convCore#(
		.tile(tile),.inChannels(inChannels),.outChannels(outChannels),
		.inHeight(inHeight),.inWidth(inWidth),
		.kernelH(kernelH),.kernelW(kernelW),
		.strideH(strideH),.strideW(strideW),.padH(padH),.padW(padW),
		.dataWidth(dataWidth),.wWidth(wWidth),.bWidth(bWidth),
		.accWidth(accWidth),.actWidth(actWidth),.requantShift(requantShift),
		.inSigned(inSigned),
		.outHeight(convHeight),.outWidth(convWidth),
		.numTile(numTile),.kernelTerms(kernelTerms),.wDepth(wDepth),
		.wAddrW(wAddrW),.bAddrW(bAddrW),
		.outDepth(convDepth),.outAddrW(convAddrW),
		.inTile(inTile),.inReadLatency(inReadLatency),
		.inDepth(inDepth),.inAddrW(inAddrW)) core(
		.clk(clk),.rst(rst),.start(coreStart),
		.inReadEnable(inReadEnable),.inReadAddress(inReadAddress),
		.inReadValid(inReadValid),.inReadData(inReadData),
		.channelMask(channelMask),
		.wdata(wdata),.bdata(bdata),.waddr(waddr),.baddr(baddr),
		.busy(convBusy),.done(convDone),
		.outValid(convValid),.outAddr(convAddress),.outData(convData));

	maxPool#(
		.channels(tile),.inHeight(convHeight),.inWidth(convWidth),
		.dataWidth(actWidth),.stride(poolStride),.kernelSize(poolKernelSize)) pool(
		.clk(clk),.rst(rst),.start(poolStart),
		.inValid(convValid),.inData(convData),
		.outValid(poolValid),.outData(poolData),.done(poolDone));

	xpm_memory_spram#(
		.ADDR_WIDTH_A(outAddrW),
		.BYTE_WRITE_WIDTH_A(outWordWidth),
		.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),
		.MEMORY_INIT_PARAM("0"),
		.MEMORY_PRIMITIVE("block"),
		.MEMORY_SIZE(outWordWidth*outMemoryDepth),
		.READ_DATA_WIDTH_A(outWordWidth),
		.READ_LATENCY_A(readLatency),
		.READ_RESET_VALUE_A("0"),
		.RST_MODE_A("SYNC"),
		.SIM_ASSERT_CHK(1),
		.USE_MEM_INIT(0),
		.WRITE_DATA_WIDTH_A(outWordWidth),
		.WRITE_MODE_A("read_first")) outputMemory(
		.clka(clk),
		.ena(memoryEnable),.wea(writeRequest),
		.addra(memoryAddress),.dina(writeWord),.douta(readWord),
		.regcea(1'b1),.rsta(rst),
		.sleep(1'b0),
		.injectsbiterra(1'b0),.injectdbiterra(1'b0),
		.sbiterra(),.dbiterra());

	`ifndef SYNTHESIS
	initial begin
		if(readLatency<1 || readLatency>100)
			$fatal(1,"convTOP requires 1 <= readLatency <= 100");
		if(poolKernelSize<1 || poolStride<1 || convHeight<poolKernelSize || convWidth<poolKernelSize)
			$fatal(1,"convTOP requires a valid Pool kernel and stride");
		if(outHeight!=(convHeight-poolKernelSize)/poolStride+1 ||
			outWidth!=(convWidth-poolKernelSize)/poolStride+1 || outDepth!=numTile*outHeight*outWidth)
			$fatal(1,"convTOP output dimensions must describe the pooled feature map");
		if(outAddrW<((outDepth>1)?$clog2(outDepth):1))
			$fatal(1,"convTOP outAddrW is too small");
	end
	always@(posedge clk)begin
		if(!rst && poolStart && convValid) $fatal(1,"Pool start overlaps Conv data");
		if(!rst && poolValid && (!busy || int'(poolWriteCount)>=outDepth))
			$fatal(1,"Unexpected Pool output");
	end
	`endif

endmodule
