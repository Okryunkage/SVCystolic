`timescale 1ns/1ps

module memoryTest(
	input wire boardCLK,
	input wire buttonC,
	input wire buttonT,
	input wire buttonB,
	
	output reg[2:0] LEDarr,

	output wire[7:0] segSel,
	output wire[6:0] seg,
	output wire      segDot,

	inout[15:0]  ddr2_dq,
	inout[1:0]   ddr2_dqs_n,
	inout[1:0]   ddr2_dqs_p,
	output[12:0] ddr2_addr,
	output[2:0]  ddr2_ba,
	output       ddr2_ras_n,
	output       ddr2_cas_n,
	output       ddr2_we_n,
	output[0:0]  ddr2_ck_p,
	output[0:0]  ddr2_ck_n,
	output[0:0]  ddr2_cke,
	output[0:0]  ddr2_cs_n,
	output[1:0]  ddr2_dm,
	output[0:0]  ddr2_odt
);
	/*
	##############################
	##       Signal  Sync       ##
	##############################
	*/
	wire resetSYNC0;
	//wire resetSYNC1;
	SYNCff#(1) resetBuff(boardCLK,{1'b0},buttonC,resetSYNC0);
	//SYNCpulse resetPulse(boardCLK,{1'b0},resetSYNC0,resetSYNC1);
	wire write0, write1;
	SYNCff#(1) writeStart(boardCLK,{1'b0},buttonT,write0);
	SYNCpulse  writePulse(boardCLK,{1'b0},write0,write1);
	wire read0, read1;
	SYNCff#(1) readStart(boardCLK,{1'b0},buttonB,read0);
	SYNCpulse  readPulse(boardCLK,{1'b0},read0,read1);

	/*
	##############################
	##        Clock  Gen        ##
	##############################
	*/
	wire clk200, locked, segCLK;
	mmcm200 clkmmcm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(clk200));
	tickgen #(.CLK(100_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(boardCLK,{1'b0},segCLK);

	/*
	##############################
	##       MIG Instance       ##
	##############################
	*/
	wire[63:0] dataOut;
	wire transactionComplete, ready;
	mig_ui migT(
		.migclk(clk200),
		.rst_n(~resetSYNC0),
		.boardclk(boardCLK),
		.addr(28'b0000_0000_0000_0000_00000_0000_0000),
		.width(2'd0),
		.data_in(64'h31_32_33_34_35_36_37_38),
		.data_out(dataOut),
		.rstrobe(read1),
		.wstrobe(write1),
		.transaction_complete(transactionComplete),
		.ready(ready),
        
		.ddr2_dq(ddr2_dq),.ddr2_dqs_n(ddr2_dqs_n),.ddr2_dqs_p(ddr2_dqs_p),.ddr2_addr(ddr2_addr),.ddr2_ba(ddr2_ba),
		.ddr2_ras_n(ddr2_ras_n),.ddr2_cas_n(ddr2_cas_n),.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),.ddr2_ck_n(ddr2_ck_n),.ddr2_cke(ddr2_cke),
		.ddr2_cs_n(ddr2_cs_n),.ddr2_dm(ddr2_dm),.ddr2_odt(ddr2_odt));

	/*
	##############################
	##      UI Data Receive     ##
	##############################
	*/
	reg[63:0] dataOutSeg;
	always@(posedge boardCLK)begin
		if(transactionComplete) dataOutSeg <=dataOut;
	end

	/*
	##############################
	##       Status Output      ##
	##############################
	*/
	always@(posedge segCLK)begin
		LEDarr[0] <=~resetSYNC0;
		LEDarr[1] <=read1;
		LEDarr[2] <=write1;
	end
	seg8Ascii ascii(boardCLK,{1'b0},segCLK,dataOutSeg,segSel,seg,segDot);

endmodule