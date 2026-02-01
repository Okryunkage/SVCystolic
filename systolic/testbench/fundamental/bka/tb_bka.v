`include "adder.v"
`include "bka.v"
`timescale 1ns/1ps

module tb_bka;
	localparam width =16;
	reg [width:0] A,B;
	wire [width:0] sum;
	reg cin;
	wire cout;
	bka #(width+1) adder(A,B,cin,sum,cout);
	//----------
	function signed [width:0] compare;
		input signed [width:0] a,b,c;
		compare = a + b + c;
	endfunction
	//----------
	integer i;
	integer errors;
	task test;
		input signed [(width-1):0] t_r0;
		input signed [(width-1):0] t_r1;
		input t_c;
		reg [width:0] exp;
		begin
			exp = compare({t_r0[width-1],t_r0},{t_r1[width-1],t_r1},{{width{1'b0}},t_c});
			A = {t_r0[width-1],t_r0};
			B = {t_r1[width-1],t_r1};
			cin = t_c;
			#5;
			if (^sum === 1'bX)begin //unary XOR
				errors = errors+1;
				$display("X/Z @%0t",$time);
			end
			else if(sum !== exp)begin
				errors = errors + 1;
		                $display("MIS @%0t",$time);
			end
		end
	endtask
	//----------
	reg [(width-1):0] r0,r1;
	reg r2;
	initial begin
		errors =0;
		$dumpfile("out.vcd");
		$dumpvars(0,tb_bka);
		for (i = 0; i < 5000; i = i + 1) begin
			r0 = $random;
			r1 = $random;
			r2 = $random;
			test(r0,r1,r2);
		end
		if(errors == 0) $display("PASS: no mismatches");
		else $display("FAIL: %0d mismatches", errors);
		#10;
		$finish;
	end
endmodule
