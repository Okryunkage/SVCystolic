`timescale 1ns/1ps

module fc2DDR#(
	parameter addrWidth =27,
	parameter [addrWidth-1:0] addrStride =27'd8,
	parameter tile     =5,
	parameter inNum    =64,
	parameter outNum   =10,
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

	//Input vector from requantize module.
	input wire [(inNum*inWidth-1):0] inFlat,

	input wire [addrWidth-1:0] wBaseADDR,
	input wire [addrWidth-1:0] bBaseADDR,

	//Payload byte counts from ddrADDRbookP.
	input wire [31:0] wPB,
	input wire [31:0] bPB,

	//DDR read interface to current mig_ui128 mux.
	output reg [addrWidth-1:0] ddrAddr,
	output reg                 ddrRstrobe,
	input  wire [127:0]        ddrData,
	input  wire                ddrReady,
	input  wire                ddrTranComp,

	output reg busy,
	output reg done,

	//Final output logits. No ReLU is applied in fc2.
	output reg signed [(outNum*accWidth-1):0] outFlat,

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

	localparam integer wBYTEperELEM  =(wWidth+7)/8;
	localparam integer wBYTEperENTRY =tile*wBYTEperELEM;
	localparam integer wBYTEtotal    =tileNum*inNum*wBYTEperENTRY;
	localparam integer wLINEStotal   =(wBYTEtotal+ddrBytes-1)/ddrBytes;

	localparam integer bBYTEperELEM  =(bWidth+7)/8;
	localparam integer bBYTEperTILE  =tile*bBYTEperELEM;
	localparam integer bBYTEtotal    =outNum*bBYTEperELEM;
	localparam integer bLINEStotal   =(bBYTEtotal+ddrBytes-1)/ddrBytes;

	localparam [4:0] S_IDLE        =5'd0;
	localparam [4:0] S_BIAS_REQ    =5'd1;
	localparam [4:0] S_BIAS_WAIT   =5'd2;
	localparam [4:0] S_BIAS_INIT   =5'd3;
	localparam [4:0] S_W_REQ       =5'd4;
	localparam [4:0] S_W_WAIT      =5'd5;
	localparam [4:0] S_W_REQ2      =5'd6;
	localparam [4:0] S_W_WAIT2     =5'd7;
	localparam [4:0] S_MAC         =5'd8;
	localparam [4:0] S_WRITE_OUT   =5'd9;
	localparam [4:0] S_DONE        =5'd10;
	localparam [4:0] S_ERROR       =5'd11;
	localparam [4:0] S_PRE_MAC     =5'd12;

	reg [4:0] state;

	assign debugState =state;
	assign error      =configError|payloadSizeError|ddrReadError;

	reg [31:0] biasLineIdx;

	reg [inIDXwidth-1:0]   inIdx;
	reg [tileIDXwidth-1:0] tileIdx;

	reg [127:0] rdBuf;
	reg [127:0] rdBuf2;

	reg [3:0]  weightByteInLine;
	reg [31:0] weightLineIndex;
	reg        weightCrossLine;

	reg signed [accWidth-1:0] acc [0:tile-1];

	reg [7:0] biasByteMem [0:bBYTEperTILE-1];

	//Pipeline registers for timing improvement.
	reg [inWidth-1:0] xValueReg;
	reg [7:0]         wValueReg [0:tile-1];

	integer i;

	//Weight layout:
	//For each tile and input index, one entry contains 'tile' weights.
	//With tile=5 and wWidth=8, one entry is 5 bytes.
	wire [31:0] wEntryIndexCalc =(tileIdx*inNum)+inIdx;
	wire [31:0] wByteOffsetCalc =wEntryIndexCalc*wBYTEperENTRY;
	wire [31:0] wLineIndexCalc  =wByteOffsetCalc>>4;
	wire [3:0]  wByteInLineCalc =wByteOffsetCalc[3:0];
	wire        wCrossLineCalc  =((wByteInLineCalc+wBYTEperENTRY)>ddrBytes);

	//Bias layout:
	//bias[0], bias[1], ..., bias[9]
	//No tile padding is required.
	wire [31:0] bByteOffsetCalc =tileIdx*bBYTEperTILE;
	wire [31:0] bLineIndexCalc  =bByteOffsetCalc>>4;
	wire [3:0]  bByteInLineCalc =bByteOffsetCalc[3:0];
	wire [31:0] bLineReadCountCalc =(({28'd0,bByteInLineCalc}+bBYTEperTILE+ddrBytes-1)>>4);

	//########################################
	//##            FUNCTIONs               ##
	//########################################
	function [7:0] getByte128;
		input [127:0] word;
		input integer byteIndex;
		begin
			if(byte0LSB) getByte128 =word[byteIndex*8+:8];
			else         getByte128 =word[(15-byteIndex)*8+:8];
		end
	endfunction

	function [7:0] getWeightByte;
		input [127:0] word0;
		input [127:0] word1;
		input [3:0]   startByte;
		input integer laneIndex;
		integer bytePos;
		begin
			bytePos =startByte+laneIndex;
			if(bytePos<16) getWeightByte =getByte128(word0,bytePos);
			else           getWeightByte =getByte128(word1,bytePos-16);
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
		input [31:0] inValue;
		begin
			if(accWidth==32) biasExtend32 =inValue;
			else             biasExtend32 ={{(accWidth-32){inValue[31]}},inValue};
		end
	endfunction

	//########################################
	//##            MAIN FSMs               ##
	//########################################
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=S_IDLE;
			busy  <=1'b0;
			done  <=1'b0;

			ddrAddr    <={addrWidth{1'b0}};
			ddrRstrobe <=1'b0;

			outFlat <={(outNum*accWidth){1'b0}};

			wLastADDR    <={addrWidth{1'b0}};
			bLastADDR    <={addrWidth{1'b0}};
			LastReadADDR <={addrWidth{1'b0}};

			{configError,payloadSizeError,ddrReadError} <=3'b000;

			biasLineIdx      <=32'd0;
			inIdx            <={inIDXwidth{1'b0}};
			tileIdx          <={tileIDXwidth{1'b0}};

			rdBuf            <=128'd0;
			rdBuf2           <=128'd0;
			weightByteInLine <=4'd0;
			weightLineIndex  <=32'd0;
			weightCrossLine  <=1'b0;

			xValueReg        <={inWidth{1'b0}};

			debugInIdx       <=32'd0;
			debugtileIdx     <=32'd0;
			debugReadLine    <=32'd0;

			for(i=0;i<tile;i=i+1)begin
				acc[i]       <={accWidth{1'b0}};
				wValueReg[i] <=8'd0;
			end
		end
		else begin
			done       <=1'b0;
			ddrRstrobe <=1'b0;

			debugInIdx   <={{(32-inIDXwidth){1'b0}},inIdx};
			debugtileIdx <={{(32-tileIDXwidth){1'b0}},tileIdx};

			case(state)
				//Wait for start.
				S_IDLE:begin
					busy <=1'b0;

					if(start)begin
						busy <=1'b1;
						{configError,payloadSizeError,ddrReadError} <=3'b000;
						outFlat <={(outNum*accWidth){1'b0}};

						if((tile!=5)||(inWidth!=8)||(wWidth!=8)||(bWidth!=32)||(accWidth<32)||
							((outNum%tile)!=0)||(wBYTEperENTRY>ddrBytes)||(bBYTEperTILE>256))begin
							configError <=1'b1;
							state       <=S_ERROR;
						end
						else if(checkPB&&((wPB<wBYTEtotal)||(bPB<bBYTEtotal)))begin
							payloadSizeError <=1'b1;
							state            <=S_ERROR;
						end
						else begin
							biasLineIdx <=32'd0;
							inIdx       <={inIDXwidth{1'b0}};
							tileIdx     <={tileIDXwidth{1'b0}};

							wLastADDR <=wBaseADDR+((wLINEStotal-1)*addrStride);
							bLastADDR <=bBaseADDR+((bLINEStotal-1)*addrStride);

							state <=S_BIAS_REQ;
						end
					end
				end

				//Load one bias tile.
				//Bias is stored contiguously without tile padding.
				S_BIAS_REQ:begin
					if(ddrReady)begin
						ddrAddr       <=bBaseADDR+((bLineIndexCalc+biasLineIdx)*addrStride);
						LastReadADDR  <=bBaseADDR+((bLineIndexCalc+biasLineIdx)*addrStride);
						debugReadLine <=bLineIndexCalc+biasLineIdx;
						ddrRstrobe    <=1'b1;
						state         <=S_BIAS_WAIT;
					end
				end

				S_BIAS_WAIT:begin
					if(ddrTranComp)begin
						for(i=0;i<ddrBytes;i=i+1)begin
							if((((bLineIndexCalc+biasLineIdx)*ddrBytes+i)>=bByteOffsetCalc)&&
							   (((bLineIndexCalc+biasLineIdx)*ddrBytes+i)<(bByteOffsetCalc+bBYTEperTILE)))begin
								biasByteMem[((bLineIndexCalc+biasLineIdx)*ddrBytes+i)-bByteOffsetCalc]
									<=getByte128(ddrData,i);
							end
						end

						if(biasLineIdx==(bLineReadCountCalc-1))begin
							state <=S_BIAS_INIT;
						end
						else begin
							biasLineIdx <=biasLineIdx+32'd1;
							state       <=S_BIAS_REQ;
						end
					end
				end

				S_BIAS_INIT:begin
					for(i=0;i<tile;i=i+1)begin
						acc[i] <=biasExtend32({
							biasByteMem[i*4+3],
							biasByteMem[i*4+2],
							biasByteMem[i*4+1],
							biasByteMem[i*4+0]
						});
					end

					inIdx <={inIDXwidth{1'b0}};
					state <=S_W_REQ;
				end

				//Read one weight entry.
				//With tile=5, one entry is 5 bytes.
				//Some entries cross a 16-byte DDR line, so two reads may be needed.
				S_W_REQ:begin
					weightByteInLine <=wByteInLineCalc;
					weightLineIndex  <=wLineIndexCalc;
					weightCrossLine  <=wCrossLineCalc;

					if(ddrReady)begin
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

						if(weightCrossLine)begin
							state <=S_W_REQ2;
						end
						else begin
							state <=S_PRE_MAC;
						end
					end
				end

				S_W_REQ2:begin
					if(ddrReady)begin
						ddrAddr       <=wBaseADDR+((weightLineIndex+32'd1)*addrStride);
						LastReadADDR  <=wBaseADDR+((weightLineIndex+32'd1)*addrStride);
						debugReadLine <=weightLineIndex+32'd1;
						ddrRstrobe    <=1'b1;
						state         <=S_W_WAIT2;
					end
				end

				S_W_WAIT2:begin
					if(ddrTranComp)begin
						rdBuf2 <=ddrData;
						state  <=S_PRE_MAC;
					end
				end

				//Pipeline stage before MAC.
				//This breaks the long path:
				//inIdx/inFlat select + weight byte select + multiply + add.
				S_PRE_MAC:begin
					xValueReg <=inFlat[(inIdx*inWidth)+:inWidth];

					for(i=0;i<tile;i=i+1)begin
						wValueReg[i] <=getWeightByte(rdBuf,rdBuf2,weightByteInLine,i);
					end

					state <=S_MAC;
				end

				//MAC: acc[lane] += input[inIdx] * weight[tile lane][inIdx]
				S_MAC:begin
					for(i=0;i<tile;i=i+1)begin
						acc[i] <=acc[i]
								+($signed(inputExtend(xValueReg))
								*$signed(weightExtend(wValueReg[i])));
					end

					if(inIdx==(inNum-1))begin
						state <=S_WRITE_OUT;
					end
					else begin
						inIdx <=inIdx+1'b1;
						state <=S_W_REQ;
					end
				end

				//Store one output tile into outFlat.
				//No ReLU is applied in fc2.
				S_WRITE_OUT:begin
					for(i=0;i<tile;i=i+1)begin
						outFlat[((tileIdx*tile+i)*accWidth)+:accWidth] <=acc[i];
					end

					if(tileIdx==(tileNum-1))begin
						state <=S_DONE;
					end
					else begin
						tileIdx     <=tileIdx+1'b1;
						biasLineIdx <=32'd0;
						inIdx       <={inIDXwidth{1'b0}};
						state       <=S_BIAS_REQ;
					end
				end

				S_DONE:begin
					busy  <=1'b0;
					done  <=1'b1;
					state <=S_IDLE;
				end

				S_ERROR:begin
					busy  <=1'b0;
					state <=S_IDLE;
				end

				default:begin
					state <=S_IDLE;
				end
			endcase
		end
	end
endmodule