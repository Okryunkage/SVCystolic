`timescale 1ns/1ps

module linear10Engine #(
	parameter integer size         =10,
	parameter integer batchSize    =100,
	parameter integer inputTileNum =79,
	parameter integer addrWidth    =16,
	parameter integer resultDelay  =19
)(
	input  wire clk,
	input  wire rst,
	input  wire start,

	output wire [addrWidth-1:0] inputAddr,
	output wire                 inputRen,
	input  wire [8*size-1:0]    inputData,

	output wire [addrWidth-1:0] weightAddr,
	output wire                 weightRen,
	input  wire [8*size-1:0]    weightData,

	output reg  [addrWidth-1:0] biasAddr,
	output reg                  biasRen,
	input  wire [31:0]          biasData,

	input  wire [addrWidth-1:0] accReadImage,
	output wire [size*32-1:0]   accReadWord,

	input  wire [addrWidth-1:0] predReadImage,
	output wire [3:0]           predReadData,

	output reg                  busy,
	output reg                  done,

	output wire [3:0]           dbgState,
	output wire [addrWidth-1:0] dbgInputTile,
	output wire [addrWidth-1:0] dbgResultImage,
	output wire [addrWidth-1:0] dbgTileResultCnt
);

	localparam integer buswire      =$clog2(size)+16;
	localparam integer resultWidth  =size*buswire;
	localparam integer accWordWidth =size*32;
	localparam integer ACC_RAM_AW   =(batchSize <=2) ? 1 : $clog2(batchSize);

	reg [3:0] state;

	localparam S_IDLE       =4'd0;
	localparam S_BIAS_REQ0  =4'd1;
	localparam S_BIAS_LOAD  =4'd2;
	localparam S_RUN_START  =4'd3;
	localparam S_RUN_WAIT   =4'd4;
	localparam S_RUN_DRAIN  =4'd5;
	localparam S_DONE       =4'd6;

	assign dbgState =state;

	reg [addrWidth-1:0] inputTile;
	assign dbgInputTile =inputTile;

	wire [addrWidth-1:0] outBaseConst;
	assign outBaseConst ={addrWidth{1'b0}};

	// Bias values are loaded every run, so they do not need reset.
	reg signed [31:0] biasBuf [0:size-1];

	reg [addrWidth-1:0] biasReqCnt;
	reg [addrWidth-1:0] biasLoadCnt;

	reg [addrWidth-1:0] tileResultCnt;
	assign dbgTileResultCnt =tileResultCnt;

	reg [3:0] drainCnt;

	// ------------------------------------------------------------
	// SA batch-tile runner
	// ------------------------------------------------------------
	reg runnerStart;

	wire [resultWidth-1:0] runnerResult;
	wire                   runnerResultValid;
	wire [addrWidth-1:0]   runnerResultImageIndex;
	wire                   runnerBusy;
	wire                   runnerDone;

	wire [3:0]             runnerDbgState;
	wire [addrWidth-1:0]   runnerDbgLoadApplyCnt;
	wire [addrWidth-1:0]   runnerDbgImageApplyCnt;
	wire [addrWidth-1:0]   runnerDbgResultCnt;

	assign dbgResultImage =runnerResultImageIndex;

	SA_btr #(
		.size         (size),
		.batchSize    (batchSize),
		.inputTileNum (inputTileNum),
		.addrWidth    (addrWidth),
		.resultDelay  (resultDelay)
	) runner (
		.clk   (clk),
		.rst   (rst),
		.start (runnerStart),
		.outBase   (outBaseConst),
		.inputTile (inputTile),

		.weightAddr (weightAddr),
		.weightRen  (weightRen),
		.weightData (weightData),

		.inputAddr (inputAddr),
		.inputRen  (inputRen),
		.inputData (inputData),

		.result           (runnerResult),
		.resultValid      (runnerResultValid),
		.resultImageIndex (runnerResultImageIndex),
		.busy             (runnerBusy),
		.done             (runnerDone),

		.dbgState         (runnerDbgState),
		.dbgLoadApplyCnt  (runnerDbgLoadApplyCnt),
		.dbgImageApplyCnt (runnerDbgImageApplyCnt),
		.dbgResultCnt     (runnerDbgResultCnt)
	);

	// ------------------------------------------------------------
	// Accumulator RAM
	//   Port A: internal read during run, external read when idle/done
	//   Port B: write calculated accumulator row
	// ------------------------------------------------------------
	wire [addrWidth-1:0]    accRdAddrFull;
	wire [ACC_RAM_AW-1:0]   accRdAddr;
	wire [accWordWidth-1:0] accRdDout;
	wire [accWordWidth-1:0] unusedAccDoutB;

	assign accRdAddrFull =((state ==S_RUN_WAIT) && runnerResultValid) ? tileResultCnt : accReadImage;
	assign accRdAddr     =accRdAddrFull[ACC_RAM_AW-1:0];
	assign accReadWord   =accRdDout;

	wire                  accWrEn;
	wire [addrWidth-1:0] accWrAddrFull;
	wire [ACC_RAM_AW-1:0] accWrAddr;
	wire [accWordWidth-1:0] accWrDin;

	assign accWrAddr =accWrAddrFull[ACC_RAM_AW-1:0];

	bram_tdpram #(
		.DATA_WIDTH   (accWordWidth),
		.DEPTH        (batchSize),
		.ADDR_WIDTH   (ACC_RAM_AW),
		.INIT_FILE    ("none"),
		.READ_LATENCY (1),
		.WRITE_MODE_A ("read_first"),
		.WRITE_MODE_B ("read_first")
	) acc_ram (
		.clk   (clk),
		.rst   (rst),

		.ena   (1'b1),
		.wea   (1'b0),
		.addra (accRdAddr),
		.dina  ({accWordWidth{1'b0}}),
		.douta (accRdDout),

		.enb   (accWrEn),
		.web   (accWrEn),
		.addrb (accWrAddr),
		.dinb  (accWrDin),
		.doutb (unusedAccDoutB)
	);

	// ------------------------------------------------------------
	// Prediction RAM
	//   Port A: sender/external read
	//   Port B: final argmax write
	// ------------------------------------------------------------
	wire [ACC_RAM_AW-1:0] predRdAddr;
	wire [ACC_RAM_AW-1:0] predWrAddr;
	wire [addrWidth-1:0]  predWrAddrFull;
	wire                  predWrEn;
	wire [3:0]            predWrDin;
	wire [3:0]            unusedPredDoutB;

	assign predRdAddr =predReadImage[ACC_RAM_AW-1:0];
	assign predWrAddr =predWrAddrFull[ACC_RAM_AW-1:0];

	bram_tdpram #(
		.DATA_WIDTH   (4),
		.DEPTH        (batchSize),
		.ADDR_WIDTH   (ACC_RAM_AW),
		.INIT_FILE    ("none"),
		.READ_LATENCY (1),
		.WRITE_MODE_A ("read_first"),
		.WRITE_MODE_B ("read_first")
	) pred_ram (
		.clk   (clk),
		.rst   (rst),

		.ena   (1'b1),
		.wea   (1'b0),
		.addra (predRdAddr),
		.dina  (4'd0),
		.douta (predReadData),

		.enb   (predWrEn),
		.web   (predWrEn),
		.addrb (predWrAddr),
		.dinb  (predWrDin),
		.doutb (unusedPredDoutB)
	);

	// ------------------------------------------------------------
	// Pipeline alignment
	//
	// cycle N:
	//   runnerResultValid
	//   acc RAM read address is current image
	//   partial sums are captured into pipe0
	//
	// cycle N+1:
	//   acc RAM dout matches pipe0
	//   accCalcWord is registered into wb2AccWord
	//
	// cycle N+2:
	//   acc RAM Port B writes wb2AccWord
	//   argmax stage 1 starts from wb2AccWord
	//
	// cycle N+3:
	//   argmax stage 2
	//
	// cycle N+4:
	//   argmax stage 3
	//
	// cycle N+5:
	//   pred RAM Port B writes final prediction
	// ------------------------------------------------------------

	reg                    pipe0Valid;
	reg [addrWidth-1:0]    pipe0Image;
	reg                    pipe0FirstTile;
	reg                    pipe0LastTile;
	reg [accWordWidth-1:0] pipe0PartialWord;

	reg                    wb2Valid;
	reg [addrWidth-1:0]    wb2Image;
	reg                    wb2LastTile;
	reg [accWordWidth-1:0] wb2AccWord;

	// Argmax pipeline stage 1: 10 scores -> 5 winners
	reg                    arg1Valid;
	reg [addrWidth-1:0]    arg1Image;
	reg                    arg1LastTile;
	reg signed [31:0]      arg1Val0;
	reg signed [31:0]      arg1Val1;
	reg signed [31:0]      arg1Val2;
	reg signed [31:0]      arg1Val3;
	reg signed [31:0]      arg1Val4;
	reg [3:0]              arg1Idx0;
	reg [3:0]              arg1Idx1;
	reg [3:0]              arg1Idx2;
	reg [3:0]              arg1Idx3;
	reg [3:0]              arg1Idx4;

	// Argmax pipeline stage 2: 5 winners -> 3 winners
	reg                    arg2Valid;
	reg [addrWidth-1:0]    arg2Image;
	reg                    arg2LastTile;
	reg signed [31:0]      arg2Val0;
	reg signed [31:0]      arg2Val1;
	reg signed [31:0]      arg2Val2;
	reg [3:0]              arg2Idx0;
	reg [3:0]              arg2Idx1;
	reg [3:0]              arg2Idx2;

	// Argmax pipeline stage 3: 3 winners -> final winner
	reg                    arg3Valid;
	reg [addrWidth-1:0]    arg3Image;
	reg                    arg3LastTile;
	reg [3:0]              arg3Pred;

	function signed [31:0] sx_result;
		input [buswire-1:0] x;
		begin
			sx_result ={{(32-buswire){x[buswire-1]}},x};
		end
	endfunction

	// ------------------------------------------------------------
	// Accumulator calculation.
	// This is only add/mux logic. Argmax is no longer here.
	// ------------------------------------------------------------
	integer cj;
	reg [accWordWidth-1:0] accCalcWord;
	reg signed [31:0] oldAcc;
	reg signed [31:0] partAcc;
	reg signed [31:0] biasAcc;

	always@(*)begin
		accCalcWord =accRdDout;

		for(cj=0; cj<size; cj=cj+1)begin
			oldAcc  =$signed(accRdDout[cj*32 +: 32]);
			partAcc =$signed(pipe0PartialWord[cj*32 +: 32]);
			biasAcc =biasBuf[cj];

			if(pipe0FirstTile)
				accCalcWord[cj*32 +: 32] =biasAcc +partAcc;
			else
				accCalcWord[cj*32 +: 32] =oldAcc +partAcc;
		end
	end

	assign accWrEn       =wb2Valid;
	assign accWrAddrFull =wb2Image;
	assign accWrDin      =wb2AccWord;

	assign predWrEn       =arg3Valid && arg3LastTile;
	assign predWrAddrFull =arg3Image;
	assign predWrDin      =arg3Pred;

	// ------------------------------------------------------------
	// Bias memory request
	// ------------------------------------------------------------
	always@(*)begin
		biasAddr ={addrWidth{1'b0}};
		biasRen =1'b0;

		case(state)
			S_BIAS_REQ0:begin
				biasRen =1'b1;
				biasAddr ={addrWidth{1'b0}};
			end

			S_BIAS_LOAD:begin
				if(biasReqCnt <size)begin
					biasRen =1'b1;
					biasAddr =biasReqCnt;
				end
			end

			default:begin
				biasAddr ={addrWidth{1'b0}};
				biasRen =1'b0;
			end
		endcase
	end

	// ------------------------------------------------------------
	// Sequential controller and pipelines
	// ------------------------------------------------------------
	integer j;

	always@(posedge clk)begin
		if(rst)begin
			state <=S_IDLE;

			inputTile <=0;
			biasReqCnt <=0;
			biasLoadCnt <=0;
			tileResultCnt <=0;
			drainCnt <=0;

			runnerStart <=1'b0;

			pipe0Valid <=1'b0;
			pipe0Image <=0;
			pipe0FirstTile <=1'b0;
			pipe0LastTile <=1'b0;

			wb2Valid <=1'b0;
			wb2Image <=0;
			wb2LastTile <=1'b0;

			arg1Valid <=1'b0;
			arg1Image <=0;
			arg1LastTile <=1'b0;

			arg2Valid <=1'b0;
			arg2Image <=0;
			arg2LastTile <=1'b0;

			arg3Valid <=1'b0;
			arg3Image <=0;
			arg3LastTile <=1'b0;
			arg3Pred <=4'd0;

			busy <=1'b0;
			done <=1'b0;
		end
		else begin
			done <=1'b0;
			runnerStart <=1'b0;

			// Default: pipe0 is valid only on a new runner result.
			pipe0Valid <=1'b0;

			// Accumulator writeback pipeline.
			// wb2 registers the calculated accumulator word that matches pipe0.
			wb2Valid <=pipe0Valid;
			wb2Image <=pipe0Image;
			wb2LastTile <=pipe0LastTile;
			wb2AccWord <=accCalcWord;

			// Argmax pipeline stage 1.
			// Tie behavior matches old argmax_word: lower index wins.
			arg1Valid <=wb2Valid;
			arg1Image <=wb2Image;
			arg1LastTile <=wb2LastTile;

			if($signed(wb2AccWord[1*32 +: 32]) > $signed(wb2AccWord[0*32 +: 32]))begin
				arg1Val0 <=$signed(wb2AccWord[1*32 +: 32]);
				arg1Idx0 <=4'd1;
			end
			else begin
				arg1Val0 <=$signed(wb2AccWord[0*32 +: 32]);
				arg1Idx0 <=4'd0;
			end

			if($signed(wb2AccWord[3*32 +: 32]) > $signed(wb2AccWord[2*32 +: 32]))begin
				arg1Val1 <=$signed(wb2AccWord[3*32 +: 32]);
				arg1Idx1 <=4'd3;
			end
			else begin
				arg1Val1 <=$signed(wb2AccWord[2*32 +: 32]);
				arg1Idx1 <=4'd2;
			end

			if($signed(wb2AccWord[5*32 +: 32]) > $signed(wb2AccWord[4*32 +: 32]))begin
				arg1Val2 <=$signed(wb2AccWord[5*32 +: 32]);
				arg1Idx2 <=4'd5;
			end
			else begin
				arg1Val2 <=$signed(wb2AccWord[4*32 +: 32]);
				arg1Idx2 <=4'd4;
			end

			if($signed(wb2AccWord[7*32 +: 32]) > $signed(wb2AccWord[6*32 +: 32]))begin
				arg1Val3 <=$signed(wb2AccWord[7*32 +: 32]);
				arg1Idx3 <=4'd7;
			end
			else begin
				arg1Val3 <=$signed(wb2AccWord[6*32 +: 32]);
				arg1Idx3 <=4'd6;
			end

			if($signed(wb2AccWord[9*32 +: 32]) > $signed(wb2AccWord[8*32 +: 32]))begin
				arg1Val4 <=$signed(wb2AccWord[9*32 +: 32]);
				arg1Idx4 <=4'd9;
			end
			else begin
				arg1Val4 <=$signed(wb2AccWord[8*32 +: 32]);
				arg1Idx4 <=4'd8;
			end

			// Argmax pipeline stage 2.
			arg2Valid <=arg1Valid;
			arg2Image <=arg1Image;
			arg2LastTile <=arg1LastTile;

			if(arg1Val1 > arg1Val0)begin
				arg2Val0 <=arg1Val1;
				arg2Idx0 <=arg1Idx1;
			end
			else begin
				arg2Val0 <=arg1Val0;
				arg2Idx0 <=arg1Idx0;
			end

			if(arg1Val3 > arg1Val2)begin
				arg2Val1 <=arg1Val3;
				arg2Idx1 <=arg1Idx3;
			end
			else begin
				arg2Val1 <=arg1Val2;
				arg2Idx1 <=arg1Idx2;
			end

			arg2Val2 <=arg1Val4;
			arg2Idx2 <=arg1Idx4;

			// Argmax pipeline stage 3.
			arg3Valid <=arg2Valid;
			arg3Image <=arg2Image;
			arg3LastTile <=arg2LastTile;

			if(arg2Val1 > arg2Val0)begin
				if(arg2Val2 > arg2Val1)
					arg3Pred <=arg2Idx2;
				else
					arg3Pred <=arg2Idx1;
			end
			else begin
				if(arg2Val2 > arg2Val0)
					arg3Pred <=arg2Idx2;
				else
					arg3Pred <=arg2Idx0;
			end

			case(state)
				S_IDLE:begin
					busy <=1'b0;

					inputTile <=0;
					biasReqCnt <=0;
					biasLoadCnt <=0;
					tileResultCnt <=0;
					drainCnt <=0;

					if(start)begin
						busy <=1'b1;
						state <=S_BIAS_REQ0;
					end
				end

				S_BIAS_REQ0:begin
					biasReqCnt <=1;
					biasLoadCnt <=0;
					state <=S_BIAS_LOAD;
				end

				S_BIAS_LOAD:begin
					biasBuf[biasLoadCnt] <=$signed(biasData);

					if(biasLoadCnt ==size-1)begin
						biasReqCnt <=0;
						biasLoadCnt <=0;
						state <=S_RUN_START;
					end
					else begin
						biasReqCnt <=biasReqCnt +1'b1;
						biasLoadCnt <=biasLoadCnt +1'b1;
					end
				end

				S_RUN_START:begin
					tileResultCnt <=0;
					drainCnt <=0;
					runnerStart <=1'b1;
					state <=S_RUN_WAIT;
				end

				S_RUN_WAIT:begin
					if(runnerResultValid)begin
						pipe0Valid <=1'b1;
						pipe0Image <=tileResultCnt;
						pipe0FirstTile <=(inputTile ==0);
						pipe0LastTile <=(inputTile ==inputTileNum-1);

						for(j=0; j<size; j=j+1)begin
							pipe0PartialWord[j*32 +: 32] <=sx_result(runnerResult[j*buswire +: buswire]);
						end

						if(tileResultCnt ==batchSize-1)begin
							tileResultCnt <=0;
							drainCnt <=0;
							state <=S_RUN_DRAIN;
						end
						else begin
							tileResultCnt <=tileResultCnt +1'b1;
						end
					end
				end

				S_RUN_DRAIN:begin
					// Conservative drain:
					// last result -> pipe0 -> wb2 -> arg1 -> arg2 -> arg3 -> pred RAM write.
					// This keeps both accumulator and prediction writes completed
					// before starting next tile or asserting done.
					if(drainCnt ==4'd6)begin
						drainCnt <=0;

						if(inputTile ==inputTileNum-1)begin
							inputTile <=0;
							state <=S_DONE;
						end
						else begin
							inputTile <=inputTile +1'b1;
							state <=S_RUN_START;
						end
					end
					else begin
						drainCnt <=drainCnt +1'b1;
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
