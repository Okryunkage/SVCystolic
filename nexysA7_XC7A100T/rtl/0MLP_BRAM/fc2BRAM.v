`timescale 1ns/1ps

module fc2BRAM(
	input                                    clk,
	input                                    rst,
	input                                    start,
	input            [(64*8-1):0]            inFlat,
	output reg                               busy,
	output reg                               done,
	output reg signed[(10*32-1):0]           outFlat);

	localparam tile     =5;

	localparam inNum    =64;
	localparam outNum   =10;
	localparam inWidth  =8;
	localparam wWidth   =8;
	localparam bWidth   =32;
	localparam accWidth =32;
	localparam inSigned =0;

	localparam numTile  =outNum/tile;
	localparam tileIdxW =$clog2(numTile);

	localparam wDepth   =numTile*inNum;
	localparam wAddrW   =$clog2(wDepth);
	localparam bAddrW   =$clog2(numTile);
	localparam inIdxW   =$clog2(inNum);
	localparam outIdxW  =$clog2(numTile);

	localparam[3:0] idle     =4'd0;
	localparam[3:0] biasReq  =4'd1;
	localparam[3:0] biasWait0=4'd2;
	localparam[3:0] biasWait1=4'd3;
	localparam[3:0] biasLoad =4'd4;
	localparam[3:0] wReq     =4'd5;
	localparam[3:0] wWait0   =4'd6;
	localparam[3:0] wWait1   =4'd7;
	localparam[3:0] MAC      =4'd8;
	localparam[3:0] write    =4'd9;

	reg[3:0] state;

	//(* ram_style ="block" *) reg signed[(tile*wWidth-1):0] wMEM[0:(wDepth-1)];
	//(* ram_style ="block" *) reg signed[(tile*bWidth-1):0] bMEM[0:(numTile-1)];

	reg[(wAddrW-1):0] waddr;
	reg[(bAddrW-1):0] baddr;
	wire signed[(wWidth*tile-1):0] wdata;
	wire signed[(bWidth*tile-1):0] bdata;
	/*
	initial begin
		$readmemh(wMEMfile,wMEM);
		$readmemh(bMEMfile,bMEM);
	end
	
	always@(posedge clk)begin
		wdata <=wMEM[waddr];
		bdata <=bMEM[baddr];
	end
	*/
	fc2w fc2w0(.clka(clk),.ena(1'b1),.wea(1'b0),.addra(waddr),.dina({(tile*wWidth){1'b0}}),.douta(wdata));
	fc2b fc2b0(.clka(clk),.ena(1'b1),.wea(1'b0),.addra(baddr),.dina({(tile*bWidth){1'b0}}),.douta(bdata));
	integer i;

	reg[(inIdxW-1):0]   inIdx;
	reg[(tileIdxW-1):0] tileIdx;
	reg[(wAddrW-1):0]   wbaseAddr;

	reg signed[(accWidth-1):0] acc[0:(tile-1)];

	reg signed[(accWidth-1):0] inExtend;
	reg signed[(accWidth-1):0] wExtend;
	reg signed[(accWidth-1):0] multCut;

	function signed[(accWidth-1):0] inputExtend;
		input[(inWidth-1):0] inValue;
		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		//    !!!!!!!!!!DO NOT EVER USE "VAR" AS THE INPUT VARIABLE NAME!!!!!!!!!!    //
		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		begin
			if(inSigned) inputExtend ={{(accWidth-inWidth){inValue[inWidth-1]}},inValue};
			else         inputExtend ={{(accWidth-inWidth){1'b0}},inValue};
		end
	endfunction
	function signed[(accWidth-1):0] weightExtend;
		input[(wWidth-1):0] inValue;
		begin
			weightExtend ={{(accWidth-wWidth){inValue[wWidth-1]}},inValue};
		end
	endfunction
	function signed[(accWidth-1):0] biasExtend;
		input[(bWidth-1):0] inValue;
		begin
			biasExtend ={{(accWidth-bWidth){inValue[bWidth-1]}},inValue};
		end
	endfunction

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state     <=idle;
			busy      <=1'b0;
			done      <=1'b0;
			outFlat   <={(outNum*accWidth){1'b0}};
			waddr     <={wAddrW{1'b0}};
			baddr     <={bAddrW{1'b0}};			
			wbaseAddr <={wAddrW{1'b0}};
			inIdx     <={inIdxW{1'b0}};
			tileIdx   <={tileIdxW{1'b0}};
			for(i=0;i<tile;i=i+1) acc[i] <={accWidth{1'b0}};
		end
		else begin
			done <=1'b0;
			case(state)
				idle:begin
					if(start)begin
						busy      <=1'b1;
						outFlat   <={(outNum*accWidth){1'b0}};
						tileIdx   <={tileIdxW{1'b0}};
						inIdx     <={inIdxW{1'b0}};
						wbaseAddr <={wAddrW{1'b0}};
						baddr     <={bAddrW{1'b0}};
						state     <=biasReq;
					end
				end
				biasReq:begin
					baddr <=tileIdx;
					state<=biasWait0;
				end
				biasWait0: state <=biasWait1;
				biasWait1: state <=biasLoad;
				biasLoad:begin
					for(i=0;i<tile;i=i+1) acc[i] <=biasExtend(bdata[(i*bWidth)+:bWidth]);
					inIdx <={inIdxW{1'b0}};
					waddr <=wbaseAddr;
					state <=wReq;
				end
				wReq:begin
					waddr <=wbaseAddr+inIdx;
					state <=wWait0;
				end
				wWait0: state <=wWait1;
				wWait1: state <=MAC;
				MAC:begin
					inExtend =inputExtend(inFlat[(inIdx*inWidth)+:inWidth]);
					for(i=0;i<tile;i=i+1)begin
						wExtend =weightExtend(wdata[(i*wWidth)+:wWidth]);
						multCut =$signed(inExtend*wExtend);
						acc[i] <=acc[i]+multCut;
					end
					if(inIdx==(inNum-1)) state <=write;
					else begin
						inIdx <=inIdx+1'b1;
						waddr <=wbaseAddr+inIdx+1'b1;
						state <=wReq;
					end
				end
				write:begin
					for(i=0;i<tile;i=i+1) outFlat[((tileIdx*tile+i)*accWidth)+:accWidth] <=acc[i];
					if(tileIdx==(numTile-1))begin
						busy  <=1'b0;
						done  <=1'b1;
						state <=idle;
					end
					else begin
						tileIdx   <=tileIdx+1'b1;
						wbaseAddr <=wbaseAddr+inNum;
						baddr     <=tileIdx+1'b1;
						state     <=biasReq;
					end
				end
				default: state <=idle;
			endcase
		end
	end
endmodule
