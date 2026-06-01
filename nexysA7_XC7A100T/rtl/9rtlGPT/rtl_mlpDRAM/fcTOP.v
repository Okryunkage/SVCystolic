`timescale 1ns/1ps

module fcTOP#(
	parameter addrWidth =27,
	parameter [addrWidth-1:0] addrStride =27'd8,

	parameter fc1InNum  =784,
	parameter fc1OutNum =64,
	parameter fc2OutNum =10,

	parameter fc1Tile =8,
	parameter fc2Tile =5,

	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,

	//requant output width. This must match fc2DDR inWidth.
	parameter rqOutWidth =8,
	parameter rqShift    =10,

	parameter byte0LSB =1,
	parameter checkPB  =1)(
	input wire clk,
	input wire rst,
	input wire start,

	//DDR base addresses
	input wire [addrWidth-1:0] inBaseADDR,

	input wire [addrWidth-1:0] fc1wBaseADDR,
	input wire [addrWidth-1:0] fc1bBaseADDR,

	input wire [addrWidth-1:0] fc2wBaseADDR,
	input wire [addrWidth-1:0] fc2bBaseADDR,

	//Payload byte counts from ddrADDRbookP.
	input wire [31:0] inPB,
	input wire [31:0] fc1wPB,
	input wire [31:0] fc1bPB,
	input wire [31:0] fc2wPB,
	input wire [31:0] fc2bPB,

	//Shared DDR read interface to mig_ui128 mux.
	output wire [addrWidth-1:0] ddrAddr,
	output wire                 ddrRstrobe,
	input  wire [127:0]         ddrData,
	input  wire                 ddrReady,
	input  wire                 ddrTranComp,

	output reg busy,
	output reg done,

	//Final predicted label index
	output reg [($clog2(fc2OutNum)-1):0] outIndex,

	//Optional debug / observation outputs
	output wire signed [(fc1OutNum*accWidth-1):0] fc1OutFlat,
	output wire        [(fc1OutNum*rqOutWidth-1):0] rqOutFlat,
	output wire signed [(fc2OutNum*accWidth-1):0] fc2OutFlat,

	output wire fc1Done,
	output wire rqDone,
	output wire fc2Done,

	output wire fc1Busy,
	output wire fc2Busy,

	output wire fc1Error,
	output wire fc2Error,
	output wire error,

	output wire [4:0] fc1DebugState,
	output wire [4:0] fc2DebugState,
	output wire [31:0] fc1DebugInIdx,
	output wire [31:0] fc1DebugtileIdx,
	output wire [31:0] fc1DebugReadLine,
	output wire [31:0] fc2DebugInIdx,
	output wire [31:0] fc2DebugtileIdx,
	output wire [31:0] fc2DebugReadLine);

	//########################################
	//##          INTERNAL WIRES            ##
	//########################################
	wire fcStart;

	wire [addrWidth-1:0] fc1DDRaddr;
	wire [addrWidth-1:0] fc2DDRaddr;

	wire fc1DDRstrobe;
	wire fc2DDRstrobe;

	wire [addrWidth-1:0] fc1InLastADDR;
	wire [addrWidth-1:0] fc1wLastADDR;
	wire [addrWidth-1:0] fc1bLastADDR;
	wire [addrWidth-1:0] fc1LastReadADDR;

	wire [addrWidth-1:0] fc2wLastADDR;
	wire [addrWidth-1:0] fc2bLastADDR;
	wire [addrWidth-1:0] fc2LastReadADDR;

	wire fc1ConfigError;
	wire fc1PayloadSizeError;
	wire fc1DDRreadError;

	wire fc2ConfigError;
	wire fc2PayloadSizeError;
	wire fc2DDRreadError;

	wire [($clog2(fc2OutNum)-1):0] argmaxIndex;

	//No edge detection here.
	//finalTOP should generate a clean one-cycle start pulse.
	assign fcStart =start & ~busy;

	assign fc1Error =fc1ConfigError|fc1PayloadSizeError|fc1DDRreadError;
	assign fc2Error =fc2ConfigError|fc2PayloadSizeError|fc2DDRreadError;
	assign error    =fc1Error|fc2Error;

	//Only one layer uses DDR read interface at a time.
	assign ddrAddr =fc1DDRstrobe ? fc1DDRaddr :
	                fc2DDRstrobe ? fc2DDRaddr :
	                {addrWidth{1'b0}};

	assign ddrRstrobe =fc1DDRstrobe|fc2DDRstrobe;

	//########################################
	//##             fc1DDR                 ##
	//########################################
	fc1DDR#(
		.addrWidth(addrWidth),
		.addrStride(addrStride),
		.tile(fc1Tile),
		.inNum(fc1InNum),
		.outNum(fc1OutNum),
		.inWidth(inWidth),
		.wWidth(wWidth),
		.bWidth(bWidth),
		.accWidth(accWidth),
		.inSigned(0),
		.byte0LSB(byte0LSB),
		.checkPB(checkPB)) u_fc1DDR(
		.clk(clk),
		.rst(rst),
		.start(fcStart),

		.inBaseADDR(inBaseADDR),
		.wBaseADDR(fc1wBaseADDR),
		.bBaseADDR(fc1bBaseADDR),

		.inPB(inPB),
		.wPB(fc1wPB),
		.bPB(fc1bPB),

		.ddrAddr(fc1DDRaddr),
		.ddrRstrobe(fc1DDRstrobe),
		.ddrData(ddrData),
		.ddrReady(ddrReady),
		.ddrTranComp(ddrTranComp),

		.busy(fc1Busy),
		.done(fc1Done),
		.outFlat(fc1OutFlat),

		.inLastADDR(fc1InLastADDR),
		.wLastADDR(fc1wLastADDR),
		.bLastADDR(fc1bLastADDR),
		.LastReadADDR(fc1LastReadADDR),

		.configError(fc1ConfigError),
		.payloadSizeError(fc1PayloadSizeError),
		.ddrReadError(fc1DDRreadError),
		.error(),

		.debugState(fc1DebugState),
		.debugInIdx(fc1DebugInIdx),
		.debugtileIdx(fc1DebugtileIdx),
		.debugReadLine(fc1DebugReadLine)
	);

	//########################################
	//##           requantUsign             ##
	//########################################
	requantUsignREG#(
		.number(fc1OutNum),
		.inWidth(accWidth),
		.outWidth(rqOutWidth),
		.shift(rqShift)) u_requantUsign(
		.clk(clk),
		.rst(rst),
		.start(fc1Done),
		.inFlat(fc1OutFlat),
		.outFlat(rqOutFlat),
		.done(rqDone)
	);

	//########################################
	//##             fc2DDR                 ##
	//########################################
	fc2DDR#(
		.addrWidth(addrWidth),
		.addrStride(addrStride),
		.tile(fc2Tile),
		.inNum(fc1OutNum),
		.outNum(fc2OutNum),
		.inWidth(rqOutWidth),
		.wWidth(wWidth),
		.bWidth(bWidth),
		.accWidth(accWidth),
		.inSigned(0),
		.byte0LSB(byte0LSB),
		.checkPB(checkPB)) u_fc2DDR(
		.clk(clk),
		.rst(rst),
		.start(rqDone),

		.inFlat(rqOutFlat),

		.wBaseADDR(fc2wBaseADDR),
		.bBaseADDR(fc2bBaseADDR),

		.wPB(fc2wPB),
		.bPB(fc2bPB),

		.ddrAddr(fc2DDRaddr),
		.ddrRstrobe(fc2DDRstrobe),
		.ddrData(ddrData),
		.ddrReady(ddrReady),
		.ddrTranComp(ddrTranComp),

		.busy(fc2Busy),
		.done(fc2Done),
		.outFlat(fc2OutFlat),

		.wLastADDR(fc2wLastADDR),
		.bLastADDR(fc2bLastADDR),
		.LastReadADDR(fc2LastReadADDR),

		.configError(fc2ConfigError),
		.payloadSizeError(fc2PayloadSizeError),
		.ddrReadError(fc2DDRreadError),
		.error(),

		.debugState(fc2DebugState),
		.debugInIdx(fc2DebugInIdx),
		.debugtileIdx(fc2DebugtileIdx),
		.debugReadLine(fc2DebugReadLine)
	);

	//########################################
	//##              argmax                ##
	//########################################
	wire argmaxStart;
	wire argmaxDone;
	wire argmaxBusy;

	assign argmaxStart =fc2Done;

	argmaxSeq#(
		.width(accWidth),
		.number(fc2OutNum)) u_argmaxSeq(
		.clk(clk),
		.rst(rst),
		.start(argmaxStart),
		.inFlat(fc2OutFlat),
		.done(argmaxDone),
		.busy(argmaxBusy),
		.outIndex(argmaxIndex)
	);

	//########################################
	//##          TOP CONTROL               ##
	//########################################
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			busy     <=1'b0;
			done     <=1'b0;
			outIndex <={$clog2(fc2OutNum){1'b0}};
		end
		else begin
			done <=1'b0;

			if(start && !busy)begin
				busy <=1'b1;
			end
			else if(argmaxDone)begin
				busy     <=1'b0;
				done     <=1'b1;
				outIndex <=argmaxIndex;
			end
			else if(busy && error)begin
				busy <=1'b0;
			end
		end
	end
endmodule