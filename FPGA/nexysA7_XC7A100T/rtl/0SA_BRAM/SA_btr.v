`timescale 1ns/1ps

module SA_btr#(
	parameter integer size=32,
	parameter integer batchSize=100,
	parameter integer inputTileNum=25,
	parameter integer addrWidth=16,
	//If first input is applied at stream cycle 0,
	//first result is valid at stream cycle resultDelay.
	//From our SA32 check, scan cycle 63 was valid.
	parameter integer resultDelay=63)(
	clk,rst,start,
	outBase,inputTile,

	weightAddr,weightRen,weightData,
	inputAddr,inputRen,inputData,

	result,resultValid,resultImageIndex,
	busy,done,

	dbgState,dbgLoadApplyCnt,dbgImageApplyCnt,dbgResultCnt);

	localparam integer buswire=$clog2(size)+16;
	localparam integer resultWidth=size*buswire;

	input clk;
	input rst;
	input start;

	input [addrWidth-1:0] outBase;
	input [addrWidth-1:0] inputTile;

	output reg [addrWidth-1:0] weightAddr;
	output reg weightRen;
	input [8*size-1:0] weightData;

	output reg [addrWidth-1:0] inputAddr;
	output reg inputRen;
	input [8*size-1:0] inputData;

	output [resultWidth-1:0] result;
	output reg resultValid;
	output reg [addrWidth-1:0] resultImageIndex;

	output reg busy;
	output reg done;

	output [3:0] dbgState;
	output [addrWidth-1:0] dbgLoadApplyCnt;
	output [addrWidth-1:0] dbgImageApplyCnt;
	output [addrWidth-1:0] dbgResultCnt;

	// ------------------------------------------------------------
	// FSM state
	// ------------------------------------------------------------
	reg [3:0] state;
	localparam S_IDLE      =4'd0;
	localparam S_W_REQ0    =4'd1;
	localparam S_W_STREAM  =4'd2;
	localparam S_I_REQ0    =4'd3;
	localparam S_I_STREAM  =4'd4;
	localparam S_DRAIN     =4'd5;
	localparam S_DONE      =4'd6;

	assign dbgState =state;

	// ------------------------------------------------------------
	// Counters
	// ------------------------------------------------------------
	reg [addrWidth-1:0] loadReqCnt;
	reg [addrWidth-1:0] loadApplyCnt;

	reg [addrWidth-1:0] imageReqCnt;
	reg [addrWidth-1:0] imageApplyCnt;

	reg [addrWidth-1:0] resultCnt;

	assign dbgLoadApplyCnt =loadApplyCnt;
	assign dbgImageApplyCnt =imageApplyCnt;
	assign dbgResultCnt =resultCnt;

	// ------------------------------------------------------------
	// Delay pipe for result valid / image index
	// resultDelay=63 means:
	//   input stream cycle 0  -> result valid cycle 63
	// ------------------------------------------------------------
	reg [resultDelay-1:0] validPipe;
	reg [addrWidth-1:0] imagePipe [0:resultDelay-1];

	integer p;

	// ------------------------------------------------------------
	// SA input controls
	// ------------------------------------------------------------
	reg wEn;
	reg [8*size-1:0] weight;
	reg [8*size-1:0] in;

	wire [resultWidth-1:0] saResult;

	SA_IOr #(.size(size)) sa(
		.clk(clk),.wEn(wEn),
		.weight(weight),.in(in),
		.result(saResult));
	assign result =saResult;

	// ------------------------------------------------------------
	// Combinational memory address / SA input
	// ------------------------------------------------------------
	always@(*)begin
		weightAddr ={addrWidth{1'b0}};
		weightRen =1'b0;

		inputAddr ={addrWidth{1'b0}};
		inputRen =1'b0;

		wEn =1'b0;
		weight ={8*size{1'b0}};
		in ={8*size{1'b0}};

		case(state)
			S_W_REQ0:begin
				// Request first weight word.
				// Preload order is out31 -> out0 because SA weight shifts.
				weightRen =1'b1;
				weightAddr =(outBase +(size-1))*inputTileNum +inputTile;
			end

			S_W_STREAM:begin
				// Apply weightData returned from previous cycle request.
				wEn =1'b1;
				weight =weightData;

				// Request next weight word while applying current one.
				if(loadReqCnt < size)begin
					weightRen =1'b1;
					weightAddr =(outBase +(size-1-loadReqCnt))*inputTileNum +inputTile;
				end
			end

			S_I_REQ0:begin
				// Request first image input tile.
				inputRen =1'b1;
				inputAddr =inputTile;
			end

			S_I_STREAM:begin
				// Apply inputData returned from previous cycle request.
				in =inputData;

				// Request next image input tile while applying current one.
				if(imageReqCnt < batchSize)begin
					inputRen =1'b1;
					inputAddr =imageReqCnt*inputTileNum +inputTile;
				end
			end

			S_DRAIN:begin
				// No more new input. Drain SA pipeline.
				in ={8*size{1'b0}};
			end

			default:begin
				weightAddr ={addrWidth{1'b0}};
				weightRen =1'b0;

				inputAddr ={addrWidth{1'b0}};
				inputRen =1'b0;

				wEn =1'b0;
				weight ={8*size{1'b0}};
				in ={8*size{1'b0}};
			end
		endcase
	end

	// ------------------------------------------------------------
	// Sequential FSM
	// ------------------------------------------------------------
	always@(posedge clk)begin
		if(rst)begin
			state <=S_IDLE;

			loadReqCnt <=0;
			loadApplyCnt <=0;

			imageReqCnt <=0;
			imageApplyCnt <=0;

			resultCnt <=0;

			validPipe <={resultDelay{1'b0}};
			for(p=0;p<resultDelay;p=p+1)begin
				imagePipe[p] <=0;
			end

			resultValid <=1'b0;
			resultImageIndex <=0;

			busy <=1'b0;
			done <=1'b0;
		end
		else begin
			done <=1'b0;
			resultValid <=1'b0;

			case(state)
				S_IDLE:begin
					busy <=1'b0;

					loadReqCnt <=0;
					loadApplyCnt <=0;

					imageReqCnt <=0;
					imageApplyCnt <=0;

					resultCnt <=0;

					validPipe <={resultDelay{1'b0}};
					for(p=0;p<resultDelay;p=p+1)begin
						imagePipe[p] <=0;
					end

					if(start)begin
						busy <=1'b1;
						state <=S_W_REQ0;
					end
				end

				S_W_REQ0:begin
					// First weight address was requested in this state.
					// Next cycle, weightData is valid.
					loadReqCnt <=1;
					loadApplyCnt <=0;
					state <=S_W_STREAM;
				end

				S_W_STREAM:begin
					// One weight word is applied to SA in this cycle.
					if(loadApplyCnt == size-1)begin
						loadReqCnt <=0;
						loadApplyCnt <=0;
						state <=S_I_REQ0;
					end
					else begin
						loadReqCnt <=loadReqCnt +1;
						loadApplyCnt <=loadApplyCnt +1;
					end
				end

				S_I_REQ0:begin
					// First input address was requested in this state.
					// Next cycle, inputData is valid.
					imageReqCnt <=1;
					imageApplyCnt <=0;
					resultCnt <=0;

					validPipe <={resultDelay{1'b0}};
					for(p=0;p<resultDelay;p=p+1)begin
						imagePipe[p] <=0;
					end

					state <=S_I_STREAM;
				end

				S_I_STREAM:begin
					// Shift valid/image pipe.
					resultValid <=validPipe[resultDelay-1];
					resultImageIndex <=imagePipe[resultDelay-1];

					for(p=resultDelay-1;p>0;p=p-1)begin
						validPipe[p] <=validPipe[p-1];
						imagePipe[p] <=imagePipe[p-1];
					end

					validPipe[0] <=1'b1;
					imagePipe[0] <=imageApplyCnt;

					if(validPipe[resultDelay-1])begin
						resultCnt <=resultCnt +1;
					end

					// One input word is applied to SA in this cycle.
					if(imageApplyCnt == batchSize-1)begin
						imageReqCnt <=0;
						imageApplyCnt <=0;
						state <=S_DRAIN;
					end
					else begin
						imageReqCnt <=imageReqCnt +1;
						imageApplyCnt <=imageApplyCnt +1;
					end
				end

				S_DRAIN:begin
					// Continue shifting valid/image pipe with no new input.
					resultValid <=validPipe[resultDelay-1];
					resultImageIndex <=imagePipe[resultDelay-1];

					for(p=resultDelay-1;p>0;p=p-1)begin
						validPipe[p] <=validPipe[p-1];
						imagePipe[p] <=imagePipe[p-1];
					end

					validPipe[0] <=1'b0;
					imagePipe[0] <=0;

					if(validPipe[resultDelay-1])begin
						if(resultCnt == batchSize-1)begin
							resultCnt <=resultCnt +1;
							state <=S_DONE;
						end
						else begin
							resultCnt <=resultCnt +1;
						end
					end
				end

				S_DONE:begin
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