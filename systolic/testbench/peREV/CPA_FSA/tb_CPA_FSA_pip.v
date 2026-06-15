`timescale 1ns/1ps

module tb_CPA_FSA_pip;

	parameter integer size =16;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;

	parameter integer PIPE_WAIT =4;

	reg clk;
	reg en;
	reg  [7:0]       weight;
	reg  [7:0]       in;
	reg  [buswire:0] psum0;
	reg  [buswire:0] psum1;
	wire [7:0]       weightO;
	wire [7:0]       inO;
	wire [buswire:0] psumO0;
	wire [buswire:0] psumO1;

	CPA_FSA_pip#(.size(size)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),
		.psum0(psum0),.psum1(psum1),
		.weightO(weightO),.inO(inO),
		.psumO0(psumO0),.psumO1(psumO1));

	initial begin
		clk =1'b0;
	end

	always #5 clk =~clk;

	task apply_vector;
		input [7:0]       w;
		input [7:0]       i;
		input [buswire:0] p0;
		input [buswire:0] p1;
		integer k;
		begin
			//1) weight load
			@(negedge clk);
			en     =1'b1;
			weight =w;
			@(posedge clk);
			#1;
			$display("[%0t] LOAD WEIGHT: weight=%0d, weightO=%0d",$time,weight,weightO);
			//2) input / psum load
			@(negedge clk);
			en    =1'b0;
			in    =i;
			psum0 =p0;
			psum1 =p1;
			@(posedge clk);
			#1;
			$display("[%0t] INPUT/PSUM: in=%0d, inO=%0d, psum0=%0d, psum1=%0d",$time,in,inO,psum0,psum1);
			//3) pipeline latency wait
			for (k=0;k<PIPE_WAIT;k =k+1)begin
				@(posedge clk);
				#1;
				$display("[%0t] PIPE WAIT %0d: psumO0=%0d, psumO1=%0d",$time,k+1,psumO0,psumO1);
			end
			$display("[%0t] FINAL OUTPUT: psumO0=%0d, psumO1=%0d",$time,psumO0,psumO1);
			$display("--------------------------------------------------");
		end
	endtask
	initial begin
		$dumpfile("out1.vcd");
		$dumpvars(0, tb_CPA_FSA_pip);

		en     =1'b0;
		weight =8'd0;
		in     =8'd0;
		psum0  ={bussize{1'b0}};
		psum1  ={bussize{1'b0}};
		repeat(3) @(posedge clk);
		apply_vector(8'd3,   8'd4,   0, 0);
		apply_vector(8'd7,   8'd9,   5, 2);
		apply_vector(8'd15,  8'd2,   10, 3);
		apply_vector(8'd255, 8'd1,   0, 0);
		apply_vector(8'd8,   8'd8,   20, 20);
		repeat(10) @(posedge clk);
		$finish;
	end

endmodule