`timescale 1ns/1ps

module tb_B_SA;
	parameter integer size =16;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;

	reg clk; 
	reg en;
	reg  [7:0]       weight;
	reg  [7:0]       in;
	reg  [buswire:0] psum;
	wire [7:0]       weightO;
	wire [7:0]       inO;
	wire [buswire:0] psumO;

	B_SA #(.size(size)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),
		.psum(psum),
		.weightO(weightO),.inO(inO),
		.psumO(psumO));

	reg[buswire:0] sumMod;
	integer signedSum;
	always@(*)begin
		sumMod =psumO;
		if(sumMod[buswire]==1'b1) signedSum =sumMod-(1<<bussize);
		else signedSum =sumMod;
	end

	initial begin
		clk =1'b0;
	end
	always #5 clk =~clk;

	task applyVector;
		input[7:0] w,i;
		input[buswire:0] p;begin
			@(negedge clk);
			en =1'b1;
			weight =w;

			@(posedge clk);
			#1;
			$display("[%0t] LOAD WEIGHT: weight=%0d, weightO=%0d",$time,$signed(weight),$signed(weightO));

			@(negedge clk);
			en =1'b0;
			in =i;
			psum =p;

			@(posedge clk);
			#1;
			$display("[%0t] LOAD INPUT : input=%0d, inputO=%0d, psum=%0d",
				$time,$signed(in),$signed(inO),psum);

			@(posedge clk);
			#2;
			//$display("[%0t] OUTPUT: weight=%0d, input=%0d, psum=%0d",
			//	$time,$signed(weightO),$signed(inO),psum,sumMod,$signed(signedSum));
			$display("%0d X %0d + %0d = %0d",$signed(in),$signed(weight),$signed(psum),$signed(signedSum));
			$display("--------------------------------------------------");
		end
	endtask

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_B_SA);

		en =1'b0;
		weight =8'd0;
		in =8'd0;
		psum ={bussize{1'b0}};

		repeat(2) @(posedge clk);

		applyVector(8'd3,   8'd4,   0);
		applyVector(8'd7,   8'd9,   7);
		applyVector(8'd15,  8'd2,   13);
		applyVector(8'd255, 8'd1,   0);
		applyVector(8'd8,   8'd8,   40);

		repeat(5) @(posedge clk);
		$finish;
	end
endmodule