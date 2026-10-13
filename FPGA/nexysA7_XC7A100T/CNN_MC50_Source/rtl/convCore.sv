`timescale 1ns/1ps

module convCore#(
	parameter int tile =8, inChannels =1, outChannels =32,
	parameter int inHeight =28, inWidth =28,
	parameter int kernelH =3, kernelW =3,
	parameter int strideH =1, strideW =1, padH =1, padW =1,
	parameter int dataWidth =8, wWidth =8, bWidth =8, accWidth =32,
	parameter int actWidth =8, requantShift =10,
	parameter int biasShift =0,
	parameter bit inSigned =1'b0,
	parameter int poolKernelSize =2, poolStride =2,
	parameter int convHeight =((inHeight+2*padH-kernelH)/strideH)+1,
	parameter int convWidth =((inWidth+2*padW-kernelW)/strideW)+1,
	parameter int outHeight =((convHeight-poolKernelSize)/poolStride)+1,
	parameter int outWidth =((convWidth-poolKernelSize)/poolStride)+1,
	parameter int numTile =outChannels/tile,
	parameter int kernelTerms =inChannels*kernelH*kernelW,
	parameter int wDepth =numTile*kernelTerms,
	parameter int wAddrW =(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW =(numTile>1)?$clog2(numTile):1,
	parameter int termIdxW =(kernelTerms>1)?$clog2(kernelTerms):1,
	parameter int outRowW =(convHeight>1)?$clog2(convHeight):1,
	parameter int outColW =(convWidth>1)?$clog2(convWidth):1,
	parameter int outDepth =numTile*outHeight*outWidth,
	parameter int outAddrW =(outDepth>1)?$clog2(outDepth):1)(
	input logic clk, rst, start,
	input logic[outChannels-1:0] channelMask,
	//Reader returns one input element exactly two clocks after each request.
	output wire logic requestEnable,
	output wire logic[termIdxW-1:0] requestTerm,
	output wire logic[outRowW-1:0] requestRow,
	output wire logic[outColW-1:0] requestColumn,
	input logic inValid,
	input logic[dataWidth-1:0] inData[0:0],
	input logic signed[tile-1:0][wWidth-1:0] wdata,
	input logic signed[tile-1:0][bWidth-1:0] bdata,
	output logic[wAddrW-1:0] waddr,
	output logic[bAddrW-1:0] baddr,
	output logic busy, done,
	output wire logic outWriteEnable,
	output wire logic[outAddrW-1:0] outWriteAddress,
	output wire logic[actWidth-1:0] outData[0:tile-1]);

	localparam int tileIdxW =(numTile>1)?$clog2(numTile):1;
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
	logic signed[accWidth-1:0] accumulator[0:tile-1];
	logic[outChannels-1:0]     channelMaskLatched;
	wire [actWidth-1:0]        quantizedData[0:tile-1];
	logic                      convValid;
	logic[actWidth-1:0]        convData[0:tile-1];
	wire                       poolValid, poolDone;
	wire [actWidth-1:0]        poolData[0:tile-1];
	logic[poolRowW-1:0]        poolRow;
	logic[poolColW-1:0]        poolColumn;

	integer lane;
	logic macValid,macLast;
	logic[dataWidth-1:0] inputRegister;
	logic signed[tile-1:0][wWidth-1:0] weightRegister;
	localparam int productWidth =dataWidth+1+wWidth;
	logic signed[dataWidth:0] inputValue;
	logic signed[wWidth-1:0] weightValue;
	logic signed[productWidth-1:0] product;

	function automatic logic signed[dataWidth:0] extendInput(
		input logic[dataWidth-1:0] value);
		if(inSigned) extendInput ={value[dataWidth-1],value};
		else extendInput ={1'b0,value};
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

	always_comb waddr =weightBaseAddress+wAddrW'(issueTerm);
	assign requestEnable =state==WEIGHT_RUN && !issueDone && !rst;
	assign requestTerm =issueTerm;
	assign requestRow =outputRow;
	assign requestColumn =outputColumn;

	//Tile-major words; the receiver commits writes on the rising clock edge.
	assign outWriteEnable =poolValid && busy && !rst;
	assign outWriteAddress =outAddrW'((int'(tileIndex)*outHeight+int'(poolRow))*outWidth+int'(poolColumn));
	for(genvar l =0;l<tile;l =l+1)begin:OUTPUT_LANES
		assign outData[l] =poolData[l];
	end

	always_ff@(posedge clk)begin
		if(rst)begin
			state <=IDLE;
			{busy,done} <=2'b0;
			{baddr,tileIndex} <='0;
			{issueTerm,consumeTerm} <='0;
			{outputRow,outputColumn} <='0;
			{weightBaseAddress,weightValid} <='0;
			issueDone <=1'b0;
			{macValid,macLast} <='0;
			inputRegister <='0;
			weightRegister <='0;
			channelMaskLatched <='1;
			convValid <=0;
			{poolRow,poolColumn} <='0;
			for(lane =0;lane<tile;lane++) {biasValue[lane],accumulator[lane],convData[lane]} <='0;

		end
		else begin
			{done,convValid} <=2'b00;
			macValid <=1'b0;
			if(poolValid&&busy)begin

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
					for(lane =0;lane<tile;lane++) biasValue[lane] <=extendBias(bdata[lane])<<<biasShift;
					state <=PIXEL_INIT;
				end
				PIXEL_INIT:begin
					for(lane =0;lane<tile;lane++) accumulator[lane] <=biasValue[lane];
					{issueTerm,consumeTerm,weightValid} <='0;
					issueDone <=1'b0;
					{macValid,macLast} <='0;
					state <=WEIGHT_RUN;
				end
				WEIGHT_RUN:begin
					weightValid <={weightValid[0],!issueDone};
					if(!issueDone)begin
						if(issueTerm==kernelTerms-1) issueDone <=1'b1;
						else issueTerm <=issueTerm+1'b1;
					end
					//Stage 1: reader has already resolved coordinates, lane and padding.
					if(weightValid[1])begin
						inputRegister <=inData[0];
						weightRegister <=wdata;
						macValid <=1'b1;
						macLast <=consumeTerm==kernelTerms-1;
						if(consumeTerm==kernelTerms-1) weightValid <='0;
						else consumeTerm <=consumeTerm+1'b1;
					end
					//Stage 2: MAC the previous clock's registered operands.
					if(macValid)begin
						inputValue =extendInput(inputRegister);
						for(lane =0;lane<tile;lane++)begin
							weightValue =$signed(weightRegister[lane]);
							product =inputValue*weightValue;
							accumulator[lane] <=accumulator[lane]+accWidth'(product);
						end
						if(macLast) state <=WRITE_OUTPUT;
					end
				end
				WRITE_OUTPUT:begin
					convValid <=1'b1;
					for(lane =0;lane<tile;lane++)begin
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
					//The last pooled write (if present) commits on this same edge.
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
	`ifndef SYNTHESIS
	always@(posedge clk)begin
		if(!rst && state==WEIGHT_RUN && weightValid[1] && inValid!==1'b1)
			$fatal(1,"convCore requires a reader response exactly two clocks after each request");
	end
	initial begin
		if(tile<1 || outChannels<1 || outChannels%tile!=0 || numTile!=outChannels/tile)
			$fatal(1,"convCore requires complete output tiles");
		if(inChannels<1 || inHeight<1 || inWidth<1 || kernelH<1 || kernelW<1 ||
			strideH<1 || strideW<1 || padH<0 || padW<0 ||
			poolKernelSize<1 || poolStride<1 || convHeight<poolKernelSize || convWidth<poolKernelSize)
			$fatal(1,"Invalid convCore dimensions");
		if(dataWidth<1 || wWidth<1 || bWidth<1 || actWidth<1 || accWidth<dataWidth+1 ||
			accWidth<wWidth || biasShift<0 || bWidth+biasShift>accWidth)
			$fatal(1,"Invalid convCore arithmetic widths");
	end
	`endif
endmodule
