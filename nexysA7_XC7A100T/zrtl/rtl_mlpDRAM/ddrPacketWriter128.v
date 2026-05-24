`timescale 1ns/1ps

module ddrPacketWriter128#(
	parameter ADDRwidth =27,
	parameter [ADDRwidth-1:0] ADDRstride =27'd8,
	parameter [7:0] PACKETimg =8'h01,
	parameter [7:0] PACKETparam =8'h02,
	parameter [7:0] PACKETparamW =8'h00,
	parameter [7:0] PACKETparamB =8'h01)(
	input wire clk,
	input wire rst,
	//Optional allocator control.
	//Use this to set the first DDR write address.
	input  wire                 baseAddrLoad,
	input  wire [ADDRwidth-1:0] baseAddrValue,

	input wire [5:0]  statusFlags,
	input wire [55:0] headerInfo,
	input wire [63:0] imageInfo,
	input wire [63:0] paramInfo,
	input wire [39:0] payloadInfo,
	input wire [4:0]  payloadFlags,
	//Interface to mig_ui128
	output reg  [ADDRwidth-1:0] ddrAddr,
	output reg  [127:0]         ddrData,
	output reg                  ddrWstrobe,
	input  wire                 ddrReady,
	input  wire                 ddrTranComp,//ddrTransactionComplete
	//Current allocator pointer.
	//This points to the first free DDR address.
	output reg  [ADDRwidth-1:0] allocPtr,
	//Address result for the packet just written
	output reg                  writeDone,
	output reg  [ADDRwidth-1:0] pStartAddr,//packetStartAddr
	output reg  [ADDRwidth-1:0] pLastAddr,
	output reg  [ADDRwidth-1:0] pNextAddr,
	output reg                  pLastAddrValid,
	//Packet metadata captured with the address result
	output reg  [7:0]            wPacketType,//writtenPacketType
	output reg  [7:0]            wFlags,
	output reg  [7:0]            wLayerID,
	output reg  [7:0]            wParamType,
	output reg  [15:0]           wBitWidth,
	output reg  [31:0]           wElemCount,
	output reg  [31:0]           wBatchID,
	output reg  [15:0]           wBatchSize,
	output reg  [15:0]           wVectorLEN,
	//Statistics
	output reg  [31:0]           writtenPayloadBytes,
	output reg  [31:0]           writtenWordCount,
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

	reg [2:0]           state;
	reg [127:0]         packData;
	reg [3:0]           packByteCount;
	reg [ADDRwidth-1:0] writeAddr;
	reg                 writeBusy;
	reg [31:0] rxPayloadByteCount;

	wire headerValid,payloadValid,packetDone,packetError,checksumError,headerError;
	wire [7:0] version,packetType,flags,layerID,paramType,payloadData;
	wire [15:0] batchSize,vectorLEN,bitWidth;
	wire [31:0] payloadLEN,batchID,elemCount,payloadIndex;
	assign {headerError,checksumError,packetError,packetDone,payloadValid,headerValid} =statusFlags;
	assign {payloadLEN,flags,packetType,version} =headerInfo;
	assign {elemCount,bitWidth,paramType,layyerID} =paramInfo;
	assign {payloadIndex,payloadData} =payloadInfo;

	wire writeBusyEffective;
	wire [127:0] packData128;
	wire [127:0] fullWordData;
	wire packWordFull;

	assign busy =(state !=IDLEs);
	assign writeBusyEffective =writeBusy && !ddrTranComp;
	assign packData128 =setBYTE128(packData,packByteCount,payloadData);

	// Timing-optimized full-word path.
	// When packWordFull is true, packByteCount is 15, so the incoming byte
	// always belongs to ddrData[127:120]. This avoids using the variable-index
	// byte insertion mux on the packData -> ddrData timing path.
	assign fullWordData ={payloadData, packData[119:0]};
	assign packWordFull =(packByteCount ==4'd15);

	function  [127:0] setBYTE128;
		input [127:0] din;
		input [3:0]   byte_index;
		input [7:0]   byte_value;
		reg [127:0]   tmp;begin
			tmp =din;
			tmp[byte_index*8+:8] =byte_value;
			setBYTE128 =tmp;
		end
	endfunction

	always @(posedge clk)begin
		if (rst) begin
			state               <=IDLEs;

			ddrAddr             <={ADDRwidth{1'b0}};
			ddrData             <=128'd0;
			ddrWstrobe          <=1'b0;

			allocPtr            <={ADDRwidth{1'b0}};

			pStartAddr     <={ADDRwidth{1'b0}};
			pLastAddr      <={ADDRwidth{1'b0}};
			pNextAddr      <={ADDRwidth{1'b0}};
			pLastAddrValid <=1'b0;

			writeDone           <=1'b0;

			wPacketType   <=8'd0;
			wFlags        <=8'd0;
			wLayerID      <=8'd0;
			wParamType    <=8'd0;
			wBitWidth     <=16'd0;
			wElemCount    <=32'd0;
			wBatchID      <=32'd0;
			wBatchSize    <=16'd0;
			wVectorLEN    <=16'd0;

			writtenPayloadBytes <=32'd0;
			writtenWordCount    <=32'd0;

			writerErrorFlags <=4'd0;

			packData            <=128'd0;
			packByteCount       <=4'd0;

			writeAddr           <={ADDRwidth{1'b0}};
			writeBusy           <=1'b0;

			rxPayloadByteCount  <=32'd0;
		end
		else begin
			ddrWstrobe      <=1'b0;
			writeDone       <=1'b0;

			writerErrorFlags <=4'd0;

			if(baseAddrLoad && (state ==IDLEs)) allocPtr <=baseAddrValue;

			if (writeBusy && ddrTranComp) writeBusy <=1'b0;

			case(state)

				IDLEs: begin
					packData           <=128'd0;
					packByteCount      <=4'd0;
					rxPayloadByteCount <=32'd0;

					if (headerValid) begin
						pStartAddr     <=allocPtr;
						pLastAddr      <=allocPtr;
						pNextAddr      <=allocPtr;
						pLastAddrValid <=1'b0;

						writeAddr           <=allocPtr;

						writtenPayloadBytes <=payloadLEN;
						writtenWordCount    <=32'd0;

						wPacketType   <=packetType;
						wFlags        <=flags;

						wLayerID      <=layerID;
						wParamType    <=paramType;
						wBitWidth     <=bitWidth;
						wElemCount    <=elemCount;

						wBatchID      <=batchID;
						wBatchSize    <=batchSize;
						wVectorLEN    <=vectorLEN;

						state <=RXs;
					end
				end

				RXs: begin
					if (payloadValid) begin
						if (rxPayloadByteCount >=writtenPayloadBytes) begin
							writerError <=1'b1;
							lengthError <=1'b1;
							state       <=DROPs;
						end
						else begin
							rxPayloadByteCount <=rxPayloadByteCount + 32'd1;

							if (packWordFull) begin
								if (writeBusyEffective || !ddrReady) begin
									writerError   <=1'b1;
									overflowError <=1'b1;
									state         <=DROPs;
								end
								else begin
									ddrAddr    <=writeAddr;

									// Timing-optimized path:
									// Do not use set_byte_128() here.
									// The incoming payloadData is byte 15.
									ddrData    <=fullWordData;

									ddrWstrobe <=1'b1;

									writeBusy  <=1'b1;

									pLastAddr      <=writeAddr;
									pNextAddr      <=writeAddr + ADDRstride;
									pLastAddrValid <=1'b1;

									writeAddr        <=writeAddr + ADDRstride;
									writtenWordCount <=writtenWordCount + 32'd1;

									packData      <=128'd0;
									packByteCount <=4'd0;
								end
							end
							else begin
								packData      <=packData128;
								packByteCount <=packByteCount + 4'd1;
							end
						end
					end

					if (packetDone) begin
						if (packetError) begin
							writerError <=1'b1;
							state       <=DROPs;
						end
						else if (rxPayloadByteCount !=writtenPayloadBytes) begin
							writerError <=1'b1;
							lengthError <=1'b1;
							state       <=DROPs;
						end
						else if(packByteCount !=4'd0) state <=FLUSHs;
						else if(writeBusyEffective)   state <=WAITs;
						else begin
							allocPtr  <=pNextAddr;
							writeDone <=1'b1;
							state     <=IDLEs;
						end
					end
				end

				// Write the final partial 128-bit word.
				// Unused upper bytes are zero-padded.
				FLUSHs: begin
					if (!writeBusyEffective && ddrReady) begin
						ddrAddr    <=writeAddr;
						ddrData    <=packData;
						ddrWstrobe <=1'b1;

						writeBusy  <=1'b1;

						pLastAddr      <=writeAddr;
						pNextAddr      <=writeAddr + ADDRstride;
						pLastAddrValid <=1'b1;

						writeAddr        <=writeAddr + ADDRstride;
						writtenWordCount <=writtenWordCount + 32'd1;

						packData      <=128'd0;
						packByteCount <=4'd0;

						state <=WAITs;
					end
				end

				WAITs: begin
					if (!writeBusyEffective) begin
						allocPtr  <=pNextAddr;
						writeDone <=1'b1;
						state     <=IDLEs;
					end
				end

				// Error recovery state.
				// Ignore the rest of the current packet.
				DROPs: begin
					if (packetDone && !writeBusyEffective) begin
						packData      <=128'd0;
						packByteCount <=4'd0;
						state         <=IDLEs;
					end
				end

				default: state <=IDLEs;

			endcase
		end
	end

endmodule