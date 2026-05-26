`timescale 1ns/1ps

module ddrADDRbookP #(
	parameter ADDRwidth =27,
	parameter [ADDRwidth-1:0] RESETbaseADDR ={ADDRwidth{1'b0}},
	parameter [7:0] PACKETimg    =8'h01,
	parameter [7:0] PACKETparam  =8'h02,
	parameter [7:0] PACKETparamW =8'h00,
	parameter [7:0] PACKETparamB =8'h01,
	parameter [7:0] incLABELmask =8'h01)(
	input  wire                  clk,
	input  wire                  rst,
	// Optional clear for sticky error flags.
	input  wire                  clear,
	// From ddrPackW128
	input  wire                  writeDone,
	input  wire [3:0]            writerErrorFlags,
	input  wire [(ADDRwidth-1):0]pStartAddr,
	input  wire [(ADDRwidth-1):0]pNextAddr,
	//wMetaInfo ={packetType[8],flags[8],layerID[8],paramType[8],
	//			bitWidth[16],elemCount[32],batchID[32],batchSize[16],vectorLEN[16]}
	input  wire [143:0]          wMetaInfo,
	input  wire [31:0]           wPayloadBytes,
	//Current allocator pointer mirror.
	output reg  [(ADDRwidth-1):0]nextFreeAddr,
	//validFlags[0] =image
	//validFlags[1] =label
	//validFlags[2] =fc1 weight
	//validFlags[3] =fc1 bias
	//validFlags[4] =fc2 weight
	//validFlags[5] =fc2 bias
	output reg  [5:0]            validFlags,
	//Slot mapping order follows validFlags.
	output reg  [6*ADDRwidth-1:0] startADDRbook,
	//Payload byte count for each slot.
	output reg  [6*32-1:0]        payloadBytesBook,
	//bookErrorFlags[0] =addressBookError
	//bookErrorFlags[1] =unknownPacketError
	//bookErrorFlags[2] =writerReportedError
	output reg  [2:0]             bookErrorFlags);
	localparam integer SLOTimage =0;
	localparam integer SLOTlabel =1;
	localparam integer SLOTfc1W  =2;
	localparam integer SLOTfc1B  =3;
	localparam integer SLOTfc2W  =4;
	localparam integer SLOTfc2B  =5;
	localparam integer BOOKerr      =0;
	localparam integer UNKNOWNerr   =1;
	localparam integer WRITERrepErr =2;
	// ------------------------------------------------------------
	// Stage 0: capture writeDone transaction
	// ------------------------------------------------------------
	reg                         s0_valid;
	reg                         s0_writerError;
	reg [(ADDRwidth-1):0]       s0_pStartAddr;
	reg [(ADDRwidth-1):0]       s0_pNextAddr;
	reg [143:0]                 s0_wMetaInfo;
	reg [31:0]                  s0_wPayloadBytes;

	wire [7:0]  s0_packetType =s0_wMetaInfo[143:136];
	wire [7:0]  s0_flags      =s0_wMetaInfo[135:128];
	wire [7:0]  s0_layerID    =s0_wMetaInfo[127:120];
	wire [7:0]  s0_paramType  =s0_wMetaInfo[119:112];
	wire [15:0] s0_batchSize  =s0_wMetaInfo[31:16];
	wire [15:0] s0_vectorLEN  =s0_wMetaInfo[15:0];

	wire s0_isImage     =(s0_packetType ==PACKETimg);
	wire s0_isParam     =(s0_packetType ==PACKETparam);
	wire s0_isFc1Weight =s0_isParam&&(s0_layerID==8'd1)&(s0_paramType==PACKETparamW);
	wire s0_isFc1Bias   =s0_isParam&&(s0_layerID==8'd1)&&(s0_paramType==PACKETparamB);
	wire s0_isFc2Weight =s0_isParam&&(s0_layerID==8'd2)&&(s0_paramType==PACKETparamW);
	wire s0_isFc2Bias   =s0_isParam&&(s0_layerID==8'd2)&&(s0_paramType==PACKETparamB);
	wire s0_incLABEL    =((s0_flags&incLABELmask)!=8'd0);
	// ------------------------------------------------------------
	// Stage 1: classification register + image byte calculation
	// ------------------------------------------------------------
	reg                         s1_valid;
	reg                         s1_writerError;
	reg [(ADDRwidth-1):0]       s1_pStartAddr;
	reg [(ADDRwidth-1):0]       s1_pNextAddr;
	reg [31:0]                  s1_wPayloadBytes;
	reg                         s1_isImage;
	reg                         s1_isFc1Weight;
	reg                         s1_isFc1Bias;
	reg                         s1_isFc2Weight;
	reg                         s1_isFc2Bias;
	reg                         s1_incLABEL;
	reg [31:0]                  s1_imageBytes;
	reg [31:0]                  s1_labelBytes;
	// ------------------------------------------------------------
	// Stage 2: label start address calculation
	// ------------------------------------------------------------
	reg                         s2_valid;
	reg                         s2_writerError;
	reg [(ADDRwidth-1):0]       s2_pStartAddr;
	reg [(ADDRwidth-1):0]       s2_pNextAddr;
	reg [31:0]                  s2_wPayloadBytes;
	reg                         s2_isImage;
	reg                         s2_isFc1Weight;
	reg                         s2_isFc1Bias;
	reg                         s2_isFc2Weight;
	reg                         s2_isFc2Bias;
	reg                         s2_incLABEL;
	reg [31:0]                  s2_imageBytes;
	reg [31:0]                  s2_labelBytes;
	reg [(ADDRwidth-1):0]       s2_labelStartAddr;
	//imageAddrOffset =ceil(imageBytes/16)*8 =((imageBytes+15)>>4)<<3
	//add imageAddrOffset value to address per one image vector
	wire [31:0] imageAddrOffsetCalc32 =((s1_imageBytes+32'd15)>>4)<<3;
	// ------------------------------------------------------------
	// Pipeline + address book update
	// ------------------------------------------------------------
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			nextFreeAddr     <=RESETbaseADDR;
			validFlags       <=6'd0;
			startADDRbook    <={(6*ADDRwidth){1'b0}};
			payloadBytesBook <={(6*32){1'b0}};
			bookErrorFlags   <=3'd0;

			s0_valid         <=1'b0;
			s0_writerError   <=1'b0;
			s0_pStartAddr    <={ADDRwidth{1'b0}};
			s0_pNextAddr     <={ADDRwidth{1'b0}};
			s0_wMetaInfo     <=144'd0;
			s0_wPayloadBytes <=32'd0;

			s1_valid         <=1'b0;
			s1_writerError   <=1'b0;
			s1_pStartAddr    <={ADDRwidth{1'b0}};
			s1_pNextAddr     <={ADDRwidth{1'b0}};
			s1_wPayloadBytes <=32'd0;

			s1_isImage       <=1'b0;
			s1_isFc1Weight   <=1'b0;
			s1_isFc1Bias     <=1'b0;
			s1_isFc2Weight   <=1'b0;
			s1_isFc2Bias     <=1'b0;
			s1_incLABEL      <=1'b0;

			s1_imageBytes    <=32'd0;
			s1_labelBytes    <=32'd0;

			s2_valid         <=1'b0;
			s2_writerError   <=1'b0;
			s2_pStartAddr    <={ADDRwidth{1'b0}};
			s2_pNextAddr     <={ADDRwidth{1'b0}};
			s2_wPayloadBytes <=32'd0;

			s2_isImage       <=1'b0;
			s2_isFc1Weight   <=1'b0;
			s2_isFc1Bias     <=1'b0;
			s2_isFc2Weight   <=1'b0;
			s2_isFc2Bias     <=1'b0;
			s2_incLABEL      <=1'b0;

			s2_imageBytes    <=32'd0;
			s2_labelBytes    <=32'd0;
			s2_labelStartAddr <={ADDRwidth{1'b0}};
		end
		else begin
			// ----------------------------------------------------
			// Clear only sticky error flags.
			// If a new error happens in the same cycle, it will be set again.
			// ----------------------------------------------------
			if(clear) bookErrorFlags <=3'd0;

			// ----------------------------------------------------
			// Stage 0
			// Capture write result from ddrPackW128.
			// ----------------------------------------------------
			s0_valid         <=writeDone;
			s0_writerError   <=|writerErrorFlags;
			s0_pStartAddr    <=pStartAddr;
			s0_pNextAddr     <=pNextAddr;
			s0_wMetaInfo     <=wMetaInfo;
			s0_wPayloadBytes <=wPayloadBytes;

			// ----------------------------------------------------
			// Stage 1
			// Decode metadata and calculate byte counts.
			// ----------------------------------------------------
			s1_valid         <=s0_valid;
			s1_writerError   <=s0_writerError;
			s1_pStartAddr    <=s0_pStartAddr;
			s1_pNextAddr     <=s0_pNextAddr;
			s1_wPayloadBytes <=s0_wPayloadBytes;

			s1_isImage       <=s0_isImage;
			s1_isFc1Weight   <=s0_isFc1Weight;
			s1_isFc1Bias     <=s0_isFc1Bias;
			s1_isFc2Weight   <=s0_isFc2Weight;
			s1_isFc2Bias     <=s0_isFc2Bias;
			s1_incLABEL      <=s0_incLABEL;
			// Image packet layout:
			//   payload =image bytes + optional label bytes
			//
			// imageBytes =batchSize * vectorLEN
			// labelBytes =batchSize, only when label is included
			s1_imageBytes <={16'd0,s0_batchSize}*{16'd0,s0_vectorLEN};
			s1_labelBytes <=s0_incLABEL?{16'd0,s0_batchSize}:32'd0;
			// ----------------------------------------------------
			// Stage 2
			// Convert image byte count to MIG-style address offset,
			// then calculate label start address.
			// ----------------------------------------------------
			s2_valid         <=s1_valid;
			s2_writerError   <=s1_writerError;
			s2_pStartAddr    <=s1_pStartAddr;
			s2_pNextAddr     <=s1_pNextAddr;
			s2_wPayloadBytes <=s1_wPayloadBytes;

			s2_isImage       <=s1_isImage;
			s2_isFc1Weight   <=s1_isFc1Weight;
			s2_isFc1Bias     <=s1_isFc1Bias;
			s2_isFc2Weight   <=s1_isFc2Weight;
			s2_isFc2Bias     <=s1_isFc2Bias;
			s2_incLABEL      <=s1_incLABEL;

			s2_imageBytes    <=s1_imageBytes;
			s2_labelBytes    <=s1_labelBytes;

			s2_labelStartAddr <=s1_pStartAddr+imageAddrOffsetCalc32[ADDRwidth-1:0];
			// ----------------------------------------------------
			// Commit stage
			// Address book update happens after the pipeline delay.
			// ----------------------------------------------------
			if(s2_valid)begin
				if(s2_writerError)begin
					bookErrorFlags[BOOKerr]      <=1'b1;
					bookErrorFlags[WRITERrepErr] <=1'b1;
				end
				else begin
					// Update allocator mirror.
					nextFreeAddr <=s2_pNextAddr;
					if (s2_isImage) begin
						// Store image region.
						validFlags[SLOTimage] <=1'b1;
						startADDRbook[SLOTimage*ADDRwidth+:ADDRwidth] <=s2_pStartAddr;
						// Store only pure image byte count.
						// Label bytes are stored separately in SLOTlabel.
						payloadBytesBook[SLOTimage*32+:32] <=s2_imageBytes;
						if(s2_incLABEL)begin
							//Store label region.
							validFlags[SLOTlabel] <=1'b1;
							startADDRbook[SLOTlabel*ADDRwidth+:ADDRwidth] <=s2_labelStartAddr;
							payloadBytesBook[SLOTlabel*32+:32] <=s2_labelBytes;
						end
						else begin
							//Avoid stale label info from a previous image packet.
							validFlags[SLOTlabel] <=1'b0;
							startADDRbook[SLOTlabel*ADDRwidth+:ADDRwidth] <={ADDRwidth{1'b0}};
							payloadBytesBook[SLOTlabel*32+:32] <=32'd0;
						end
					end
					else if(s2_isFc1Weight)begin
						validFlags[SLOTfc1W] <=1'b1;
						startADDRbook[SLOTfc1W*ADDRwidth+:ADDRwidth] <=s2_pStartAddr;
						payloadBytesBook[SLOTfc1W*32+:32] <=s2_wPayloadBytes;
					end
					else if(s2_isFc1Bias)begin
						validFlags[SLOTfc1B] <=1'b1;
						startADDRbook[SLOTfc1B*ADDRwidth+:ADDRwidth] <=s2_pStartAddr;
						payloadBytesBook[SLOTfc1B*32+:32] <=s2_wPayloadBytes;
					end
					else if(s2_isFc2Weight)begin
						validFlags[SLOTfc2W] <=1'b1;
						startADDRbook[SLOTfc2W*ADDRwidth+:ADDRwidth] <=s2_pStartAddr;
						payloadBytesBook[SLOTfc2W*32+:32] <=s2_wPayloadBytes;
					end
					else if(s2_isFc2Bias)begin
						validFlags[SLOTfc2B] <=1'b1;
						startADDRbook[SLOTfc2B*ADDRwidth+:ADDRwidth] <=s2_pStartAddr;
						payloadBytesBook[SLOTfc2B*32+:32] <=s2_wPayloadBytes;
					end
					else begin
						bookErrorFlags[BOOKerr]    <=1'b1;
						bookErrorFlags[UNKNOWNerr] <=1'b1;
					end
				end
			end
		end
	end
endmodule