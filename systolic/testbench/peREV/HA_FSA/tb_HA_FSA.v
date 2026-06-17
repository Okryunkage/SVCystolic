`timescale 1ns/1ps

module tb_HA_FSA;
	parameter integer size =16;
	parameter integer k    =4;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	parameter integer PIPE_WAIT =1;

	reg clk;
	reg en;
	reg  [7:0]       in;
	reg  [7:0]       weight;
	reg  [(buswire-k):0] psum0;
	reg  [buswire:0]     psum1;
	wire [7:0]       inO;
	wire [7:0]       weightO;
	wire [(buswire-k):0] psumO0;
	wire [buswire:0]     psumO1;

	integer i;
	integer err;
	integer seed;

	HA_FSA#(.size(size),.k(k)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),.psum0(psum0),.psum1(psum1),
		.weightO(weightO),.inO(inO),.psumO0(psumO0),.psumO1(psumO1));

	initial begin
		clk =0;
		forever #5 clk =~clk;
	end

	task exp_calc;
		input  [15:0] r0;
		input  [15:0] r1;
		input  [(buswire-k):0] p0;
		input  [buswire:0]     p1;
		output [(buswire-k):0] exp0;
		output [buswire:0]     exp1;

		reg [buswire:0] psumS;
		reg [buswire:0] psumC;
		reg [(buswire-k):0] coutW;
		reg [k:0] low_add;
		reg abit;
		reg bbit;
		reg cbit;
		integer j;
	begin
		psumS =0;
		psumC =0;
		coutW =0;
		exp0  =0;
		exp1  =0;

		for(j=0;j<17;j=j+1)begin
			if(j==16)begin
				abit = ~r0[15];
				bbit = ~r1[15];
			end
			else begin
				abit = r0[j];
				bbit = r1[j];
			end

			cbit = p1[j];

			psumS[j] = abit ^ bbit ^ cbit;
			psumC[j] = (abit&bbit) | (abit&cbit) | (bbit&cbit);
		end

		for(j=17;j<bussize;j=j+1)begin
			psumS[j] = 1'b1 ^ p1[j];
			psumC[j] = 1'b1 & p1[j];
		end

		low_add = {1'b0,psumS[(k-1):0]} + {1'b0,psumC[(k-2):0],1'b0};

		exp1[(k-1):0] = low_add[(k-1):0];
		exp0[0]       = low_add[k];

		for(j=0;j<(bussize-k);j=j+1)begin
			abit = p0[j];
			bbit = psumC[(k-1)+j];
			cbit = psumS[k+j];

			exp1[k+j] = abit ^ bbit ^ cbit;
			coutW[j] = (abit&bbit) | (abit&cbit) | (bbit&cbit);
		end

		exp0[(buswire-k):1] = coutW[(buswire-k-1):0];
	end
	endtask

	task check_one;
		input [7:0]  weight_t;
		input [7:0]  in_t;
		input [(buswire-k):0] psum0_t;
		input [buswire:0]     psum1_t;

		reg [(buswire-k):0] exp0;
		reg [buswire:0]     exp1;
	begin
		@(negedge clk);
		en     =1'b1;
		weight =weight_t;

		@(posedge clk);
		#1;

		if(weightO !== weight_t)begin
			$display("WEIGHT ERROR time=%0t weight=%h weightO=%h",$time,weight_t,weightO);
			err =err+1;
		end

		@(negedge clk);
		en    =1'b0;
		in    =in_t;
		psum0 =psum0_t;
		psum1 =psum1_t;

		repeat(PIPE_WAIT) @(posedge clk);
		#1;

		exp_calc(dut.result0,dut.result1,psum0_t,psum1_t,exp0,exp1);

		if(inO !== in_t)begin
			$display("IN ERROR time=%0t in=%h inO=%h",$time,in_t,inO);
			err =err+1;
		end

		if((psumO0 !== exp0) || (psumO1 !== exp1))begin
			$display("PSUM ERROR time=%0t",$time);
			$display(" weight=%h in=%h result0=%h result1=%h",weight_t,in_t,dut.result0,dut.result1);
			$display(" psum0=%h psum1=%h",psum0_t,psum1_t);
			$display(" psumO0=%h exp0=%h",psumO0,exp0);
			$display(" psumO1=%h exp1=%h",psumO1,exp1);
			err =err+1;
		end
	end
	endtask

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_HA_FSA);

		err  =0;
		seed =32'h1234abcd;

		en     =0;
		weight =0;
		in     =0;
		psum0  =0;
		psum1  =0;

		repeat(2) @(posedge clk);

		check_one(8'h00,8'h00,{(bussize-k){1'b0}},{bussize{1'b0}});
		check_one(8'hff,8'hff,{(bussize-k){1'b1}},{bussize{1'b1}});
		check_one(8'h55,8'h55,{(bussize-k){1'b0}},{bussize{1'b1}});
		check_one(8'haa,8'haa,{(bussize-k){1'b1}},{bussize{1'b0}});

		for(i=0;i<100;i=i+1)begin
			check_one($random(seed),$random(seed),$random(seed),$random(seed));
		end

		if(err==0)begin
			$display("========================================");
			$display(" HA_FSA TEST PASS");
			$display("========================================");
		end
		else begin
			$display("========================================");
			$display(" HA_FSA TEST FAIL : err=%0d",err);
			$display("========================================");
		end

		$finish;
	end

endmodule