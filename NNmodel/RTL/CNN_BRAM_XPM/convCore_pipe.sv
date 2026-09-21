`timescale 1ns/1ps

module convCore_pipe#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int inHeight=28, inWidth=28,
	parameter int kernelH=3, kernelW=3,
	parameter int strideH=1, strideW=1, padH=1, padW=1,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter bit inSigned=1'b0,
	parameter int outHeight=((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int outWidth=((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	//Computing one output pixel requries kernelTerms accumulation (kernel size X input channel depth).
	parameter int wDepth=numTile*kernelTerms,
	//BRAM depth of Weight is numTile X kernelTerms, as each operation computes kernelTemrs for every tile.
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1)(
	input logic clk, rst, start,
	input logic [dataWidth-1:0] inData[0:inChannels-1][0:inHeight-1][0:inWidth-1],
	input logic signed [tile-1:0][wWidth-1:0] wdata,
	input logic signed [tile-1:0][bWidth-1:0] bdata,
	output logic [wAddrW-1:0] waddr,
	output logic [bAddrW-1:0] baddr,
	output logic busy, done,
	output logic signed [accWidth-1:0] outData[0:outChannels-1][0:outHeight-1][0:outWidth-1]);
	
	localparam int tileIdxW =(numTile>1)?$clog2(numTile):1;
	localparam int termIdxW =(kernelTerms>1)?$clog2(kernelTerms):1;
	localparam int outRowW  =(outHeight>1)?$clog2(outHeight):1;
	localparam int outColW  =(outWidth>1)?$clog2(outWidth):1;

	typedef enum logic[3:0] {IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,PIXEL_INIT,WEIGHT_RUN,WRITE_OUTPUT} state_t;
	state_t state;

	logic[tileIdxW-1:0] tileIndex;
	logic[termIdxW-1:0] issueTerm,consumeTerm;
	//A term is one MAC element identified by an input channel, kernel row, and kernel column.
	//issueTerm:   Kernel term currently requested from weight BRAM.
	//consumeTerm: Kernel term currently used for the MAC operation
	logic[outRowW-1:0] outputRow;
	logic[outColW-1:0] outputColumn;
	logic[wAddrW-1:0] weightBaseAddress;
	logic[1:0] weightValid;
	//Tracks valid weight data through the two-cycle BRAM read pipeline.
	//weightValid[0]: first BRAM delay stage.
	//weightValid[1]: wdata is valid for MAC.
	logic issueDone;
	//High after all weight read requests are issued.
	logic signed[accWidth-1:0] biasValue[0:tile-1];
	logic signed[accWidth-1:0] accumulator[0:tile-1];

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

	always_comb waddr =weightBaseAddress+issueTerm;

	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLE;
			{busy,done} <=2'b0;
			baddr <='0;
			tileIndex <='0;
			{issueTerm,consumeTerm} <='0;
			{outputRow,outputColumn} <='0;
			{weightBaseAddress,weightValid} <='0;
			issueDone <=1'b0;
			for(lane=0; lane<tile; lane++)begin
				biasValue[lane] <='0;
				accumulator[lane] <='0;
			end
			for(channel=0; channel<outChannels; channel++)
				for(row=0; row<outHeight; row++)
					for(column=0; column<outWidth; column++)
						outData[channel][row][column] <='0;
		end
		else begin
			done <=1'b0;
			unique case(state)
				IDLE:begin
					busy <=1'b0;
					if(start)begin
						busy <=1'b1;
						tileIndex <='0;
						{outputRow,outputColumn} <='0;
						weightBaseAddress <='0;
						baddr <='0;
						state <=BIAS_REQ;
					end
				end
				BIAS_REQ:begin
					baddr <=tileIndex;
					state <=BIAS_WAIT0;
				end
				BIAS_WAIT0:state <=BIAS_WAIT1;
				BIAS_WAIT1:state <=BIAS_LOAD;
				BIAS_LOAD:begin
					for(lane=0; lane<tile; lane++) biasValue[lane] <=extendBias(bdata[lane]);
					state <=PIXEL_INIT;
				end
				PIXEL_INIT:begin
					for(lane=0; lane<tile; lane++) accumulator[lane] <=biasValue[lane];
					{issueTerm,consumeTerm,weightValid} <='0;
					issueDone <=1'b0;
					state <=WEIGHT_RUN;
				end
				WEIGHT_RUN:begin
					weightValid <={weightValid[0], !issueDone};
					if(!issueDone)begin
						if(issueTerm ==kernelTerms-1) issueDone <=1'b1;
						else issueTerm <=issueTerm+1'b1;
					end
					if(weightValid[1])begin
						inputChannel =consumeTerm/(kernelH*kernelW);
						kernelRow =(consumeTerm/kernelW)%kernelH;
						kernelColumn =consumeTerm%kernelW;
						inputRow =outputColumn*strideW+kernelColumn-padW;
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
					for(lane=0; lane<tile; lane++) outData[tileIndex*tile+lane][outputRow][outputColumn] <=accumulator[lane];
					if(outputColumn !=outWidth-1)begin
						outputColumn <=outputColumn+1'b1;
						state <=PIXEL_INIT;
					end
					else if(outputRow!=outHeight-1)begin
						outputColumn <='0;
						outputRow <=outputRow+1'b1;
						state <=PIXEL_INIT;
					end
					else if(tileIndex !=outHeight-1)begin
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


