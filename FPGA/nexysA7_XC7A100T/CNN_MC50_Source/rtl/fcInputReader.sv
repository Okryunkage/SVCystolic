`timescale 1ns/1ps

//Translate channel-major flatten order to tile-major BRAM words and lane index.
module fcInputReader#(
	parameter int inChannels =16,inHeight =7,inWidth =7,inputLanes =8,dataWidth =8,
	parameter int inNum =inChannels*inHeight*inWidth,
	parameter int indexW =(inNum>1)?$clog2(inNum):1,
	parameter int memoryDepth =((inChannels+inputLanes-1)/inputLanes)*inHeight*inWidth,
	parameter int addrW =(memoryDepth>1)?$clog2(memoryDepth):1)(
	input logic clk,rst,requestEnable,
	input logic[indexW-1:0] requestIndex,
	output wire logic readEnable,
	output logic[addrW-1:0] readAddress,
	input logic readValid,
	input logic[dataWidth-1:0] readData[0:inputLanes-1],
	output wire logic outValid,
	output logic[dataWidth-1:0] outData[0:0]);

	localparam int area =inHeight*inWidth;
	localparam int laneW =(inputLanes>1)?$clog2(inputLanes):1;
	//Constant address/lane ROM avoids a runtime divide/modulo by area (49).
	//This is metadata only; no feature-map storage is duplicated.
	(* rom_style ="distributed" *) logic[addrW+laneW-1:0] addressLookup[0:inNum-1];
	wire[addrW+laneW-1:0] decodedAddress =addressLookup[requestIndex];
	initial begin
		for(integer i =0;i<inNum;i++)
			addressLookup[i] ={addrW'(((i/area)/inputLanes)*area+i%area),laneW'((i/area)%inputLanes)};
	end
	logic[1:0] validPipeline;
	logic[laneW-1:0] lanePipeline[0:1];
	assign readEnable =requestEnable && !rst;
	assign outValid =validPipeline[1] && !rst;
	always_comb begin
		readAddress =decodedAddress[addrW+laneW-1:laneW];
		outData[0] ='0;
		if(outValid) outData[0] =readData[lanePipeline[1]];
	end
	always_ff@(posedge clk)begin
		if(rst)begin
			validPipeline <='0;
			lanePipeline[0] <='0;
			lanePipeline[1] <='0;
		end
		else begin
			validPipeline <={validPipeline[0],requestEnable};
			lanePipeline[0] <=decodedAddress[laneW-1:0];
			lanePipeline[1] <=lanePipeline[0];
		end
	end
	`ifndef SYNTHESIS
	always@(posedge clk)begin
		if(!rst && outValid && readValid!==1'b1) $fatal(1,"fcInputReader requires a two-clock memory response");
		if(!rst && requestEnable && int'(requestIndex)>=inNum) $fatal(1,"fcInputReader index out of range");
	end
	initial if(inputLanes<1 || dataWidth<1 || inChannels<1 || inHeight<1 || inWidth<1)
		$fatal(1,"Invalid fcInputReader parameters");
	`endif
endmodule
