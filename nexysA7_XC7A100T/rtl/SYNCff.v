`timescale 1ns/1ps

module SYNCff#(
	parameter width=1)(
		clk, rst,
		in, out);
		input clk, rst;
		input[(width-1):0] in;
		output reg[(width-1):0] out;
		// Marks this register as part of an asynchronous synchronizer chain.
		// This helps the synthesis/place-and-route tool preserve the register
		// and place it appropriately to improve metastability robustness.
		//(* ASYNC_REG = "TRUE" *) reg[(width-1):0] SYNCreg;
		reg[(width-1):0] SYNCreg;
		always@(posedge clk or posedge rst)begin
			if(rst)begin
				SYNCreg <=0;
				out <=0;
			end
			else {out,SYNCreg} <={SYNCreg,in};
		end
endmodule