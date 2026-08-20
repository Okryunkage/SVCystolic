`timescale 1ns/1ps
`default_nettype none

module top #(
	parameter integer BASE_CLK   =100_000_000,
	parameter integer BAUD       =921600,

	parameter integer NINV       =51,
	parameter integer MAX_NUM_RO =51,

	parameter integer SWEEP_EN      =1,
	parameter integer FIXED_NUM_RO  =3,

	parameter integer TOTAL_BITS = 100_000_000,
	parameter integer FIFO_BYTES = 4096)(

	input  wire clk_100m,
	input  wire BTNC,
	output wire UART_TX);

	// ============================================================
	// RO BANK (MAX_NUM_RO개 전부 인스턴스, 런타임 XOR mask로 선택)
	// ============================================================
	wire [MAX_NUM_RO-1:0] raw_ro_out;

	genvar gi;
	generate
		for (gi = 0; gi < MAX_NUM_RO; gi = gi + 1) begin : GEN_RO
			(* keep_hierarchy = "yes", dont_touch = "true" *)
			RO #(.NINV(NINV)) u_ro (
				.en     (1'b1),
				.raw_ro (raw_ro_out[gi])
			);
		end
	endgenerate

	// ============================================================
	// DFF Sampler (100MHz 직접 샘플링, CE_generator 제거)
	// ============================================================
	wire [MAX_NUM_RO-1:0] samp_ro_output;

	genvar fi;
	generate
		for (fi = 0; fi < MAX_NUM_RO; fi = fi + 1) begin : GEN_DFF
			(* keep_hierarchy = "yes", dont_touch = "true" *)
			DFF u_dff (
				.raw_ro    (raw_ro_out[fi]),
				.clk       (clk_100m),
				.ce        (1'b1),          // 100MHz 고정
				.sample_ro (samp_ro_output[fi])
			);
		end
	endgenerate

	// ============================================================
	// XOR (xor_num_sel개만큼 마스킹)
	// ============================================================
	wire [5:0] xor_num_sel;   // controller 출력

	localparam integer NRO  = MAX_NUM_RO;
	localparam integer SHW  = $clog2(NRO + 1);

	// sample_ce 대신 매 클럭 래치
	reg [5:0] xor_num_q = 6'd3;
	always @(posedge clk_100m)
		xor_num_q <= xor_num_sel;

	wire [5:0] k =
		(xor_num_q == 6'd0)    ? 6'd0 :
		(xor_num_q > NRO[5:0]) ? NRO[5:0] :
								  xor_num_q;

	wire [NRO-1:0] all1          = {NRO{1'b1}};
	wire [SHW-1:0] shamt         = NRO[SHW-1:0] - k[SHW-1:0];
	wire [NRO-1:0] xor_mask      = (k == 0) ? {NRO{1'b0}} : (all1 >> shamt);
	wire           xor_bit       = ^(samp_ro_output & xor_mask);

	reg rng_bit = 1'b0;
	always @(posedge clk_100m)
		rng_bit <= xor_bit;

	// ============================================================
	// UART
	// ============================================================
	wire       uart_rst;
	wire       uart_start;
	wire [7:0] uart_data;
	wire       uart_busy;

	(* keep_hierarchy = "yes", dont_touch = "true" *)
	uart #(
		.BASE_CLK (BASE_CLK),
		.BAUD     (BAUD)
	) u_uart (
		.clk      (clk_100m),
		.rst      (uart_rst),
		.tx_start (uart_start),
		.tx_data  (uart_data),
		.tx       (UART_TX),
		.busy     (uart_busy)
	);

	// ============================================================
	// Controller
	// ============================================================
	(* keep_hierarchy = "yes", dont_touch = "true" *)
	controller #(
		.TOTAL_BITS        (TOTAL_BITS),
		.FIFO_BYTES        (FIFO_BYTES),
		.SWEEP_EN          (SWEEP_EN),
		.FIXED_XOR_NUM_SEL (FIXED_NUM_RO)
	) u_ctrl (
		.clk         (clk_100m),
		.sw0         (BTNC),
		.btnc        (1'b0),
		.rng_bit     (rng_bit),
		.uart_busy   (uart_busy),
		.uart_rst    (uart_rst),
		.uart_start  (uart_start),
		.uart_data   (uart_data),
		.xor_num_sel (xor_num_sel)
	);

endmodule

`default_nettype wire
