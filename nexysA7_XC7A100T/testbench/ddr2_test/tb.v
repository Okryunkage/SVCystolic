`timescale 1ns/1ps

module tbmemoryTest;
	reg boardCLK;
	
	reg buttonC;
	reg buttonT;
	reg buttonB;

	wire[2:0] LEDarr;
	wire[7:0] segSel;
	wire[6:0] seg;
	wire segDot;

	wire [15:0] ddr2_dq;
	wire [1:0]  ddr2_dqs_n;
	wire [1:0]  ddr2_dqs_p;
	wire [12:0] ddr2_addr;
	wire [2:0]  ddr2_ba;
	wire        ddr2_ras_n;
	wire        ddr2_cas_n;
	wire        ddr2_we_n;
	wire [0:0]  ddr2_ck_p;
	wire [0:0]  ddr2_ck_n;
	wire [0:0]  ddr2_cke;
	wire [0:0]  ddr2_cs_n;
	wire [1:0]  ddr2_dm;
	wire [0:0]  ddr2_odt;

	wire[1:0] ddr2_rdqs_n;

	memoryTest memTest(
		.boardCLK(boardCLK),
		.buttonC(buttonC),
		.buttonT(buttonT),
		.buttonB(buttonB),
		.LEDarr(LEDarr),
		.segSel(segSel),
		.seg(seg),
		.segDot(segDot),
		.ddr2_dq(ddr2_dq),
		.ddr2_dqs_n(ddr2_dqs_n),
		.ddr2_dqs_p(ddr2_dqs_p),
		.ddr2_addr(ddr2_addr),
		.ddr2_ba(ddr2_ba),
		.ddr2_ras_n(ddr2_ras_n),
		.ddr2_cas_n(ddr2_cas_n),
		.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),
		.ddr2_ck_n(ddr2_ck_n),
		.ddr2_cke(ddr2_cke),
		.ddr2_cs_n(ddr2_cs_n),
		.ddr2_dm(ddr2_dm),
		.ddr2_odt(ddr2_odt));
	
	ddr2_model model(
		.ck(ddr2_ck_p[0]),
		.ck_n(ddr2_ck_n[0]),
		.cke(ddr2_cke[0]),
		.cs_n(ddr2_cs_n),
		.ras_n(ddr2_ras_n),
		.cas_n(ddr2_cas_n),
		.we_n(ddr2_we_n),
		.dm_rdqs(ddr2_dm),
		.ba(ddr2_ba),
		.addr(ddr2_addr),
		.dq(ddr2_dq),
		.dqs(ddr2_dqs_p),
		.dqs_n(ddr2_dqs_n),
		.rdqs_n(ddr2_rdqs_n),
		.odt(ddr2_odt[0]));

	// Xilinx global simulation module
	glbl glbl_i();

	initial boardCLK =1'b0;
	always #5 boardCLK =~boardCLK;

	task pressReset;
	begin
		buttonC =1'b1;
		repeat(20)@(posedge boardCLK);
		buttonC =1'b0;
	end
	endtask

	task pressWrite;
	begin
		buttonT =1'b1;
		repeat(20)@(posedge boardCLK);
		buttonT =1'b0;
	end
	endtask

	task pressRead;
	begin
		buttonB =1'b1;
		repeat(20)@(posedge boardCLK);
		buttonB =1'b0;
	end
	endtask

	localparam CLKperiod =10;
	localparam readyTimeoutCycles =100_000;
	localparam extraCycles =200;
	localparam transactionTimoutCycles =50_000;

	task waitready;
		integer cnt;
	begin
		cnt =0;
		while((memTest.migT.mem_rdy !==1'b1)&&(cnt<readyTimeoutCycles))begin
			@(posedge boardCLK);
			cnt =cnt+1;
		end
		if(memTest.migT.mem_rdy !==1'b1)begin
			$display("[%0t] ERROR: memTest.migT.mem_rdy timeout", $time);
			$display("[%0t] init_calib_complete=%b", $time, memTest.migT.mem_rdy);
			$stop;
		end
		else begin
			$display("[%0t] memTest.migT.mem_rdy asserted after %0d cycles (~%0t)",$time, cnt, cnt*CLKperiod);
			repeat (extraCycles)@(posedge boardCLK);
		end
	end
	endtask
	/*
	task waitTransactionRise;
		integer cnt;
	begin
		cnt =0;
		while ((memTest.transactionComplete !==1'b1)&&(cnt <transactionTimoutCycles))begin
			@(posedge boardCLK);
			cnt =cnt+1;
		end
		if(memTest.transactionComplete !==1'b0)begin
			$display("[%0t] ERROR: transactionComplete fall timeout", $time);
			$stop;
		end
	end
	endtask
	*/
	initial begin
		buttonC =1'b0;
		buttonT =1'b0;
		buttonB =1'b0;

        $display("====================================================");
		$display(" Start simulation");
		$display("====================================================");
		repeat(50)@(posedge boardCLK);

		$display("[%0t] reset pulse", $time);
		pressReset();
		//$display("[%0t] waiting for memTest.ready...", $time);
		//wait (memTest.ready == 1'b1);
		$display("[%0t] Waiting for MIG ready/calibration...", $time);
		waitready();
		$display("[%0t] Calibration done", $time);
		repeat(50)@(posedge boardCLK);
		$display("[%0t] write pulse", $time);
		pressWrite();
		//wait (memTest.transactionComplete == 1'b1);
		$display("[%0t] write transaction complete", $time);
		repeat(100)@(posedge boardCLK);
		$display("[%0t] read pulse", $time);
		pressRead();
		//wait (memTest.transactionComplete == 1'b1);
		@(posedge boardCLK);
		$display("[%0t] read transaction complete", $time);
		$display("[%0t] memTest.dataOut    = %h", $time, memTest.dataOut);

		$display("====================================================");
		$display(" Finish simulation");
		$display("====================================================");
		$finish;
	end
	initial begin
		forever begin
			@(posedge boardCLK);
			if(memTest.transactionComplete)begin
				$display("[%0t] transactionComplete=1, dataOut=%h",$time, memTest.dataOut);
			end
		end
	end
endmodule