`timescale 1ns/1ps

module test0#(
	parameter ADDRwidth =27,
	parameter [ADDRwidth-1:0] RESETbaseADDR ={ADDRwidth{1'b0}},
	parameter [ADDRwidth-1:0] ADDRstride    =27'd8,
	parameter [7:0] SOF0            =8'hAA,
	parameter [7:0] SOF1            =8'h55,
	parameter [7:0] versionEXP      =8'd1,
	parameter [7:0] PACKETimg       =8'h01,
	parameter [7:0] PACKETparam     =8'h02,
	parameter [7:0] PACKETparamW    =8'h00,
	parameter [7:0] PACKETparamB    =8'h01,
	parameter [7:0] incLABELmask    =8'h01,
	parameter [7:0] paramSIGNEDmask =8'h01)(
	input  wire         boardCLK,
	input  wire         rst,
	input  wire         UARTRX,
	output wire         UARTTX,
	//Simple debug output.
	output wire [15:0]  LEDarr,
	//DDR2 physical interface.
	inout  wire [15:0]  ddr2_dq,
	inout  wire [1:0]   ddr2_dqs_n,
	inout  wire [1:0]   ddr2_dqs_p,
	output wire [12:0]  ddr2_addr,
	output wire [2:0]   ddr2_ba,
	output wire         ddr2_ras_n,
	output wire         ddr2_cas_n,
	output wire         ddr2_we_n,
	output wire [0:0]   ddr2_ck_p,
	output wire [0:0]   ddr2_ck_n,
	output wire [0:0]   ddr2_cke,
	output wire [0:0]   ddr2_cs_n,
	output wire [1:0]   ddr2_dm,
	output wire [0:0]   ddr2_odt);

	wire migclk,locked;
	mmcm200 clkmmcm(.reset(rst),.clk_in1(boardCLK),.locked(locked),.clk_out1(migclk));
	wire rst_n =(~rst)&locked;
	wire rxDone;
	wire [7:0] rxData;
	uartTOP#(.boardCLK(100_000_000),.oversample(20),.baudrate(1_000_000),.ACCwidth(24))
		UART0(.clk(boardCLK),.rst(rst),
			.uartRX(UARTTX),.uartTX(UARTRX),
			.TXstart(1'b0),.TXitem(8'd0),.TXdone(),.TXbusy(),
			.RXout(rxData),.RXdone(rxDone),.RXbusy(),.RXerror());
	//########################################
	//##          upDEC  outputs            ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [5:0]  statusFlags;
	(* MARK_DEBUG ="TRUE" *) wire [55:0] headerInfo;
	(* MARK_DEBUG ="TRUE" *) wire [63:0] imageInfo;
	(* MARK_DEBUG ="TRUE" *) wire [63:0] paramInfo;
	(* MARK_DEBUG ="TRUE" *) wire [39:0] payloadInfo;
	(* MARK_DEBUG ="TRUE" *) wire [4:0]  payloadFlags;
	(* MARK_DEBUG ="TRUE" *) wire [15:0] checksumInfo;
	(* MARK_DEBUG ="TRUE" *) wire        decBusy;
	wire decHeaderValid   =statusFlags[0];
	wire decPayloadValid  =statusFlags[1];
	wire decPacketDone    =statusFlags[2];
	wire decPacketError   =statusFlags[3];
	wire decChecksumError =statusFlags[4];
	wire decHeaderError   =statusFlags[5];
	//########################################
	//## ddrPackW128 <-> mig_ui128 signals  ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] ddrAddr;
	(* MARK_DEBUG ="TRUE" *) wire [127:0]         ddrData;
	(* MARK_DEBUG ="TRUE" *) wire                 ddrWstrobe;
	(* MARK_DEBUG ="TRUE" *) wire                 migReady;
	(* MARK_DEBUG ="TRUE" *) wire                 migTranComp;
	(* MARK_DEBUG ="TRUE" *) wire [127:0]         migDataOut;
	// Write-only test top for now.
	wire ddrRstrobe =1'b0;
	//########################################
	//##        ddrPackW128  outputs        ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] allocPtr;
	(* MARK_DEBUG ="TRUE" *) wire                 writeDone;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] pStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] pLastAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] pNextAddr;
	(* MARK_DEBUG ="TRUE" *) wire                 pLastAddrValid;
	(* MARK_DEBUG ="TRUE" *) wire [143:0]         wMetaInfo;
	(* MARK_DEBUG ="TRUE" *) wire [31:0]          wPayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0]          wWordCount;
	(* MARK_DEBUG ="TRUE" *) wire [3:0]           writerErrorFlags;
	(* MARK_DEBUG ="TRUE" *) wire                 writerBusy;
	//########################################
	//##        Address book outputs        ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0]   nextFreeAddr;
	(* MARK_DEBUG ="TRUE" *) wire [5:0]             bookValidFlags;
	(* MARK_DEBUG ="TRUE" *) wire [6*ADDRwidth-1:0] startADDRbook;
	(* MARK_DEBUG ="TRUE" *) wire [6*32-1:0]        payloadBytesBook;
	(* MARK_DEBUG ="TRUE" *) wire [2:0]             bookErrorFlags;
	localparam integer SLOTimage =0;
	localparam integer SLOTlabel =1;
	localparam integer SLOTfc1W  =2;
	localparam integer SLOTfc1B  =3;
	localparam integer SLOTfc2W  =4;
	localparam integer SLOTfc2B  =5;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] imageStartAddr     =startADDRbook[SLOTimage*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] labelStartAddr     =startADDRbook[SLOTlabel*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc1WeightStartAddr =startADDRbook[SLOTfc1W*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc1BiasStartAddr   =startADDRbook[SLOTfc1B*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc2WeightStartAddr =startADDRbook[SLOTfc2W*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc2BiasStartAddr   =startADDRbook[SLOTfc2B*ADDRwidth +: ADDRwidth];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] imagePayloadBytes     =payloadBytesBook[SLOTimage*32 +: 32];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] labelPayloadBytes     =payloadBytesBook[SLOTlabel*32 +: 32];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc1WeightPayloadBytes =payloadBytesBook[SLOTfc1W*32 +: 32];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc1BiasPayloadBytes   =payloadBytesBook[SLOTfc1B*32 +: 32];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc2WeightPayloadBytes =payloadBytesBook[SLOTfc2W*32 +: 32];
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc2BiasPayloadBytes   =payloadBytesBook[SLOTfc2B*32 +: 32];

	upDEC#(
		.SOF0(SOF0),
		.SOF1(SOF1),
		.versionEXP(versionEXP),
		.PACKETimg(PACKETimg),
		.PACKETparam(PACKETparam),
		.PACKETparamW(PACKETparamW),
		.PACKETparamB(PACKETparamB),
		.incLABELmask(incLABELmask),
		.paramSIGNEDmask(paramSIGNEDmask),
		.payloadLENcheck(1))
		u_upDEC(
		.clk(boardCLK),.rst(rst),
		.rxDone(rxDone),.rxData(rxData),
		.statusFlags(statusFlags),
		.headerInfo(headerInfo),
		.imageInfo(imageInfo),
		.paramInfo(paramInfo),
		.payloadInfo(payloadInfo),
		.payloadFlags(payloadFlags),
		.checksumInfo(checksumInfo),
		.busy(decBusy));

	ddrPackW#(
		.ADDRwidth(ADDRwidth),
		.ADDRstride(ADDRstride),
		.PACKETimg(PACKETimg),
		.PACKETparam(PACKETparam),
		.PACKETparamW(PACKETparamW),
		.PACKETparamB(PACKETparamB))
		u_ddrPackW128(
		.clk(boardCLK),
		.rst(rst),
		.baseAddrLoad(1'b0),
		.baseAddrValue(RESETbaseADDR),
		.statusFlags(statusFlags),
		.headerInfo(headerInfo),
		.imageInfo(imageInfo),
		.paramInfo(paramInfo),
		.payloadInfo(payloadInfo),
		.payloadFlags(payloadFlags),
		.ddrAddr(ddrAddr),
		.ddrData(ddrData),
		.ddrWstrobe(ddrWstrobe),
		.ddrReady(migReady),
		.ddrTranComp(migTranComp),
		.allocPtr(allocPtr),
		.writeDone(writeDone),
		.pStartAddr(pStartAddr),
		.pLastAddr(pLastAddr),
		.pNextAddr(pNextAddr),
		.pLastAddrValid(pLastAddrValid),
		.wMetaInfo(wMetaInfo),
		.wPayloadBytes(wPayloadBytes),
		.wWordCount(wWordCount),
		.writerErrorFlags(writerErrorFlags),
		.busy(writerBusy));

	mig_ui128 u_mig_ui128(
		.migclk(migclk),.rst_n(rst_n),
		.boardclk(boardCLK),
		.addr(ddrAddr),.data_in(ddrData),.data_out(migDataOut),
		.rstrobe(ddrRstrobe),.wstrobe(ddrWstrobe),
		.transaction_complete(migTranComp),.ready(migReady),
		.ddr2_dq(ddr2_dq),.ddr2_dqs_n(ddr2_dqs_n),.ddr2_dqs_p(ddr2_dqs_p),.ddr2_addr(ddr2_addr),
		.ddr2_ba(ddr2_ba),.ddr2_ras_n(ddr2_ras_n),.ddr2_cas_n(ddr2_cas_n),.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),.ddr2_ck_n(ddr2_ck_n),.ddr2_cke(ddr2_cke),.ddr2_cs_n(ddr2_cs_n),
		.ddr2_dm(ddr2_dm),.ddr2_odt(ddr2_odt));

	ddrADDRbookP#(
		.ADDRwidth(ADDRwidth),
		.RESETbaseADDR(RESETbaseADDR),
		.PACKETimg(PACKETimg),
		.PACKETparam(PACKETparam),
		.PACKETparamW(PACKETparamW),
		.PACKETparamB(PACKETparamB),
		.incLABELmask(incLABELmask))
		u_ddrADDRbookP(
		.clk(boardCLK),.rst(rst),
		.clear(1'b0),
		.writeDone(writeDone),
		.writerErrorFlags(writerErrorFlags),
		.pStartAddr(pStartAddr),
		.pNextAddr(pNextAddr),
		.wMetaInfo(wMetaInfo),
		.wPayloadBytes(wPayloadBytes),
		.nextFreeAddr(nextFreeAddr),
		.validFlags(bookValidFlags),
		.startADDRbook(startADDRbook),
		.payloadBytesBook(payloadBytesBook),
		.bookErrorFlags(bookErrorFlags));

	assign LEDarr[0]    =migReady;//MIG ready
	assign LEDarr[1]    =decBusy;//decoder busy
	assign LEDarr[2]    =writerBusy;//writer busy
	assign LEDarr[3]    =writeDone;//wiirter writeDone pulse
	assign LEDarr[4]    =decPacketDone;//decoder packetDone pulse
	assign LEDarr[5]    =decPacketError;//decoder PacketError pulse
	assign LEDarr[6]    =|writerErrorFlags;//writer error exists
	assign LEDarr[7]    =|bookErrorFlags;//address book error exists
	assign LEDarr[13:8] =bookValidFlags;//{fc2Bvalid,fc2Wvalid,fc1Bvalid,fc1Wvalid,LABELvalid,IMGvalid}
	assign LEDarr[14]   =ddrWstrobe;//DDR write strobe
	assign LEDarr[15]   =migTranComp;//MIG transaction complete
endmodule