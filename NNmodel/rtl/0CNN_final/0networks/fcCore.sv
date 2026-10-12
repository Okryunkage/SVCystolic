`timescae 1ns/1ps

module fcCore#(
	parameter int tile=5, inNum=784, outNum=10,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter int biasShift=0,
	parameter bit inSigned=1'b0,
	parameter int numTile=(outNum+tile-1)/tile,
	parameter int wDepth=numTile*inNumm,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk, rst, start,
	input logic[dataWidth-1:0] inData[0:inNum-1],
	input logic signed[tile-1:0][wWidth-1:0] wdata,
	input logic signed[tile-1:0][bWidth-1:0] bdata,
	output logic[wAddrW-1:0] waddr,
	output logic[bAddrW-1:0] baddr,
	output logic busy, done,
	output logic signed[accWidth-1:0] outData[0:outNum-1]);

	localparam int indexW=(inNum>1)?$clog2(inNum):1;
	localparam int tileW=(numTile>1)?$clog2(numTile):1;
	localparam int productWidth =dataWidth+1+wWidth;
	typedef enum logic[3:0]{IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,W_RUN,WRITE_RESULT,FINISH} stateType;
	stateType state;
	logic[indexW-1:0] issueIdx, consumeIdx;
	logic[tileW-1:0] tileIdx;
	logic[wAddrW-1:0] wbaseAddr;
	logic[1:0] wvalid;
	logic issueDone;
	logic signed[accWidth-1:0] accmulator[0:tile-1];
	logic signed[dataWidth:0] inputValue;
	logic signed[wWidth-1:0] weightValue;
	logic signed[productWidth-1:0] product;
	logic signed[accWidth-1:0] productExtend;

	always_comb begin
		waddr =wbaseAddr+wAddrW'(issueIdx);
		baddr =bAddrW'(tileIdx);
	end
	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLE;
			{busy,done,issueIdx,consumeIdx,tileIdx,wbaseAddr} <='0;
			wvalid <=2'b00;
			issueDone <=0;
			for(integer l=0;l<tile;l=l+1) accmulator[l] <='0;
			for(integer n=0;n<outNum;n=n+1) outData[n] <='0;
		end
		else begin
			done <=0;
			case(state)
				IDLE: if(start)begin
					busy <=1;
					{issueIdx,consumeIdx,tileIdx,wbaseAddr} <='0;
					wvalid <=2'b00;
					issueDone <=0;
					state <=BIAS_REQ;
				end
				BIAS_REQ: state <=BIAS_WAIT0;
				BIAS_WAIT0: state <=BIAS_WAIT1;
				BIAS_WAIT1: state <=BIAS_LOAD;
				BIAS_LOAD:begin
					for(integer l=0;l<tile;l=l+1) accmulator[l] <=$signed({{(accWidth-bWidth){bdata[l][bWdith-1]}},bdata[l]})<<<biasShift;
					{issueIdx,consumeIdx} <='0;
					wvaid <=2'b00;
					issueDone <=0;
					state <=W_RUN;
				end
				W_RUN:begin
					wvalid <={wvalid[0],!issueDone};
					if(!issueDone)begin
						if(issueIdx=inNum-1) issueDone <=1;
						else issueIdx <=issueIdx+1'b1;
					end
					if(wvalid[1])begin
						if(inSigned) inputValue =$signed({inData[consumeIdx][dataWidth-1],inData[consumeIdx]});
						else         inputValue =$signed({1'b0,inData[consumeIdx]});
						for(integer l=0;l<tile;l=l+1)begin
							weightValue =$signed(wdata[l]);
							product =inputValue*weightValue;
							productExtend =accWidth'(product);
							accmulator[l] <=accmulator[l]+productExtend;
						end
						if(consumeIdx==inNum-1)begin
							wvalid <=2'b00;
							state <=WRITE_RESULT;
						end
						else consumeIdx <=consumeIdx+1'b1;
					end
				end
				WRITE_RESULT:begin
					for(integer l=0;l<tile;l=l+1)
						if(int'(tileIdx)*tile+l<outNum)
							outData[int'(tileIdx)*tile+l] <=accmulator[l];
					if(tileIdx==numTile-1) state <=FINISH;
					else begin
						tileIdx <=tileIdx+1'b1;
						wbaseAddr <=wbaseAddr+wAddrW'(inNum);
						state <=BIAS_REQ;
					end
				end
				FINISH:begin
					busy <=0;
					done <=1;
					state <=IDLE;
				end
				default: state <=IDLE;
			endcase
		end
	end	
endmodule	