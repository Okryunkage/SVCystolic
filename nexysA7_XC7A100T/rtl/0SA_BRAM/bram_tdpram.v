`timescale 1ns/1ps

module bram_tdpram #(
	parameter integer DATA_WIDTH   =256,
	parameter integer DEPTH        =1024,
	parameter integer ADDR_WIDTH   =10,
	parameter         INIT_FILE    ="none",
	parameter integer READ_LATENCY =1,
	parameter         WRITE_MODE_A ="read_first",
	parameter         WRITE_MODE_B ="read_first"
)(
	input  wire                  clk,
	input  wire                  rst,

	input  wire                  ena,
	input  wire                  wea,
	input  wire [ADDR_WIDTH-1:0] addra,
	input  wire [DATA_WIDTH-1:0] dina,
	output wire [DATA_WIDTH-1:0] douta,

	input  wire                  enb,
	input  wire                  web,
	input  wire [ADDR_WIDTH-1:0] addrb,
	input  wire [DATA_WIDTH-1:0] dinb,
	output wire [DATA_WIDTH-1:0] doutb
);

	xpm_memory_tdpram #(
		.ADDR_WIDTH_A        (ADDR_WIDTH),
		.ADDR_WIDTH_B        (ADDR_WIDTH),
		.AUTO_SLEEP_TIME     (0),
		.BYTE_WRITE_WIDTH_A  (DATA_WIDTH),
		.BYTE_WRITE_WIDTH_B  (DATA_WIDTH),
		.CASCADE_HEIGHT      (0),
		.CLOCKING_MODE       ("common_clock"),
		.ECC_MODE            ("no_ecc"),
		.MEMORY_INIT_FILE    (INIT_FILE),
		.MEMORY_INIT_PARAM   ("0"),
		.MEMORY_OPTIMIZATION ("true"),
		.MEMORY_PRIMITIVE    ("block"),
		.MEMORY_SIZE         (DATA_WIDTH * DEPTH),
		.MESSAGE_CONTROL     (0),
		.READ_DATA_WIDTH_A   (DATA_WIDTH),
		.READ_DATA_WIDTH_B   (DATA_WIDTH),
		.READ_LATENCY_A      (READ_LATENCY),
		.READ_LATENCY_B      (READ_LATENCY),
		.READ_RESET_VALUE_A  ("0"),
		.READ_RESET_VALUE_B  ("0"),
		.RST_MODE_A          ("SYNC"),
		.RST_MODE_B          ("SYNC"),
		.SIM_ASSERT_CHK      (0),
		.USE_EMBEDDED_CONSTRAINT (0),
		.USE_MEM_INIT        (1),
		.USE_MEM_INIT_MMI    (0),
		.WAKEUP_TIME         ("disable_sleep"),
		.WRITE_DATA_WIDTH_A  (DATA_WIDTH),
		.WRITE_DATA_WIDTH_B  (DATA_WIDTH),
		.WRITE_MODE_A        (WRITE_MODE_A),
		.WRITE_MODE_B        (WRITE_MODE_B)
	) xpm_mem (
		.clka           (clk),
		.clkb           (clk),
		.rsta           (rst),
		.rstb           (rst),
		.ena            (ena),
		.enb            (enb),
		.regcea         (1'b1),
		.regceb         (1'b1),
		.wea            (wea),
		.web            (web),
		.addra          (addra),
		.addrb          (addrb),
		.dina           (dina),
		.dinb           (dinb),
		.douta          (douta),
		.doutb          (doutb),
		.injectsbiterra (1'b0),
		.injectsbiterrb (1'b0),
		.injectdbiterra (1'b0),
		.injectdbiterrb (1'b0),
		.sbiterra       (),
		.sbiterrb       (),
		.dbiterra       (),
		.dbiterrb       (),
		.sleep          (1'b0)
	);

endmodule
