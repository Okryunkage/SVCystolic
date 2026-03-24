`timescale 1ns/1ps

module clockGen#(
	parameter integer board =2_000_000,
	parameter integer target=1_000_000)(
	input  wire boardCLKp,
	input  wire boardCLKn,
	output wire clock
);
	`include "ceillog2.vh"
	wire CLKibuf;
	wire baseCLK;
	IBUFDS clkIBUFDS(
		.I(boardCLKp),
		.IB(boardCLKn),
		.O(CLKibuf)
	);
	BUFG clkBUFG(
		.I(CLKibuf),
		.O(baseCLK)
	);
	generate
		if(target==board)begin:genBypass
			assign clock=baseCLK;
		end
		else begin:genDivide
			localparam integer divide =board/(2*target);
			localparam integer divide_width =ceillog2(divide);
			reg [(divide_width-1):0] count =1'd0;
			reg divClock =1'd0;
			assign clock=divClock;
			always@(posedge baseCLK)begin
				if(count==(divide-1))begin
					count<=1'd0;
					divClock<=~divClock;
				end
				else count<=count+1'b1;
			end
		end
	endgenerate
endmodule
