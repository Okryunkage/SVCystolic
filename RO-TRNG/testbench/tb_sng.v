`timescale 1ns/1ps
`default_nettype none

module tb_sng;
	reg clk = 1'b0;
	reg rst = 1'b1;
	reg raw_bit = 1'b0;
	reg [1:0] lut_prob_sel = 2'b00;
	reg [3:0] mux_probability = 4'b0000;
	wire lut_bit;
	wire lut_valid;
	wire mux_bit;
	wire mux_valid;
	integer selection;
	integer value;
	integer ones;
	integer expected;

	sng_lut u_lut (
		.clk(clk), .rst(rst), .rawBit(raw_bit),
		.probSel(lut_prob_sel),
		.randomBit(lut_bit), .randomValid(lut_valid)
	);

	sng_mux u_mux (
		.clk(clk), .rst(rst), .rawBit(raw_bit),
		.probability(mux_probability),
		.randomBit(mux_bit), .randomValid(mux_valid)
	);

	always #5 clk = ~clk;

	task send_nibble;
		input [3:0] nibble;
		integer bit_index;
		begin
			for (bit_index = 3; bit_index >= 0; bit_index = bit_index - 1) begin
				raw_bit = nibble[bit_index];
				@(posedge clk); #1;
			end
			if (!lut_valid || !mux_valid) begin
				$display("FAIL: output valid missing");
				$finish;
			end
		end
	endtask

	initial begin
		repeat (2) @(posedge clk);
		@(negedge clk);
		rst = 1'b0;

		for (selection = 0; selection < 4; selection = selection + 1) begin
			lut_prob_sel = selection[1:0];
			case (selection)
				0: expected = 4;
				1: expected = 8;
				2: expected = 12;
				default: expected = 16;
			endcase
			ones = 0;
			for (value = 0; value < 16; value = value + 1) begin
				send_nibble(value[3:0]);
				ones = ones + lut_bit;
			end
			if (ones != expected) begin
				$display("FAIL: LUT select=%0d ones=%0d", selection, ones);
				$finish;
			end
		end

		for (selection = 0; selection < 16; selection = selection + 1) begin
			mux_probability = selection[3:0];
			ones = 0;
			for (value = 0; value < 16; value = value + 1) begin
				send_nibble(value[3:0]);
				ones = ones + mux_bit;
			end
			if (ones != selection) begin
				$display("FAIL: MUX probability=%0d ones=%0d", selection, ones);
				$finish;
			end
		end

		$display("PASS: separate LUT6 and MUX generators verified");
		$finish;
	end
endmodule

`default_nettype wire