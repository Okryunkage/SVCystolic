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
	output reg  [5:0]  statusFlags,
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
	output reg  [55:0] headerInfo,
	output reg  [63:0] imageInfo,
	output reg  [63:0] paramInfo,
	output reg  [39:0] payloadInfo,
	output reg  [4:0]  payloadFlags,
	output reg  [15:0] checksumInfo,
	output wire        busy);

	localparam [2:0] waitSOF0s =3'd0;
	localparam [2:0] waitSOF1s =3'd1;
	localparam [2:0] HEADERs   =3'd2;
	localparam [2:0] PAYLOADs  =3'd3;
	localparam [2:0] CHECKSUMs =3'd4;

	localparam [3:0] HEADERbytes =4'd15;

	localparam integer ST

	reg [2:0]  state;
	reg [3:0]  HEADERcount;
	reg [31:0] PAYLOADcount;
	reg [7:0]  CHECKSUMacc;

	reg [31:0] imgBYTEcount;
	reg [31:0] payloadLENexp;

	wire [31:0] imgBYTEcountCALC;
	wire [31:0] imagePayloadLENexpCALC;
	wire [31:0] paramPayloadLENexpCALC;
	wire [31:0] bytesPerElemCALC;
	wire [31:0] payloadLENcurrent;

	wire        isImageHeader;
	wire        isParamHeader;
	wire        paramIsWeightHeader;
	wire        paramIsBiasHeader;

	assign busy =(state !=waitSOF0s);

	assign isImageHeader       =(packetType==PACKETimg);
	assign isParamHeader       =(packetType==PACKETparam);
	assign paramIsWeightHeader =isParamHeader&&(paramType==PACKETparamW);
	assign paramIsBiasHeader   =isParamHeader&&(paramType==PACKETparamB);

	assign imgBYTEcountCALC ={16'd0,batchSize}*{16'd0,vectorLEN};

	assign imagePayloadLENexpCALC =imgBYTEcountCALC+(((flags&incLABELmask)!=8'd0)?{16'd0,batchSize}:32'd0);

	assign bytesPerElemCALC =({16'd0,bitWidth}+32'd7)>>3;
	assign paramPayloadLENexpCALC =elemCount*bytesPerElemCALC;

	assign payloadLENcurrent ={rxData, payloadLEN[23:0]};

	always @(posedge clk or posedge rst)begin
		if(rst)begin
			state         <=waitSOF0s;
			HEADERcount   <=4'd0;
			PAYLOADcount  <=32'd0;
			CHECKSUMacc   <=8'd0;
			headerValid   <=1'b0;
			version       <=8'd0;
			packetType    <=8'd0;
			flags         <=8'd0;
			batchID       <=32'd0;
			batchSize     <=16'd0;
			vectorLEN     <=16'd0;
			layerID       <=8'd0;
			paramType     <=8'd0;
			bitWidth      <=16'd0;
			elemCount     <=32'd0;
			payloadLEN    <=32'd0;
			payloadValid  <=1'b0;
			payloadData   <=8'd0;
			payloadIndex  <=32'd0;
			payloadImage  <=1'b0;
			payloadLabel  <=1'b0;
			payloadParam  <=1'b0;
			payloadWeight <=1'b0;
			payloadBias   <=1'b0;
			packetDone    <=1'b0;
			packetError   <=1'b0;
			checksumError <=1'b0;
			headerError   <=1'b0;
			rxChecksum    <=8'd0;
			cmChecksum    <=8'd0;
			imgBYTEcount  <=32'd0;
			payloadLENexp <=32'd0;
		end
		else begin
			headerValid   <=1'b0;
			payloadValid  <=1'b0;
			payloadImage  <=1'b0;
			payloadLabel  <=1'b0;
			payloadParam  <=1'b0;
			payloadWeight <=1'b0;
			payloadBias   <=1'b0;
			packetDone    <=1'b0;
			packetError   <=1'b0;
			checksumError <=1'b0;
			headerError   <=1'b0;
			if(rxDone)begin
				case(state)
					waitSOF0s: if(rxData==SOF0) state <=waitSOF1s;
					waitSOF1s:begin
						if(rxData==SOF1)begin
							state        <=HEADERs;
							HEADERcount  <=4'd0;
							PAYLOADcount <=32'd0;
							CHECKSUMacc  <=8'd0;
							version      <=8'd0;
							packetType   <=8'd0;
							flags        <=8'd0;
							batchID      <=32'd0;
							batchSize    <=16'd0;
							vectorLEN    <=16'd0;
							layerID      <=8'd0;
							paramType    <=8'd0;
							bitWidth     <=16'd0;
							elemCount    <=32'd0;
							payloadLEN   <=32'd0;
							imgBYTEcount <=32'd0;
							payloadLENexp<=32'd0;
						end
						else if(rxData ==SOF0) state <=waitSOF1s;
						else                   state <=waitSOF0s;
					end
					HEADERs:begin
						CHECKSUMacc <=CHECKSUMacc+rxData;
						case(HEADERcount)
							4'd0:  version    <=rxData;
							4'd1:  packetType <=rxData;
							4'd2:  flags      <=rxData;
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
							4'd3:begin
								batchID[7:0]   <=rxData;
								layerID        <=rxData;
							end
							4'd4:begin
								batchID[15:8]  <=rxData;
								paramType      <=rxData;
							end
							4'd5:begin
								batchID[23:16] <=rxData;
								bitWidth[7:0]  <=rxData;
							end
							4'd6:begin
								batchID[31:24] <=rxData;
								bitWidth[15:8] <=rxData;
							end
							4'd7:begin
								batchSize[7:0] <=rxData;
								elemCount[7:0] <=rxData;
							end
							4'd8:begin
								batchSize[15:8]  <=rxData;
								elemCount[15:8]  <=rxData;
							end
							4'd9:begin
								vectorLEN[7:0]   <=rxData;
								elemCount[23:16] <=rxData;
							end
							4'd10:begin
								vectorLEN[15:8]  <=rxData;
								elemCount[31:24] <=rxData;
							end
							4'd11: payloadLEN[7:0]   <=rxData;
							4'd12: payloadLEN[15:8]  <=rxData;
							4'd13: payloadLEN[23:16] <=rxData;
							4'd14: payloadLEN[31:24] <=rxData;
							default: ;
						endcase
						if (HEADERcount==(HEADERbytes-1))begin
							HEADERcount <=4'd0;
							// Header checks
							if (version !=versionEXP)begin
								headerError <=1'b1;
								packetError <=1'b1;
								state       <=waitSOF0s;
							end
							else if((packetType !=PACKETimg)&&(packetType !=PACKETparam))begin
								headerError <=1'b1;
								packetError <=1'b1;
								state       <=waitSOF0s;
							end
							else if(packetType ==PACKETimg)begin
								if((flags & ~incLABELmask) !=8'd0)begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else if(payloadLENcheck &&(payloadLENcurrent !=imagePayloadLENexpCALC))begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else begin
									headerValid   <=1'b1;
									imgBYTEcount  <=imgBYTEcountCALC;
									payloadLENexp <=imagePayloadLENexpCALC;
									PAYLOADcount  <=32'd0;
									if(payloadLENcurrent==32'd0) state <=CHECKSUMs;
									else state <=PAYLOADs;
								end
							end
							else begin
								// packetType ==PACKETparam
								if((flags & ~paramSIGNEDmask) !=8'd0)begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else if((paramType !=PACKETparamW)&&(paramType !=PACKETparamB))begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else if ((bitWidth==16'd0)||(bitWidth>16'd32))begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else if(payloadLENcheck &&(payloadLENcurrent !=paramPayloadLENexpCALC)) begin
									headerError <=1'b1;
									packetError <=1'b1;
									state       <=waitSOF0s;
								end
								else begin
									headerValid   <=1'b1;
									imgBYTEcount  <=32'd0;
									payloadLENexp <=paramPayloadLENexpCALC;
									PAYLOADcount  <=32'd0;
									if(payloadLENcurrent==32'd0) state <=CHECKSUMs;
									else state <=PAYLOADs;
								end
							end
						end
						else HEADERcount <=HEADERcount+4'd1;
					end
					PAYLOADs:begin
						payloadValid <=1'b1;
						payloadData  <=rxData;
						payloadIndex <=PAYLOADcount;
						CHECKSUMacc  <=CHECKSUMacc + rxData;
						if(packetType==PACKETimg)begin
							payloadImage <=1'b1;
							// If labels are included, label bytes come after image bytes.
							payloadLabel <=((flags&incLABELmask) !=8'd0)&&(PAYLOADcount >=imgBYTEcount);
						end
						else if(packetType==PACKETparam)begin
							payloadParam  <=1'b1;
							payloadWeight <=(paramType ==PACKETparamW);
							payloadBias   <=(paramType ==PACKETparamB);
						end
						if(PAYLOADcount==(payloadLEN-1)) state <=CHECKSUMs;
						else PAYLOADcount <=PAYLOADcount+32'd1;
					end
					CHECKSUMs:begin
						rxChecksum <=rxData;
						cmChecksum <=CHECKSUMacc;
						if(rxData ==CHECKSUMacc) packetDone <=1'b1;
						else begin
							checksumError <=1'b1;
							packetError   <=1'b1;
						end
						state <=waitSOF0s;
					end
					default: state <=waitSOF0s;
				endcase
			end
		end
	end
endmodule