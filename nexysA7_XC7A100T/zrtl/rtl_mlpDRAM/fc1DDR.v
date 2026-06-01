`timescale 1ns/1ps

module fc1DDR#(
	parameter addrWidth =27,
	parameter [addrWidth-1:0] addrStride =27'd8,
	parameter tile     =8,
	/*
	Other tile configuration is not supported in this code.
	*/
	parameter inNum   =784,
	parameter outNum  =64,
	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,
	parameter inSigned =0,
	parameter byte0LSB =1,
	parameter checkPB  =1)(//checkPayloadBytes
	input wire clk,
	input wire rst,
	input wire start,
	input wire [addrWidth-1:0] inBaseADDR,
	input wire [addrWidth-1:0] wBaseADDR,
	input wire [addrWidth-1:0] bBaseADDR,
	//Payload byte counts from ddrADDRbookP.
	input wire [31:0] inPB,
	input wire [31:0] wPB,
	input wire [31:0] bPB,
	//DDR read interface to current mig_ui128 mux.
	output reg [addrWidth-1:0] ddrAddr,
	output reg                 ddrRstrobe,
	input  wire [127:0]        ddrData,
	input  wire                ddrReady,
	input  wire                ddrTranComp,
	output reg busy,
	output reg done,//used in next layer as start signal
	output reg signed [(outNum*accWidth-1):0] outFlat,
	output reg [addrWidth-1:0] inLastADDR,
	output reg [addrWidth-1:0] wLastADDR,
	output reg [addrWidth-1:0] bLastADDR,
	output reg [addrWidth-1:0] LastReadADDR,
	output reg  configError,
	output reg  payloadSizeError,
	output reg  ddrReadError,
	output wire error,
	//Small debug outputs for LED/ILA.
	output wire [4:0]                   debugState,
	output reg  [31:0]                  debugInIdx,
	output reg  [31:0]                  debugtileIdx,
	output reg  [31:0]                  debugReadLine);

	localparam integer ddrBytes =16;
	localparam integer tileNum =outNum/tile;
	localparam integer tileIDXwidth =$clog2(tileNum);
	localparam integer inIDXwidth   =$clog2(inNum);
	localparam integer inBytesTotal =inNum;
	localparam integer inLines      =(inBytesTotal+ddrBytes-1)/ddrBytes;

	localparam integer wBYTEperELEM  =(wWidth+7)/8;
	localparam integer wBYTEperENTRY =tile*wBYTEperELEM;
	localparam integer wBYTEtotal    =inNum*outNum*wBYTEperELEM;
	localparam integer wLINEStotal   =(wBYTEtotal+ddrBytes-1)/ddrBytes;

	localparam integer bBYTEperELEM  =(bWidth+7)/8;
	localparam integer bBYTEperTILE  =tile*bBYTEperELEM;
	localparam integer bLINEperTILE  =(bBYTEperTILE+ddrBytes-1)/ddrBytes;
	localparam integer bBYTEtotal    =outNum*bBYTEperELEM;
	localparam integer bLINEStotal   =(bBYTEtotal+ddrBytes-1)/ddrBytes;

	localparam [4:0] S_IDLE        =5'd0;
	localparam [4:0] S_LOAD_X_REQ  =5'd1;
	localparam [4:0] S_LOAD_X_WAIT =5'd2;
	localparam [4:0] S_BIAS_REQ    =5'd3;
	localparam [4:0] S_BIAS_WAIT   =5'd4;
	localparam [4:0] S_BIAS_INIT   =5'd5;
	localparam [4:0] S_W_REQ       =5'd6;
	localparam [4:0] S_W_WAIT      =5'd7;
	localparam [4:0] S_MAC         =5'd8;
	localparam [4:0] S_WRITE_OUT   =5'd9;
	localparam [4:0] S_DONE        =5'd10;
	localparam [4:0] S_ERROR       =5'd11;

	reg [4:0] state;

	assign debugState =state;
	assign error      =configError|payloadSizeError|ddrReadError;

	reg [31:0] xLineIdx;
	reg [31:0] biasLineIdx;

	reg [inIDXwidth-1:0]   inIdx;
	reg [tileIDXwidth-1:0] tileIdx;

	reg [127:0] rdBuf;
	reg [3:0]   weightByteInLine;

	reg signed [accWidth-1:0] acc [0:tile-1];

	reg [7:0] xMem [0:inNum-1];
	reg [7:0] biasByteMem [0:bBYTEperTILE-1];

	integer i;

	//when tile==8, weight per tile perfectily match to ddrData (128bit)
	wire [31:0] wEntryIndexCalc =(tileIdx*inNum)+inIdx;
	//Index of the current weight entry. One entry contains 'tile' weights for the current input index.
	wire [31:0] wByteOffsetCalc =wEntryIndexCalc * wBYTEperENTRY;
	//Byte offset of the current weight entry from the weight base address.
	wire [31:0] wLineIndexCalc  =wByteOffsetCalc >> 4;
	//DDR 128bit line index. One line is 16 Bytes.
	wire [3:0]  wByteInLineCalc =wByteOffsetCalc[3:0];
	//Start byte position inside the 128bit line

	reg [7:0] xValueReg;
	reg [7:0] wValueReg [0:tile-1];
	localparam [4:0] S_PRE_MAC =5'd12;

	//########################################
	//##            FUNCTIONs               ##
	//########################################
	function [7:0] getByte128;
		input [127:0] word;
		input integer byteIndex;begin
			if(byte0LSB) getByte128 =word[byteIndex*8+:8];
			else         getByte128 =word[(15-byteIndex)*8+:8];
		end
	endfunction
	function signed [accWidth-1:0] inputExtend;
		input [inWidth-1:0] inValue;begin
			if(inSigned) inputExtend ={{(accWidth-inWidth){inValue[inWidth-1]}},inValue};
			else         inputExtend ={{(accWidth-inWidth){1'b0}},inValue};
		end
	endfunction
	function signed [accWidth-1:0] weightExtend;
		input [7:0] inValue;begin
			weightExtend ={{(accWidth-8){inValue[7]}},inValue};
		end
	endfunction
	function signed [accWidth-1:0] biasExtend32;
		input [31:0] inValue;begin
			if(accWidth==32) biasExtend32 =inValue;
			else             biasExtend32 ={{(accWidth-32){inValue[31]}},inValue};
		end
	endfunction
	function signed [accWidth-1:0] relu;
		input signed [accWidth-1:0] inValue;begin
			if(inValue[accWidth-1]) relu ={accWidth{1'b0}};
			else                    relu =inValue;
		end
	endfunction
	//########################################
	//##            MAIN FSMs               ##
	//########################################
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=S_IDLE;
			busy <=1'b0;
			done <=1'b0;
			ddrAddr <={addrWidth{1'b0}};
			ddrRstrobe <=1'b0;
			outFlat <={(outNum*accWidth){1'b0}};
			inLastADDR <={addrWidth{1'b0}};
			wLastADDR <={addrWidth{1'b0}};
			bLastADDR <={addrWidth{1'b0}};
			LastReadADDR <={addrWidth{1'b0}};
			{configError,payloadSizeError,ddrReadError} <=3'b000;
			xLineIdx         <=32'd0;
			biasLineIdx      <=32'd0;
			inIdx            <={inIDXwidth{1'b0}};
			tileIdx          <={tileIDXwidth{1'b0}};
			rdBuf            <=128'd0;
			weightByteInLine <=4'd0;
			debugInIdx       <=32'd0;
			debugtileIdx     <=32'd0;
			debugReadLine    <=32'd0;
			for(i=0;i<tile;i=i+1) acc[i] <={accWidth{1'b0}};
			
			xValueReg <=8'd0;
			for(i=0;i<tile;i=i+1) begin
				wValueReg[i] <=8'd0;
			end
		end
		else begin
			done       <=1'b0;
			ddrRstrobe <=1'b0;
			debugInIdx   <={{(32-inIDXwidth){1'b0}}, inIdx};
			debugtileIdx <={{(32-tileIDXwidth){1'b0}}, tileIdx};
			case(state)
				//Wait for start.
				S_IDLE:begin
					busy <=1'b0;
					if(start)begin
						busy <=1'b1;
						{configError,payloadSizeError,ddrReadError} <=3'b000;
						outFlat <={(outNum*accWidth){1'b0}};
						if((inWidth!=8)||(wWidth!=8)||(bWidth!=32)||(accWidth<32)||
							((outNum%tile)!=0)||(wBYTEperENTRY>ddrBytes)||(bBYTEperTILE>256))begin
							configError <=1'b1;
							state       <=S_ERROR;
						end
						else if(checkPB&&((inPB<inBytesTotal)||(wPB<wBYTEtotal)||(bPB<bBYTEtotal)))begin
							payloadSizeError <=1'b1;
							state            <=S_ERROR;
						end
						else begin
							xLineIdx    <=32'd0;
							biasLineIdx <=32'd0;
							inIdx       <={inIDXwidth{1'b0}};
							tileIdx     <={tileIDXwidth{1'b0}};
							inLastADDR  <=inBaseADDR +((inLines-1)*addrStride);
							wLastADDR   <=wBaseADDR+((wLINEStotal-1)*addrStride);
							bLastADDR   <=bBaseADDR+((bLINEStotal-1)*addrStride);
							state       <=S_LOAD_X_REQ;
						end
					end
				end
				//Load input vector from DDR into xMem.
				S_LOAD_X_REQ:begin
					if(ddrReady)begin
						ddrAddr       <=inBaseADDR+(xLineIdx*addrStride);
						LastReadADDR  <=inBaseADDR+(xLineIdx*addrStride);
						debugReadLine <=xLineIdx;
						ddrRstrobe    <=1'b1;
						state         <=S_LOAD_X_WAIT;
					end
				end
				S_LOAD_X_WAIT:begin
					if(ddrTranComp)begin
						rdBuf <=ddrData;
						for (i=0;i<ddrBytes;i=i+1)begin
							if((xLineIdx*ddrBytes+i)<inNum) xMem[xLineIdx*ddrBytes+i] <=getByte128(ddrData,i);
						end
						if(xLineIdx==(inLines-1))begin
							tileIdx     <={tileIDXwidth{1'b0}};
							biasLineIdx <=32'd0;
							state       <=S_BIAS_REQ;
						end
						else begin
							xLineIdx <=xLineIdx+32'd1;
							state    <=S_LOAD_X_REQ;
						end
					end
				end
				//Load one bias tile. Bias layout: bias[0], bias[1], ... bias[outNum-1]
				//Each bias is little-endian int32.
				S_BIAS_REQ:begin
					if(ddrReady)begin
						ddrAddr       <=bBaseADDR+(((tileIdx*bLINEperTILE)+biasLineIdx)*addrStride);
						LastReadADDR  <=bBaseADDR+(((tileIdx*bLINEperTILE)+biasLineIdx)*addrStride);
						debugReadLine <=(tileIdx*bLINEperTILE)+biasLineIdx;
						ddrRstrobe    <=1'b1;
						state         <=S_BIAS_WAIT;
					end
				end
				S_BIAS_WAIT:begin
					if(ddrTranComp)begin
						for (i =0; i<ddrBytes; i =i+1)begin
							if((biasLineIdx*ddrBytes+i)<bBYTEperTILE) biasByteMem[biasLineIdx*ddrBytes+i] <=getByte128(ddrData, i);
						end
						if(biasLineIdx==(bLINEperTILE-1)) state <=S_BIAS_INIT;
						else begin
							biasLineIdx <=biasLineIdx+32'd1;
							state       <=S_BIAS_REQ;
						end
					end
				end
				S_BIAS_INIT:begin
					for (i=0;i<tile;i=i+1) acc[i] <=biasExtend32({biasByteMem[i*4+3],biasByteMem[i*4+2],biasByteMem[i*4+1],biasByteMem[i*4+0]});
					inIdx <={inIDXwidth{1'b0}};
					state <=S_W_REQ;
				end
				//Read one weight entry. For tile=8 and wWidth=8, one entry is 8 bytes.
				S_W_REQ:begin
					weightByteInLine <=wByteInLineCalc;
					if((wByteInLineCalc+wBYTEperENTRY)>ddrBytes)begin
						ddrReadError <=1'b1;
						state        <=S_ERROR;
					end
					else if(ddrReady)begin
						ddrAddr       <=wBaseADDR+(wLineIndexCalc*addrStride);
						LastReadADDR  <=wBaseADDR+(wLineIndexCalc*addrStride);
						debugReadLine <=wLineIndexCalc;
						ddrRstrobe    <=1'b1;
						state         <=S_W_WAIT;
					end
				end
				S_W_WAIT:begin
					if(ddrTranComp)begin
						rdBuf <=ddrData;
						state <=S_PRE_MAC;
					end
				end
				S_PRE_MAC:begin
					xValueReg <=xMem[inIdx];
					for(i=0;i<tile;i=i+1) wValueReg[i] <=getByte128(rdBuf,weightByteInLine+i);
					state <=S_MAC;
				end
				S_MAC:begin
					for(i=0;i<tile;i=i+1)begin
						acc[i] <=acc[i]+($signed(inputExtend(xValueReg))*$signed(weightExtend(wValueReg[i])));
					end

					if(inIdx==(inNum-1)) state <=S_WRITE_OUT;
					else begin
						inIdx <=inIdx+1'b1;
						state <=S_W_REQ;
					end
				end
				//Store one output tile into outFlat.
				S_WRITE_OUT:begin
					for(i=0;i<tile;i =i+1) outFlat[((tileIdx*tile+i)*accWidth)+:accWidth] <=relu(acc[i]);
					if(tileIdx==(tileNum-1))state <=S_DONE;
					else begin
						tileIdx     <=tileIdx+1'b1;
						biasLineIdx <=32'd0;
						inIdx       <={inIDXwidth{1'b0}};
						state       <=S_BIAS_REQ;
					end
				end
				S_DONE:begin
					busy <=1'b0;
					done <=1'b1;
					state <=S_IDLE;
				end
				S_ERROR:begin
					busy <=1'b0;
					state <=S_IDLE;
				end
				default:state <=S_IDLE;
			endcase
		end
	end
endmodule