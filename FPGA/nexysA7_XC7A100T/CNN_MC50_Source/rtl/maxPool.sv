`timescale 1ns/1ps
`default_nettype none

// Streaming kernelSize x kernelSize unsigned max pooling, without padding.
// kernelSize and stride are compile-time parameters.
//
// Input pixels must arrive in row-major order. CHANNELS values belonging to
// the same spatial position arrive together. Assert start for one clock before
// the first valid pixel of each feature-map tile.
module maxPool #(
	parameter int channels =8,
	parameter int inHeight =28,
	parameter int inWidth =28,
	parameter int dataWidth =8,
	parameter int stride =2,
	parameter int rowW =(inHeight>1)?$clog2(inHeight):1,
	parameter int colW =(inWidth>1)?$clog2(inWidth):1,
	parameter int kernelSize =2
)(
	input  wire logic clk,rst,start,inValid,
	input  wire logic [dataWidth-1:0] inData[0:channels-1],
	output logic outValid,
	output logic [dataWidth-1:0] outData[0:channels-1],
	output logic done
);

	logic[rowW-1:0] rowIndex;
	logic[colW-1:0] columnIndex;
	// Keep legal array bounds for kernelSize=1; history is unused in that case.
	localparam int historySize =(kernelSize>1)?kernelSize-1:1;
	logic[dataWidth-1:0] previousRow[0:channels-1][0:historySize-1][0:inWidth-1];
	logic[dataWidth-1:0] leftVerticalMax[0:channels-1][0:historySize-1];

	integer channel;
	logic[dataWidth-1:0] verticalMax[0:channels-1];
	logic[dataWidth-1:0] windowMax[0:channels-1];
	wire windowValid =int'(rowIndex)>=kernelSize-1 && int'(columnIndex)>=kernelSize-1 &&
		((int'(rowIndex)-(kernelSize-1))%stride)==0 &&
		((int'(columnIndex)-(kernelSize-1))%stride)==0;

	always_comb begin
		for(integer c =0;c<channels;c++)begin
			verticalMax[c] =inData[c];
			for(integer r =0;r<kernelSize-1;r++)begin
				if(previousRow[c][r][columnIndex]>verticalMax[c])
					verticalMax[c] =previousRow[c][r][columnIndex];
			end
			windowMax[c] =verticalMax[c];
			for(integer x =0;x<kernelSize-1;x++)begin
				if(leftVerticalMax[c][x]>windowMax[c]) windowMax[c] =leftVerticalMax[c][x];
			end
		end
	end

	// History has no reset. Warm-up overwrites it before the first valid window.
	// Keep it out of the asynchronous-reset process for portable RAM inference.
	always_ff@(posedge clk)begin
		if(!rst && !start && inValid && kernelSize>1)begin
			for(integer c =0;c<channels;c++)begin
				previousRow[c][0][columnIndex] <=inData[c];
				for(integer r =1;r<kernelSize-1;r++)
					previousRow[c][r][columnIndex] <=previousRow[c][r-1][columnIndex];
				leftVerticalMax[c][0] <=verticalMax[c];
				for(integer x =1;x<kernelSize-1;x++)
					leftVerticalMax[c][x] <=leftVerticalMax[c][x-1];
			end
		end
	end

    `ifndef SYNTHESIS
    initial begin
        if (kernelSize < 1 || inHeight < kernelSize || inWidth < kernelSize)
            $fatal(1,"maxPool requires 1 <= kernelSize <= min(inHeight,inWidth)");
        if (stride < 1)
            $fatal(1,"maxPool requires stride >= 1");
        if (channels < 1 || dataWidth < 1)
            $fatal(1,"maxPool requires channels and dataWidth >= 1");
    end
    `endif

	always_ff@(posedge clk)begin
		if(rst)begin
			rowIndex <='0;
			columnIndex <='0;
			outValid <=1'b0;
			done <=1'b0;
			for(channel =0;channel<channels;channel =channel+1)
				outData[channel] <='0;
		end
		else begin
			outValid <=1'b0;
			done <=1'b0;
			if(start)begin
				rowIndex <='0;
				columnIndex <='0;
			end
			else if(inValid)begin
				if(windowValid)begin
					for(channel =0;channel<channels;channel =channel+1)
						outData[channel] <=windowMax[channel];
					outValid <=1'b1;
				end

				if(columnIndex==inWidth-1)begin
					columnIndex <='0;
					if(rowIndex==inHeight-1)begin
						rowIndex <='0;
						done <=1'b1;
					end
					else rowIndex <=rowIndex+1'b1;
				end
				else columnIndex <=columnIndex+1'b1;
			end
		end
	end

endmodule

`default_nettype wire
