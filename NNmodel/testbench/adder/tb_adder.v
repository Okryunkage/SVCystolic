`include "fc.v"
`include "relu.v"
`include "sign.v"
`include "adderTOPmlp.v"
`timescale 1ns/1ps

module tb_adderTOPmlp;
	reg  [3:0] a;
	reg  [3:0] b;
	wire [4:0] out;

	reg  [4:0] expected;

	integer i;
	integer j;
	integer passCount;
	integer failCount;

	adderTOPmlp adder4(.a(a),.b(b),.out(out));

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0, tb_adderTOPmlp);
		
		a = 4'd0;
		b = 4'd0;
		expected = 5'd0;
		passCount = 0;
		failCount = 0;
		#10;
		for(i=0; i<16; i=i+1) begin
			for(j=0; j<16; j=j+1) begin
				a = i[3:0];
				b = j[3:0];
				expected = i + j;

				#1; // 조합회로 settle 시간

				if(out !== expected) begin
					failCount = failCount + 1;
					$display("FAIL : a=%0d b=%0d | out=%0d (%b) | expected=%0d (%b)",
							 i, j, out, out, expected, expected);
				end
				else begin
					passCount = passCount + 1;
					$display("PASS : a=%0d b=%0d | out=%0d (%b)",
							 i, j, out, out);
				end
			end
		end

		$display("========================================");
		$display("TEST DONE");
		$display("PASS = %0d", passCount);
		$display("FAIL = %0d", failCount);
		$display("========================================");

		$finish;
	end

endmodule