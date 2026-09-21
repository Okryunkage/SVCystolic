`timescale 1ns/1ps

module fcCore_pipe#(
	parameter tile     =8,
	parameter inNum    =784,
	parameter outNum   =64,
	parameter inWIdth  =8,
	parameter wWidth   =8,
	parameter bWidth   =8,
	parameter accWidth =32,
	parameter inSigned =0,

	parameter numTile  =outNum/tile,
	parameter wDepth   =numTile*inNum,
	parameter wAddrW   =(wDepth>1)?$clog2(wDepth):1,
	parameter bAddrW   =(numTile>1)?$clog2(numTile):1)(

	input clk,
	input rst,
	input start,
	input       [(inNum*inWidth-1):0] inFlat,
	input signed[(tile*wWidth-1):0]   wdata,
	input signed[(tile*bWidth-1):0]   bdata,
	output reg   [(wAddrW-1):0]        waddr,
	output reg   [(bAddrW-1):0]        baddr,
	output reg busy,
	output reg done,
	output reg signed[(outNum*accWidth-1):0] outFlat);

	localparam tileIdxW =(numTile>1)?$clog2(numTile):1;
	localparam inIdxW   =(inNum>1)?$clog2(inNum):1;

	localparam[3:0] idle     =4'd0;
	localparam[3:0] biasReq  =4'd1;
	localparam[3:0] biasWait0=4'd2;
	localparam[3:0] biasWait1=4'd3;
	localparam[3:0] biasLoad =4'd4;
	localparam[3:0] wRun     =4'd5;
	localparam[3:0] write    =4'd6;

	reg[3:0] state;

	integer i;

	reg[(inIdxW-1):0]   issueIdx;
	reg[(inIdxW-1):0]   consumeIdx;
	reg[(tileIdxW-1):0] tileIdx;
	reg[(wAddrW-1):0]   wbaseAddr;
	reg[1:0]            wvalid;
	reg                 issueDone;

	reg signed[(accWidth-1):0] acc[0:(tile-1)];

	reg signed[(accWidth-1):0] inExtend;
	reg signed[(accWidth-1):0] wExtend;
	reg signed[(accWidth-1):0] multCut;

	assign waddr =wbaseAddr+issueIdx;

	function signed[(accWidth-1):0] inputExtend;
		input[(inWidth-1):0] inValue;begin
			if(inSigned) inputExtend ={{(accWidth-inWidth){inValue[inWidth-1]}},inValue};
			else         inputExtend ={{(accWidth-inWidth){1'b0}},inValue};
		end
	endfunction
	function signed[(accWidth-1):0] weightExtend;
		input[(wWidth-1):0] inValue;begin
			weightExtend ={{(accWidth-wWidth){inValue[wWidth-1]}},inValue};
		end
	endfunction
	function signed[(accWidth-1):0] biasExtend;
		input[(bWidth-1):0] inValue;begin
			biasExtend ={{(accWidth-bWidth){inValue[bWidth-1]}},inValue};
		end
	endfunction

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state     <=idle;
			busy      <=1'b0;
			done      <=1'b0;
			outFlat   <={(outNum*accWidth){1'b0}};
			baddr     <={bAddrW{1'b0}};
			wbaseAddr <={wAddrW{1'b0}};
			issueIdx  <={inIdxW{1'b0}};
			consumeIdx<={inIdxW{1'b0}};
			tileIdx   <={tileIdxW{1'b0}};
			wvalid    <=2'b00;
			issueDone <=1'b0;
			for(i=0;i<tile;i=i+1) acc[i] <={accWidth{1'b0}};
		end
		else begin
			done <=1'b0;
			case(state)
				idle:begin
					busy <=1'b0;
					if(start)begin
						busy      <=1'b1;
						outFlat   <={(outNum*accWidth){1'b0}};
						tileIdx   <={tileIdxW{1'b0}};
						issueIdx  <={inIdxW{1'b0}};
						consumeIdx<={inIdxW{1'b0}};
						wbaseAddr <={wAddrW{1'b0}};
						baddr     <={bAddrW{1'b0}};
						wvalid    <=2'b00;
						issueDone <=1'b0;
						state     <=biasReq;
					end
				end
				biasReq:begin
					baddr <=tileIdx;
					state <=biasWait0;
				end
				biasWait0: state <=biasWait1;
				biasWait1: state <=biasLoad;
				biasLoad:begin
					for(i=0;i<tile;i=i+1) acc[i] <=biasExtend(bdata[(i*bWidth)+:bWidth]);
					issueIdx   <={inIdxW{1'b0}};
					consumeIdx <={inIdxW{1'b0}};
					wvalid     <=2'b00;
					issueDone  <=1'b0;
					state      <=wRun;
				end
				wRun:begin
					wvalid <={wvalid[0],!issueDone};
					if(!issueDone)begin
						if(issueIdx==(inNum-1)) issueDone <=1'b1;
						else issueIdx <=issueIdx+1'b1;
					end
					if(wvalid[1])begin
						inExtend =inputExtend(inFlat[(consumeIdx*inWidth)+:inWidth]);
						for(i=0;i<tile;i=i+1)begin
							wExtend =weightExtend(wdata[(i*wWidth)+:wWidth]);
							multCut =$signed(inExtend*wExtend);
							acc[i] <=acc[i]+multCut;
						end
						if(consumeIdx==(inNum-1))begin
							wvalid <=2'b00;
							state  <=write;
						end
						else consumeIdx <=consumeIdx+1'b1;
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