`timescale 1ns / 1ps
`default_nettype none

module controller_simple #(
	parameter integer TOTAL_BITS = 100_000_000,
	parameter integer COUNT_W =
		(TOTAL_BITS < 2) ? 1 : $clog2(TOTAL_BITS + 1)
)(
	input  wire               clk,
	input  wire               rst,
	input  wire               start,
	input  wire               rng_bit,

	output reg                random_bit   =1'b0,
	output reg                random_valid =1'b0,
	output reg                random_done  =1'b0,
	output reg                busy         =1'b0,
	output reg [COUNT_W-1:0]  random_count ={COUNT_W{1'b0}});

	always @(posedge clk) begin
		random_valid <=1'b0;
		random_done  <=1'b0;
		if(rst)begin
			random_bit   <=1'b0;
			random_valid <=1'b0;
			random_done  <=1'b0;
			busy         <=1'b0;
			random_count <={COUNT_W{1'b0}};
		end 
		else if(start&&!busy)begin
			busy         <=1'b1;
			random_count <={COUNT_W{1'b0}};
		end
		else if(busy)begin
			random_bit   <=rng_bit;
			random_valid <=1'b1;
			if(random_count==TOTAL_BITS-1)begin
				random_count <=TOTAL_BITS;
				random_done  <=1'b1;
				busy         <=1'b0;
			end
			else random_count <=random_count+1'b1;
		end
	end
endmodule
`default_nettype wire
