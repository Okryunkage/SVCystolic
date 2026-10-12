`timescale 1ns/1ps

module maxPool#(
	parameter int channels   =8,
	parameter int inHeight   =28,
	parameter int inWidth    =28,
	parameter int dataWidth  =8,
	parameter int stride     =2,
	parameter int rowW       =(inHeight>1)?$clog2(inHeight):1,
	parameter int colW       =(inWidth>1) ?$clog2(inWidth):1,
	parameter int kernelSize =2)(
	
	input wire logic clk, rst, start, inValid,
	input wire logic [dataWidth-1:0] inData[0:channels-1],
	output logic outValid,
	output logic [dataWidth-1:0] outData[0:channels-1],
	output logic done);
	
	logic[rowW-1:0] rowIndex;
	logic[colW-1:0] columnIndex;
	localparam int historySize =(kernelSize>1)?kernelSize-1:1;
	logic[dataWidth-1:0] previousRow[0:channels-1][0:historySize-1][0:inWidth-1];
	logic[dataWidth-1:0] leftVerticalMax[0:channels-1][0:historySize-1];

	integer channel, rowOffset, colOffset;
	logic[dataWidth-1:0] inputValue, verticalMax, windowMax;

	`ifndef SYNTHESIS
	initial begin
		if(kernelSize<1||inHeight<kernelSize||inWidth<kernelSize)
			$fatal(1,"maxPool requires 1 <= kernelSize <= min(inHeight,inWidth)");
		if(stride<1) $fatal(1,"maxPool requires stride >= 1");
		if(channels<1||dataWidth<1) $fatal(1,"maxPool requires channels and dataWidth >=1");
	end
	`endif 
	
	always_ff@(posedge clk or posedge rst)begin
		if(rst)begin
			rowIndex    <='0;
			columnIndex <='0;
			outValid    <=1'b0;
			done        <=1'b0;
			for(channel=0;channel<channels;channel=channel+1)
				outData[channel] <='0;
		end
		else begin
			outValid <=1'b0;
			done     <=1'b0;
			if(start)begin
				rowIndex    <='0;
				columnIndex <='0;
			end
			else if(inValid)begin
				for(channel=0;channel<channels;channel=channel+1)begin
					inputValue  =inData[channel];
					verticalMax =inputValue;
					for(rowOffset=0;rowOffset<kernelSize-1;rowOffset=rowOffset+1)begin
						if(previousRow[channel][rowOffset][columnIndex]>verticalMax)
							verticalMax =previousRow[channel][rowOffset][columnIndex];
					end
					if(kernelSize>1)begin
						previousRow[channel][0][columnIndex] <=inputValue;
						for(rowOffset=1;rowOffset<kernelSize-1;rowOffset=rowOffset+1)
							previousRow[channel][rowOffset][columnIndex]
								<=previousRow[channel][rowOffset-1][columnIndex];
					end

					windowMax =verticalMax;
					for(colOffset=0;colOffset<kernelSize-1;colOffset=colOffset+1)begin
						if(leftVerticalMax[channel][colOffset]>windowMax)
							windowMax =leftVerticalMax[channel][colOffset];
					end
					if(kernelSize>1)begin
						leftVerticalMax[channel][0] <=verticalMax;
						for(colOffset=1;colOffset<kernelSize-1;colOffset=colOffset+1)
							leftVerticalMax[channel][colOffset]
								<=leftVerticalMax[channel][colOffset-1];
					end

					if(rowIndex>=kernelSize-1 && columnIndex>=kernelSize-1 &&
						((rowIndex-(kernelSize-1))%stride)==0 &&
						((columnIndex-(kernelSize-1))%stride)==0)
						outData[channel] <=windowMax;
				end
				if(rowIndex>=kernelSize-1 && columnIndex>=kernelSize-1 &&
					((rowIndex-(kernelSize-1))%stride)==0 &&
					((columnIndex-(kernelSize-1))%stride)==0)
					outValid <=1'b1;

				if(columnIndex==inWidth-1)begin
					columnIndex <='0;
					if(rowIndex==inHeight-1)begin
						rowIndex <='0;
						done     <=1'b1;
					end
					else rowIndex <=rowIndex+1'b1;
				end
				else columnIndex <=columnIndex+1'b1;
			end
		end	
	end
endmodule
