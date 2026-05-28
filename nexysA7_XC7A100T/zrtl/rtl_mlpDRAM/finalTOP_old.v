`timescale 1ns/1ps

module finalTOP#(
	parameter ADDRwidth =27,
	parameter [ADDRwidth-1:0] RESETbaseADDR ={ADDRwidth{1'b0}},
	parameter [ADDRwidth-1:0] ADDRstride    =27'd8,

	parameter batchSize =16,

	parameter fc1InNum  =784,
	parameter fc1OutNum =64,
	parameter fc2OutNum =10,

	parameter fc1Tile =8,
	parameter fc2Tile =5,

	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,

	parameter rqOutWidth =8,
	parameter rqShift    =10,

	parameter [7:0] SOF0            =8'hAA,
	parameter [7:0] SOF1            =8'h55,
	parameter [7:0] versionEXP      =8'd1,
	parameter [7:0] PACKETimg       =8'h01,
	parameter [7:0] PACKETparam     =8'h02,
	parameter [7:0] PACKETparamW    =8'h00,
	parameter [7:0] PACKETparamB    =8'h01,
	parameter [7:0] incLABELmask    =8'h01,
	parameter [7:0] paramSIGNEDmask =8'h01,

	parameter byte0LSB =1,
	parameter checkPB  =1)(
	input  wire         boardCLK,
	input  wire         rst,
	input  wire         start,

	output wire         UARTRX,
	input  wire         UARTTX,

	output wire [15:0]  LEDarr,

	output wire [7:0]   an,
	output wire [6:0]   seg,
	output wire         dp,

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

	//########################################
	//##          SLOT DEFINITIONS          ##
	//########################################
	localparam integer SLOTimage =0;
	localparam integer SLOTlabel =1;
	localparam integer SLOTfc1W  =2;
	localparam integer SLOTfc1B  =3;
	localparam integer SLOTfc2W  =4;
	localparam integer SLOTfc2B  =5;

	localparam integer fc1WbytePerElem =((wWidth+7)/8);
	localparam integer fc2WbytePerElem =((wWidth+7)/8);
	localparam integer fc1BbytePerElem =((bWidth+7)/8);
	localparam integer fc2BbytePerElem =((bWidth+7)/8);

	localparam [31:0] imageBytesREQ =batchSize*fc1InNum;
	localparam [31:0] labelBytesREQ =batchSize;

	localparam [31:0] fc1WbytesREQ  =fc1InNum*fc1OutNum*fc1WbytePerElem;
	localparam [31:0] fc1BbytesREQ  =fc1OutNum*fc1BbytePerElem;

	localparam [31:0] fc2WbytesREQ  =fc1OutNum*fc2OutNum*fc2WbytePerElem;
	localparam [31:0] fc2BbytesREQ  =fc2OutNum*fc2BbytePerElem;

	//########################################
	//##          CLOCK / RESET             ##
	//########################################
	wire migclk;
	wire locked;

	mmcm200 u_clkmmcm(
		.reset(rst),
		.clk_in1(boardCLK),
		.locked(locked),
		.clk_out1(migclk)
	);

	//Small power-on reset generator.
	reg [3:0] porCnt;
	wire porRst;

	assign porRst = ~porCnt[3];

	always@(posedge boardCLK or posedge rst)begin
		if(rst)begin
			porCnt <=4'd0;
		end
		else begin
			if(!porCnt[3]) porCnt <=porCnt+4'd1;
		end
	end

	wire rstPulse;
	wire startPulse;
	wire sysRst;
	wire rst_n;

	SYNCpulse u_rstPulse(
		.clk(boardCLK),
		.rst(porRst),
		.signal(rst),
		.SYNCsig(rstPulse)
	);

	assign sysRst =porRst|rstPulse|(~locked);
	assign rst_n  =locked&(~sysRst);

	SYNCpulse u_startPulse(
		.clk(boardCLK),
		.rst(sysRst),
		.signal(start),
		.SYNCsig(startPulse)
	);

	//Load RESETbaseADDR into ddrPackW allocator after reset.
	reg baseAddrLoadDone;
	reg baseAddrLoadPulse;

	always@(posedge boardCLK or posedge sysRst)begin
		if(sysRst)begin
			baseAddrLoadDone  <=1'b0;
			baseAddrLoadPulse <=1'b0;
		end
		else begin
			if(!baseAddrLoadDone)begin
				baseAddrLoadPulse <=1'b1;
				baseAddrLoadDone  <=1'b1;
			end
			else begin
				baseAddrLoadPulse <=1'b0;
			end
		end
	end

	//########################################
	//##          MIG SHARED WIRES          ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire                 migReady;
	(* MARK_DEBUG ="TRUE" *) wire                 migTranComp;
	(* MARK_DEBUG ="TRUE" *) wire [127:0]         migDataOut;

	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] migAddr;
	(* MARK_DEBUG ="TRUE" *) wire [127:0]         migDataIn;
	(* MARK_DEBUG ="TRUE" *) wire                 migWstrobe;
	(* MARK_DEBUG ="TRUE" *) wire                 migRstrobe;

	//########################################
	//##              UART                  ##
	//########################################
	wire rxDone;
	wire [7:0] rxData;

	uartTOP#(
		.boardCLK(100_000_000),
		.oversample(20),
		.baudrate(1_000_000),
		.ACCwidth(24))
		u_uartTOP(
		.clk(boardCLK),
		.rst(sysRst),

		.uartRX(UARTTX),
		.uartTX(UARTRX),

		.TXstart(1'b0),
		.TXitem(8'd0),
		.TXdone(),
		.TXbusy(),

		.RXout(rxData),
		.RXdone(rxDone),
		.RXbusy(),
		.RXerror()
	);
	wire rxDoneS;
	SYNCpulse rxDoneSYNC(.clk(boardCLK),.rst(sysRst),.signal(rxDone),.SYNCsig(rxDoneS));

	//########################################
	//##          upDEC OUTPUTS            ##
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
		.clk(boardCLK),
		.rst(sysRst),

		.rxDone(rxDoneS),
		.rxData(rxData),

		.statusFlags(statusFlags),
		.headerInfo(headerInfo),
		.imageInfo(imageInfo),
		.paramInfo(paramInfo),
		.payloadInfo(payloadInfo),
		.payloadFlags(payloadFlags),
		.checksumInfo(checksumInfo),
		.busy(decBusy)
	);

	//########################################
	//##        ddrPackW OUTPUTS           ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] writerDDRaddr;
	(* MARK_DEBUG ="TRUE" *) wire [127:0]         writerDDRdata;
	(* MARK_DEBUG ="TRUE" *) wire                 writerDDRwstrobe;

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
	//##          FC / ACC WIRES            ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fcDDRaddr;
	(* MARK_DEBUG ="TRUE" *) wire                 fcDDRRstrobe;

	(* MARK_DEBUG ="TRUE" *) wire fcBusy;
	(* MARK_DEBUG ="TRUE" *) wire fcDone;
	(* MARK_DEBUG ="TRUE" *) wire fcError;
	(* MARK_DEBUG ="TRUE" *) wire fcAccError;

	(* MARK_DEBUG ="TRUE" *) wire [($clog2(fc2OutNum)-1):0] predIndex;
	(* MARK_DEBUG ="TRUE" *) wire [7:0] currentLabel;
	(* MARK_DEBUG ="TRUE" *) wire currentCorrect;

	(* MARK_DEBUG ="TRUE" *) wire [31:0] predCount;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] totalCount;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] correctCount;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] accuracyPermille;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] currentBatchIndex;

	(* MARK_DEBUG ="TRUE" *) wire labelBusy;
	(* MARK_DEBUG ="TRUE" *) wire labelDone;

	(* MARK_DEBUG ="TRUE" *) wire batchDone;
	(* MARK_DEBUG ="TRUE" *) wire batchError;
	(* MARK_DEBUG ="TRUE" *) wire labelValueError;

	wire writerDDRready;
	wire fcDDRready;

	assign writerDDRready =migReady&(~fcBusy);
	assign fcDDRready     =migReady&(~writerBusy)&(~writerDDRwstrobe);

	ddrPackW#(
		.ADDRwidth(ADDRwidth),
		.ADDRstride(ADDRstride),
		.PACKETimg(PACKETimg),
		.PACKETparam(PACKETparam),
		.PACKETparamW(PACKETparamW),
		.PACKETparamB(PACKETparamB))
		u_ddrPackW(
		.clk(boardCLK),
		.rst(sysRst),

		.baseAddrLoad(baseAddrLoadPulse),
		.baseAddrValue(RESETbaseADDR),

		.statusFlags(statusFlags),
		.headerInfo(headerInfo),
		.imageInfo(imageInfo),
		.paramInfo(paramInfo),
		.payloadInfo(payloadInfo),
		.payloadFlags(payloadFlags),

		.ddrAddr(writerDDRaddr),
		.ddrData(writerDDRdata),
		.ddrWstrobe(writerDDRwstrobe),
		.ddrReady(writerDDRready),
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
		.busy(writerBusy)
	);

	//########################################
	//##          Address Book              ##
	//########################################
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0]   nextFreeAddr;
	(* MARK_DEBUG ="TRUE" *) wire [5:0]             bookValidFlags;
	(* MARK_DEBUG ="TRUE" *) wire [6*ADDRwidth-1:0] startADDRbook;
	(* MARK_DEBUG ="TRUE" *) wire [6*32-1:0]        payloadBytesBook;
	(* MARK_DEBUG ="TRUE" *) wire [2:0]             bookErrorFlags;

	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] imageStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] labelStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc1WeightStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc1BiasStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc2WeightStartAddr;
	(* MARK_DEBUG ="TRUE" *) wire [ADDRwidth-1:0] fc2BiasStartAddr;

	(* MARK_DEBUG ="TRUE" *) wire [31:0] imagePayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] labelPayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc1WeightPayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc1BiasPayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc2WeightPayloadBytes;
	(* MARK_DEBUG ="TRUE" *) wire [31:0] fc2BiasPayloadBytes;

	assign imageStartAddr     =startADDRbook[SLOTimage*ADDRwidth +: ADDRwidth];
	assign labelStartAddr     =startADDRbook[SLOTlabel*ADDRwidth +: ADDRwidth];
	assign fc1WeightStartAddr =startADDRbook[SLOTfc1W *ADDRwidth +: ADDRwidth];
	assign fc1BiasStartAddr   =startADDRbook[SLOTfc1B *ADDRwidth +: ADDRwidth];
	assign fc2WeightStartAddr =startADDRbook[SLOTfc2W *ADDRwidth +: ADDRwidth];
	assign fc2BiasStartAddr   =startADDRbook[SLOTfc2B *ADDRwidth +: ADDRwidth];

	assign imagePayloadBytes     =payloadBytesBook[SLOTimage*32 +: 32];
	assign labelPayloadBytes     =payloadBytesBook[SLOTlabel*32 +: 32];
	assign fc1WeightPayloadBytes =payloadBytesBook[SLOTfc1W *32 +: 32];
	assign fc1BiasPayloadBytes   =payloadBytesBook[SLOTfc1B *32 +: 32];
	assign fc2WeightPayloadBytes =payloadBytesBook[SLOTfc2W *32 +: 32];
	assign fc2BiasPayloadBytes   =payloadBytesBook[SLOTfc2B *32 +: 32];

	ddrADDRbookP#(
		.ADDRwidth(ADDRwidth),
		.RESETbaseADDR(RESETbaseADDR),
		.PACKETimg(PACKETimg),
		.PACKETparam(PACKETparam),
		.PACKETparamW(PACKETparamW),
		.PACKETparamB(PACKETparamB),
		.incLABELmask(incLABELmask))
		u_ddrADDRbookP(
		.clk(boardCLK),
		.rst(sysRst),
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
		.bookErrorFlags(bookErrorFlags)
	);

	//########################################
	//##          READY CHECK               ##
	//########################################
	wire validDataReady;
	wire payloadDataReady;
	wire allDataReady;

	assign validDataReady =
		bookValidFlags[SLOTimage] &
		bookValidFlags[SLOTlabel] &
		bookValidFlags[SLOTfc1W]  &
		bookValidFlags[SLOTfc1B]  &
		bookValidFlags[SLOTfc2W]  &
		bookValidFlags[SLOTfc2B];

	assign payloadDataReady =
		(imagePayloadBytes     >= imageBytesREQ) &
		(labelPayloadBytes     >= labelBytesREQ) &
		(fc1WeightPayloadBytes >= fc1WbytesREQ)  &
		(fc1BiasPayloadBytes   >= fc1BbytesREQ)  &
		(fc2WeightPayloadBytes >= fc2WbytesREQ)  &
		(fc2BiasPayloadBytes   >= fc2BbytesREQ);

	assign allDataReady =validDataReady&payloadDataReady&(~(|bookErrorFlags));

	wire fcStartPulse;

	assign fcStartPulse =startPulse&allDataReady&(~writerBusy)&(~decBusy)&(~fcBusy)&migReady;

	//########################################
	//##          FC Batch Accuracy         ##
	//########################################
	fcBatchAccTOP#(
		.addrWidth(ADDRwidth),
		.addrStride(ADDRstride),

		.batchSize(batchSize),

		.fc1InNum(fc1InNum),
		.fc1OutNum(fc1OutNum),
		.fc2OutNum(fc2OutNum),

		.fc1Tile(fc1Tile),
		.fc2Tile(fc2Tile),

		.inWidth(inWidth),
		.wWidth(wWidth),
		.bWidth(bWidth),
		.accWidth(accWidth),

		.rqOutWidth(rqOutWidth),
		.rqShift(rqShift),

		.byte0LSB(byte0LSB),
		.checkPB(checkPB))
		u_fcBatchAccTOP(
		.clk(boardCLK),
		.rst(sysRst),
		.start(fcStartPulse),

		.inBaseADDR(imageStartAddr),
		.labelBaseADDR(labelStartAddr),

		.fc1wBaseADDR(fc1WeightStartAddr),
		.fc1bBaseADDR(fc1BiasStartAddr),

		.fc2wBaseADDR(fc2WeightStartAddr),
		.fc2bBaseADDR(fc2BiasStartAddr),

		.inPB(imagePayloadBytes),
		.fc1wPB(fc1WeightPayloadBytes),
		.fc1bPB(fc1BiasPayloadBytes),
		.fc2wPB(fc2WeightPayloadBytes),
		.fc2bPB(fc2BiasPayloadBytes),

		.ddrAddr(fcDDRaddr),
		.ddrRstrobe(fcDDRRstrobe),
		.ddrData(migDataOut),
		.ddrReady(fcDDRready),
		.ddrTranComp(migTranComp),

		.busy(fcBusy),
		.done(fcDone),

		.predIndex(predIndex),

		.currentLabel(currentLabel),
		.currentCorrect(currentCorrect),

		.predCount(predCount),
		.totalCount(totalCount),
		.correctCount(correctCount),
		.accuracyPermille(accuracyPermille),

		.currentBatchIndex(currentBatchIndex),

		.fcBusy(),
		.fcDone(),
		.fcError(fcError),

		.labelBusy(labelBusy),
		.labelDone(labelDone),

		.batchDone(batchDone),
		.batchError(batchError),
		.labelValueError(labelValueError),
		.error(fcAccError),

		.fc1DebugState(),
		.fc2DebugState(),
		.fc1DebugInIdx(),
		.fc1DebugtileIdx(),
		.fc1DebugReadLine(),
		.fc2DebugInIdx(),
		.fc2DebugtileIdx(),
		.fc2DebugReadLine()
	);

	//########################################
	//##          DDR ACCESS MUX            ##
	//########################################
	//Writer and fcBatchAccTOP should not access DDR at the same time.
	//writerDDRready and fcDDRready prevent normal collision.
	assign migAddr =
		writerDDRwstrobe ? writerDDRaddr :
		fcDDRRstrobe     ? fcDDRaddr     :
		{ADDRwidth{1'b0}};

	assign migDataIn  =writerDDRdata;
	assign migWstrobe =writerDDRwstrobe;
	assign migRstrobe =fcDDRRstrobe&(~writerBusy)&(~writerDDRwstrobe);

	mig_ui128 u_mig_ui128(
		.migclk(migclk),
		.rst_n(rst_n),

		.boardclk(boardCLK),

		.addr(migAddr),
		.data_in(migDataIn),
		.data_out(migDataOut),

		.rstrobe(migRstrobe),
		.wstrobe(migWstrobe),

		.transaction_complete(migTranComp),
		.ready(migReady),

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
		.ddr2_odt(ddr2_odt)
	);

	//########################################
	//##          8-SEG DISPLAY             ##
	//########################################
	reg [15:0] scanCnt;
	wire scanTick;

	always@(posedge boardCLK or posedge sysRst)begin
		if(sysRst) begin
			scanCnt <=16'd0;
		end
		else begin
			scanCnt <=scanCnt+16'd1;
		end
	end

	assign scanTick =(scanCnt==16'd0);

	//accuracyPermille display.
	//Example: A0875 means 87.5%.
	wire [31:0] accAscii4;

	bin2decASCII1#(
		.binWidth(32),
		.digits(4))
		u_accBin2DecASCII(
		.bin(accuracyPermille),
		.asciiFlat(accAscii4)
	);

	reg [63:0] segAsciiData;

	always@(*)begin
		if(fcAccError|batchError|labelValueError|(|bookErrorFlags)|(|writerErrorFlags))begin
			//Display: "     Err"
			segAsciiData ={
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_E,
				`ASCII_r,
				`ASCII_r
			};
		end
		else if(fcBusy)begin
			//Display: "     run"
			segAsciiData ={
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_r,
				`ASCII_u,
				`ASCII_n
			};
		end
		else if(allDataReady && !batchDone)begin
			//Display: "    rEAd"
			segAsciiData ={
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_r,
				`ASCII_E,
				`ASCII_A,
				`ASCII_d
			};
		end
		else begin
			//Display: "   Axxxx"
			//xxxx = accuracyPermille.
			//Example: A0875 means 87.5%.
			segAsciiData ={
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_SPACE,
				`ASCII_A,
				accAscii4
			};
		end
	end

	seg8Ascii u_seg8Ascii(
		.clk(boardCLK),
		.rst(sysRst),
		.scanTick(scanTick),
		.asciiData(segAsciiData),
		.an(an),
		.seg(seg),
		.dp(dp)
	);
	/*
	//########################################
	//##       STICKY DEBUG FLAGS            ##
	//########################################
	reg rxSeen;
	reg headerSeen;
	reg payloadSeen;
	reg packetDoneSeen;
	reg packetErrorSeen;
	reg writeDoneSeen;
	reg writerErrorSeen;
	reg bookErrorSeen;

	always@(posedge boardCLK or posedge sysRst)begin
		if(sysRst)begin
			rxSeen          <=1'b0;
			headerSeen      <=1'b0;
			payloadSeen     <=1'b0;
			packetDoneSeen  <=1'b0;
			packetErrorSeen <=1'b0;
			writeDoneSeen   <=1'b0;
			writerErrorSeen <=1'b0;
			bookErrorSeen   <=1'b0;
		end
		else begin
			if(rxDone)              rxSeen          <=1'b1;
			if(decHeaderValid)      headerSeen      <=1'b1;
			if(decPayloadValid)     payloadSeen     <=1'b1;
			if(decPacketDone)       packetDoneSeen  <=1'b1;
			if(decPacketError)      packetErrorSeen <=1'b1;
			if(writeDone)           writeDoneSeen   <=1'b1;
			if(|writerErrorFlags)   writerErrorSeen <=1'b1;
			if(|bookErrorFlags)     bookErrorSeen   <=1'b1;
		end
	end
	*/
	//########################################
	//##              LED                   ##
	//########################################
	assign LEDarr[0] =bookValidFlags[SLOTimage]; // image batch valid
	assign LEDarr[1] =bookValidFlags[SLOTlabel]; // label valid
	assign LEDarr[2] =bookValidFlags[SLOTfc1W];  // fc1 weight valid
	assign LEDarr[3] =bookValidFlags[SLOTfc1B];  // fc1 bias valid
	assign LEDarr[4] =bookValidFlags[SLOTfc2W];  // fc2 weight valid
	assign LEDarr[5] =bookValidFlags[SLOTfc2B];  // fc2 bias valid

	assign LEDarr[6] =allDataReady;              // ready for inference
	assign LEDarr[7] =fcBusy;                    // inference running
	assign LEDarr[8] =fcDone;                    // inference done pulse
	assign LEDarr[9] =currentCorrect;            // last prediction was correct

	assign LEDarr[10] =decBusy;
	assign LEDarr[11] =writerBusy;
	assign LEDarr[12] =|writerErrorFlags;
	assign LEDarr[13] =|bookErrorFlags;
	assign LEDarr[14] =migWstrobe;
	assign LEDarr[15] =migRstrobe;
	/*
	assign LEDarr[0]  = locked;
	assign LEDarr[1]  = migReady;

	assign LEDarr[2]  = rxSeen;
	assign LEDarr[3]  = headerSeen;
	assign LEDarr[4]  = payloadSeen;
	assign LEDarr[5]  = packetDoneSeen;
	assign LEDarr[6]  = writeDoneSeen;
	assign LEDarr[7]  = packetErrorSeen | writerErrorSeen | bookErrorSeen;

	assign LEDarr[13:8] = bookValidFlags;

	assign LEDarr[14] = writerBusy;
	assign LEDarr[15] = migWstrobe;
	*/
endmodule