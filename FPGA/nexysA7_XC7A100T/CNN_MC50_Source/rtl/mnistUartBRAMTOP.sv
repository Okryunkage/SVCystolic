`timescale 1ns/1ps

//Nexys A7: 100 MHz, active-low CPU reset, USB-UART RX/TX, LED status.
//Request: A5 5A 03/04, 784 normalized int8 bytes, sum16(command+payload bytes) little endian.
//Reply: 5A A5 status prediction, 10 signed32 scores LE, sum16(status..scores) LE.
//Command 03: one deterministic reply. Command 04: 50 masked replies (50 bytes each).
//MC reply: 5A A6 status iteration prediction mask1 mask2LE scores[10]LE checksumLE.
module mnistUartBRAMTOP#(
	parameter int clockHz =100_000_000,baud =8_000_000,
	parameter int timeoutClocks =clockHz/2,
	parameter parameterDir ="data/mcdc_int8_fixed")(
	input logic clk,resetN,uartRX,
	output wire logic uartTX,
	output wire logic[7:0] led);
	(* ASYNC_REG ="TRUE" *) logic[1:0] resetSync =2'b11;
	//Only resetSync asserts asynchronously. All datapath/reset control changes
	//are clocked, including assertion, so BRAM control inputs cannot glitch.
	logic rst =1'b1;
	always_ff@(posedge clk) rst <=resetSync[1];
	always_ff@(posedge clk or negedge resetN)begin
		if(!resetN) resetSync <=2'b11;
		else resetSync <={resetSync[0],1'b0};
	end
	typedef enum logic[3:0] {HEADER0,HEADER1,COMMAND,PIXELS,CHECK_LO,CHECK_HI,
		START_INFER,WAIT_INFER,SEND_REQUEST,SEND_WAIT} stateType;
	stateType state;
	localparam int timeoutW =(timeoutClocks>1)?$clog2(timeoutClocks):1;
	logic[timeoutW-1:0] timeoutCount;
	wire[7:0] rxData;
	wire rxValid,rxError,txBusy,txDone;
	logic[7:0] txData;
	wire txStart =(state==SEND_REQUEST) && !txBusy;
	logic[9:0] pixelIndex;
	logic[15:0] imageSum,replySum;
	logic[7:0] checksumLow,status;
	logic[5:0] replyIndex;
    logic mcRequest;
    logic[5:0] iteration;
    wire[7:0] usedMask1;
    wire[15:0] usedMask2;
    wire[3:0] randomWord;
    wire randomValid;
    wire[5:0] lastReplyByte=mcRequest?6'd49:6'd45;
    lutRngSource rngSource(.clk(clk),.rst(rst),.randomWord(randomWord),.randomValid(randomValid));
	wire imgReady,imgLoaded,imgLoadError,nnBusy,nnDone,resultValid;
	wire[3:0] prediction;
	wire signed[31:0] scores[0:9];
	wire receiving =state==HEADER1 || state==COMMAND || state==PIXELS || state==CHECK_LO || state==CHECK_HI;
	wire imgWriteEnable =state==PIXELS && rxValid && !rxError && imgReady;
	assign led ={prediction,status!=0,resultValid,nnBusy,(state!=HEADER0)};
	mnistUart#(.clockHz(clockHz),.baud(baud)) serialPort(
		.clk(clk),.rst(rst),.rx(uartRX),.tx(uartTX),
		.rxData(rxData),.rxValid(rxValid),.rxError(rxError),
		.txStart(txStart),.txData(txData),.txBusy(txBusy),.txDone(txDone));
	mnistBRAMTOP#(.useLutBits(1'b1),.parameterDir(parameterDir)) nn(
		.clk(clk),.rst(rst),.start(state==START_INFER),.mcMode(mcRequest),
		.imgWriteEnable(imgWriteEnable),.imgWriteAddress(pixelIndex),.imgWriteData(rxData),
		.imgReady(imgReady),.imgLoaded(imgLoaded),.imgLoadError(imgLoadError),
		.randomWord(randomWord),.randomValid(randomValid),.randomReady(),
		.busy(nnBusy),.done(nnDone),.resultValid(resultValid),.prediction(prediction),.scores(scores),
		.usedMask1(usedMask1),.usedMask2(usedMask2));
    always_comb begin
        txData=0;
        if(mcRequest)begin
            case(replyIndex)
                0: txData=8'h5a;
                1: txData=8'ha6;
                2: txData=status;
                3: txData={2'b00,iteration};
                4: txData=status==0?{4'b0,prediction}:8'hff;
                5: txData=usedMask1;
                6: txData=usedMask2[7:0];
                7: txData=usedMask2[15:8];
                48: txData=replySum[7:0];
                49: txData=replySum[15:8];
                default: if(replyIndex>=8 && replyIndex<48 && status==0)
                    txData=scores[(int'(replyIndex)-8)/4][((int'(replyIndex)-8)%4)*8+:8];
            endcase
        end else begin
            case(replyIndex)
                0: txData=8'h5a;
                1: txData=8'ha5;
                2: txData=status;
                3: txData=status==0?{4'b0,prediction}:8'hff;
                44: txData=replySum[7:0];
                45: txData=replySum[15:8];
                default: if(replyIndex>=4 && replyIndex<(lastReplyByte-1) && status==0)
                    txData=scores[(int'(replyIndex)-4)/4][((int'(replyIndex)-4)%4)*8+:8];
            endcase
        end
    end

	always_ff@(posedge clk)begin
		if(rst)begin
			state <=HEADER0;
            mcRequest<=0;
            iteration<=0;
			pixelIndex <=0;
			imageSum <=0;
			checksumLow <=0;
			status <=0;
			replyIndex <=0;
			replySum <=0;
			timeoutCount <=0;
		end
		else begin
			if(!receiving || rxValid || rxError) timeoutCount <=0;
			else timeoutCount <=timeoutCount+1'b1;
			if(receiving && (rxError || (!rxValid && timeoutCount==timeoutClocks-1)))begin
				status <=rxError?8'he2:8'he3;
				replyIndex <=0;
				replySum <=0;
				state <=SEND_REQUEST;
			end
			else case(state)
				HEADER0: if(rxValid && rxData==8'ha5)begin
					status <=0;
                    mcRequest<=0;
                    iteration<=0;
					state <=HEADER1;
				end
				HEADER1: if(rxValid)begin
					if(rxData==8'h5a) state <=COMMAND;
					else if(rxData!=8'ha5) state <=HEADER0;
				end
				COMMAND: if(rxValid)begin
					if(rxData==3 || rxData==4)begin
                        mcRequest<=(rxData==4);
						pixelIndex <=0;
						imageSum <=16'(rxData);
						state <=PIXELS;
					end
					else begin
						status <=8'he4;
						replyIndex <=0;
						replySum <=0;
						state <=SEND_REQUEST;
					end
				end
				PIXELS: if(rxValid)begin
					imageSum <=imageSum+16'(rxData);
					if(pixelIndex==783) state <=CHECK_LO;
					else pixelIndex <=pixelIndex+1'b1;
				end
				CHECK_LO: if(rxValid)begin
					checksumLow <=rxData;
					state <=CHECK_HI;
				end
				CHECK_HI: if(rxValid)begin
					if({rxData,checksumLow}==imageSum && imgLoaded && !imgLoadError) state <=START_INFER;
					else begin
						status <=8'he1;
						replyIndex <=0;
						replySum <=0;
						state <=SEND_REQUEST;
					end
				end
				START_INFER: state <=WAIT_INFER;
				WAIT_INFER: if(nnDone)begin
					status <=0;
					replyIndex <=0;
					replySum <=0;
					state <=SEND_REQUEST;
				end
				SEND_REQUEST: if(!txBusy)begin
					if(replyIndex>=2 && replyIndex<(lastReplyByte-1)) replySum <=replySum+16'(txData);
					state <=SEND_WAIT;
				end
				SEND_WAIT: if(txDone)begin
					if(replyIndex==lastReplyByte)begin
                        if(mcRequest && status==0 && iteration<49)begin
                            iteration<=iteration+1'b1;
                            state<=START_INFER;
                        end else state<=HEADER0;
                    end
					else begin
						replyIndex <=replyIndex+1'b1;
						state <=SEND_REQUEST;
					end
				end
				default: state <=HEADER0;
			endcase
		end
	end
	`ifndef SYNTHESIS
	initial if(timeoutClocks<1) $fatal(1,"timeoutClocks must be positive");
	always@(posedge clk) if(!rst && state==PIXELS && rxValid && !imgReady)
		$fatal(1,"UART controller attempted a write while image memory was busy");
	`endif
endmodule
