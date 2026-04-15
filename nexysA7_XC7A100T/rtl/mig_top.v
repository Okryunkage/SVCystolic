//will be updated soon
`timescale 1ns/1ps

module migTop(
	input wire boardCLK,

	inout[15:0]  ddr2_dq,
	inout[1:0]   ddr2_dqs_n,
	inout[1:0]   ddr2_dqs_p,
	output[12:0] ddr2_addr,
	output[2:0] ddr2_ba,
	output ddr2_ras_n,
	output ddr2_cas_n,
	output ddr2_we_n,
	output[0:0] ddr2_ck_p,
	output[0:0] ddr2_ck_n,
	output[0:0] ddr2_cke,
	output[0:0] ddr2_cs_n,
	output[1:0] ddr2_dm,
	output[0:0] ddr2_odt
);
	wire resetSYNC0;
	SYNCff#(1) resetBuff(boardCLK,{1'b0},buttonC,resetSYNC);

	wire write0, write1;
	SYNCff#(1) writeStart(boardCLK,{1'b0},buttonT,write0);
	SYNCpulse  writePulse(boardCLK,{1'b0},write0,write1);

	wire read0, read1;
	SYNCff#(1) readStart(boardCLK,{1'b0},buttonB,read0);
	SYNCpulse  readPulse(boardCLK,{1'b0},read0,read1);
	
	wire transmit0, transmit1;
	SYNCff#(1) transmitStart(boardCLK,{1'b0},buttonL,transmit0);
	SYNCpulse  transmitPulse(boardCLK,{1'b0},transmit0,transmit1);