`timescale 1ns/1ps

module tb_convBRAM;
	localparam int inChannels=1, outChannels=2;
	localparam int inHeight=3, inWidth=3;
	localparam int outHeight=3, outWidth=3;
	localparam int accWidth=32;

	logic clk=1'b0, rst=1'b1, start=1'b0;
	logic[7:0] inData[0:inChannels-1][0:inHeight-1][0:inWidth-1];
	logic busy,done;
	logic signed[accWidth-1:0]
		outData[0:outChannels-1][0:outHeight-1][0:outWidth-1];
	int expected0[0:8];
	int index,row,column;

	always #5 clk=~clk;

	convBRAM #(
		.tile(2),.inChannels(inChannels),.outChannels(outChannels),
		.inHeight(inHeight),.inWidth(inWidth),.kernelH(3),.kernelW(3),
		.strideH(1),.strideW(1),.padH(1),.padW(1),
		.dataWidth(8),.wWidth(8),.bWidth(8),.accWidth(accWidth),
		.wInitFile("tb_conv_w_tile.mem"),
		.bInitFile("tb_conv_b_tile.mem")) dut(
		.clk(clk),.rst(rst),.start(start),.inData(inData),
		.busy(busy),.done(done),.outData(outData));

	initial begin
		expected0[0] = 13;
		expected0[1] = 22;
		expected0[2] = 17;
		expected0[3] = 28;
		expected0[4] = 46;
		expected0[5] = 34;
		expected0[6] = 25;
		expected0[7] = 40;
		expected0[8] = 29;
		
		for(index=0;index<9;index++)begin
			row=index/3;
			column=index%3;
			inData[0][row][column]=index+1;
		end
		repeat(3)@(posedge clk);
		rst=1'b0;
		@(posedge clk);start=1'b1;
		@(posedge clk);start=1'b0;
		wait(done);
		#1;
		for(index=0;index<9;index++)begin
			row=index/3;
			column=index%3;
			if(outData[0][row][column]!==expected0[index])
				$fatal(1,"ch0 [%0d][%0d] expected=%0d actual=%0d",
					row,column,expected0[index],outData[0][row][column]);
			if(outData[1][row][column]!==2*(index+1)-1)
				$fatal(1,"ch1 [%0d][%0d] expected=%0d actual=%0d",
					row,column,2*(index+1)-1,outData[1][row][column]);
		end
		$display("PASS: XPM BRAM initialization, lane packing, latency and convolution");
		$finish;
	end
endmodule