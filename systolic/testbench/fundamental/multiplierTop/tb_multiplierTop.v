`include "multiplier_top.v"
`include "multiplier.v"
`include "tree.v"
`include "adder.v"
`timescale 1ns/1ps

module tb_multiplierTop;
	reg  [7:0]  multiplier;
	reg  [7:0]  multiplicand;
	wire [15:0] result;
	integer i;
	integer errors;
	reg [7:0] ra, rb; //No matter if it's singed or unsigned.
	multiplier_top8 dut(multiplier,multiplicand,result);
	//----------
	function [15:0] compare;
        	input signed [7:0] a;
        	input signed [7:0] b;
		compare = a * b;
	endfunction
	//----------
	task test;
		input [7:0] a;
		input [7:0] b;
		input [255:0] tag;
		reg [15:0] exp;
        	begin
			multiplier = a;
			multiplicand = b;
			#1;
			exp = compare(a,b);
			if(^result === 1'bX)begin //xor operation for every bits of result | === for comparing 0/1/X/Z
				errors = errors + 1;
				$display("X/Z @%0t %0s : a=0x%02h b=0x%02h result=0x%04h exp=0x%04h",
					$time, tag, a, b, result, exp);
			end
			else if(result !== exp)begin
				errors = errors + 1;
				$display("MIS @%0t %0s : a=%0d(0x%02h) b=%0d(0x%02h) result=%0d(0x%04h) exp=%0d(0x%04h)",
					$time, tag, $signed(a), a, $signed(b), b, $signed(result), result, $signed(exp), exp);
			end
		end
	endtask
	//----------
	initial begin
		errors = 0;
		multiplier = 8'h00;
		multiplicand = 8'h00;
        	$dumpfile("out.vcd");
        	$dumpvars(0, tb_multiplierTop);
		test(8'h00, 8'h00, "0*0");
		test(8'h01, 8'h00, "1*0");
		test(8'h00, 8'h01, "0*1");
		test(8'h01, 8'h01, "1*1");
		test(8'h02, 8'h03, "2*3");
		test(8'h7f, 8'h01, "127*1");
		test(8'hff, 8'h01, "-1*1");
		test(8'hff, 8'hff, "-1*-1");
		test(8'h80, 8'h01, "-128*1");
		test(8'h80, 8'h80, "-128*-128");
		test(8'h7f, 8'h7f, "127*127");
		test(8'h80, 8'h7f, "-128*127");
		test(8'h7f, 8'h80, "127*-128");
		//----------
		for (i = -8;i <=7; i = i + 1) begin
			ra = i;
			rb = 7 - i;
			test(ra, rb, "small_sweep");
		end
		for (i = 0; i < 5000; i = i + 1) begin
			ra = $random;
			rb = $random;
			test(ra, rb, "random");
		end
		if(errors == 0) $display("PASS: no mismatches");
		else $display("FAIL: %0d mismatches", errors);
		#10;
		$finish;
	end
endmodule
