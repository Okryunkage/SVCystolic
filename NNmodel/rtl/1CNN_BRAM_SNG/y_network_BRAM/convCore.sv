`timescale 1ns/1ps

module convCore#(
	parameter int tile=8, inChannels=1, outChannels=32,
	parameter int inHeight=28, inWidth=28,
	parameter int kernelH=3, kernelW=3,
	parameter int strideH=1, strideW=1, padH=1, padW=1,
	parameter int dataWidth=8, wWidth=8, bWidth=8, accWidth=32,
	parameter int actWidth=8, requantShift=10,
	parameter bit inSigned=1'b0,
	parameter int outHeight=((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int outWidth=((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int numTile=outChannels/tile,
	parameter int kernelTerms=inChannels*kernelH*kernelW,
	parameter int wDepth=numTile*kernelTerms,
	parameter int wAddrW=(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW=(numTile>1)?$clog2(numTile):1,
	parameter int outDepth=numTile*outHeight*outWidth,
	parameter int outAddrW=(outDepth>1)?$clog2(outDepth):1,
	parameter int inTile=1, inReadLatency=2,
	parameter int inDepth=((inChannels+inTile-1)/inTile)*inHeight*inWidth,
	parameter int inAddrW=(inDepth>1)?$clog2(inDepth):1)(
	input logic clk, rst, start,
	input logic [outChannels-1:0] channelMask,
	output logic inReadEnable,
	output logic[inAddrW-1:0] inReadAddress,
	input logic inReadValid,
	input logic[dataWidth-1:0] inReadData[0:inTile-1],
	input logic signed [tile-1:0][wWidth-1:0] wdata,
	input logic signed [tile-1:0][bWidth-1:0] bdata,
	output logic [wAddrW-1:0] waddr,
	output logic [bAddrW-1:0] baddr,
	output logic busy, done,
	output logic outValid,
	output logic [outAddrW-1:0] outAddr,
	output logic [actWidth-1:0] outData[0:tile-1]);
	
	localparam int tileIdxW =(numTile>1)?$clog2(numTile):1;
	localparam int termIdxW =(kernelTerms>1)?$clog2(kernelTerms):1;
	localparam int outRowW  =(outHeight>1)?$clog2(outHeight):1;
	localparam int outColW  =(outWidth>1)?$clog2(outWidth):1;
	localparam int inLaneW  =(inTile>1)?$clog2(inTile):1;
	localparam int termLatency=(inReadLatency>2)?inReadLatency:2;

	typedef enum logic[3:0] {IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,PIXEL_INIT,WEIGHT_RUN,WRITE_OUTPUT,OUTPUT_DONE} state_t;
	state_t state;

	logic[tileIdxW-1:0] tileIndex;
	logic[termIdxW-1:0] issueTerm,consumeTerm;
	logic[outRowW-1:0] outputRow;
	logic[outColW-1:0] outputColumn;
	logic[wAddrW-1:0] weightBaseAddress;
	logic[termLatency-1:0] termValid,paddingPipeline;
	logic[inLaneW-1:0] lanePipeline[0:termLatency-1];
	logic issueValid,issuePadding;
	logic[inLaneW-1:0] issueLane;
	wire[dataWidth-1:0] alignedInput;
	wire signed[tile-1:0][wWidth-1:0] alignedWeight;
	logic issueDone;
	logic [outChannels-1:0] channelMaskLatched;
	logic signed[accWidth-1:0] biasValue[0:tile-1];
	logic signed[accWidth-1:0] accumulator[0:tile-1];
	wire[actWidth-1:0] quantizedData[0:tile-1];

	integer lane;
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
		.number(tile),.inWidth(accWidth),.outWidth(actWidth),.shift(requantShift))
	u_requant(
		.inData(accumulator),.outData(quantizedData));

	always_comb waddr =weightBaseAddress+issueTerm;

	always_comb begin
		inputChannel =int'(issueTerm)/(kernelH*kernelW);
		kernelRow    =(int'(issueTerm)/kernelW)%kernelH;
		kernelColumn =int'(issueTerm)%kernelW;
		inputRow     =int'(outputRow)*strideH+kernelRow-padH;
		inputColumn  =int'(outputColumn)*strideW+kernelColumn-padW;
		issueValid   =(state==WEIGHT_RUN) && !issueDone && !rst;
		issuePadding =inputRow<0 || inputRow>=inHeight || inputColumn<0 || inputColumn>=inWidth;
		issueLane    =inLaneW'(inputChannel%inTile);
		inReadEnable =issueValid && !issuePadding;
		inReadAddress='0;
		if(inReadEnable)
			inReadAddress=inAddrW'((inputChannel/inTile)*inHeight*inWidth+
				inputRow*inWidth+inputColumn);
	end

	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			termValid <='0;
			paddingPipeline <='0;
			for(integer s=0;s<termLatency;s=s+1) lanePipeline[s] <='0;
		end
		else begin
			termValid[0] <=issueValid;
			paddingPipeline[0] <=issuePadding;
			lanePipeline[0] <=issueLane;
			for(integer s=1;s<termLatency;s=s+1)begin
				termValid[s] <=termValid[s-1];
				paddingPipeline[s] <=paddingPipeline[s-1];
				lanePipeline[s] <=lanePipeline[s-1];
			end
		end
	end

	generate
		if(inReadLatency<termLatency)begin:INPUT_ALIGN
			logic[dataWidth-1:0] pixelPipeline[0:termLatency-inReadLatency-1];
			always_ff@(posedge clk or posedge rst)begin
				if(rst)begin
					for(integer s=0;s<termLatency-inReadLatency;s=s+1) pixelPipeline[s] <='0;
				end
				else begin
					if(termValid[inReadLatency-1] && !paddingPipeline[inReadLatency-1])
						pixelPipeline[0] <=inReadData[lanePipeline[inReadLatency-1]];
					else pixelPipeline[0] <='0;
					for(integer s=1;s<termLatency-inReadLatency;s=s+1)
						pixelPipeline[s] <=pixelPipeline[s-1];
				end
			end
			assign alignedInput=pixelPipeline[termLatency-inReadLatency-1];
		end
		else begin:INPUT_DIRECT
			assign alignedInput=inReadData[lanePipeline[termLatency-1]];
		end
		if(termLatency>2)begin:WEIGHT_ALIGN
			logic signed[tile-1:0][wWidth-1:0] weightPipeline[0:termLatency-3];
			always_ff@(posedge clk or posedge rst)begin
				if(rst)begin
					for(integer s=0;s<termLatency-2;s=s+1) weightPipeline[s] <='0;
				end
				else begin
					weightPipeline[0] <=wdata;
					for(integer s=1;s<termLatency-2;s=s+1)
						weightPipeline[s] <=weightPipeline[s-1];
				end
			end
			assign alignedWeight=weightPipeline[termLatency-3];
		end
		else begin:WEIGHT_DIRECT
			assign alignedWeight=wdata;
		end
	endgenerate

	`ifndef SYNTHESIS
	initial begin
		if(inChannels<1 || inHeight<1 || inWidth<1 || inTile<1 || inReadLatency<1 || inReadLatency>100)
			$fatal(1,"convCore requires valid input dimensions, inTile and 1 <= inReadLatency <= 100");
		if(inDepth!=((inChannels+inTile-1)/inTile)*inHeight*inWidth ||
			inAddrW<((inDepth>1)?$clog2(inDepth):1))
			$fatal(1,"convCore input memory depth/address width mismatch");
		if(tile<1 || outChannels<1 || outChannels%tile!=0 || numTile!=outChannels/tile)
			$fatal(1,"convCore requires positive tile/outChannels and complete tiles");
		if(outHeight<1 || outWidth<1 || outDepth!=numTile*outHeight*outWidth)
			$fatal(1,"convCore requires valid output dimensions and matching outDepth");
		if(outAddrW<((outDepth>1)?$clog2(outDepth):1))
			$fatal(1,"convCore outAddrW is too small");
	end
	always@(posedge clk)begin
		if(!rst && termValid[inReadLatency-1] && !paddingPipeline[inReadLatency-1] && inReadValid!==1'b1)
			$fatal(1,"convCore: missing input response at configured inReadLatency");
	end
	`endif

	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			state <=IDLE;
			{busy,done} <=2'b0;
			outValid <=1'b0;
			outAddr <='0;
			baddr <='0;
			tileIndex <='0;
			{issueTerm,consumeTerm} <='0;
			{outputRow,outputColumn} <='0;
			weightBaseAddress <='0;
			issueDone <=1'b0;
			channelMaskLatched <='1;
			for(lane=0; lane<tile; lane++)begin
				biasValue[lane] <='0;
				accumulator[lane] <='0;
				outData[lane] <='0;
			end
		end
		else begin
			done <=1'b0;
			outValid <=1'b0;
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
					{issueTerm,consumeTerm} <='0;
					issueDone <=1'b0;
					state <=WEIGHT_RUN;
				end
				WEIGHT_RUN:begin
					if(!issueDone)begin
						if(issueTerm ==kernelTerms-1) issueDone <=1'b1;
						else issueTerm <=issueTerm+1'b1;
					end
					if(termValid[termLatency-1])begin
						if(paddingPipeline[termLatency-1]) inputValue ='0;
						else inputValue =extendInput(alignedInput);
						for(lane=0; lane<tile; lane++)begin
							weightValue =extendWeight(alignedWeight[lane]);
							product =inputValue*weightValue;
							accumulator[lane] <=accumulator[lane]+product[accWidth-1:0];
						end
						if(consumeTerm==kernelTerms-1)begin
							state <=WRITE_OUTPUT;
						end
						else consumeTerm <=consumeTerm+1'b1;
					end
				end
				WRITE_OUTPUT:begin
					//Registered write request: the receiver stores it on the next edge.
					outValid <=1'b1;
					outAddr <=outAddrW'(tileIndex*(outHeight*outWidth)
						+outputRow*outWidth+outputColumn);
					for(lane=0; lane<tile; lane++)begin
						if(channelMaskLatched[tileIndex*tile+lane])
							outData[lane] <=quantizedData[lane];
						else
							outData[lane] <='0;
					end
					if(outputColumn !=outWidth-1)begin
						outputColumn <=outputColumn+1'b1;
						state <=PIXEL_INIT;
					end
					else if(outputRow!=outHeight-1)begin
						outputColumn <='0;
						outputRow <=outputRow+1'b1;
						state <=PIXEL_INIT;
					end
					else if(tileIndex !=numTile-1)begin
						tileIndex <=tileIndex +1'b1;
						outputRow <='0;
						outputColumn <='0;
						weightBaseAddress <=weightBaseAddress +kernelTerms;
						baddr <=tileIndex+1'b1;
						state <=BIAS_REQ;
					end
					else begin
						state <=OUTPUT_DONE;
					end
				end
				OUTPUT_DONE:begin
					//Same-clock memory consumes the final request at this edge.
					busy <=1'b0;
					done <=1'b1;
					state <=IDLE;
				end
				default: state <=IDLE;
			endcase
		end
	end
endmodule
