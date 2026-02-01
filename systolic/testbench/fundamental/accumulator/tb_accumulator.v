`include "adder.v"
`include "accumulator.v"
`timescale 1ns/1ps

module tb_accumulator;
	localparam arraysize =4;
	localparam bussize =arraysize+16;
	localparam busize =bussize-1;
	reg [15:0] result0, result1;
	reg [busize:0] psum0, psum1;
	wire [busize:0] psumO0, psumO1;
	accumulator #(arraysize) dut(result0,result1,psum0,psum1,psumO0,psumO1);
	
	wire [bussize:0] finalresult;
	wire [busize:0] finalx;
	cpa #(bussize) finalAdder(.A(psumO0),.B(psumO1),.sum(finalresult));
	assign finalx = finalresult[31:0];
	reg [15:0] r0, r1;
	reg [(15+arraysize/2):0] r2, r3;
	//----------
	function [busize:0] compare;
		input signed [15:0] result0, result1;
		input signed [(15+arraysize/2):0] psum0, psum1;
		compare = result0 + result1 + psum0 + psum1;
	endfunction
	//----------
	integer i;
	integer errors;
	task test;
		input signed [15:0] t_r0;
		input signed [15:0] t_r1;
		input signed [(15+arraysize/2):0] t_p0;
		input signed [(15+arraysize/2):0] t_p1;
		reg [busize:0] exp;
		begin
			exp = compare(t_r0,t_r1,t_p0,t_p1);
			result0 = t_r0;
			result1 = t_r1;
			psum0 = {{(arraysize/2){t_p0[(15+arraysize/2)]}},t_p0};
			psum1 = {{(arraysize/2){t_p1[(15+arraysize/2)]}},t_p1};
			#1;
			if (^finalx === 1'bX)begin
				errors = errors+1;
				$display("X/Z @%0t",$time);
			end
			else if(finalx !== exp)begin
				errors = errors + 1;
                $display("MIS @%0t",$time);
			end
		end
	endtask
	//----------
	initial begin
		errors =0;
		result0 = 16'h0000;
		result1 = 16'h0000;
		psum0 = {bussize{1'b0}};
		psum1 = {bussize{1'b0}};
		$dumpfile("out.vcd");
		$dumpvars(0,tb_accumulator);
		for (i = 0; i < 5000; i = i + 1) begin
			r0 = $random;
			r1 = $random;
			r2 = $random;
			r3 = $random;
			test(r0,r1,r2,r3);
		end
		if(errors == 0) $display("PASS: no mismatches");
		else $display("FAIL: %0d mismatches", errors);
		#10;
		$finish;
	end
endmodule
