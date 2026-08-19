`timescale 1ns/1ps

module tb_proposed;
	localparam integer size =64;
	localparam integer outW =22;

	reg clk, en;
	reg [(8*size-1):0]    weight, in;
	wire[(size*outW-1):0] result;

	integer i,j, errCount;

	reg signed[7:0]        weightArr[0:(size-1)];
	reg signed[7:0]        inArr    [0:(size-1)];

	reg signed[(outW-1):0] expected [0:(size-1)];
	reg signed[(outW-1):0] got      [0:(size-1)];

	integer sumTemp, idx;

	proposed dut(.clk(clk),.en(en),.weight(weight),.in(in),.result(result));

	initial begin
		clk =1'b0;
		forever #0.5 clk =~clk;
	end

	task packInput;begin
		for(i=0;i<size;i=i+1) in[(i*8)+:8] =inArr[i];
	end
	endtask

	task packWeight;begin
		for(i=0;i<size;i=i+1) weight[(i*8)+:8] =weightArr[i];
	end
	endtask

	task calcExpected;begin
		for(i=0;i<size;i=i+1)begin
			sumTemp =0;
			for(j=0;j<size;j=j+1)begin
				idx     =(i+((size/2+1)*j))%size;
				sumTemp =sumTemp+weightArr[i]*inArr[idx];
			end
			expected[i] =sumTemp[(outW-1):0];
		end
	end
	endtask

	task unpackResult;begin
		for(i=0;i<size;i=i+1) got[i] =result[(i*outW)+:outW];
	end
	endtask

	task printInput;begin
		$display("============================================================");
		$display("Input vectors");
		$display("============================================================");
		for(i=0;i<size;i=i+1) $display("idx=%0d  weight=%0d  in=%0d", i, weightArr[i], inArr[i]);
		$display("============================================================");
	end
	endtask

	task checkResult;begin
		errCount =0;
		unpackResult;
		$display("============================================================");
		$display("Result Check");
		$display("============================================================");

		for(i=0;i<size;i=i+1)begin
			if(^result[(i*outW)+:outW]===1'bx)begin
				$display("[X/Z] col=%0d result has X or Z, raw=%b", i,result[(i*outW)+:outW]);
				errCount =errCount+1;
			end
			else if(got[i] !==expected[i])begin
				$display("[FAIL] col=%0d expected=%0d got=%0d expected_hex=0x%h got_hex=0x%h", i,expected[i],got[i],expected[i],got[i]);
				errCount =errCount+1;
			end
			else begin
				$display("[PASS] col=%0d expected=%0d got=%0d hex=0x%h", i,expected[i],got[i],got[i]);
			end
		end

		$display("============================================================");
		if(errCount==0) $display("TEST PASS: all %0d columns matched.", size);
		else            $display("TEST FAIL: %0d mismatches detected.", errCount);
		$display("============================================================");
	end
	endtask

	task applyTESTpattern1;begin
		for(i=0;i<size;i=i+1)begin
			weightArr[i] =i-(size/2);
			inArr    [i] =(size/2-1)-i;
		end
	end
	endtask

	task applyTESTpattern2;begin
		for(i=0;i<size;i=i+1)begin
			if     (i%4==0) weightArr[i] =8'sd7;
			else if(i%4==1) weightArr[i] =-8'sd3;
			else if(i%4==2) weightArr[i] =8'sd12;
			else            weightArr[i] =-8'sd9;

			if     (i%5==0) inArr[i] =-8'sd4;
			else if(i%5==1) inArr[i] =8'sd6;
			else if(i%5==2) inArr[i] =-8'sd8;
			else if(i%5==3) inArr[i] =8'sd10;
			else            inArr[i] =8'sd2;
		end
	end
	endtask

	localparam integer PE16lat      =1;
	localparam integer otherPElat   =2;
	localparam integer marginCycle  =10;
	localparam integer finalAdderLat =2;
	localparam integer arrayLat     =PE16lat+(size-1)*otherPElat;
	localparam integer preloadCycle =arrayLat+marginCycle;
	localparam integer computeCycle =arrayLat+finalAdderLat+marginCycle;

	initial begin
		$display("============================================================");
		$display("Start proposed module testbench");
		$display("============================================================");

		en     =1'b0;
		weight ={(8*size){1'b0}};
		in     ={(8*size){1'b0}};

		repeat(5) @(posedge clk);

		// ========================================================
		// TEST 1
		// ========================================================
		$display("");
		$display("#################### TEST 1 ####################");

		applyTESTpattern1;
		printInput;
		calcExpected;

		in ={(8*size){1'b0}};
		packWeight;

		@(negedge clk);
		en =1'b1;
		$display("[INFO] TEST1 weight preload start, en=1");

		repeat(preloadCycle) @(posedge clk);

		@(negedge clk);
		en =1'b0;
		$display("[INFO] TEST1 weight preload done, en=0");

		packInput;
		$display("[INFO] TEST1 compute start");

		repeat(computeCycle) @(posedge clk);
		#0.1;

		checkResult;

		@(negedge clk);
		en =1'b0;
		weight ={(8*size){1'b0}};
		in     ={(8*size){1'b0}};

		repeat(10) @(posedge clk);

		// ========================================================
		// TEST 2
		// ========================================================
		$display("");
		$display("#################### TEST 2 ####################");

		applyTESTpattern2;
		printInput;
		calcExpected;

		in ={(8*size){1'b0}};
		packWeight;

		@(negedge clk);
		en =1'b1;
		$display("[INFO] TEST2 weight preload start, en=1");

		repeat(preloadCycle) @(posedge clk);

		@(negedge clk);
		en =1'b0;
		$display("[INFO] TEST2 weight preload done, en=0");

		packInput;
		$display("[INFO] TEST2 compute start");

		repeat(computeCycle) @(posedge clk);
		#0.1;

		checkResult;

		@(negedge clk);
		en =1'b0;

		repeat(10) @(posedge clk);

		$display("");
		$display("============================================================");
		$display("Simulation finished");
		$display("============================================================");

		$finish;
	end

endmodule