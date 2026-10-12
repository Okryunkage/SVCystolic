`timescale 1ns/1ps

module convCore#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int inHeight=28, inWidth=28,
	parameter int kernelH=3, kernelW=3,
	parameter int strideH=1, strideW=1, padH=1, padW=1,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter int actWidth=8, requantShift=10,
	parameter int biasShift=0,
	parameter bit inSigned=1'b0,
	parameter int poolKernelSize=2, poolStride=2,
	parameter int convHeight=((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int convWidth =((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int outHeight =((convHeight-poolKernelSize)/poolStride)+1,
	parameter int outWidth  =((convWidth-poolKernelSize)/poolStride)+1,
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	parameter int wDepth=numTile*kernelTerms,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk, rst, start,
	input logic[outChannels-1:0] channelMask,
	input logic[dataWidth-1:0]   inData[0:inChannels-1][0:inHeight][0:inWidth-1],
	input logic signed[tile-1:0][wwidth-1:0] wdata,
	input logic signed[tile-1:0][bwidth-1:0] bdata,
	output logic[wAddrW-1:0] waddr,
	output logic[bAddrW-1:0] baddr,
	output logic busy, done,
	output logic[actWidth-1:0] outData[0:outChannels-1][0:outHeight-1][0:outWidth-1]);

	localparam int tileIdxW =(numTile>1)?$clog2(numTile):1;
	localparam int termIdxW =(kernelTerms>1)?$clog2(kernelTerms):1;
	localparam int outRowW  =(convHeight>1)?$clog2(convHeight):1;
	localparam int outColW  =(convWidth>1)?$clog2(convWidth):1;
	localparam int poolRowW =(outHeight>1)?$clog2(outHeight):1;
	localparam int poolColW =(outWidth>1)?$clog2(outWidth):1;

	typedef enum logic[3:0] {IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,PIXEL_INIT,WEIGHT_RUN,WRITE_OUTPUT,WAIT_POOL} state_t;
	state_t state;

	logic[tileIdxW-1:0]        tileIndex;
	logic[termIdxW-1:0]        issueTerm, consumeTerm;
	logic[outRowW-1:0]         outputRow;
	logic[outColW-1:0]         outputColumn;
	logic[wAddrW-1:0]          weightBaseAddress;
	logic[1:0]                 weightValid;
	logic                      issueDone;
	logic signed[accWidth-1:0] biasValue[0:tile-1];
	logic signed[accWidht-1:0] accumulator[0:tile-1];
	logic[outChannels-1:0]     channelMaskLatched;
	wire [actWidth-1:0]        quantizedData[0:tile-1];
	logic                      convValid;
	logic[actWidth-1:0]        convData[0:tile-1];
	wire                       poolValid, poolDone;
	wire [actWidth-1:0]        poolData[0:tile-1];
	logic[poolRowW-1:0]        poolRow;
	logic[poolColW-1:0]        poolColumn;

	integer lane, channel, row, column;
	integer inputChannel, kernelRow, kernelColumn, inputRow, inputColumn;
	logic signed[accWidth-1:0] inputValue, weightValue;
	logic signed[(2*accWidth)-1:0] product;

	function automatic logic signed[accWidth-1:0] extendInput(
		input logic[dataWidth-1:0] value);
		if(inSigned) extendInput ={{(accWidth-dataWidth){value[dataWidth-1]}}, value};
		else extendInput ={{(accWidth-dataWidth){1'b0}}, value};
	endfunction

	function automatic logic signed[accWidth-1:0] extendWeight(
		input logic[wWidth-1:0] value);
		extendWeight ={{(accWidth-wWidth){value[wWidth-1]}}, value};
	endfunction

	function automatic logic signed[accWidth-1:0] extendBias(
		input logic[bWidth-1:0] value);
		extendBias ={{(accWidth-bWidth){value[bWidth-1]}}, value};
	endfunction

	requantUsign#(
		.number(tile), .inWidth(accWidth),
		.outWidth(actWidth), .shift(requantShift)) uRequant(
		.inData(accumulator), .outData(quantizedData));

	maxPool#(
		.channels(tile),.inHeight(convHeight),.inWidth(convWidth),
		.dataWidth(actWidth),.kernelSize(poolKernelSize),.stride(poolStride)) pool(
		.clk(clk),.rst(rst),.start(state==BIAS_REQ),
		.inValid(convValid),.inData(convData),
		.outValid(poolValid),.outData(poolData),.done(poolDone));

	always_comb waddr =weightBaseAddress+issueTerm;

	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLE;
			{busy,done} <=2'b0;
			{baddr,tileIndex} <='0;
			{issueTerm,consumeTerm} <='0;
			{outputRow,outputColumn} <='0;
			{weightBaseAddress,weightValid} <='0;
			issueDone <=1'b0;
			channelMaskLatched <='1;
			convValid <=0;
			{poolRow,poolColumn} <='0;
			for(lane=0;lane<tile;lane++) {biasValue[lane],accumulator[lane],convData[lane]} <='0;
			for(channel=0;channel<outChannels;channel++)
				for(row=0;row<outHeight;row++)
					for(column=0;column<outWidth;column++)
						outData[channel][row][column] <='0;
		end
		else begin
			{done,convValid} <=2'b00;
			if(poolValid&&busy)begin
				for(lane=0;lane<tile;lane++) outData[tileIndex*tile+lane][poolRow][poolColumn] <=poolData[lane];
				if(poolColumn==outWidth-1)begin
					poolColumn <='0;
					if(poolRow==outHeight-1) poolRow <='0;
					else poolRow <=poolRow+1'b1;
				end
				else poolColumn <=poolColumn+1'b1;
			end
			unique case(state)
				IDLE:begin
					busy <=1'b0;
					if(start)begin
						busy <=1'b1;
						channelMaskLatched <=channelMask;
						tileIndex <='0;
						{outputRow,outputColumn} <='0;
						weightBaseAddress <='0;
						baddr <='0;
						state <=BIAS_REQ;
					end
				end
				BIAS_REQ:begin
					baddr <=tileIndex;
					poolRow <='0;
					poolColumn <='0;
					state <=BIAS_WAIT0;
				end
				BIAS_WAIT0:state <=BIAS_WAIT1;
				BIAS_WAIT1:state <=BIAS_LOAD;
				BIAS_LOAD:begin
					for(lane=0;lane<tile;lane++) biasValue[lane] <=extendBias(bdata[lane])<<<biasShift;
					state <=PIXEL_INIT;
				end
				PIXEL_INIT:begin
					for(lane=0;lane<tile;lane++) accumulator[lane] <=biasValue[lane];
					{issueTerm,consumeTerm,weightValid} <='0;
					issueDone <=1'b0;
					state <=WEIGHT_RUN;
				end
				WEIGHT_RUN:begin
					weightValid <={weightValid[0],!issueDone};
					if(!issueDone)begin
						if(issueTerm==kernelTerms-1) issueDone <=1'b1;
						else issueTerm <=issueTerm+1'b1;
					end
					if(weightValid[1])begin
						inputChannel =consumeTerm/(kernelH*kernelW);
						kernelRow    =(consumeTerm/kernelW)%kernelH;
						kernelColumn =consumeTerm%kernelW;
						inputRow     =outputRow   *strideH+kernelRow   -padH;
						inputColumn  =outputColumn*strideW+kernelColumn-padW;
						if(inputRow<0 || inputRow>=inHeight || inputColumn<0 || inputColumn>=inWidth) inputValue ='0;
						else inputValue =extendInput(inData[inputChannel][inputRow][inputColumn]);
						for(lane=0; lane<tile; lane++)begin
							weightValue =extendWeight(wdata[lane]);
							product =inputValue*weightValue;
							accumulator[lane] <=accumulator[lane]+product[accWidth-1:0];
						end
						if(consumeTerm==kernelTerms-1)begin
							weightValid <='0;
							state <=WRITE_OUTPUT;
						end
						else consumeTerm <=consumeTerm+1'b1;
					end
				end
				WRITE_OUTPUT:begin
					convValid <=1'b1;
					for(lane=0;lane<tile;lane++)begin
						if(channelMaskLatched[tileIndex*tile+lane]) convData[lane] <=quantizedData[lane];
						else                                        convData[lane] <='0;
					end
					if(outputColumn !=convWidth-1)begin
						outputColumn <=outputColumn+1'b1;
						state <=PIXEL_INIT;
					end
					else if(outputRow!=convHeight-1)begin
						outputColumn <='0;
						outputRow <=outputRow+1'b1;
						state <=PIXEL_INIT;
					end
					else state <=WAIT_POOL;
				end
				WAIT_POOL: if(poolDone)begin
					if(tileIndex !=numTile-1)begin
						tileIndex <=tileIndex+1'b1;
						outputRow <='0;
						outputColumn <='0;
						weightBaseAddress <=weightBaseAddress +kernelTerms;
						baddr <=tileIndex+1'b1;
						state <=BIAS_REQ;
					end
					else begin
						busy <=1'b0;
						done <=1'b1;
						state <=IDLE;
					end
				end
				default: state <=IDLE;
			endcase
		end
	end
endmodule