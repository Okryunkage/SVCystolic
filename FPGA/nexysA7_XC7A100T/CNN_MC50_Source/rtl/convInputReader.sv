`timescale 1ns/1ps

module convInputReader#(
	parameter int inChannels =1,inHeight =28,inWidth =28,inputLanes =1,dataWidth =8,
	parameter int kernelH =3,kernelW =3,strideH =1,strideW =1,padH =1,padW =1,
	parameter int convHeight =(inHeight+2*padH-kernelH)/strideH+1,
	parameter int convWidth =(inWidth+2*padW-kernelW)/strideW+1,
	parameter int termIdxW =(inChannels*kernelH*kernelW>1)?$clog2(inChannels*kernelH*kernelW):1,
	parameter int rowW =(convHeight>1)?$clog2(convHeight):1,
	parameter int colW =(convWidth>1)?$clog2(convWidth):1,
	parameter int memoryDepth =((inChannels+inputLanes-1)/inputLanes)*inHeight*inWidth,
	parameter int addrW =(memoryDepth>1)?$clog2(memoryDepth):1)(
	input logic clk,rst,requestEnable,
	input logic[termIdxW-1:0] requestTerm,
	input logic[rowW-1:0] requestRow,
	input logic[colW-1:0] requestColumn,
	output logic readEnable,
	output logic[addrW-1:0] readAddress,
	input logic readValid,
	input logic[dataWidth-1:0] readData[0:inputLanes-1],
	output wire logic outValid,
	output logic[dataWidth-1:0] outData[0:0]);

	localparam int laneW =(inputLanes>1)?$clog2(inputLanes):1;
	localparam int channelW =(inChannels>1)?$clog2(inChannels):1;
	localparam int kernelRowW =(kernelH>1)?$clog2(kernelH):1;
	localparam int kernelColW =(kernelW>1)?$clog2(kernelW):1;
	localparam int decodeW =channelW+kernelRowW+kernelColW;

	(* rom_style ="distributed" *) logic[decodeW-1:0] termLookup[0:inChannels*kernelH*kernelW-1];
	wire[decodeW-1:0] decodedTerm =termLookup[requestTerm];
	initial begin
		for(integer t =0;t<inChannels*kernelH*kernelW;t++)
			termLookup[t] ={channelW'(t/(kernelH*kernelW)),kernelRowW'((t/kernelW)%kernelH),kernelColW'(t%kernelW)};
	end

	integer inputChannel,inputRow,inputColumn;
	logic requestPadding;
	logic[1:0] validPipeline,paddingPipeline;
	logic[laneW-1:0] lanePipeline[0:1];
	always_comb begin
		inputChannel =int'(decodedTerm[decodeW-1:kernelRowW+kernelColW]);
		inputRow =int'(requestRow)*strideH+int'(decodedTerm[kernelColW+:kernelRowW])-padH;
		inputColumn =int'(requestColumn)*strideW+int'(decodedTerm[0+:kernelColW])-padW;
		requestPadding =inputRow<0 || inputRow>=inHeight || inputColumn<0 || inputColumn>=inWidth;
		readEnable =requestEnable && !requestPadding && !rst;
		readAddress ='0;
		if(readEnable)
			readAddress =addrW'((inputChannel/inputLanes*inHeight+inputRow)*inWidth+inputColumn);
		outData[0] ='0;
		if(outValid && !paddingPipeline[1]) outData[0] =readData[lanePipeline[1]];
	end
	assign outValid =validPipeline[1] && !rst;
	always_ff@(posedge clk)begin
		if(rst)begin
			{validPipeline,paddingPipeline} <='0;
			lanePipeline[0] <='0;
			lanePipeline[1] <='0;
		end
		else begin
			validPipeline <={validPipeline[0],requestEnable};
			paddingPipeline <={paddingPipeline[0],requestPadding};
			lanePipeline[0] <=laneW'(inputChannel%inputLanes);
			lanePipeline[1] <=lanePipeline[0];
		end
	end
	`ifndef SYNTHESIS
	always@(posedge clk)begin
		if(!rst && outValid && !paddingPipeline[1] && readValid!==1'b1)
			$fatal(1,"convInputReader requires a two-clock memory response");
		if(!rst && requestEnable && int'(requestTerm)>=inChannels*kernelH*kernelW)
			$fatal(1,"convInputReader term out of range");
	end
	initial if(inputLanes<1 || dataWidth<1 || inChannels<1 || inHeight<1 || inWidth<1)
		$fatal(1,"Invalid convInputReader parameters");
	`endif
endmodule
