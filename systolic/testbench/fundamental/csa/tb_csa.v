`include "adder.v"
`timescale 1ns/1ps

module tb_csa();
	parameter size =16;
	reg [(size-1):0] A, B, C;
	wire [(size-1):0] sum, cout;
	wire [(size-1):0] sumhalf, couthalf;

	wire [(size+1):0] final0, final1;
	
	csa #(size) csatest(A, B, C, sum, cout);
	cpa #(size+1) cpa0({sum[size-1],sum}, {cout,1'b0}, final0);

	halfcsa#(size) halfcsatest(A, B, sumhalf, couthalf);
	cpa #(size+1) cpa1({sumhalf[size-1],sumhalf}, {couthalf,1'b0}, final1);

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0, tb_csa);
		A = 10;
		B = 20;
		C = 30;
		#10;
		A = 5;
		B = 6;
		C = 7;
		#10;
		$finish;
	end
endmodule

