`timescale 1ns/1ps

module tb_CPA_FSA_pip0;
	parameter integer size =16;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
	parameter integer PIPE_WAIT =1;

	reg clk;
	reg en;
	reg  [7:0]       weight;
	reg  [7:0]       in;
	wire [7:0]       weightO;
	wire [7:0]       inO;
	wire [buswire:0] psumO0;
	wire [buswire:0] psumO1;

	CPA_FSA_pip0#(.size(size)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),
		.weightO(weightO),.inO(inO),
		.psumO0(psumO0),.psumO1(psumO1));

	initial begin
		clk =1'b0;
	end
	always #5 clk =~clk;

	reg[16:0] sumExt16;
	reg[15:0] sumMod16;
	integer signedSum;
	always@(*)begin
		sumExt16 ={1'b0,psumO0[15:0]}+{1'b0,psumO1[15:0]};
		sumMod16 =sumExt16[15:0];
		if(sumMod16[15]==1'b1) signedSum =sumMod16-(1<<16);
		else                   signedSum =sumMod16;
	end

	task applyVector;
		input [7:0] w;
		input [7:0] i;
		integer k;
		begin
			//1) weight load
			@(negedge clk);
			en     =1'b1;
			weight =w;
			@(posedge clk);
			#1;
			$display("[%0t] LOAD WEIGHT: weight=%0d, weightO=%0d",$time,weight,weightO);
			//2) input load
			@(negedge clk);
			en    =1'b0;
			in    =i;
			@(posedge clk);
			#1;
			$display("[%0t] INPUT/PSUM: in=%0d, inO=%0d",$time,in,inO);
			//3) pipeline latency wait
			for (k=0;k<PIPE_WAIT;k =k+1)begin
				@(posedge clk);
				#1;
				$display("[%0t] PIPE WAIT %0d: psumO0=%0d, psumO1=%0d",$time,k+1,psumO0,psumO1);
			end
			$display("[%0t] FINAL OUTPUT: psumO0=%0d, psumO1=%0d",$time,psumO0,psumO1);
			$display("%0d X %0d = %0d",$signed(in),$signed(weight),$signed(signedSum));
			$display("--------------------------------------------------");
		end
	endtask
	initial begin
		$dumpfile("out2.vcd");
		$dumpvars(0, tb_CPA_FSA_pip0);

		en     =1'b0;
		weight =8'd0;
		in     =8'd0;
		repeat(3) @(posedge clk);
		applyVector(8'd3,   8'd4);
		applyVector(8'd7,   8'd9);
		applyVector(8'd15,  8'd2);
		applyVector(8'd255, 8'd1);
		applyVector(8'd8,   8'd8);
		repeat(10) @(posedge clk);
		$finish;
	end

endmodule