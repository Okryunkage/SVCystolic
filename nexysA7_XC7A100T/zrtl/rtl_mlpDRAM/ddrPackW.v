`timescale 1ns/1ps

module ddrPackW128#(
	parameter ADDRwidth =27,
	parameter [(ADDRwidth-1):0] ADDRstride =27'd8,
	parameter [7:0] PACKETimg =8'h01,
	parameter [7:0] PACKETparam =8'h02,
	parameter [7:0] PACKETparamW =8'h00,
	parameter [7:0] PACKETparamB =8'h01)(
	input wire clk,
	input wire rst,
	//Optional allocator control.
	//Use this to set the first DDR write address.
	input  wire                   baseAddrLoad,
	input  wire [(ADDRwidth-1):0] baseAddrValue,

	input wire [5:0]  statusFlags,
	input wire [55:0] headerInfo,
	input wire [63:0] imageInfo,
	input wire [63:0] paramInfo,
	input wire [39:0] payloadInfo,
	input wire [4:0]  payloadFlags,
	//Interface to mig_ui128
	output reg  [(ADDRwidth-1):0] ddrAddr,
	output reg  [127:0]           ddrData,
	output reg                    ddrWstrobe,
	input  wire                   ddrReady,
	input  wire                   ddrTranComp,//ddrTransactionComplete
	//Current allocator pointer.
	//This points to the first free DDR address.
	output reg  [(ADDRwidth-1):0] allocPtr,
	//Address result for the packet just written
	output reg                    writeDone,
	output reg  [(ADDRwidth-1):0] pStartAddr,//packetStartAddr
	output reg  [(ADDRwidth-1):0] pLastAddr,
	output reg  [(ADDRwidth-1):0] pNextAddr,
	output reg                    pLastAddrValid,
	//Packet metadata captured with the address result
	//{wPacketType[8],wFlags[8],wLayerID[8],wParamType[8],wBitWidth[16],
	//wElemCount[32],wBatchID[32],wBatchSize[16],wVectorLEN[16]} =wMetaInfo
	output reg [143:0]           wMetaInfo,//writtenMetaInfo
	//Statistics
	output reg  [31:0]           wPayloadBytes,
	output reg  [31:0]           wWordCount,
	//Error outputs
	//writerErrorFlags ={unexpectedError,lengthError,overflowError,writerError}
	output reg  [3:0] writerErrorFlags,
	output wire       busy);

	localparam [2:0] IDLEs  =3'd0;
	localparam [2:0] RXs    =3'd1;
	localparam [2:0] FLUSHs =3'd2;
	localparam [2:0] WAITs  =3'd3;
	localparam [2:0] DROPs  =3'd4;
	localparam integer wERRwriter =0;
	localparam integer wERRovf    =1;
	localparam integer wERRlen    =2;
	localparam integer WERRunexp  =3;

	reg [2:0]             state;
	reg [127:0]           packData;
	reg [3:0]             packByteCount;
	reg [(ADDRwidth-1):0] writeAddr;
	reg                   writeBusy;
	reg [31:0] rxPayloadByteCount;

	wire headerValid,payloadValid,packetDone,packetError,checksumError,headerError;
	wire [7:0] version,packetType,flags,layerID,paramType,payloadData;
	wire [15:0] batchSize,vectorLEN,bitWidth;
	wire [31:0] payloadLEN,batchID,elemCount,payloadIndex;
	assign {headerError,checksumError,packetError,packetDone,payloadValid,headerValid} =statusFlags;
	assign {vectorLEN,batchSize,batchID} =imageInfo;
	assign {payloadLEN,flags,packetType,version} =headerInfo;
	assign {elemCount,bitWidth,paramType,layerID} =paramInfo;
	assign {payloadIndex,payloadData} =payloadInfo;

	wire writeBusyEffective;
	wire [127:0] shiftedPackData;
	wire [127:0] fullWordData;
	wire packWordFull;

	assign busy =(state !=IDLEs);
	assign writeBusyEffective =writeBusy && !ddrTranComp;

	assign shiftedPackData ={payloadData,packData[127:8]};
	assign fullWordData =shiftedPackData;//just to seperate the meaning from shiftedPackData
	assign packWordFull =(packByteCount==4'd15);

	reg dropNeedPacketEnd;
	/*
	dropNeedPacketEnd indicates whether this writer must wait until the currnet UART packet reaches its end before returning to IDLE.
	1'b1: The writer detected an internal error in the middle of receiving the payload, such as DDR overflow or payload length overflow.
	      In this case, the decoder may stil be receiving the reset of the current apcket.
		  Therefore, the writer must stay in DROPs until packetDone or packetError is asserted.
	1'b0: The decoder itself has already reported packetError, or the packet has already reached its end.
	      In this case, the writer does not need to wait for another packetDone pulse and can safely return to IDLE once any pending DDR transaction is complete.
	*/

	reg [127:0] flushWordData;
	//flushWordData value is chosen by the case funciton below
	//the complex case function can be synthesised to complex MUX
	//To mitigate the delay induced by this MUX, the pipeline-REG flushWordReg is added.
	always@(*)begin
		case(packByteCount)
			4'd0:flushWordData =128'd0;
			4'd1:flushWordData ={120'd0,packData[127:120]};
			4'd2:flushWordData ={112'd0,packData[127:112]};
			4'd3:flushWordData ={104'd0,packData[127:104]};
			4'd4:flushWordData ={96'd0,packData[127:96]};
			4'd5:flushWordData ={88'd0,packData[127:88]};
			4'd6:flushWordData ={80'd0,packData[127:80]};
			4'd7:flushWordData ={72'd0,packData[127:72]};
			4'd8:flushWordData ={64'd0,packData[127:64]};
			4'd9:flushWordData ={56'd0,packData[127:56]};
			4'd10:flushWordData ={48'd0,packData[127:48]};
			4'd11:flushWordData ={40'd0,packData[127:40]};
			4'd12:flushWordData ={32'd0,packData[127:32]};
			4'd13:flushWordData ={24'd0,packData[127:24]};
			4'd14:flushWordData ={16'd0,packData[127:16]};
			4'd15:flushWordData ={8'd0,packData[127:8]};
			default:flushWordData =128'd0;
		endcase
	end
	reg [127:0] flushWordReg;

	always@(posedge clk)begin
		if (rst) begin
			state          <=IDLEs;
			ddrAddr        <={ADDRwidth{1'b0}};
			ddrData        <=128'd0;
			ddrWstrobe     <=1'b0;
			allocPtr       <={ADDRwidth{1'b0}};
			pStartAddr     <={ADDRwidth{1'b0}};
			pLastAddr      <={ADDRwidth{1'b0}};
			pNextAddr      <={ADDRwidth{1'b0}};
			pLastAddrValid <=1'b0;
			writeDone      <=1'b0;
			wMetaInfo      <=144'd0;
			{wPayloadBytes,wWordCount} <=64'd0;
			writerErrorFlags <=4'd0;
			packData         <=128'd0;
			packByteCount    <=4'd0;
			writeAddr        <={ADDRwidth{1'b0}};
			writeBusy        <=1'b0;
			rxPayloadByteCount <=32'd0;

			dropNeedPacketEnd <=1'b0;
			flushWordReg      <=128'd0;
		end
		else begin
			ddrWstrobe       <=1'b0;
			writeDone        <=1'b0;
			writerErrorFlags <=4'd0;
			if(baseAddrLoad&&(state==IDLEs)) allocPtr <=baseAddrValue;
			if(writeBusy&&ddrTranComp) writeBusy <=1'b0;
			case(state)
				IDLEs:begin
					packData           <=128'd0;
					packByteCount      <=4'd0;
					rxPayloadByteCount <=32'd0;
					if(headerValid)begin
						pStartAddr     <=allocPtr;
						pLastAddr      <=allocPtr;
						pNextAddr      <=allocPtr;
						pLastAddrValid <=1'b0;
						writeAddr      <=allocPtr;
						wPayloadBytes <=payloadLEN;
						wWordCount    <=32'd0;
						wMetaInfo     <={packetType,flags,layerID,paramType,
							bitWidth,elemCount,batchID,batchSize,vectorLEN};
						dropNeedPacketEnd <=1'b0;
						state <=RXs;
					end
				end
				RXs:begin
					if(payloadValid)begin
						if(rxPayloadByteCount >=wPayloadBytes)begin
							{writerErrorFlags[wERRwriter],writerErrorFlags[wERRlen]} <=2'b11;
							dropNeedPacketEnd <=1'b1;//case when ddrPackW detect error
							state <=DROPs;
						end
						else begin
							rxPayloadByteCount <=rxPayloadByteCount+32'd1;
							if(packWordFull)begin
								if (writeBusyEffective || !ddrReady)begin
									{writerErrorFlags[wERRwriter],writerErrorFlags[wERRovf]} <=2'b11;
									dropNeedPacketEnd <=1'b1;//case when ddrPackW detect error
									state <=DROPs;
								end
								else begin
									ddrAddr <=writeAddr;
									ddrData <=fullWordData;//same as shiftedPackData
									ddrWstrobe <=1'b1;
									writeBusy  <=1'b1;
									pLastAddr  <=writeAddr;
									pNextAddr  <=writeAddr+ADDRstride;
									pLastAddrValid <=1'b1;
									writeAddr  <=writeAddr+ADDRstride;
									wWordCount <=wWordCount+32'd1;
									packData   <=128'd0;
									packByteCount <=4'd0;
								end
							end
							else begin
								packData      <=shiftedPackData;
								packByteCount <=packByteCount+4'd1;
							end
						end
					end
					if(packetError)begin
						writerErrorFlags[wERRwriter] <=1'b1;
						dropNeedPacketEnd <=1'b0;//case when DEC detect error
						state <=DROPs;
					end
					else if(packetDone)begin
						//packData doesn't update when packDone goes high | goto flushWordData
						if(rxPayloadByteCount !=wPayloadBytes)begin
							{writerErrorFlags[wERRwriter],writerErrorFlags[wERRlen]} <=2'b11;
							dropNeedPacketEnd <=1'b0;//case when written-payload Bytes are different from decoder
							state <=DROPs;
						end
						else if(packByteCount !=4'd0)begin
							flushWordReg <=flushWordData;//pipline-Reg for flushWordData
							state <=FLUSHs;
						end
						else if(writeBusyEffective) state <=WAITs;
						else begin
							allocPtr  <=pNextAddr;
							writeDone <=1'b1;
							state     <=IDLEs;
						end
					end
				end
				//Write the final partial 128-bit word.
				//Unused upper bytes are zero-padded.
				FLUSHs:begin
					if(!writeBusyEffective && ddrReady)begin
						ddrAddr    <=writeAddr;
						ddrData    <=flushWordReg;
						ddrWstrobe <=1'b1;
						writeBusy  <=1'b1;
						pLastAddr  <=writeAddr;
						pNextAddr  <=writeAddr+ADDRstride;
						pLastAddrValid <=1'b1;
						writeAddr  <=writeAddr+ADDRstride;
						wWordCount <=wWordCount+32'd1;
						packData   <=128'd0;
						packByteCount <=4'd0;
						state <=WAITs;
					end
				end
				WAITs:begin
					if(!writeBusyEffective)begin
						allocPtr  <=pNextAddr;
						writeDone <=1'b1;
						state     <=IDLEs;
					end
				end
				//Error recovery state.
				//Ignore the rest of the current packet.
				DROPs:begin
					if((packetDone||packetError||!dropNeedPacketEnd) && !writeBusyEffective)begin
						packData      <=128'd0;
						packByteCount <=4'd0;
						state         <=IDLEs;
						rxPayloadByteCount <=32'd0;
						dropNeedPacketEnd  <=1'b0;
					end
				end
				default: state <=IDLEs;
			endcase
		end
	end
endmodule