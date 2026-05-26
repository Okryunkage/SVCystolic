`timescale 1ns/1ps

module upDEC#(
	parameter[7:0] SOF0            =8'hAA,
	parameter[7:0] SOF1            =8'h55,
	parameter[7:0] versionEXP      =8'd1,
	parameter[7:0] PACKETimg       =8'h01,
	parameter[7:0] PACKETparam     =8'h02,
	parameter[7:0] PACKETparamW    =8'h00,
	parameter[7:0] PACKETparamB    =8'h01,
	parameter[7:0] incLABELmask    =8'h01,//used in image Packet
	parameter[7:0] paramSIGNEDmask =8'h01,//used in param Packet
	parameter      payloadLENcheck =1)(
	input wire         clk, 
	input wire         rst,
	input wire         rxDone,
	input wire  [7:0]  rxData,
	/*
	statusFlags[0] =headerValid
	statusFlags[1] =payloadValid
	statusFlags[2] =packetDone
	statusFlags[3] =packetError
	statusFlags[4] =checksumError
	statusFlags[5] =headerError
	headerInfo[7:0]   =version
	headerInfo[15:8]  =packetType
	headerInfo[23:16] =flags
	headerInfo[55:24] =payloadLEN
	imageInfo[31:0]  =batchID
	imageInfo[47:32] =batchSize
	imageInfo[63:48] =vectorLEN
	paramInfo[7:0]   =layerID
	paramInfo[15:8]  =paramType
	paramInfo[31:16] =bitWidth
	paramInfo[63:32] =elemCount
	payloadInfo[7:0]  =payloadData
	payloadInfo[39:8] =payloadIndex
	payloadFlags[0] =payloadImage
	payloadFlags[1] =payloadLabel
	payloadFlags[2] =payloadParam
	payloadFlags[3] =payloadWeight
	payloadFlags[4] =paylaodBias
	checksumInfo[7:0]  =rxChecksum
	checksumInfo[15:8] =cmChecksum
	*/
	output reg  [5:0]  statusFlags,
	output reg  [55:0] headerInfo,
	output reg  [63:0] imageInfo,
	output reg  [63:0] paramInfo,
	output reg  [39:0] payloadInfo,
	output reg  [4:0]  payloadFlags,
	output reg  [15:0] checksumInfo,
	output wire        busy);

	localparam [2:0] waitSOF0s    =3'd0;
	localparam [2:0] waitSOF1s    =3'd1;
	localparam [2:0] HEADERs      =3'd2;
	localparam [2:0] HEADERchecks =3'd3;
	localparam [2:0] PAYLOADs     =3'd4;
	localparam [2:0] CHECKSUMs    =3'd5;

	localparam [3:0] HEADERbytes =4'd15;

	localparam integer STheaderVALID   =0;
	localparam integer STpayloadVALILD =1;
	localparam integer STpacketDONE    =2;
	localparam integer STpacketERROR   =3;
	localparam integer STchecksumERROR =4;
	localparam integer STheaderERROR   =5;

	localparam integer PFimage         =0;
	localparam integer PFlabel         =1;
	localparam integer PFparam         =2;
	localparam integer PFweight        =3;
	localparam integer PFbias          =4;

	reg [2:0]  state;
	reg [3:0]  HEADERcount;
	reg [31:0] PAYLOADcount;
	reg [7:0]  CHECKSUMacc;

	reg [31:0] imgBYTEcount;
	reg [31:0] payloadLENexp;

	wire [7:0] version, packetType, flags, layerID, paramType;
	wire [15:0] batchSize, vectorLEN, bitWidth;
	wire [31:0] payloadLEN, batchID, elemCount;

	assign {payloadLEN,flags,packetType,version}  =headerInfo;
	assign {vectorLEN,batchSize,batchID}          =imageInfo;
	assign {elemCount,bitWidth,paramType,layerID} =paramInfo;

	wire [31:0] imgBYTEcountCALC, imgPayloadLENexpCALC, paramPayloadLENexpCALC;
	//wire [31:0]  bytesPerElemCALC;

	assign busy =(state !=waitSOF0s);

	wire isImageHeader, isParamHeader;
	assign {isImageHeader,isParamHeader} ={(packetType==PACKETimg),(packetType==PACKETparam)};

	assign imgBYTEcountCALC ={16'd0,batchSize}*{16'd0,vectorLEN};

	assign imgPayloadLENexpCALC =imgBYTEcountCALC+(((flags&incLABELmask)!=8'd0)?{16'd0,batchSize}:32'd0);

	//assign bytesPerElemCALC =({16'd0,bitWidth}+32'd7)>>3;//ceil(bitWidht/8)
	//assign paramPayloadLENexpCALC =elemCount*bytesPerElemCALC;
	wire [2:0] bytesPerElemCALC =(bitWidth<=16'd8)?3'd1:
								(bitWidth<=16'd16)?3'd2:
								(bitWidth<=16'd24)?3'd3:3'd4;
	assign paramPayloadLENexpCALC =(bytesPerElemCALC==3'd1)?elemCount:
							(bytesPerElemCALC==3'd2)?(elemCount<<1):
							(bytesPerElemCALC==3'd3)?((elemCount<<1)+elemCount):(elemCount<<2);

	//assign payloadLENcurrent ={rxData, payloadLEN[23:0]};

	//To match the timing requirement,
	//(payloadLEN-1) and ((flags & incLABELmask) != 8'd0) is calculated once and stored in reg.
	reg [31:0] payloadLastIndex;
	reg        incLABELreg;

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state         <=waitSOF0s;
			HEADERcount   <=4'd0;
			PAYLOADcount  <=32'd0;
			CHECKSUMacc   <=8'd0;
			statusFlags   <=6'd0;
			headerInfo    <=56'd0;
			imageInfo     <=64'd0;
			paramInfo     <=64'd0;
			payloadInfo   <=40'd0;
			payloadFlags  <=5'd0;
			checksumInfo  <=16'd0;
			imgBYTEcount  <=32'd0;
			payloadLENexp <=32'd0;

			payloadLastIndex <=32'd0;
			incLABELreg <=1'b0;
		end
		else begin
			statusFlags   <=6'd0;
			payloadFlags  <=5'd0;
			//HEADERchecks should work when !RXdone
			if(state==HEADERchecks)begin
				if(version !=versionEXP)begin
					{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
					state <=waitSOF0s;
				end
				else if((packetType !=PACKETimg)&&(packetType !=PACKETparam))begin
					{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
					state <=waitSOF0s;
				end
				else if(packetType==PACKETimg)begin
					if((flags & ~incLABELmask) !=8'd0)begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						state <=waitSOF0s;
					end
					else if(payloadLENcheck &&(payloadLEN!=imgPayloadLENexpCALC))begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						state <=waitSOF0s;
					end
					else begin
						statusFlags[STheaderVALID] <=1'b1;
						imgBYTEcount  <=imgBYTEcountCALC;
						payloadLENexp <=imgPayloadLENexpCALC;
						PAYLOADcount  <=32'd0;
						if(payloadLEN==32'd0) state <=CHECKSUMs;
						else state <=PAYLOADs;

						payloadLastIndex <=payloadLEN-32'd1;
						incLABELreg      <=((flags&incLABELmask)!=8'd0);
					end
				end
				else begin
					//packetType ==PACKETparam
					if((flags & ~paramSIGNEDmask) !=8'd0)begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						state <=waitSOF0s;
					end
					else if((paramType !=PACKETparamW)&&(paramType !=PACKETparamB))begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						state <=waitSOF0s;
					end
					else if((bitWidth==16'd0)||(bitWidth>16'd32))begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						//if bitWidth is 0 or greater than 32, goto waitSOF0s.
						state <=waitSOF0s;
					end
					else if(payloadLENcheck &&(payloadLEN!=paramPayloadLENexpCALC))begin
						{statusFlags[STheaderERROR],statusFlags[STpacketERROR]} <=2'b11;
						state <=waitSOF0s;
					end
					else begin
						statusFlags[STheaderVALID] <=1'b1;
						imgBYTEcount  <=32'd0;
						payloadLENexp <=paramPayloadLENexpCALC;
						PAYLOADcount  <=32'd0;
						if(payloadLEN==32'd0) state <=CHECKSUMs;
						else state <=PAYLOADs;

						payloadLastIndex <=payloadLEN-32'd1;
						incLABELreg      <=1'b0;
					end
				end
			end
			else if(rxDone)begin
				case(state)
					waitSOF0s: if(rxData==SOF0) state <=waitSOF1s;
					waitSOF1s:begin
						if(rxData==SOF1)begin
							state         <=HEADERs;
							HEADERcount   <=4'd0;
							PAYLOADcount  <=32'd0;
							CHECKSUMacc   <=8'd0;
							headerInfo    <=56'd0;
							imageInfo     <=64'd0;
							paramInfo     <=64'd0;
							payloadInfo   <=40'd0;
							payloadFlags  <=5'd0;
							checksumInfo  <=16'd0;
							imgBYTEcount  <=32'd0;
							payloadLENexp <=32'd0;

							payloadLastIndex <=32'd0;
							incLABELreg <=1'b0;
						end
						else if(rxData ==SOF0) state <=waitSOF1s;
						else                   state <=waitSOF0s;
					end
					HEADERs:begin
						CHECKSUMacc <=CHECKSUMacc+rxData;
						case(HEADERcount)
							4'd0: headerInfo[7:0]   <=rxData;
							4'd1: headerInfo[15:8]  <=rxData;
							4'd2: headerInfo[23:16] <=rxData;
							//Byte positions are reused depending on packetType.
							//IMAGE interpretation:
							//	byte 3~6   : batchID
							//	byte 7~8   : batchSize
							//	byte 9~10  : vectorLEN
							//	byte 11~14 : payloadLEN
							//PARAM interpretation:
							//	byte 3     : layerID
							//	byte 4     : paramType
							//	byte 5~6   : bitWidth
							//	byte 7~10  : elemCount
							//	byte 11~14 : payloadLEN
							4'd3: {imageInfo[7:0],paramInfo[7:0]}     <={rxData,rxData};
							4'd4: {imageInfo[15:8],paramInfo[15:8]}   <={rxData,rxData};
							4'd5: {imageInfo[23:16],paramInfo[23:16]} <={rxData,rxData};
							4'd6: {imageInfo[31:24],paramInfo[31:24]} <={rxData,rxData};
							4'd7: {imageInfo[39:32],paramInfo[39:32]} <={rxData,rxData};
							4'd8: {imageInfo[47:40],paramInfo[47:40]} <={rxData,rxData};
							4'd9: {imageInfo[55:48],paramInfo[55:48]} <={rxData,rxData};
							4'd10:{imageInfo[63:56],paramInfo[63:56]} <={rxData,rxData};
							4'd11: headerInfo[31:24] <=rxData;
							4'd12: headerInfo[39:32] <=rxData;
							4'd13: headerInfo[47:40] <=rxData;
							4'd14: headerInfo[55:48] <=rxData;
							default: ;
						endcase
						if(HEADERcount==(HEADERbytes-1))begin
							HEADERcount <=4'd0;
							//Header checks
							state <=HEADERchecks;
						end
						else HEADERcount <=HEADERcount+4'd1;
					end
					PAYLOADs:begin
						statusFlags[STpayloadVALILD] <=1'b1;
						payloadInfo <={PAYLOADcount,rxData};
						CHECKSUMacc <=CHECKSUMacc + rxData;
						if(packetType==PACKETimg)begin
							payloadFlags[PFimage] <=1'b1;
							//If labels are included, label bytes come after image bytes.
							//user can check if the output data is img or label by PFlabel.
							payloadFlags[PFlabel] <=incLABELreg&&(PAYLOADcount>=imgBYTEcount);
						end
						else if(packetType==PACKETparam)begin
							payloadFlags[PFparam]  <=1'b1;
							payloadFlags[PFweight] <=(paramType==PACKETparamW);
							payloadFlags[PFbias]   <=(paramType ==PACKETparamB);
						end
						if(PAYLOADcount==payloadLastIndex) state <=CHECKSUMs;
						else PAYLOADcount <=PAYLOADcount+32'd1;
					end
					CHECKSUMs:begin
						checksumInfo <={CHECKSUMacc,rxData};
						if(rxData==CHECKSUMacc) statusFlags[STpacketDONE] <=1'b1;
						else begin
							statusFlags[STchecksumERROR] <=1'b1;
							statusFlags[STpacketERROR]   <=1'b1;
						end
						state <=waitSOF0s;
					end
					default: state <=waitSOF0s;
				endcase
			end
		end
	end
endmodule