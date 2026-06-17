`timescale 1ns/1ps

module tb_CPA_FSA;
	parameter integer size =16;
	localparam integer bussize =$clog2(size)+16;
	localparam integer buswire =bussize-1;
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
	CPA_FSA #(.size(size)) dut(
		.clk(clk),.en(en),
		.weight(weight),.in(in),
		.psum0(psum0),.psum1(psum1),
		.weightO(weightO),.inO(inO),
		.psumO0(psumO0),.psumO1(psumO1));

	reg[bussize:0] sumExt;
	reg[buswire:0] sumMod;
	integer signedSum;
	always@(*)begin
		sumExt =psumO0+psumO1;
		sumMod =sumExt[buswire:0];
		if(sumMod[buswire]==1'b1) signedSum =sumMod-(1<<bussize);
		else signedSum =sumMod;
	end

	initial begin
		clk =1'b0;
	end
	always #5 clk =~clk;

	task applyVector;
		input[7:0] w,i;
		input[buswire:0] p0,p1;begin
			@(negedge clk);
			en =1'b1;
			weight =w;
			@(posedge clk);
			#1;
			$display("[%0t] LOAD WEIGHT: weight=%0d, weightO=%0d",$time,weight,weightO);
			@(negedge clk);
			en =1'b0;
			in =i;
			psum0 =p0;
			psum1 =p1;
			@(posedge clk);
			#2;
			$display("[%0t] OUTPUT: weight=%0d, input=%0d, usignSUM=%0d, signSUM=%0d",$time,$signed(weight),$signed(in),sumMod,$signed(signedSum));
		end
	endtask

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_CPA_FSA);
		en =1'b0;
		weight =8'd0;
		in =8'd0;
		psum0 ={bussize{1'b0}};
		psum1 ={bussize{1'b0}};
		repeat(2) @(posedge clk);
		applyVector(8'd3,   8'd4,   0, 0);
		applyVector(8'd7,   8'd9,   5, 2);
		applyVector(8'd15,  8'd2,   10, 3);
		applyVector(8'd255, 8'd1,   0, 0);
		applyVector(8'd8,   8'd8,   20, 20);
		repeat(5) @(posedge clk);
		$finish;
	end
endmodule
