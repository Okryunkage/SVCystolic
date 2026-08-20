`timescale 1ns / 1ps
`default_nettype none

module top_simple#(
	parameter integer NINV       =13,
	parameter integer NUM_RO     =8,
	parameter integer TOTAL_BITS =100_000_000,
	parameter integer COUNT_W =
		(TOTAL_BITS < 2) ? 1 : $clog2(TOTAL_BITS + 1))(
	input  wire              clk,
	input  wire              START,
	input  wire              RST,

	output wire              RANDOM_BIT,
	output wire              RANDOM_VALID,
	output wire              RANDOM_DONE,
	output wire              RANDOM_BUSY,
	output wire[COUNT_W-1:0] RANDOM_COUNT);

	(* ASYNC_REG = "TRUE" *) reg[2:0] start_sync =3'b000;
	(* ASYNC_REG = "TRUE" *) reg[1:0] reset_sync =2'b00;

	always @(posedge clk) begin
		start_sync <={start_sync[1:0], START};
		reset_sync <={reset_sync[0], RST};
	end

	wire start_pulse =start_sync[1] & ~start_sync[2];
	wire reset_i     =reset_sync[1];

	wire [NUM_RO-1:0] raw_ro_out;

	genvar ro_idx;
	generate
		for (ro_idx=0; ro_idx<NUM_RO; ro_idx =ro_idx+1)begin:GEN_RO
			(* keep_hierarchy = "yes", dont_touch = "true" *)
			RO #(.INV(NINV)) u_ro(.en(1'b1),.raw_ro(raw_ro_out[ro_idx]));
		end
	endgenerate

	// ========================================================
	// 비동기 RO 출력 샘플러
	// 각 raw_ro를 100 MHz clock으로 한 번씩 샘플링한다.
	// ========================================================
	wire [NUM_RO-1:0] sampled_ro;

	genvar dff_idx;
	generate
		for (dff_idx = 0; dff_idx < NUM_RO; dff_idx = dff_idx + 1) begin : GEN_DFF
			(* keep_hierarchy = "yes", dont_touch = "true" *)
			DFF u_dff (
				.clk       (clk),
				.ce        (1'b1),
				.raw_ro    (raw_ro_out[dff_idx]),
				.sample_ro (sampled_ro[dff_idx])
			);
		end
	endgenerate

	// ========================================================
	// 모든 RO 샘플의 reduction XOR
	// NUM_RO는 짝수여도 무방하다. 홀수 조건은 NINV에 적용된다.
	// ========================================================
	wire xor_bit = ^sampled_ro;
	reg  rng_bit = 1'b0;

	always @(posedge clk) begin
		if (reset_i)
			rng_bit <= 1'b0;
		else
			rng_bit <= xor_bit;
	end

	// ========================================================
	// 원하는 개수만큼 rng_bit을 출력하는 단순 Controller
	// ========================================================
	controller_simple #(
		.TOTAL_BITS (TOTAL_BITS),
		.COUNT_W    (COUNT_W)
	) u_controller_simple (
		.clk          (clk),
		.rst          (reset_i),
		.start        (start_pulse),
		.rng_bit      (rng_bit),
		.random_bit   (RANDOM_BIT),
		.random_valid (RANDOM_VALID),
		.random_done  (RANDOM_DONE),
		.busy         (RANDOM_BUSY),
		.random_count (RANDOM_COUNT)
	);

endmodule

`default_nettype wire