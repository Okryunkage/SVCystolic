`timescale 1ns/1ps

module mnistBRAMTOP#(
	parameter bit useLutBits =1'b0,
	parameter int tile =8,
	parameter int fcTile =5,
	parameter parameterDir ="data/mcdc_int8_fixed")(
	input logic clk,rst,start,mcMode,
	input logic imgWriteEnable,
	input logic[9:0] imgWriteAddress,
	input logic[7:0] imgWriteData,
	output wire logic imgReady,imgLoaded,imgLoadError,
	input logic[3:0] randomWord,
	input logic randomValid,
	output wire logic randomReady,
	output wire logic busy,
	output logic done,resultValid,
	output logic[3:0] prediction,
	output wire logic signed[31:0] scores[0:9],
	output wire logic[7:0] usedMask1,
	output wire logic[15:0] usedMask2);

	typedef enum logic[3:0] {IDLE,MASK_START,MASK_WAIT,START1,WAIT1,START2,WAIT2,
		START_FC,WAIT_FC,WAIT_ARGMAX} stateType;
	stateType state;
	logic savedMC;
	wire maskBusy,maskDone;
	wire[7:0] generatedMask1;
	wire[15:0] generatedMask2;
	wire imageReadEnable,imageReadValid;
	wire[9:0] imageReadAddress;
	wire[7:0] imageReadData[0:0];
	wire linkReadEnable,linkReadValid,fcReadEnable,fcReadValid;
	wire[7:0] linkReadAddress;
	wire[6:0] fcReadAddress;
	wire[7:0] linkReadData[0:tile-1],fcReadData[0:tile-1];
	wire fcRequestEnable,fcInputValid;
	wire[9:0] fcRequestIndex;
	wire[7:0] fcInput[0:0];
	wire busy1,busy2,busyFC,done1,done2,doneFC;
	wire[10:0] fcWaddr;
	wire fcBaddr;
	wire signed[fcTile-1:0][7:0] fcWdata;
	wire signed[fcTile-1:0][7:0] fcBdata;
	wire[3:0] maximumIndex;
	wire maximumValid;
	wire acceptedStart =(state==IDLE) && start && imgLoaded && !imgWriteEnable && !rst;

	assign busy =(state!=IDLE);
	assign imgReady =!busy && !start && !rst;
	assign usedMask1 =savedMC?generatedMask1:8'hff;
	assign usedMask2 =savedMC?generatedMask2:16'hffff;

	mnistImageMEM imageMemory(
		.clk(clk),.rst(rst),.writeEnable(imgWriteEnable && imgReady),
		.writeAddress(imgWriteAddress),.writeData(imgWriteData),
		.loaded(imgLoaded),.loadError(imgLoadError),
		.readEnable(imageReadEnable),.readAddress(imageReadAddress),
		.readValid(imageReadValid),.readData(imageReadData));

	dropChannelMask#(.useLutBits(useLutBits),.channels1(8),.channels2(16)) maskGenerator(
		.clk(clk),.rst(rst),.start(state==MASK_START),
		.randomWord(randomWord),.randomValid(randomValid),.randomReady(randomReady),
		.busy(maskBusy),.done(maskDone),.mask1(generatedMask1),.mask2(generatedMask2));

	convTOP#(
		.tile(tile),.inChannels(1),.outChannels(8),.inHeight(28),.inWidth(28),
		.dataWidth(8),.wWidth(8),.bWidth(8),.accWidth(32),.actWidth(8),
		.biasShift(5),.requantShift(7),.inSigned(1'b1),
		.inputLanes(1),
		.poolKernelSize(2),.poolStride(2),
		.wInitFile({parameterDir,"/conv1_w.mem"}),.bInitFile({parameterDir,"/conv1_b.mem"})) conv1(
		.clk(clk),.rst(rst),.start(state==START1),.channelMask(usedMask1),
		.busy(busy1),.done(done1),
		.readEnable(linkReadEnable),.readAddress(linkReadAddress),
		.readValid(linkReadValid),.readData(linkReadData),
		.inReadEnable(imageReadEnable),.inReadAddress(imageReadAddress),
		.inReadValid(imageReadValid),.inReadData(imageReadData));

	convTOP#(
		.tile(tile),.inChannels(8),.outChannels(16),.inHeight(14),.inWidth(14),
		.dataWidth(8),.wWidth(8),.bWidth(8),.accWidth(32),.actWidth(8),
		.biasShift(5),.requantShift(8),.inSigned(1'b0),.inputLanes(tile),
		.poolKernelSize(2),.poolStride(2),
		.wInitFile({parameterDir,"/conv2_w.mem"}),.bInitFile({parameterDir,"/conv2_b.mem"})) conv2(
		.clk(clk),.rst(rst),.start(state==START2),.channelMask(usedMask2),
		.busy(busy2),.done(done2),
		.inReadEnable(linkReadEnable),.inReadAddress(linkReadAddress),
		.inReadValid(linkReadValid),.inReadData(linkReadData),
		.readEnable(fcReadEnable),.readAddress(fcReadAddress),
		.readValid(fcReadValid),.readData(fcReadData));

	//784 logical FC inputs: packed BRAM words are read in channel-major order.
	fcInputReader#(.inChannels(16),.inHeight(7),.inWidth(7),.inputLanes(tile)) fcReader(
		.clk(clk),.rst(rst),.requestEnable(fcRequestEnable),.requestIndex(fcRequestIndex),
		.readEnable(fcReadEnable),.readAddress(fcReadAddress),.readValid(fcReadValid),.readData(fcReadData),
		.outValid(fcInputValid),.outData(fcInput));
	convMEM#(
		.tile(fcTile),.inChannels(784),.outChannels(10),.kernelH(1),.kernelW(1),
		.wWidth(8),.bWidth(8),
		.wInitFile({parameterDir,"/classifier_w.mem"}),.bInitFile({parameterDir,"/classifier_b.mem"})) fcMemory(
		.clk(clk),.waddr(fcWaddr),.baddr(fcBaddr),.wdata(fcWdata),.bdata(fcBdata));

	fcCore#(.tile(fcTile),.inNum(784),
		.dataWidth(8),.bWidth(8),.accWidth(32),.biasShift(4)) classifier(
		.clk(clk),.rst(rst),.start(state==START_FC),
		.requestEnable(fcRequestEnable),.requestIndex(fcRequestIndex),.inValid(fcInputValid),.inData(fcInput),
		.wdata(fcWdata),.bdata(fcBdata),.waddr(fcWaddr),.baddr(fcBaddr),
		.busy(busyFC),.done(doneFC),.outData(scores));
	argmax_pipe#(.width(32),.number(10)) classify(
		.clk(clk),.rst(rst),.inValid((state==WAIT_FC) && doneFC),
		.inData(scores),.outValid(maximumValid),.outIndex(maximumIndex));

	always_ff@(posedge clk)begin
		if(rst)begin
			state <=IDLE;
			savedMC <=0;
			done <=0;
			resultValid <=0;
			prediction <=0;
		end
		else begin
			done <=0;
			if(imgWriteEnable && imgReady) resultValid <=0;
			case(state)
				IDLE: if(acceptedStart)begin
					savedMC <=mcMode;
					resultValid <=0;
					state <=mcMode?MASK_START:START1;
				end
				MASK_START: state <=MASK_WAIT;
				MASK_WAIT: if(maskDone) state <=START1;
				START1: state <=WAIT1;
				WAIT1: if(done1) state <=START2;
				START2: state <=WAIT2;
				WAIT2: if(done2) state <=START_FC;
				START_FC: state <=WAIT_FC;
				WAIT_FC: if(doneFC) state <=WAIT_ARGMAX;
				WAIT_ARGMAX: if(maximumValid)begin
					prediction <=maximumIndex;
					resultValid <=1;
					done <=1;
					state <=IDLE;
				end
				default: state <=IDLE;
			endcase
		end
	end
	`ifndef SYNTHESIS
	initial if(tile!=8 || fcTile!=5) $fatal(1,"BRAM integration requires Conv tile=8 and FC tile=5");
	`endif
endmodule
