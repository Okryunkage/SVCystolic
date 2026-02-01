`timescale 1ns/1ps

module halfadder(
	input a, input b,
	output sum, output cout);
	assign sum = a ^ b;
	assign cout = a & b;
endmodule

module fulladder(
	input a, input b, input cin,
	output sum, output cout);
	assign sum = a ^ b ^ cin;
	assign cout = (a&b)|(b&cin)|(cin&a);
endmodule

module compress42(
	input i0, input i1, input i2, input i3, input c,
	output Csum, output Ccy, output Ccount);
	assign Csum = c ^ i0 ^ i1 ^ i2 ^ i3;
	assign Ccount = (i0 & !(i0^i1))|(i2 & (i0^i1));
	assign Ccy = (i3 & !(i0^i1^i2^i3))|(c&(i0^i1^i2^i3));
endmodule

module blackCell(
	input wire gc, input wire pc,
	input wire gp, input wire pp,
	output wire gn, output wire pn);
	assign gn = gc|(pc&gp);
	assign pn = pc&pp;
endmodule

module grayCell(
	input wire gc, input wire pc, input wire gp,
	output wire gn);
	assign gn = gc|(pc&gp);
endmodule

module cpa #(
	parameter integer size = 8)(
	input [(size-1):0] A, input [(size-1):0] B,
	output [size:0] sum);
	wire [(size-1):0] carry;
	halfadder ha(A[0], B[0], sum[0], carry[0]);
	genvar i;
	generate
		for(i=1; i<size; i=i+1) begin:adder
			fulladder fa(A[i], B[i], carry[i-1], sum[i], carry[i]);
		end
	endgenerate
	assign sum[size] = carry[size-1];
endmodule

module cpaS #(
	parameter integer size = 8)(
	input [(size-1):0] A, input [(size-1):0] B,
	output [(size-1):0] sum);
	wire [(size-1):0] carry;
	halfadder ha(A[0],B[0],sum[0],carry[0]);
	genvar i;
	generate
		for(i=1;i<size;i=i+1)begin:adder
			fulladder fa(A[i],B[i],carry[i-1],sum[i],carry[i]);
		end
	endgenerate
endmodule

module csa #(
	parameter integer size = 8)(
	input [(size-1):0] A, input [(size-1):0] B, input [(size-1):0] C,
	output [(size-1):0] sum, output [(size-1):0] cout);
	genvar i;
	generate
		for(i=0; i<size; i=i+1) begin:adder
			fulladder fa(A[i], B[i], C[i], sum[i], cout[i]);
		end
	endgenerate
endmodule

module halfcsa #(
	parameter integer size = 8)(
	input [(size-1):0] A, input [(size-1):0] B,
	output [(size-1):0] sum, output [(size-1):0] cout);
	genvar i;
	generate
		for(i=0; i<size; i=i+1) begin:adder
			halfadder ha(A[i], B[i], sum[i], cout[i]);
		end
	endgenerate
endmodule


