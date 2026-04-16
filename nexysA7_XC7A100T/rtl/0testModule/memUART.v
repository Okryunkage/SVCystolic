/*
If reset button pushed, initialization proceed.
	wstrobe <=0.
	rstrobe <=0.
	countR  <=0.
	countT  <=0. 
	writeAddress <=0.
	readAddress  <=0.
	waitFlag <=0.
	receiveReg[127:0] <=0. (dataIn)
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
				countR <=0
				goto memRead_wating state.
			else,
				receiveReg update.
				countR up.
				if countR[4],
					countR <=0.
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
				LED2 reg <=False.

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
		if TXbusy & TXflag, TXstart <=False.
		if TXdone & TXflag,
			TXflag <=False.
			countT up.
			if countT ==16,
				countT <=0.
				goto idle state.
*/

`timescale 1ns/1ps

module memUART(
	input wire boardCLK,
	input wire buttonC,
	input wire buttonT,
	input wire buttonB,
	input wire buttonL,
	input wire buttonR,

	input  wire UARTTX,
	output wire UARTRX,

	output reg[6:0] LEDarr,
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
	wire clk200, locked, segtick, RXtick, TXtick;
	mmcm200 clkmmcm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(clk200));
	tickgen#(.CLK(100_000_000),.TICK(8_000),.ACCwidth(32)) segTickGen(boardCLK,{1'b0},segtick);
	baudtickgen#(.CLK(100_000_000),.baudrate(1_000_000),.oversample(20),.ACCwidth(24)) UARTickGen(boardCLK,{1'b0},RXtick,TXtick);

	/*
	##############################
	##       UART Moudle        ##
	##############################
	*/
	reg TXen, TXstart;
	reg[7:0] sendITEM;
	wire TXdone, TXbusy;
	transmit#(8) TXmodule(
		.clk(boardCLK),.tick(TXtick),.en(TXen),.start(TXstart),
		.in(sendITEM),
		.out(UARTRX),.done(TXdone),.busy(TXbusy),
		.cts({1'b1}));
	wire RXdone, RXbusy;
	wire[7:0] RXout;
	receive#(8,20) RXmodule(
		.clk(boardCLK),.tick(RXtick),.en(!TXen),.in(UARTTX),.rst(resetSYNC0),
		.out(RXout),.done(RXdone),.busy(RXbusy),.error());

	/*
	##############################
	##       MIG Instance       ##
	##############################
	*/
	reg [127:0] dataIn;
	wire[127:0] dataOut;
	reg wstrobe, rstrobe;
	wire transactionComplete, ready;
	//addressReg's data is connected to either readAddress or WriteAddress
	reg[26:0] addressReg;
	mig_ui128 migT(
		.migclk(clk200),
		.rst_n(~resetSYNC0),
		.boardclk(boardCLK),
		.addr(addressReg),
		.data_in(dataIn),
		.data_out(dataOut),
		.rstrobe(rstrobe),
		.wstrobe(wstrobe),
		.transaction_complete(transactionComplete),
		.ready(ready),
        
		.ddr2_dq(ddr2_dq),.ddr2_dqs_n(ddr2_dqs_n),.ddr2_dqs_p(ddr2_dqs_p),.ddr2_addr(ddr2_addr),.ddr2_ba(ddr2_ba),
		.ddr2_ras_n(ddr2_ras_n),.ddr2_cas_n(ddr2_cas_n),.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),.ddr2_ck_n(ddr2_ck_n),.ddr2_cke(ddr2_cke),
		.ddr2_cs_n(ddr2_cs_n),.ddr2_dm(ddr2_dm),.ddr2_odt(ddr2_odt));

	/*
	##############################
	##           FSM            ##
	##############################
	*/
	localparam idle      =3'd0;
	localparam receiveS  =3'd1;
	localparam memWriteW =3'd2;
	localparam memWrite  =3'd3;
	localparam memReadW  =3'd4;
	localparam memRead   =3'd5;
	localparam transmitS =3'd6;

	reg[2:0] state;
	reg[4:0] countR, countT;
	reg[26:0] wAddress, rAddress;
	reg waitFlag;
	reg[127:0] readReg;
	reg[6:0] LEDREG;
	reg TX0flag;
	reg TX1flag;

	reg[63:0] segREG;

	always@(posedge boardCLK)begin
		if(resetSYNC0)begin
			wstrobe  <=1'b0;
			rstrobe  <=1'b0;
			countR   <=1'b0;
			countT   <=1'b0;
			wAddress <=27'b0;
			rAddress <=27'b0;
			waitFlag <=1'b0;
			dataIn   <=128'b0;
			readReg  <=128'b0;
			state    <=idle;
			TXstart  <=1'b0;
			sendITEM <=8'b0;
			LEDREG   <=3'b0;
			TXen     <=1'b0;
			TX0flag  <=1'b0;
			TX1flag  <=1'b0;

			segREG   <=64'b0;
		end
		else begin
			case(state)
				idle:begin
					LEDREG <=7'b000_0001;
					TXen      <=1'b0;
					if(RXbusy) state <=receiveS;
					if(countR==5'd16)begin
						countR <=4'd0;
						state <=memWriteW;
					end
				end

				receiveS:begin
					if(RXdone)begin
						if(RXout==8'hFF)begin
							countR <=0;
							state <=memReadW;
						end
						else begin
							dataIn <={dataIn[119:0],RXout};
							countR <=countR+5'd1;
							state <=idle;

							segREG <={segREG[55:0],RXout};
						end
					end
				end

				memWriteW:begin
					LEDREG <=7'b000_0100;
					if(RXbusy) waitFlag <=1'b1;
					if(waitFlag&RXdone)begin
						waitFlag <=1'b0;
						if(RXout==8'hFF)begin
							wstrobe <=1'b1;
							state <=memWrite;
							addressReg <=wAddress;
							LEDREG <=7'b0;
						end
					end
				end

				memWrite:begin
					wstrobe <=1'b0;
					if(transactionComplete)begin
						wAddress <=wAddress+27'd8;
						state <=idle;
					end
				end

				memReadW:begin
					LEDREG <=7'b001_0000;
					if(RXbusy) waitFlag <=1'b1;
					if(waitFlag&RXdone)begin
						waitFlag <=1'b0;
						if(RXout==8'hFF)begin
							rstrobe <=1'b1;
							state <=memRead;
							addressReg <=rAddress;
							LEDREG <=7'b0;
						end
					end
				end

				memRead:begin
					LEDREG <=7'b010_0000;
					rstrobe <=1'b0;
					if(transactionComplete)begin
						readReg <=dataOut;
						rAddress <=rAddress+27'd8;
						state <=transmitS;
						LEDREG <=7'b0;
						TXen <=1'b1;

					end
				end

				transmitS:begin
					LEDREG <=7'b100_0000;
					if((!TX0flag)&(!TX1flag))begin
						TXstart <=1'b1;
						TX0flag <=1'b1;
						{sendITEM,readReg[127:0]} <={readReg[127:0],8'b0};
					end
					if(TXbusy&TX0flag)begin
						TX0flag <=1'b0;
						TXstart <=1'b0;
						TX1flag <=1'b1;
					end
					if(TXdone&TX1flag)begin
						TX1flag <=1'b0;
						if(countT==4'd15)begin
							countT <=5'b0;
							state <=idle;
							LEDREG <=7'b0;
						end
						else countT <=countT+5'd1;
					end
				end
			endcase
		end
		if(segtick)begin
			LEDarr <=LEDREG;
		end
	end
	seg8Ascii ascii(boardCLK,resetSYNC0,segtick,segREG,segSel,seg,segDot);
endmodule
