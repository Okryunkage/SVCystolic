`timescale 1ns/1ps

module fcCore#(
	parameter int tile=5,inChannels=16,inHeight=7,inWidth=7,outNum=10,
	parameter int dataWidth=8,wWidth=8,bWidth=8,accWidth=32,
	parameter int biasShift=0,
	parameter int inNum=inChannels*inHeight*inWidth,
	parameter int numTile=(outNum+tile-1)/tile,
	parameter int wDepth=numTile*inNum,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk,rst,start,
	input logic[dataWidth-1:0] inData[0:inChannels-1][0:inHeight-1][0:inWidth-1],
	input logic signed[tile-1:0][wWidth-1:0] wdata,
	input logic signed[tile-1:0][bWidth-1:0] bdata,
	output logic[wAddrW-1:0] waddr,
	output logic[bAddrW-1:0] baddr,
	output logic busy,done,
	output logic signed[accWidth-1:0] outData[0:outNum-1]);

	localparam int indexW=(inNum>1)?$clog2(inNum):1;
	localparam int tileW=(numTile>1)?$clog2(numTile):1;
	typedef enum logic[3:0] {IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,
		READ_REQ,READ_WAIT,MAC,WRITE_RESULT,FINISH} stateType;
	stateType state;
	logic[indexW-1:0] inputIndex;
	logic[tileW-1:0] tileIndex;
	logic signed[accWidth-1:0] accumulator[0:tile-1];
	logic signed[accWidth-1:0] inputValue,weightValue;
	logic signed[2*accWidth-1:0] product;
	integer inputChannel,spatial;

	always_comb begin
		inputChannel=int'(inputIndex)/(inHeight*inWidth);
		spatial=int'(inputIndex)%(inHeight*inWidth);
		waddr=wAddrW'(int'(tileIndex)*inNum+int'(inputIndex));
		baddr=bAddrW'(tileIndex);
	end
	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLE;
			busy <=0;
			done <=0;
			inputIndex <='0;
			tileIndex <='0;
			for(integer l=0;l<tile;l=l+1) accumulator[l] <='0;
			for(integer n=0;n<outNum;n=n+1) outData[n] <='0;
		end
		else begin
			done <=0;
			case(state)
				IDLE: if(start)begin
					busy <=1;
					inputIndex <='0;
					tileIndex <='0;
					state <=BIAS_REQ;
				end
				BIAS_REQ: state <=BIAS_WAIT0;
				BIAS_WAIT0: state <=BIAS_WAIT1;
				BIAS_WAIT1: state <=BIAS_LOAD;
				BIAS_LOAD:begin
					for(integer l=0;l<tile;l=l+1)
						accumulator[l] <=$signed({{(accWidth-bWidth){bdata[l][bWidth-1]}},bdata[l]}) <<< biasShift;
					inputIndex <='0;
					state <=READ_REQ;
				end
				READ_REQ: state <=READ_WAIT;
				READ_WAIT: state <=MAC;
				MAC:begin
					inputValue=$signed({{(accWidth-dataWidth){1'b0}},inData[inputChannel][spatial/inWidth][spatial%inWidth]});
					for(integer l=0;l<tile;l=l+1)begin
						weightValue=$signed({{(accWidth-wWidth){wdata[l][wWidth-1]}},wdata[l]});
						product=inputValue*weightValue;
						accumulator[l] <=accumulator[l]+product[accWidth-1:0];
					end
					if(inputIndex==inNum-1) state <=WRITE_RESULT;
					else begin
						inputIndex <=inputIndex+1'b1;
						state <=READ_REQ;
					end
				end
				WRITE_RESULT:begin
					for(integer l=0;l<tile;l=l+1)
						if(int'(tileIndex)*tile+l<outNum)
							outData[int'(tileIndex)*tile+l] <=accumulator[l];
					if(tileIndex==numTile-1) state <=FINISH;
					else begin
						tileIndex <=tileIndex+1'b1;
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
	`ifndef SYNTHESIS
	initial begin
		if(tile<1 || outNum<1 || inChannels<1 || inHeight<1 || inWidth<1 ||
			accWidth<dataWidth+1 || accWidth<bWidth || accWidth<wWidth ||
			biasShift<0 || bWidth+biasShift>accWidth)
			$fatal(1,"Invalid fcCoreArray parameters");
	end
	`endif
endmodule