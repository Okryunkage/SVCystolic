`timescale 1ns/1ps

module tb_linear10Top_bram;

	localparam integer SIZE           = 10;
	localparam integer BATCH_SIZE     = 100;
	localparam integer INPUT_TILE_NUM = 79;
	localparam integer ADDR_WIDTH     = 16;
	localparam integer RESULT_DELAY   = 19;

	localparam integer ACC_WIDTH      = SIZE * 32;

	parameter INPUT_MEM_FILE  = "input_batch_tile10_lsb.mem";
	parameter WEIGHT_MEM_FILE = "mnist_linear_w_outmajor_for_sabtr.mem";
	parameter BIAS_MEM_FILE   = "mnist_linear_b_int32.mem";
	parameter REF_ACC_FILE    = "ref_acc_10x32_lsb.mem";
	parameter REF_PRED_FILE   = "ref_pred.mem";

	reg clk;
	reg rst;
	reg start;

	reg  [ADDR_WIDTH-1:0] accReadImage;
	wire [ACC_WIDTH-1:0]  accReadWord;

	reg  [ADDR_WIDTH-1:0] predReadImage;
	wire [3:0]            predReadData;

	wire busy;
	wire done;

	wire [3:0]            dbgState;
	wire [ADDR_WIDTH-1:0] dbgInputTile;
	wire [ADDR_WIDTH-1:0] dbgResultImage;
	wire [ADDR_WIDTH-1:0] dbgTileResultCnt;

	wire [ADDR_WIDTH-1:0] dbgInputAddr;
	wire                  dbgInputRen;
	wire [ADDR_WIDTH-1:0] dbgWeightAddr;
	wire                  dbgWeightRen;
	wire [ADDR_WIDTH-1:0] dbgBiasAddr;
	wire                  dbgBiasRen;

	reg [ACC_WIDTH-1:0] refAcc  [0:BATCH_SIZE-1];
	reg [3:0]           refPred [0:BATCH_SIZE-1];

	integer cycle;
	integer timeout;
	integer i;
	integer j;
	integer errors;
	integer predErrors;
	integer accErrors;

	reg signed [31:0] actualScore;
	reg signed [31:0] expectScore;

	linear10Top_bram #(
		.SIZE           (SIZE),
		.BATCH_SIZE     (BATCH_SIZE),
		.INPUT_TILE_NUM (INPUT_TILE_NUM),
		.ADDR_WIDTH     (ADDR_WIDTH),
		.RESULT_DELAY   (RESULT_DELAY),
		.INPUT_MEM_FILE  (INPUT_MEM_FILE),
		.WEIGHT_MEM_FILE (WEIGHT_MEM_FILE),
		.BIAS_MEM_FILE   (BIAS_MEM_FILE)
	) dut (
		.clk   (clk),
		.rst   (rst),
		.start (start),

		.accReadImage (accReadImage),
		.accReadWord  (accReadWord),

		.predReadImage (predReadImage),
		.predReadData  (predReadData),

		.busy (busy),
		.done (done),

		.dbgState         (dbgState),
		.dbgInputTile     (dbgInputTile),
		.dbgResultImage   (dbgResultImage),
		.dbgTileResultCnt (dbgTileResultCnt),

		.dbgInputAddr  (dbgInputAddr),
		.dbgInputRen   (dbgInputRen),
		.dbgWeightAddr (dbgWeightAddr),
		.dbgWeightRen  (dbgWeightRen),
		.dbgBiasAddr   (dbgBiasAddr),
		.dbgBiasRen    (dbgBiasRen)
	);

	initial begin
		clk = 1'b0;
		forever #5 clk = ~clk;
	end

	initial begin
		$dumpfile("tb_linear10Top_bram.vcd");
		$dumpvars(0, tb_linear10Top_bram);
	end

	initial begin
		$display("============================================================");
		$display("linear10Top_bram testbench");
		$display("BATCH_SIZE      = %0d", BATCH_SIZE);
		$display("INPUT_TILE_NUM  = %0d", INPUT_TILE_NUM);
		$display("RESULT_DELAY    = %0d", RESULT_DELAY);
		$display("INPUT_MEM_FILE  = %s", INPUT_MEM_FILE);
		$display("WEIGHT_MEM_FILE = %s", WEIGHT_MEM_FILE);
		$display("BIAS_MEM_FILE   = %s", BIAS_MEM_FILE);
		$display("REF_ACC_FILE    = %s", REF_ACC_FILE);
		$display("REF_PRED_FILE   = %s", REF_PRED_FILE);
		$display("============================================================");

		$readmemh(REF_ACC_FILE, refAcc);
		$readmemh(REF_PRED_FILE, refPred);

		rst = 1'b1;
		start = 1'b0;
		accReadImage = {ADDR_WIDTH{1'b0}};
		predReadImage = {ADDR_WIDTH{1'b0}};

		errors = 0;
		predErrors = 0;
		accErrors = 0;
		cycle = 0;
		timeout = 1000000;

		repeat(10) @(posedge clk);
		rst = 1'b0;
		repeat(5) @(posedge clk);

		$display("[TB] start pulse");
		start = 1'b1;
		@(posedge clk);
		start = 1'b0;

		while(!done && cycle < timeout) begin
			@(posedge clk);
			cycle = cycle + 1;

			if((cycle % 1000) == 0) begin
				$display("[INFO] cycle=%0d state=%0d tile=%0d resultImage=%0d tileResultCnt=%0d busy=%0d",
					cycle, dbgState, dbgInputTile, dbgResultImage, dbgTileResultCnt, busy);
			end
		end

		if(cycle >= timeout) begin
			$display("============================================================");
			$display("[FAIL] Timeout waiting for done.");
			$display("state=%0d tile=%0d resultImage=%0d tileResultCnt=%0d busy=%0d",
				dbgState, dbgInputTile, dbgResultImage, dbgTileResultCnt, busy);
			$display("============================================================");
			$finish;
		end

		$display("============================================================");
		$display("[TB] DUT done at cycle %0d", cycle);
		$display("[TB] Checking acc[0:9] and pred for %0d images", BATCH_SIZE);
		$display("============================================================");

		for(i=0; i<BATCH_SIZE; i=i+1) begin
			accReadImage = i[ADDR_WIDTH-1:0];
			predReadImage = i[ADDR_WIDTH-1:0];

			@(posedge clk);
			@(posedge clk);

			if(predReadData !== refPred[i]) begin
				predErrors = predErrors + 1;
				errors = errors + 1;
				$display("[PRED MISMATCH] image=%0d expected=%0d actual=%0d",
					i, refPred[i], predReadData);
			end

			for(j=0; j<SIZE; j=j+1) begin
				actualScore = $signed(accReadWord[j*32 +: 32]);
				expectScore = $signed(refAcc[i][j*32 +: 32]);

				if(actualScore !== expectScore) begin
					accErrors = accErrors + 1;
					errors = errors + 1;
					$display("[ACC MISMATCH] image=%0d out=%0d expected=%0d actual=%0d",
						i, j, expectScore, actualScore);
				end
			end
		end

		$display("============================================================");
		if(errors == 0) begin
			$display("[PASS] All accumulator values and predictions matched.");
			$display("images=%0d outputs=%0d", BATCH_SIZE, SIZE);
		end
		else begin
			$display("[FAIL] errors=%0d predErrors=%0d accErrors=%0d",
				errors, predErrors, accErrors);
		end
		$display("============================================================");

		$finish;
	end

endmodule