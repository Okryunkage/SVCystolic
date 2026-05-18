`timescale 1ns/1ps

module uartPacketDec#(
	parameter [7:0] SOF0            =8'hAA,
	parameter [7:0] SOF1            =8'h55,
	parameter [7:0] versionEXP      =8'd1,
	parameter [7:0] incLABELmask    =8'h01,
	parameter       payloadLENcheck =1)(
	
	input  wire        clk,
	input  wire        rst,
	input  wire        rxDone,
	input  wire [7:0]  rxData,

	output reg         headerValid,
	//1-cyle pulse after header is decoded
	output reg  [7:0]  version,
	output reg  [7:0]  flags,
	output reg  [31:0] batchID,
	output reg  [15:0] batchSize,
	output reg  [15:0] vectorLEN,
	output reg  [31:0] payloadLEN,
	output reg         payloadValid,
	output reg  [7:0]  payloadData,
	output reg  [31:0] payloadIndex,
	output reg         payloadLabel,
	output reg         packetDone,
	output reg         packetError,
	output reg         checksumError,
	output reg         headerError,
	output reg  [7:0]  rxChecksum,
	//received Checksum
	output reg  [7:0]  cmChecksum,
	//computed Checksum
	output wire        busy);

	localparam [2:0] waitSOF0s  =3'd0;
	localparam [2:0] waitSOF1s  =3'd1;
	localparam [2:0] HEADERs    =3'd2;
	localparam [2:0] PAYLOADs   =3'd3;
	localparam [2:0] CHECKSUMs  =3'd4;
	
	localparam [3:0] HEADERbytes  =4'd14;
	/*
	#Packet header, little-endian:
	#version      : uint8
	#flags        : uint8
	#batch_id     : uint32
	#batch_size   : uint16
	#vector_len   : uint16
	#payload_len  : uint32
	*/
	reg [2:0]  state;
	reg [3:0]  HEADERcount;
	reg [31:0] PAYLOADcount;

	reg [7:0]  CHECKSUMacc;

	reg [31:0] imgBYTEcount;
	reg [31:0] payloadLENexp;

	wire [31:0] imgBYTEcountCALC;
	wire [31:0] payloadLENexpCALC;
	wire [31:0] payloadLENcurrent;

	assign busy =(state !=waitSOF0s);

	assign imgBYTEcountCALC ={16'd0,batchSize}*{16'd0,vectorLEN};
	//Extend operand to 32 bits so the multiplication result is not truncated.
	assign payloadLENexpCALC =imgBYTEcountCALC+((flags & incLABELmask)?{16'd0,batchSize}:32'd0);

	//Used when receiving the last byte of payloadLEN.
	//payloadLEN is little-endian
	//Complete payload length including the current RX byte.
	assign payloadLENcurrent ={rxData,payloadLEN[23:0]};

	always @(posedge clk or negedge rst)begin
		if(rst)begin
			state            <=waitSOF0s;
			HEADERcount      <=4'd0;
			PAYLOADcount     <=32'd0;
			CHECKSUMacc      <=8'd0;
			headerValid      <=1'b0;
			version          <=8'd0;
			flags            <=8'd0;
			batchID          <=32'd0;
			batchSize        <=16'd0;
			vectorLEN        <=16'd0;
			payloadLEN       <=32'd0;
			payloadValid     <=1'b0;
			payloadData      <=8'd0;
			payloadIndex     <=32'd0;
			payloadLabel     <=1'b0;
			packetDone       <=1'b0;
			packetError      <=1'b0;
			checksumError    <=1'b0;
			headerError      <=1'b0;
			rxChecksum       <=8'd0;
			cmChecksum       <=8'd0;
			imgBYTEcount     <=32'd0;
			payloadLENexp    <=32'd0;
		end 
		else begin
			//Default pulse outputs
			headerValid     <=1'b0;
			payloadValid    <=1'b0;
			packetDone      <=1'b0;
			packetError     <=1'b0;
			checksumError   <=1'b0;
			headerError     <=1'b0;

			if(rxDone)begin
				case (state)
					waitSOF0s:begin
						if(rxData==SOF0) state <=waitSOF1s;
					end
					waitSOF1s:begin
						if (rxData==SOF1)begin
							state            <=HEADERs;
							HEADERcount      <=4'd0;
							PAYLOADcount     <=32'd0;
							CHECKSUMacc      <=8'd0;
							version          <=8'd0;
							flags            <=8'd0;
							batchID          <=32'd0;
							batchSize        <=16'd0;
							vectorLEN        <=16'd0;
							payloadLEN       <=32'd0;
							imgBYTEcount     <=32'd0;
							payloadLENexp    <=32'd0;
						end 
						else if (rxData==SOF0) state <=waitSOF1s;
						else                   state <=waitSOF0s;
					end
					//Read 14-byte header
					HEADERs: begin
						CHECKSUMacc <=CHECKSUMacc +rxData;
						case(HEADERcount)
							//version: uint8
							4'd0:  version           <=rxData;
							//flags: uint8
							4'd1:  flags             <=rxData;
							//batchID: uint8
							4'd2:  batchID[7:0]      <=rxData;
							4'd3:  batchID[15:8]     <=rxData;
							4'd4:  batchID[23:16]    <=rxData;
							4'd5:  batchID[31:24]    <=rxData;
							//batchSize: uint16
							4'd6:  batchSize[7:0]    <=rxData;
							4'd7:  batchSize[15:8]   <=rxData;
							//vectorLEN: uint16
							4'd8:  vectorLEN[7:0]    <=rxData;
							4'd9:  vectorLEN[15:8]   <=rxData;
							//payloadLEN: uint32
							4'd10: payloadLEN[7:0]   <=rxData;
							4'd11: payloadLEN[15:8]  <=rxData;
							4'd12: payloadLEN[23:16] <=rxData;
							4'd13: payloadLEN[31:24] <=rxData;
							default:;
						endcase
						if (HEADERcount==(HEADERbytes-1))begin
							headerValid   <=1'b1;
							imgBYTEcount  <=imgBYTEcountCALC;
							payloadLENexp <=payloadLENexpCALC;
							//Header checks
							if(version!=versionEXP)begin
								headerError <=1'b1;
								packetError <=1'b1;
								state       <=waitSOF0s;
							end
							else if((flags & ~incLABELmask)!=8'd0)begin
								//Only bit0 is currently defined.
								headerError <=1'b1;
								packetError <=1'b1;
								state       <=waitSOF0s;
							end
							else if(payloadLENcheck&&(payloadLENcurrent !=payloadLENexpCALC))begin
								headerError <=1'b1;
								packetError <=1'b1;
								state       <=waitSOF0s;
							end
							else begin
								PAYLOADcount <=32'd0;
								if(payloadLENcurrent==32'd0) state <=CHECKSUMs;
								else state <=PAYLOADs;
							end
							HEADERcount <=4'd0;
						end
						else HEADERcount <=HEADERcount+4'd1;
					end
					//Stream payload bytes
					PAYLOADs:begin
						payloadValid <=1'b1;
						payloadData  <=rxData;
						payloadIndex <=PAYLOADcount;
						// If labels are included, label bytes come after image bytes.
						payloadLabel <=((flags & incLABELmask)!=8'd0)&&(PAYLOADcount >=imgBYTEcount);
						CHECKSUMacc <=CHECKSUMacc+rxData;
						if(PAYLOADcount==(payloadLEN-1)) state <=CHECKSUMs;
						else PAYLOADcount <=PAYLOADcount + 32'd1;
					end
					//Read and check checksum byte
					CHECKSUMs: begin
						rxChecksum <=rxData;
						cmChecksum <=CHECKSUMacc;
						if(rxData==CHECKSUMacc) packetDone <=1'b1;
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