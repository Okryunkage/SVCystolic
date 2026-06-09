`timescale 1ns/1ps

module tb_fpgaTOP;

	localparam integer BOARD_CLK      =100_000_000;
	localparam integer BAUDRATE       =5_000_000;  // faster than FPGA default for simulation
	localparam integer OVERSAMPLE     =10;
	localparam integer ACCWIDTH       =24;

	localparam integer SIZE           =10;
	localparam integer BATCH_SIZE     =100;
	localparam integer INPUT_TILE_NUM =79;
	localparam integer ADDR_WIDTH     =16;
	localparam integer RESULT_DELAY   =19;

	localparam integer BIT_NS         =1_000_000_000 / BAUDRATE;

	parameter INPUT_MEM_FILE  ="input_batch_tile10_lsb.mem";
	parameter WEIGHT_MEM_FILE ="mnist_linear_w_outmajor_for_sabtr.mem";
	parameter BIAS_MEM_FILE   ="mnist_linear_b_int32.mem";
	parameter REF_PRED_FILE   ="ref_pred.mem";

	reg clk;
	reg resetBtn;
	reg startBtn;
	reg uartRX;
	wire uartTX;
	wire [15:0] LED;
	wire [3:0] dbgTopState;

	reg [8*SIZE-1:0] inputMem [0:BATCH_SIZE*INPUT_TILE_NUM-1];
	reg [3:0] refPred [0:BATCH_SIZE-1];

	integer image;
	integer tile;
	integer k;
	integer addr;
	integer pixel;
	integer errors;
	integer totalRx;
	integer cycle;

	reg [7:0] rxByte;

	fpgaTOP #(
		.BOARD_CLK      (BOARD_CLK),
		.BAUDRATE       (BAUDRATE),
		.OVERSAMPLE     (OVERSAMPLE),
		.ACCWIDTH       (ACCWIDTH),

		.SIZE           (SIZE),
		.BATCH_SIZE     (BATCH_SIZE),
		.INPUT_TILE_NUM (INPUT_TILE_NUM),
		.ADDR_WIDTH     (ADDR_WIDTH),
		.RESULT_DELAY   (RESULT_DELAY),

		.INPUT_MEM_FILE  ("none"),
		.WEIGHT_MEM_FILE (WEIGHT_MEM_FILE),
		.BIAS_MEM_FILE   (BIAS_MEM_FILE)
	) dut (
		.clk      (clk),
		.resetBtn (resetBtn),
		.startBtn (startBtn),

		.uartRX (uartRX),
		.uartTX (uartTX),

		.LED (LED),

		.dbgTopState (dbgTopState)
	);

	initial begin
		clk =1'b0;
		forever #5 clk =~clk;
	end

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_fpgaTOP);
	end

	task uart_send_byte;
		input [7:0] b;
		integer bi;
		begin
			// idle high before start
			uartRX =1'b1;
			#(BIT_NS);

			// start bit
			uartRX =1'b0;
			#(BIT_NS);

			// data bits LSB first
			for(bi=0; bi<8; bi=bi+1)begin
				uartRX =b[bi];
				#(BIT_NS);
			end

			// stop bit
			uartRX =1'b1;
			#(BIT_NS);
		end
	endtask

	task uart_recv_byte;
		output [7:0] b;
		integer bi;
		begin
			b =8'd0;

			// Wait for start bit falling edge.
			@(negedge uartTX);

			// Move to center of bit0: 1.5 bit times after start edge.
			#(BIT_NS + BIT_NS/2);

			for(bi=0; bi<8; bi=bi+1)begin
				b[bi] =uartTX;
				#(BIT_NS);
			end

			// Stop bit time.
			#(BIT_NS/2);
		end
	endtask

	initial begin
		$display("============================================================");
		$display("tb_linear10FpgaTop_uart");
		$display("BAUDRATE        = %0d", BAUDRATE);
		$display("BIT_NS          = %0d", BIT_NS);
		$display("BATCH_SIZE      = %0d", BATCH_SIZE);
		$display("INPUT_MEM_FILE  = %s", INPUT_MEM_FILE);
		$display("WEIGHT_MEM_FILE = %s", WEIGHT_MEM_FILE);
		$display("BIAS_MEM_FILE   = %s", BIAS_MEM_FILE);
		$display("REF_PRED_FILE   = %s", REF_PRED_FILE);
		$display("============================================================");

		$readmemh(INPUT_MEM_FILE,inputMem);
		$readmemh(REF_PRED_FILE,refPred);

		resetBtn =1'b1;
		startBtn =1'b0;
		uartRX =1'b1;
		errors =0;
		totalRx =0;
		cycle =0;

		repeat(30) @(posedge clk);
		resetBtn =1'b0;
		repeat(100) @(posedge clk);

		$display("[TB] Sending %0d image bytes through UART RX.", BATCH_SIZE*784);

		for(image=0; image<BATCH_SIZE; image=image+1)begin
			for(tile=0; tile<INPUT_TILE_NUM; tile=tile+1)begin
				addr =image*INPUT_TILE_NUM +tile;

				for(k=0; k<SIZE; k=k+1)begin
					pixel =tile*SIZE +k;

					// Send only real 784 pixels. Do not send padding bytes.
					if(pixel <784)begin
						uart_send_byte(inputMem[addr][k*8 +: 8]);
						totalRx =totalRx +1;
					end
				end
			end

			if((image % 10)==9)begin
				$display("[TB] Sent image %0d / %0d", image+1, BATCH_SIZE);
			end
		end

		$display("[TB] Sent total bytes = %0d", totalRx);
		$display("[TB] Waiting for LOAD DONE / READY.");

		while(LED[1] !==1'b1)begin
			@(posedge clk);
			cycle =cycle +1;
			if(cycle >2_000_000)begin
				$display("[FAIL] Timeout waiting for READY. state=%0d LED=%b", dbgTopState, LED);
				$finish;
			end
		end

		$display("[TB] READY reached. Pressing start button.");
		repeat(50) @(posedge clk);
		startBtn =1'b1;
		repeat(50) @(posedge clk);
		startBtn =1'b0;

		$display("[TB] Waiting for prediction UART packet.");

		uart_recv_byte(rxByte);
		if(rxByte !==8'hCC)begin
			$display("[FAIL] Header0 mismatch. expected=CC actual=%02x", rxByte);
			errors =errors +1;
		end
		else begin
			$display("[TB] Header0 OK");
		end

		uart_recv_byte(rxByte);
		if(rxByte !==8'h33)begin
			$display("[FAIL] Header1 mismatch. expected=33 actual=%02x", rxByte);
			errors =errors +1;
		end
		else begin
			$display("[TB] Header1 OK");
		end

		uart_recv_byte(rxByte);
		if(rxByte !==BATCH_SIZE[7:0])begin
			$display("[FAIL] Batch size mismatch. expected=%0d actual=%0d", BATCH_SIZE, rxByte);
			errors =errors +1;
		end
		else begin
			$display("[TB] Batch size OK: %0d", rxByte);
		end

		for(image=0; image<BATCH_SIZE; image=image+1)begin
			uart_recv_byte(rxByte);

			if(rxByte[3:0] !==refPred[image])begin
				$display("[PRED MISMATCH] image=%0d expected=%0d actual=%0d raw=%02x",
					image, refPred[image], rxByte[3:0], rxByte);
				errors =errors +1;
			end
		end

		repeat(1000) @(posedge clk);

		$display("============================================================");
		if(errors ==0)begin
			$display("[PASS] UART load -> inference -> UART pred send matched reference.");
		end
		else begin
			$display("[FAIL] errors=%0d", errors);
		end
		$display("Final LED=%b state=%0d", LED, dbgTopState);
		$display("============================================================");

		$finish;
	end

endmodule
