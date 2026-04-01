`timescale 1ns/1ps

module tickgen_rev #(
	parameter integer CLK    =100_000_000,
	parameter integer TICK   =1_000_000,
	parameter integer ACCwidth =24
)(
	input  wire clk,
	input  wire rst,
	output reg  tick
);

	localparam [63:0] SCALE =(64'd1 << ACCwidth);
	localparam [63:0] INC   =((TICK*SCALE)+(CLK/2))/CLK;

	reg  [ACCwidth-1:0] acc ={ACCwidth{1'b0}};
	wire [ACCwidth:0]   sum ={1'b0,acc}+INC[ACCwidth:0];

	always@(posedge clk) begin
		if (rst) begin
			acc  <={ACCwidth{1'b0}};
			tick <=1'b0;
		end
		else {tick, acc} <= sum;
	end
endmodule
