`timescale 1ns/1ps

module convOutputCase#(
	parameter int readLatency=2)(output logic finished=0);
	// The Ubuntu script runs from CNN_BRAM_XPM; keep the original XSim paths.
	`ifdef CONV_TESTDATA_LOCAL
	localparam wFile="testdata/conv_output_w.mem";
	localparam bFile="testdata/conv_output_b.mem";
	`else
	localparam wFile="tb_conv_w_tile.mem";
	localparam bFile="tb_conv_b_tile.mem";
	`endif
	logic clk=0,rst=1,start=0,readEnable=0;
	logic[3:0] channelMask='1,savedMask;
	logic[7:0] inData[0:0][0:2][0:3];
	logic[4:0] readAddress=0;
	wire busy,done,readValid;
	wire[7:0] readData[0:1];
	logic[readLatency-1:0] expectedValid='0;
	integer expectedAddress[0:readLatency-1];
	integer checked=0;
	integer writeCount=0,blockedWriteReads=0;
	always #5 clk=~clk;

	convBRAM#(
		.tile(2),.outChannels(4),.inHeight(3),.inWidth(4),
		.requantShift(1),.readLatency(readLatency),
		.wInitFile(wFile),.bInitFile(bFile)) dut(.*);

	function automatic logic[7:0] referencePixel(input integer address,lane);
		integer ch,r,c,kr,kc,ir,ic,sum,q;
		begin
			ch=(address/12)*2+lane;
			r=(address%12)/4;
			c=address%4;
			sum=3*ch-4;
			for(kr=0;kr<3;kr=kr+1)
				for(kc=0;kc<3;kc=kc+1)begin
					ir=r+kr-1;
					ic=c+kc-1;
					if(ir>=0 && ir<3 && ic>=0 && ic<4)
						sum=sum+int'(inData[0][ir][ic])*(((ch+kr*3+kc)%5)-1);
				end
			q=(sum<=0)?0:(sum+1)/2;
			if(q>255) q=255;
			if(!savedMask[ch]) q=0;
			referencePixel=8'(q);
		end
	endfunction

	always@(posedge clk)begin
		if(rst) expectedValid='0;
		else begin
			for(integer s=readLatency-1;s>0;s=s-1)begin
				expectedValid[s]=expectedValid[s-1];
				expectedAddress[s]=expectedAddress[s-1];
			end
			expectedValid[0]=readEnable && !busy && !start && readAddress<24;
			expectedAddress[0]=readAddress;
			if(dut.convValid)begin
				if(!busy || done || int'(dut.convAddress)!=writeCount)
					$fatal(1,"Invalid write sequence or completion timing");
				writeCount=writeCount+1;
				if(readEnable) blockedWriteReads=blockedWriteReads+1;
			end
		end
		#1;
		if(readValid!==expectedValid[readLatency-1])
			$fatal(1,"readValid mismatch latency=%0d",readLatency);
		if(readValid)begin
			for(integer l=0;l<2;l=l+1)
				if(readData[l]!==referencePixel(expectedAddress[readLatency-1],l))
					$fatal(1,"latency=%0d addr=%0d lane=%0d got=%0d expected=%0d",
						readLatency,expectedAddress[readLatency-1],l,readData[l],
						referencePixel(expectedAddress[readLatency-1],l));
			checked=checked+1;
		end
	end

	task automatic request(input bit enable,input integer address);
		@(negedge clk);
		readEnable=enable;
		readAddress=5'(address);
	endtask

	task automatic runFrame(input logic[3:0] mask,input integer baseValue);
		integer beforeCount;
		begin
			@(negedge clk);
			for(integer r=0;r<3;r=r+1)
				for(integer c=0;c<4;c=c+1)
					inData[0][r][c]=8'(baseValue+r*4+c);
			savedMask=mask;
			channelMask=mask;
			writeCount=0;
			blockedWriteReads=0;
			beforeCount=checked;
			//Keep a read pending from start through the final write.
			//It must not steal the single port or produce a response while busy.
			readEnable=1;
			readAddress=0;
			start=1;
			@(negedge clk);
			start=0;
			channelMask=~mask;
			wait(done);
			#2;
			if(busy) $fatal(1,"busy at done");
			if(writeCount!=24 || blockedWriteReads!=24 || checked!=beforeCount || readValid)
				$fatal(1,"Single-port arbitration or final write check failed");
			beforeCount=checked;
			// Read the final word immediately after completion, then all words.
			request(1,23);
			for(integer a=0;a<24;a=a+1)begin
				request(1,a);
				if(a%5==0) request(0,0);
			end
			request(1,24); // Out-of-range request must not produce readValid.
			request(0,0);
			repeat(readLatency+1) @(negedge clk);
			if(checked-beforeCount!=25) $fatal(1,"read count mismatch");
			if(done) $fatal(1,"done did not clear");
		end
	endtask

	initial begin
		repeat(3) @(negedge clk);
		rst=0;
		runFrame(4'b1111,20);
		runFrame(4'b0101,20);
		runFrame(4'b1010,20);
		runFrame(4'b0000,20);
		runFrame(4'b1111,200);
		$display("PASS convBRAM XPM: latency=%0d, 5 frames, %0d reads",readLatency,checked);
		finished=1;
	end
endmodule

module tb_conv;
	string waveFile;
	initial begin
		if($value$plusargs("wave=%s",waveFile))begin
			$dumpfile(waveFile);
			$dumpvars(0,tb_conv);
		end
	end
	wire[2:0] finished;
	convOutputCase#(.readLatency(1)) c0(finished[0]);
	convOutputCase#(.readLatency(2)) c1(finished[1]);
	convOutputCase#(.readLatency(3)) c2(finished[2]);
	initial begin
		wait(&finished);
		$display("PASS: convolution, requantization, mask, XPM write/read integration");
		$finish;
	end
	initial begin
		#1000000;
		$fatal(1,"timeout");
	end
endmodule
