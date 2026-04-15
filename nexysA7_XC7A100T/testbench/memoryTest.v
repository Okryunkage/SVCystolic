/*
If reset button pushed, initialization proceed.
	wstrobe <=0.
	rstrobe <=0.
	countR  <=0.
	countT  <=0. 
	writeAddress <=0.
	readAddress  <=0.
	waitFlag <=0.
	receiveReg[127:0] <=0.
	readReg[127:0]    <=0.
	state <=idle
	TXstart <=0;
	sendITEM <=0;
	*initially begins at idle state

FSM description:
	idle:
		LED0 reg <=True.
		TXen <=False.
		if RXbusy signal rise, goto receive state

	receive:
		*data saved to receiveReg[127:0] in FIFO manner
		*countR register used to count the number of receivement.
		*5bit register used for countR register. the MSB indicate reveiceReg full.
		LED0 reg <=False.
		if RXdone rise,
			if RXout ==8'hFF,
				countR =0
				goto memRead_wating state.
			else,
				receiveReg update.
				countR up.
				if countR[4],
					countR =0.
					goto memWrite_waiting state.
				else,
					goto idle state.
			
	memWrite_waiting:
		LED0 reg <=False.
		LED1 reg <=True.
		if RXbusy signal rise, waitFlag on.
		if waitFlag on & Rxdone rise,
			waitFlag down.
			if RXout ==8'hFF,
				wstrobe <=1'b1.
				goto memWrite state.
				LED1 reg <=False.
	
	memWrite:
		wstrobe <=1'b0.
		if transactionComplete rise,
			writeAddress update.
			goto idle state.

	memRead_waiting:
		LED0 reg <=False.
		LED2 reg <=True.
		if RXbusy signal rise, waitFlag on.
		if waitFlag on & RXdone rise,
			waitFlag down.
			if RXout ==8'hFF,
				rstrobe <=1'b1.
				goto memRead state.
				LED1 reg <=False.

	memRead:
		rstrobe <=1'b0.
		if transactionComplete rise,
			readReg <=data_out.
			readAddress update.
			goto transmit state.
	
	transmit:
		TXen <=True.
		if !TXflag,
			TXstart <=True.
			TXflag <=True.
			{sendITEM,readReg[127:0]} <={readReg[127:0],8'b0}.
		if TXbusy & TXflag,
			TXstart <=False.
		if TXdone & TXflag,
			TXflag <=False.
			countT up.
			if countT ==16,
				countT <=0.
				goto idle state.
*/

`timescale 1ns/1ps

module memoryTest(
	input wire boardCLK,
	input wire buttonC,
	input wire buttonT,
	input wire buttonB,
	input wire buttonL,
	input wire buttonR,

	input wire UARTTX,
	input wire UARTRX,

	output reg[7:0] LEDarr,
	output wire[7:0] segSel,
	output wire[6:0] seg,
	output wire segDot,

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

	/*
	##############################
	##        Clock  Gen        ##
	##############################
	*/
	wire clk200, locked, segCLK, RXtick, TXtick;
	mmcm200 clkmmcm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(clk200));
	
	tickgen#(.CLK(100_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(boardCLK,{1'b0},segCLK);
	
	baudrategen#(.clock(100_000_000),.baudrate(1_000_000),.oversample(20)) UARTickGen(boardCLK,{1'b0},RXtick,TXtick);

	/*
	##############################
	##       UART Moudle        ##
	##############################
	*/
	transmit_rev#(8) TXmodule(
		.clk(boardCLK),.tick(TXtick),.en(TXen),.start(TXstart),
		.in(),
		.out(),.done(),.busy(),
		.cts());
	receive_rev_tick#(8,20) RXmodule(
		.clk(boardCLK),.tick(RXtick),.en()),.in(),.rst(),
		.out(),.done(),.busy(),.error(),.
		.rst(),.read());

	/*
	##############################
	##       MIG Instance       ##
	##############################
	*/
	wire[63:0] dataOut;
	wire transactionComplete, ready;
	reg[26:0] addressReg;
	mig_ui128 migT(
		.migclk(clk200),
		.rst_n(~resetSYNC0),
		.boardclk(boardCLK),
		.addr(addressReg),
		.data_in(),
		.data_out(dataOut),
		.rstrobe(),
		.wstrobe(),
		.transaction_complete(transactionComplete),
		.ready(ready),
        
		.ddr2_dq(ddr2_dq),.ddr2_dqs_n(ddr2_dqs_n),.ddr2_dqs_p(ddr2_dqs_p),.ddr2_addr(ddr2_addr),.ddr2_ba(ddr2_ba),
		.ddr2_ras_n(ddr2_ras_n),.ddr2_cas_n(ddr2_cas_n),.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),.ddr2_ck_n(ddr2_ck_n),.ddr2_cke(ddr2_cke),
		.ddr2_cs_n(ddr2_cs_n),.ddr2_dm(ddr2_dm),.ddr2_odt(ddr2_odt));

	localparam idle      =3'd0;
	localparam receive   =3'd1;
	localparam memWriteW =3'd2;
	localparam memWrite  =3'd3;
	localparam memReadW  =3'd4;
	localparam memRead   =3'd5;
	localparam transmit  =3'd6;

	reg[2:0] state;
	reg[4:0] count;
	always@(posedge boardCLK)begin
		
	end
endmodule
