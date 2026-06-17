`timescale 1ns/1ps

module tb_C_SA_pip;
	parameter integer size =16;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	parameter integer PIPE_WAIT =2;

	reg clk;
	reg en;
	reg  [7:0]       weight;
	reg  [7:0]       in;
	reg  [buswire:0] psum;
	wire [7:0]       weightO;
	wire [7:0]       inO;
	wire [buswire:0] psumO;

	C_SA_pip#(.size(size)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),
		.psum(psum),
		.weightO(weightO),.inO(inO),
		.psumO(psumO));

	initial begin
		clk =1'b0;
	end
	always #5 clk =~clk;

	reg[buswire:0] sumMod;
	integer signedSum;
	always@(*)begin
		sumMod =psumO;
		if(sumMod[buswire]==1'b1) signedSum =sumMod-(1<<bussize);
		else signedSum =sumMod;
	end

	task applyVector;
		input [7:0]       w;
		input [7:0]       i;
		input [buswire:0] p;
		integer k;
		begin
			//1) weight load
			@(negedge clk);
			en     =1'b1;
			weight =w;
			@(posedge clk);
			#1;
			$display("[%0t] LOAD WEIGHT: weight=%0d, weightO=%0d",$time,$signed(weight),$signed(weightO));
			//2) input / psum load
			@(negedge clk);
			en   =1'b0;
			in   =i;
			psum =p;
			@(posedge clk);
			#1;
			$display("[%0t] INPUT/PSUM: in=%0d, inO=%0d, psum=%0d",$time,$signed(in),$signed(inO),$signed(psum));
			//3) pipeline latency wait
			for (k=0;k<PIPE_WAIT;k =k+1)begin
				@(posedge clk);
				#1;
				$display("[%0t] PIPE WAIT %0d: psumO=%0d",$time,k+1,psumO);
			end
			$display("[%0t] FINAL OUTPUT: psumO=%0d",$time,psumO);
			$display("%0d X %0d + %0d = %0d",$signed(in),$signed(weight),$signed(psum),$signed(signedSum));
			$display("--------------------------------------------------");
		end
	endtask
	initial begin
		$dumpfile("out1.vcd");
		$dumpvars(0, tb_C_SA_pip);

		en     =1'b0;
		weight =8'd0;
		in     =8'd0;
		psum   ={bussize{1'b0}};
		repeat(3) @(posedge clk);
		applyVector(8'd3,   8'd4,   0);
		applyVector(8'd7,   8'd9,   7);
		applyVector(8'd15,  8'd2,   13);
		applyVector(8'd255, 8'd1,   0);
		applyVector(8'd8,   8'd8,   40);
		repeat(10) @(posedge clk);
		$finish;
	end

endmodule