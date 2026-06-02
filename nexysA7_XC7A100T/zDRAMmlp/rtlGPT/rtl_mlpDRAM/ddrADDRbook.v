`timescale 1ns/1ps

module ddrADDRbook128#(
	parameter ADDRwidth =27,
	parameter [ADDRwidth-1:0] RESETbaseADDR ={ADDRwidth{1'b0}},
	parameter [7:0] PACKETimg    =8'h01,
	parameter [7:0] PACKETparam  =8'h02,
	parameter [7:0] PACKETparamW =8'h00,
	parameter [7:0] PACKETparamB =8'h01,
	parameter [7:0] incLABELmask =8'h01)(
	input  wire                  clk,
	input  wire                  rst,
	//Optional clear for sticky error flags.
	input  wire                  clear,
	//From ddrPackW128
	input  wire                  writeDone,
	input  wire [3:0]            writerErrorFlags,
	input  wire [ADDRwidth-1:0]  pStartAddr,
	input  wire [ADDRwidth-1:0]  pNextAddr,
	//wMetaInfo ={packetType[8],flags[8],layerID[8],paramType[8],
	//            bitWidth[16],elemCount[32],batchID[32],batchSize[16],vectorLEN[16]}
	input  wire [143:0]          wMetaInfo,
	input  wire [31:0]           wPayloadBytes,
	//Current allocator pointer mirror.
	output reg  [ADDRwidth-1:0]  nextFreeAddr,
	//validFlags ={fc2B,fc2w,fc1b,fc1w,label,img}
	output reg  [5:0]            validFlags,
	//startADDRbook stores start addresses for each slot.
	//Slot mapping order follows the same as validFlags
	output reg  [6*ADDRwidth-1:0] startADDRbook,
	//payloadBytesBook stores payload byte count for each slot.
	output reg  [6*32-1:0]        payloadBytesBook,
	//bookErrorFlags[0] =addressBookError
	//bookErrorFlags[1] =unknownPacketError
	//bookErrorFlags[2] =writerReportedError
	output reg  [2:0]             bookErrorFlags);

	localparam integer SLOTimage =0;
	localparam integer SLOTlavel =1;
	localparam integer SLOTfc1W  =2;
	localparam integer SLOTfc1B  =3;
	localparam integer SLOTfc2W  =4;
	localparam integer SLOTfc2B  =5;
	localparam integer BOOKerr       =0;
	localparam integer UNKNOWNerr    =1;
	localparam integer WRITERrepErr  =2;

	wire writerError;
	wire acceptedWrite;
	assign writerError   =writeDone&& (|writerErrorFlags);//reduction OR
	assign acceptedWrite =writeDone&&!(|writerErrorFlags);//write successfully done in ddrPackW
	//Only these fields are needed for address classification.
	wire [7:0]  wPacketType;
	wire [7:0]  wFlags;
	wire [7:0]  wLayerID;
	wire [7:0]  wParamType;
	wire [15:0] wBatchSize;
	wire [15:0] wVectorLEN;
	assign wPacketType =wMetaInfo[143:136];
	assign wFlags      =wMetaInfo[135:128];
	assign wLayerID    =wMetaInfo[127:120];
	assign wParamType  =wMetaInfo[119:112];
	assign wBatchSize  =wMetaInfo[31:16];
	assign wVectorLEN  =wMetaInfo[15:0];

	wire isImage;
	wire isParam;
	wire isFc1Weight;
	wire isFc1Bias;
	wire isFc2Weight;
	wire isFc2Bias;
	assign isImage =(wPacketType==PACKETimg);
	assign isParam =(wPacketType==PACKETparam);
	assign isFc1Weight =isParam&&(wLayerID ==8'd1)&&(wParamType ==PACKETparamW);
	assign isFc1Bias   =isParam&&(wLayerID ==8'd1)&&(wParamType ==PACKETparamB);
	assign isFc2Weight =isParam&&(wLayerID ==8'd2)&&(wParamType ==PACKETparamW);
	assign isFc2Bias   =isParam&&(wLayerID ==8'd2)&&(wParamType ==PACKETparamB);

	wire incLABEL;
	wire [31:0] imageBytes, labelBytes;
	wire [(ADDRwidth-1):0] imageByteOffset;
	wire [(ADDRwidth-1):0] labelStartAddr;
	assign incLABEL =((wFlags&incLABELmask)!=8'd0);
	assign imageBytes ={16'd0,wBatchSize}*{16'd0,wVectorLEN};
	assign labelBytes =incLABEL?{16'd0,wBatchSize}:32'd0;
	assign imageByteOffset =imageBytes;
	assign labelStartAddr =pStartAddr+imageByteOffset;

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			nextFreeAddr     <=RESETbaseADDR;
			validFlags       <=6'd0;
			startADDRbook    <={(6*ADDRwidth){1'b0}};
			payloadBytesBook <={(6*32){1'b0}};
			bookErrorFlags   <=3'd0;
		end
		else begin
			if(clear) bookErrorFlags <=3'd0;
			if(writerError)begin
				bookErrorFlags[BOOKerr]      <=1'b1;
				bookErrorFlags[WRITERrepErr] <=1'b1;
			end
			if(acceptedWrite)begin
				nextFreeAddr <=pNextAddr;
				if(isImage)begin
					validFlags[SLOTimage] <=1'b1;
					startADDRBook[SLOTimage*ADDRwidth+:ADDRwidth] <=pStartAddr;
					payloadBytesBook[SLOTimage*32+:32] <=imageBytes;
					if(incLABEL)begin
						validFlags[SLOTlabel] <=1'b1;
						startADDRBook[SLOTlabel*ADDRwidth+:ADDRwidth] <=labelStartAddr;
						payloadBytesBook[SLOTlabel*32+:32] <=labelBytes;
					end
					else begin
						validFlags[SLOTlabel] <= 1'b0;
						startADDRBook[SLOTlabel*ADDRwidth+:ADDRwidth] <={ADDRwidth{1'b0}};
						payloadBytesBook[SLOTlabel*32+:32] <=32'd0;
					end
				end
				else if(isFc1Weight)begin
					validFlags[SLOTfc1W] <=1'b1;
					startADDRbook[SLOTfc1W*ADDRwidth+:ADDRwidth] <=pStartAddr;
					payloadBytesBook[SLOTfc1W*32+:32] <=wPayloadBytes;
				end
				else if(isFc1Bias)begin
					validFlags[SLOTfc1B] <=1'b1;
					startADDRbook[SLOTfc1B*ADDRwidth+:ADDRwidth] <=pStartAddr;
					payloadBytesBook[SLOTfc1B*32+:32] <=wPayloadBytes;
				end
				else if(isFc2Weight)begin
					validFlags[SLOTfc2W] <=1'b1;
					startADDRbook[SLOTfc2W*ADDRwidth+:ADDRwidth] <=pStartAddr;
					payloadBytesBook[SLOTfc2W*32 +: 32]
						<=wPayloadBytes;
				end
				else if (isFc2Bias) begin
					validFlags[SLOTfc2B] <=1'b1;
					startADDRbook[SLOTfc2B*ADDRwidth+:ADDRwidth] <=pStartAddr;
					payloadBytesBook[SLOTfc2B*32+:32] <=wPayloadBytes;
				end
				else begin
					bookErrorFlags[BOOKerr]    <=1'b1;
					bookErrorFlags[UNKNOWNerr] <=1'b1;
				end
			end
		end
	end

endmodule