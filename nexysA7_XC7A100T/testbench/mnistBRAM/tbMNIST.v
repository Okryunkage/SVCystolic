`include "pseudoBRAM.v"
`include "MNISTbram.v"
`include "fc1BRAM.v"
`include "fc2BRAM.v"
`include "sign.v"
`include "relu.v"
`include "argmax.v"
`include "requantize.v"
`include "mnistTOPbram.v"
`timescale 1ns/1ps

module tb_mnistTOPbram;
	localparam integer inNum     =784;
	localparam integer hidNum    =64;
	localparam integer outNum    =10;
	localparam integer inWidth   =8;
	localparam integer acc1Width =32;
	localparam integer a1Width   =8;
	localparam integer outWidth  =32;
	localparam integer clkPeriod =10;
	localparam integer maxCycles =200_000;

	reg clk;
	reg rst;
	reg start;

	reg[(inNum*inWidth-1):0] imgFlat;

	wire busy;
	wire done;
	wire[3:0] predDigit;

	reg[7:0] sampleMem[0:(inNum-1)];

	integer i;
	integer failCount;
	integer cycleCount;
	integer expectedLabelINT;

	reg[3:0] expectedLabel;

	initial begin
		expectedLabelINT =0;
		if($value$plusargs("EXPECTED_LABEL=%d",expectedLabelINT)) expectedLabel =expectedLabelINT[3:0];
		else expectedLabel =4'b0;
		$display("EXPECTED_LABEL =%0d", expectedLabel);
	end

	initial begin
		clk =1'b0;
		forever #(clkPeriod/2) clk =~clk;
	end

	mnistTOPbram dut(.clk(clk),.rst(rst),.start(start),.imgFlat(imgFlat),.busy(busy),.done(done),.predDigit(predDigit));

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_mnistTOPbram);
	end

	task print_input_head;
		integer k;
		begin
			$write("imgFlat[0:31] =[");
			for(k=0;k<32;k=k+1)begin
				$write("%0d",imgFlat[(k*inWidth)+:inWidth]);
				if(k!=31) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_acc1;
		integer k;
		begin
			$write("acc1Flat =[");
			for(k=0;k<hidNum;k=k+1)begin
				$write("%0d",$signed(dut.acc1Flat[(k*acc1Width)+:acc1Width]));
				if(k!=hidNum-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_relu1;
		integer k;
		begin
			$write("relu1Flat = [");
			for(k=0;k<hidNum;k=k+1)begin
				$write("%0d",$signed(dut.relu1Flat[(k*acc1Width)+:acc1Width]));
				if(k !=hidNum-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_act1;
		integer k;
		begin
			$write("act1Flat = [");
			for(k=0; k<hidNum; k=k+1)begin
				$write("%0d",dut.act1Flat[(k*a1Width)+:a1Width]);
				if(k !=hidNum-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_acc2;
		integer k;
		begin
			$write("acc2Flat = [");
			for(k=0;k<outNum;k=k+1) begin
				$write("%0d",$signed(dut.acc2Flat[(k*outWidth)+:outWidth]));
				if(k !=outNum-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_case_debug;
		begin
			$display("--------------------------------------------------");
			$display("DEBUG CASE");
			$display("predDigit      = %0d",predDigit);
			$display("EXPECTED_LABEL = %0d",expectedLabel);
			print_input_head();
			print_acc1();
			print_relu1();
			print_act1();
			print_acc2();
			$display("--------------------------------------------------");
		end
	endtask

	task pulse_start;
	//Since DUT samples start signal at posedge clk,
	//start pulse rise at negedge clk
		begin
			@(negedge clk);
			start =1'b1;
			@(negedge clk);
			start =1'b0;
		end
	endtask

	task wait_done_or_timeout;
		begin
			cycleCount =0;
			while((done !==1'b1)&&(cycleCount<maxCycles))begin
				@(posedge clk);
				#1;
				cycleCount =cycleCount+1;
			end
			if(done!==1'b1)begin
				$display("ERROR: timeout waiting for done");
				$display("cycleCount = %0d", cycleCount);
				$finish;
			end
			else $display("done asserted after %0d cycles", cycleCount);
		end
	endtask

	initial begin
		failCount =0;
		start     =1'b0;
		rst       =1'b1;
		imgFlat   ={(inNum*inWidth){1'b0}};

		for(i=0;i<inNum;i=i+1) sampleMem[i] =8'd0;
		$readmemh("mnist_sample.mem", sampleMem);
		for(i=0;i<inNum;i=i+1) imgFlat[(i*inWidth)+:inWidth] =sampleMem[i];
		repeat(5) @(posedge clk);
		rst =1'b0;
		repeat(2) @(posedge clk);
		$display("Start inference");
		print_input_head();
		pulse_start();
		wait_done_or_timeout();
		
		@(posedge clk);
		#1;

		if(predDigit!==expectedLabel)begin
			failCount =failCount+1;
			$display("FAIL:pred=%0d expected=%0d",predDigit,expectedLabel);
			print_case_debug();
		end
		else begin
			$display("PASS:pred=%0d expected=%0d",predDigit,expectedLabel);
		end

		$display("========================================");
		$display("TEST DONE");
		$display("FAIL = %0d", failCount);
		$display("========================================");

		$finish;
	end
endmodule