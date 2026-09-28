`timescale 1ns/1ps

module bram_spram #(
	parameter integer DATA_WIDTH = 256,
	parameter integer DEPTH      = 1024,
	parameter integer ADDR_WIDTH = 10,
	parameter         INIT_FILE  = "none",
	parameter integer READ_LATENCY = 1
)(
	input  wire                  clk,
	input  wire                  rst,

	input  wire                  en,
	input  wire                  we,
	input  wire [ADDR_WIDTH-1:0] addr,
	input  wire [DATA_WIDTH-1:0] din,
	output wire [DATA_WIDTH-1:0] dout
);

	xpm_memory_spram #(
		.ADDR_WIDTH_A        (ADDR_WIDTH),
		.AUTO_SLEEP_TIME     (0),
		.BYTE_WRITE_WIDTH_A  (DATA_WIDTH),
		.CASCADE_HEIGHT      (0),
		.ECC_MODE            ("no_ecc"),
		.MEMORY_INIT_FILE    (INIT_FILE),
		.MEMORY_INIT_PARAM   ("0"),
		.MEMORY_OPTIMIZATION ("true"),
		.MEMORY_PRIMITIVE    ("block"),
		.MEMORY_SIZE         (DATA_WIDTH * DEPTH),
		.MESSAGE_CONTROL     (0),
		.READ_DATA_WIDTH_A   (DATA_WIDTH),
		.READ_LATENCY_A      (READ_LATENCY),
		.READ_RESET_VALUE_A  ("0"),
		.RST_MODE_A          ("SYNC"),
		.SIM_ASSERT_CHK      (0),
		.USE_MEM_INIT        (1),
		.WAKEUP_TIME         ("disable_sleep"),
		.WRITE_DATA_WIDTH_A  (DATA_WIDTH),
		.WRITE_MODE_A        ("read_first")
	) xpm_mem (
		.clka           (clk),
		.rsta           (rst),
		.ena            (en),
		.regcea         (1'b1),
		.wea            (we),
		.addra          (addr),
		.dina           (din),
		.douta          (dout),
		.injectsbiterra (1'b0),
		.injectdbiterra (1'b0),
		.sbiterra       (),
		.dbiterra       (),
		.sleep          (1'b0)
	);

endmodule