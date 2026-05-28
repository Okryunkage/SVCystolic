`timescale 1ns/1ps

module fcBatchAccTOP#(
	parameter addrWidth =27,
	parameter [addrWidth-1:0] addrStride =27'd8,

	parameter batchSize =16,

	parameter fc1InNum  =784,
	parameter fc1OutNum =64,
	parameter fc2OutNum =10,

	parameter fc1Tile =8,
	parameter fc2Tile =5,

	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,

	parameter rqOutWidth =8,
	parameter rqShift    =10,

	parameter byte0LSB =1,
	parameter checkPB  =1)(
	input wire clk,
	input wire rst,
	input wire start,

	//Base address of the first input image.
	input wire [addrWidth-1:0] inBaseADDR,

	//Base address of labels.
	input wire [addrWidth-1:0] labelBaseADDR,

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

	//Last prediction result.
	output reg [($clog2(fc2OutNum)-1):0] predIndex,

	//Current label and compare result.
	output reg [7:0] currentLabel,
	output reg       currentCorrect,

	//Statistics.
	output reg [31:0] predCount,
	output reg [31:0] totalCount,
	output reg [31:0] correctCount,

	//Current batch index for debug.
	output reg [31:0] currentBatchIndex,

	output wire fcBusy,
	output wire fcDone,
	output wire fcError,

	output wire labelBusy,
	output wire labelDone,

	output reg  batchDone,
	output reg  batchError,
	output reg  labelValueError,
	output wire error,

	//Optional fcTOP debug outputs.
	output wire [4:0] fc1DebugState,
	output wire [4:0] fc2DebugState,
	output wire [31:0] fc1DebugInIdx,
	output wire [31:0] fc1DebugtileIdx,
	output wire [31:0] fc1DebugReadLine,
	output wire [31:0] fc2DebugInIdx,
	output wire [31:0] fc2DebugtileIdx,
	output wire [31:0] fc2DebugReadLine);

	localparam integer ddrBytes =16;
	localparam integer inLines  =(fc1InNum+ddrBytes-1)/ddrBytes;
	localparam integer imageADDRstride =inLines*addrStride;

	localparam integer labelWidth = $clog2(fc2OutNum);
	localparam integer batchIDXwidth = (batchSize<=1) ? 1 : $clog2(batchSize);

	localparam [3:0] S_IDLE        =4'd0;
	localparam [3:0] S_FC_START    =4'd1;
	localparam [3:0] S_FC_WAIT     =4'd2;
	localparam [3:0] S_LABEL_START =4'd3;
	localparam [3:0] S_LABEL_WAIT  =4'd4;
	localparam [3:0] S_COMPARE     =4'd5;
	localparam [3:0] S_DONE        =4'd6;
	localparam [3:0] S_ERROR       =4'd7;

	reg [3:0] state;

	reg [(batchIDXwidth-1):0] batchIdx;

	wire fcStart;
	wire labelStart;

	wire [addrWidth-1:0] currentInBaseADDR;
	wire [31:0] imageOffsetCalc;

	wire [($clog2(fc2OutNum)-1):0] fcOutIndex;

	wire [addrWidth-1:0] fcDDRaddr;
	wire                 fcDDRstrobe;

	wire [addrWidth-1:0] labelDDRaddr;
	wire                 labelDDRstrobe;
	wire [7:0]           labelValue;

	wire [7:0]  predIndex8;
	wire        compareMatch;
	wire [31:0] correctCountNext;

	assign fcStart    =(state==S_FC_START);
	assign labelStart =(state==S_LABEL_START);

	assign imageOffsetCalc   ={{(32-batchIDXwidth){1'b0}},batchIdx}*imageADDRstride;
	assign currentInBaseADDR =inBaseADDR+imageOffsetCalc[addrWidth-1:0];

	//Use registered currentLabel, not raw labelValue.
	assign predIndex8       ={{(8-labelWidth){1'b0}},predIndex};
	assign compareMatch     =(predIndex8==currentLabel);
	assign correctCountNext =correctCount+(compareMatch ? 32'd1 : 32'd0);

	assign error =batchError|fcError|labelValueError;

	//DDR read mux.
	//fcTOP and labelReader do not access DDR at the same time.
	assign ddrAddr =labelDDRstrobe ? labelDDRaddr :
	                fcDDRstrobe    ? fcDDRaddr :
	                {addrWidth{1'b0}};

	assign ddrRstrobe =labelDDRstrobe|fcDDRstrobe;

	//########################################
	//##              fcTOP                 ##
	//########################################
	fcTOP#(
		.addrWidth(addrWidth),
		.addrStride(addrStride),

		.fc1InNum(fc1InNum),
		.fc1OutNum(fc1OutNum),
		.fc2OutNum(fc2OutNum),

		.fc1Tile(fc1Tile),
		.fc2Tile(fc2Tile),

		.inWidth(inWidth),
		.wWidth(wWidth),
		.bWidth(bWidth),
		.accWidth(accWidth),

		.rqOutWidth(rqOutWidth),
		.rqShift(rqShift),

		.byte0LSB(byte0LSB),
		.checkPB(checkPB)) u_fcTOP(
		.clk(clk),
		.rst(rst),
		.start(fcStart),

		.inBaseADDR(currentInBaseADDR),

		.fc1wBaseADDR(fc1wBaseADDR),
		.fc1bBaseADDR(fc1bBaseADDR),

		.fc2wBaseADDR(fc2wBaseADDR),
		.fc2bBaseADDR(fc2bBaseADDR),

		.inPB(inPB),
		.fc1wPB(fc1wPB),
		.fc1bPB(fc1bPB),
		.fc2wPB(fc2wPB),
		.fc2bPB(fc2bPB),

		.ddrAddr(fcDDRaddr),
		.ddrRstrobe(fcDDRstrobe),
		.ddrData(ddrData),
		.ddrReady(ddrReady),
		.ddrTranComp(ddrTranComp),

		.busy(fcBusy),
		.done(fcDone),

		.outIndex(fcOutIndex),

		.fc1OutFlat(),
		.rqOutFlat(),
		.fc2OutFlat(),

		.fc1Done(),
		.rqDone(),
		.fc2Done(),

		.fc1Busy(),
		.fc2Busy(),

		.fc1Error(),
		.fc2Error(),
		.error(fcError),

		.fc1DebugState(fc1DebugState),
		.fc2DebugState(fc2DebugState),
		.fc1DebugInIdx(fc1DebugInIdx),
		.fc1DebugtileIdx(fc1DebugtileIdx),
		.fc1DebugReadLine(fc1DebugReadLine),
		.fc2DebugInIdx(fc2DebugInIdx),
		.fc2DebugtileIdx(fc2DebugtileIdx),
		.fc2DebugReadLine(fc2DebugReadLine)
	);

	//########################################
	//##           labelReader              ##
	//########################################
	labelReader#(
		.addrWidth(addrWidth),
		.addrStride(addrStride),
		.byte0LSB(byte0LSB)) u_labelReader(
		.clk(clk),
		.rst(rst),
		.start(labelStart),

		.labelBaseAddr(labelBaseADDR),
		.labelIndex({{(32-batchIDXwidth){1'b0}},batchIdx}),

		.ddrAddr(labelDDRaddr),
		.ddrRstrobe(labelDDRstrobe),
		.ddrData(ddrData),
		.ddrReady(ddrReady),
		.ddrTranComp(ddrTranComp),

		.busy(labelBusy),
		.done(labelDone),
		.label(labelValue)
	);

	//########################################
	//##            MAIN FSM                ##
	//########################################
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=S_IDLE;

			busy <=1'b0;
			done <=1'b0;

			predIndex <={labelWidth{1'b0}};
			currentLabel <=8'd0;
			currentCorrect <=1'b0;

			predCount <=32'd0;
			totalCount <=32'd0;
			correctCount <=32'd0;

			currentBatchIndex <=32'd0;

			batchIdx <={batchIDXwidth{1'b0}};

			batchDone <=1'b0;
			batchError <=1'b0;
			labelValueError <=1'b0;
		end
		else begin
			done <=1'b0;
			batchDone <=1'b0;

			currentBatchIndex <={{(32-batchIDXwidth){1'b0}},batchIdx};

			case(state)
				S_IDLE:begin
					busy <=1'b0;

					if(start)begin
						busy <=1'b1;

						predIndex <={labelWidth{1'b0}};
						currentLabel <=8'd0;
						currentCorrect <=1'b0;

						predCount <=32'd0;
						totalCount <=32'd0;
						correctCount <=32'd0;

						batchIdx <={batchIDXwidth{1'b0}};

						batchError <=1'b0;
						labelValueError <=1'b0;

						state <=S_FC_START;
					end
				end

				//Generate one-cycle start pulse for fcTOP.
				S_FC_START:begin
					state <=S_FC_WAIT;
				end

				//Wait until fcTOP finishes one image inference.
				S_FC_WAIT:begin
					if(fcError)begin
						batchError <=1'b1;
						state      <=S_ERROR;
					end
					else if(fcDone)begin
						predIndex <=fcOutIndex;
						predCount <=predCount+32'd1;
						state     <=S_LABEL_START;
					end
				end

				//Generate one-cycle start pulse for labelReader.
				S_LABEL_START:begin
					state <=S_LABEL_WAIT;
				end

				//Wait until target label is read from DDR.
				//Latch labelValue here, then compare in S_COMPARE.
				S_LABEL_WAIT:begin
					if(labelDone)begin
						currentLabel <=labelValue;
						state        <=S_COMPARE;
					end
				end

				//Compare current prediction with registered current label.
				S_COMPARE:begin
					currentCorrect <=compareMatch;

					totalCount   <=totalCount+32'd1;
					correctCount <=correctCountNext;

					if(currentLabel>=fc2OutNum)begin
						labelValueError <=1'b1;
					end

					if(batchIdx==(batchSize-1))begin
						state <=S_DONE;
					end
					else begin
						batchIdx <=batchIdx+1'b1;
						state    <=S_FC_START;
					end
				end

				S_DONE:begin
					busy <=1'b0;
					done <=1'b1;
					batchDone <=1'b1;
					state <=S_IDLE;
				end

				S_ERROR:begin
					busy <=1'b0;
					done <=1'b1;
					state <=S_IDLE;
				end

				default:begin
					state <=S_IDLE;
				end
			endcase
		end
	end
endmodule