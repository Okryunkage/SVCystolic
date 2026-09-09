`timescale 1ns/1ps

module fpgaTOP #(
	parameter integer BOARD_CLK      =100_000_000,
	parameter integer BAUDRATE       =1_000_000,
	parameter integer OVERSAMPLE     =20,
	parameter integer ACCWIDTH       =24,

	parameter integer SIZE           =10,
	parameter integer BATCH_SIZE     =100,
	parameter integer INPUT_TILE_NUM =79,
	parameter integer ADDR_WIDTH     =16,
	parameter integer RESULT_DELAY   =19,

	parameter INPUT_MEM_FILE  ="none",
	parameter WEIGHT_MEM_FILE ="mnist_linear_w.mem",
	parameter BIAS_MEM_FILE   ="mnist_linear_b.mem"
)(
	input  wire clk,
	input  wire resetBtn,
	input  wire startBtn,

	input  wire UARTRX,
	output wire UARTTX,

	output wire [15:0] LEDarr
);

	localparam integer INPUT_WIDTH  =8*SIZE;
	localparam integer WEIGHT_WIDTH =8*SIZE;
	localparam integer BIAS_WIDTH   =32;

	localparam integer INPUT_DEPTH  =BATCH_SIZE*INPUT_TILE_NUM;
	localparam integer WEIGHT_DEPTH =SIZE*INPUT_TILE_NUM;
	localparam integer BIAS_DEPTH   =SIZE;

	localparam integer INPUT_RAM_AW  =(INPUT_DEPTH <=2) ? 1 : $clog2(INPUT_DEPTH);
	localparam integer WEIGHT_RAM_AW =(WEIGHT_DEPTH<=2) ? 1 : $clog2(WEIGHT_DEPTH);
	localparam integer BIAS_RAM_AW   =(BIAS_DEPTH  <=2) ? 1 : $clog2(BIAS_DEPTH);

	reg [1:0] rstSync;
	reg [1:0] startSync;
	reg startPrev;

	always@(posedge clk)begin
		rstSync <= {rstSync[0], resetBtn};
		startSync <= {startSync[0], startBtn};
		startPrev <= startSync[1];
	end

	wire rst =rstSync[1];
	wire startBtnRise =startSync[1] & ~startPrev;

	reg [3:0] state;

	localparam [3:0] S_LOAD_START =4'd0;
	localparam [3:0] S_LOAD       =4'd1;
	localparam [3:0] S_READY      =4'd2;
	localparam [3:0] S_RUN_START  =4'd3;
	localparam [3:0] S_RUN        =4'd4;
	localparam [3:0] S_SEND_START =4'd5;
	localparam [3:0] S_SEND       =4'd6;
	localparam [3:0] S_FINISH     =4'd7;
	localparam [3:0] S_ERROR      =4'd8;

	reg loaderStart;
	reg engineStart;
	reg senderStart;

	reg loadDoneSticky;
	reg engineDoneSticky;
	reg sendDoneSticky;

	wire       txStart;
	wire [7:0] txItem;
	wire       txDone;
	wire       txBusy;

	wire [7:0] rxOut;
	wire       rxDone;
	wire       rxBusy;
	wire       rxError;

	uartTOP #(
		.boardCLK   (BOARD_CLK),
		.oversample (OVERSAMPLE),
		.baudrate   (BAUDRATE),
		.ACCwidth   (ACCWIDTH)
	) uart0 (
		.clk   (clk),
		.rst   (rst),

		.uartRX (UARTRX),
		.uartTX (UARTTX),

		.TXstart (txStart),
		.TXitem  (txItem),

		.TXdone (txDone),
		.TXbusy (txBusy),

		.RXout   (rxOut),
		.RXdone  (rxDone),
		.RXbusy  (rxBusy),
		.RXerror (rxError)
	);

	wire                  loaderBramEn;
	wire                  loaderBramWe;
	wire [ADDR_WIDTH-1:0] loaderBramAddr;
	wire [INPUT_WIDTH-1:0] loaderBramDin;

	wire loaderBusy;
	wire loaderDone;
	wire loaderError;

	wire [ADDR_WIDTH-1:0] dbgLoaderImage;
	wire [ADDR_WIDTH-1:0] dbgLoaderPixel;
	wire [ADDR_WIDTH-1:0] dbgLoaderWord;
	wire [3:0]            dbgLoaderByte;

	batchLoader #(
		.BATCH_SIZE     (BATCH_SIZE),
		.IMAGE_BYTES    (784),
		.TILE_SIZE      (SIZE),
		.INPUT_TILE_NUM (INPUT_TILE_NUM),
		.ADDR_WIDTH     (ADDR_WIDTH)
	) loader (
		.clk   (clk),
		.rst   (rst),
		.start (loaderStart),

		.rxData  (rxOut),
		.rxDone  (rxDone),
		.rxError (rxError),

		.bramEn   (loaderBramEn),
		.bramWe   (loaderBramWe),
		.bramAddr (loaderBramAddr),
		.bramDin  (loaderBramDin),

		.busy  (loaderBusy),
		.done  (loaderDone),
		.error (loaderError),

		.dbgImageIndex (dbgLoaderImage),
		.dbgPixelIndex (dbgLoaderPixel),
		.dbgWordAddr   (dbgLoaderWord),
		.dbgByteInTile (dbgLoaderByte)
	);

	wire [ADDR_WIDTH-1:0] engineInputAddr;
	wire                  engineInputRen;
	wire [INPUT_WIDTH-1:0] engineInputData;

	wire [ADDR_WIDTH-1:0] engineWeightAddr;
	wire                  engineWeightRen;
	wire [WEIGHT_WIDTH-1:0] engineWeightData;

	wire [ADDR_WIDTH-1:0] engineBiasAddr;
	wire                  engineBiasRen;
	wire [BIAS_WIDTH-1:0] engineBiasData;

	wire [ADDR_WIDTH-1:0] predReadImage;
	wire [3:0]            predReadData;

	wire [ADDR_WIDTH-1:0] unusedAccReadImage;
	wire [SIZE*32-1:0]    unusedAccReadWord;
	assign unusedAccReadImage ={ADDR_WIDTH{1'b0}};

	wire engineBusy;
	wire engineDone;

	wire [3:0] engineDbgState;
	wire [ADDR_WIDTH-1:0] engineDbgInputTile;
	wire [ADDR_WIDTH-1:0] engineDbgResultImage;
	wire [ADDR_WIDTH-1:0] engineDbgTileResultCnt;

	wire loadMode = (state ==S_LOAD);

	wire                  inputBramEn;
	wire                  inputBramWe;
	wire [ADDR_WIDTH-1:0] inputBramAddrFull;
	wire [INPUT_RAM_AW-1:0] inputBramAddr;
	wire [INPUT_WIDTH-1:0] inputBramDin;
	wire [INPUT_WIDTH-1:0] inputBramDout;

	assign inputBramEn       =loadMode ? loaderBramEn   : engineInputRen;
	assign inputBramWe       =loadMode ? loaderBramWe   : 1'b0;
	assign inputBramAddrFull =loadMode ? loaderBramAddr : engineInputAddr;
	assign inputBramAddr     =inputBramAddrFull[INPUT_RAM_AW-1:0];
	assign inputBramDin      =loadMode ? loaderBramDin  : {INPUT_WIDTH{1'b0}};

	assign engineInputData =inputBramDout;

	bram_spram #(
		.DATA_WIDTH   (INPUT_WIDTH),
		.DEPTH        (INPUT_DEPTH),
		.ADDR_WIDTH   (INPUT_RAM_AW),
		.INIT_FILE    (INPUT_MEM_FILE),
		.READ_LATENCY (1)
	) input_bram (
		.clk  (clk),
		.rst  (rst),
		.en   (inputBramEn),
		.we   (inputBramWe),
		.addr (inputBramAddr),
		.din  (inputBramDin),
		.dout (inputBramDout)
	);

	wire [WEIGHT_RAM_AW-1:0] weightBramAddr =engineWeightAddr[WEIGHT_RAM_AW-1:0];
	wire [BIAS_RAM_AW-1:0]   biasBramAddr   =engineBiasAddr[BIAS_RAM_AW-1:0];

	bram_spram #(
		.DATA_WIDTH   (WEIGHT_WIDTH),
		.DEPTH        (WEIGHT_DEPTH),
		.ADDR_WIDTH   (WEIGHT_RAM_AW),
		.INIT_FILE    (WEIGHT_MEM_FILE),
		.READ_LATENCY (1)
	) weight_bram (
		.clk  (clk),
		.rst  (rst),
		.en   (engineWeightRen),
		.we   (1'b0),
		.addr (weightBramAddr),
		.din  ({WEIGHT_WIDTH{1'b0}}),
		.dout (engineWeightData)
	);

	bram_spram #(
		.DATA_WIDTH   (BIAS_WIDTH),
		.DEPTH        (BIAS_DEPTH),
		.ADDR_WIDTH   (BIAS_RAM_AW),
		.INIT_FILE    (BIAS_MEM_FILE),
		.READ_LATENCY (1)
	) bias_bram (
		.clk  (clk),
		.rst  (rst),
		.en   (engineBiasRen),
		.we   (1'b0),
		.addr (biasBramAddr),
		.din  ({BIAS_WIDTH{1'b0}}),
		.dout (engineBiasData)
	);

	linear10Engine #(
		.size         (SIZE),
		.batchSize    (BATCH_SIZE),
		.inputTileNum (INPUT_TILE_NUM),
		.addrWidth    (ADDR_WIDTH),
		.resultDelay  (RESULT_DELAY)
	) engine (
		.clk   (clk),
		.rst   (rst),
		.start (engineStart),

		.inputAddr (engineInputAddr),
		.inputRen  (engineInputRen),
		.inputData (engineInputData),

		.weightAddr (engineWeightAddr),
		.weightRen  (engineWeightRen),
		.weightData (engineWeightData),

		.biasAddr (engineBiasAddr),
		.biasRen  (engineBiasRen),
		.biasData (engineBiasData),

		.accReadImage (unusedAccReadImage),
		.accReadWord  (unusedAccReadWord),

		.predReadImage (predReadImage),
		.predReadData  (predReadData),

		.busy (engineBusy),
		.done (engineDone),

		.dbgState         (engineDbgState),
		.dbgInputTile     (engineDbgInputTile),
		.dbgResultImage   (engineDbgResultImage),
		.dbgTileResultCnt (engineDbgTileResultCnt)
	);

	wire senderBusy;
	wire senderDone;
	wire [ADDR_WIDTH-1:0] dbgSendIndex;
	wire [3:0] senderDbgState;

	predSender #(
		.BATCH_SIZE  (BATCH_SIZE),
		.ADDR_WIDTH  (ADDR_WIDTH),
		.SEND_HEADER (1),
		.HEADER0     (8'hCC),
		.HEADER1     (8'h33)
	) sender (
		.clk   (clk),
		.rst   (rst),
		.start (senderStart),

		.predReadImage (predReadImage),
		.predReadData  (predReadData),

		.txStart (txStart),
		.txItem  (txItem),
		.txDone  (txDone),
		.txBusy  (txBusy),

		.busy (senderBusy),
		.done (senderDone),

		.dbgSendIndex (dbgSendIndex),
		.dbgState     (senderDbgState)
	);

	always@(posedge clk)begin
		if(rst)begin
			state <=S_LOAD_START;

			loaderStart <=1'b0;
			engineStart <=1'b0;
			senderStart <=1'b0;

			loadDoneSticky <=1'b0;
			engineDoneSticky <=1'b0;
			sendDoneSticky <=1'b0;
		end
		else begin
			loaderStart <=1'b0;
			engineStart <=1'b0;
			senderStart <=1'b0;

			if(loaderDone) loadDoneSticky <=1'b1;
			if(engineDone) engineDoneSticky <=1'b1;
			if(senderDone) sendDoneSticky <=1'b1;

			case(state)
				S_LOAD_START:begin
					loadDoneSticky <=1'b0;
					engineDoneSticky <=1'b0;
					sendDoneSticky <=1'b0;

					loaderStart <=1'b1;
					state <=S_LOAD;
				end

				S_LOAD:begin
					if(loaderError)begin
						state <=S_ERROR;
					end
					else if(loaderDone)begin
						state <=S_READY;
					end
				end

				S_READY:begin
					if(startBtnRise)begin
						state <=S_RUN_START;
					end
				end

				S_RUN_START:begin
					engineStart <=1'b1;
					state <=S_RUN;
				end

				S_RUN:begin
					if(engineDone)begin
						state <=S_SEND_START;
					end
				end

				S_SEND_START:begin
					senderStart <=1'b1;
					state <=S_SEND;
				end

				S_SEND:begin
					if(senderDone)begin
						state <=S_FINISH;
					end
				end

				S_FINISH:begin
					state <=S_FINISH;
				end

				S_ERROR:begin
					state <=S_ERROR;
				end

				default:begin
					state <=S_LOAD_START;
				end
			endcase
		end
	end

	assign LEDarr[0]  =loadDoneSticky;
	assign LEDarr[1]  =(state ==S_READY);
	assign LEDarr[2]  =engineBusy;
	assign LEDarr[3]  =engineDoneSticky;
	assign LEDarr[4]  =senderBusy;
	assign LEDarr[5]  =sendDoneSticky;
	assign LEDarr[6]  =loaderError;
	assign LEDarr[7]  =rxError;
	assign LEDarr[8]  =rxBusy;
	assign LEDarr[9]  =txBusy;
	assign LEDarr[10] =loaderBusy;
	assign LEDarr[11] =(state ==S_FINISH);
	assign LEDarr[15:12] =state;

endmodule
