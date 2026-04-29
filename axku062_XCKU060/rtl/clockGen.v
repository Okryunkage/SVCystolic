`timescale 1ns/1ps

module clockGen(
	input  wire boardCLKp,
	input  wire boardCLKn,
	output wire clock
);
	wire CLKibuf;
	IBUFDS clkIBUFDS(
		.I(boardCLKp),
		.IB(boardCLKn),
		.O(CLKibuf)
	);
	BUFG clkBUFG(
		.I(CLKibuf),
		.O(clock)
	);
endmodule
