`timescale 1ns/1ps

// Unpacked-array replacements. Compile this file OR functions.v, not both.
module relu#(
	parameter int number =16,
	parameter int width =20)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic signed[width-1:0] outData[0:number-1]);

	integer n;
	always_comb begin
		for(n =0;n<number;n =n+1)begin
			if(inData[n][width-1]) outData[n] ='0;
			else outData[n] =inData[n];
		end
	end
endmodule

module argmax#(
	parameter int width =32,
	parameter int number =10)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic[((number>1)?$clog2(number):1)-1:0] outIndex);

	localparam int indexWidth =(number>1)?$clog2(number):1;
	integer i;
	logic signed[width-1:0] maxValue;
	always_comb begin
		maxValue =inData[0];
		outIndex ='0;
		for(i =1;i<number;i =i+1)begin
			// Strict comparison preserves the first index when maxima tie.
			if(inData[i]>maxValue)begin
				maxValue =inData[i];
				outIndex =indexWidth'(i);
			end
		end
	end
endmodule

// Registered input followed by a balanced, registered comparison tree.
// If sampled at edge E0, the result is valid after edge E$clog2(number).
// For number=10: E0 captures inputs; E1..E4 reduce 10 -> 5 -> 3 -> 2 -> 1.
// Supports one input vector per clock. Equal maxima select the lowest index.
module argmax_pipe#(
	parameter int width =32,
	parameter int number =10)(
	input wire logic clk,rst,inValid,
	input wire logic signed[width-1:0] inData[0:number-1],
	output wire logic outValid,
	output wire logic[((number>1)?$clog2(number):1)-1:0] outIndex);

	localparam int indexWidth =(number>1)?$clog2(number):1;
	localparam int stageCount =(number>1)?$clog2(number):0;
	logic[stageCount:0] validPipeline;
	logic signed[width-1:0] maxValue[0:stageCount][0:number-1];
	logic[indexWidth-1:0] maxIndex[0:stageCount][0:number-1];

	assign outValid =validPipeline[stageCount];
	assign outIndex =maxIndex[stageCount][0];

	always_ff@(posedge clk)begin
		if(rst) validPipeline <='0;
		else begin
			validPipeline[0] <=inValid;
			for(integer stage =1;stage <=stageCount;stage =stage+1)
				validPipeline[stage] <=validPipeline[stage-1];
		end
	end

	genvar lane,level,node;
	generate
		for(lane =0;lane<number;lane =lane+1)begin:INPUT_LANES
			always_ff@(posedge clk)begin
				if(rst)begin
					maxValue[0][lane] <='0;
					maxIndex[0][lane] <='0;
				end
				else if(inValid)begin
					maxValue[0][lane] <=inData[lane];
					maxIndex[0][lane] <=indexWidth'(lane);
				end
			end
		end
		for(level =1;level <=stageCount;level =level+1)begin:STAGES
			localparam int previousCount =(number+(1<<(level-1))-1)>>(level-1);
			localparam int nodeCount =(previousCount+1)/2;
			for(node =0;node<nodeCount;node =node+1)begin:NODES
				if(2*node+1<previousCount)begin:COMPARE
					always_ff@(posedge clk)begin
						if(rst)begin
							maxValue[level][node] <='0;
							maxIndex[level][node] <='0;
						end
						else if(validPipeline[level-1])begin
							if(maxValue[level-1][2*node+1]>maxValue[level-1][2*node])begin
								maxValue[level][node] <=maxValue[level-1][2*node+1];
								maxIndex[level][node] <=maxIndex[level-1][2*node+1];
							end
							else begin
								maxValue[level][node] <=maxValue[level-1][2*node];
								maxIndex[level][node] <=maxIndex[level-1][2*node];
							end
						end
					end
				end
				else begin:PASS_THROUGH
					// An unpaired candidate still crosses a register at this level.
					always_ff@(posedge clk)begin
						if(rst)begin
							maxValue[level][node] <='0;
							maxIndex[level][node] <='0;
						end
						else if(validPipeline[level-1])begin
							maxValue[level][node] <=maxValue[level-1][2*node];
							maxIndex[level][node] <=maxIndex[level-1][2*node];
						end
					end
				end
			end
		end
	endgenerate

	`ifndef SYNTHESIS
	initial begin
		if(width<1 || number<1) $fatal(1,"argmax_pipe requires width and number >= 1");
	end
	`endif
endmodule

module sign#(
	parameter number =5,
	parameter width =32)(
	input wire logic signed[width-1:0] inData[0:number-1],
	output logic outBits[0:number-1]);

	integer n;
	always_comb begin
		for(n =0;n<number;n =n+1)begin
			if(inData[n]>0) outBits[n] =1'b1;
			else outBits[n] =1'b0;
		end
	end
endmodule
