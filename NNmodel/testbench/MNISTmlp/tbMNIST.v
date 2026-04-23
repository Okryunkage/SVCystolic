`include "fc.v"
`include "relu.v"
`include "sign.v"
`include "argmax.v"
`include "requantize.v"
`include "mnistTOPmlp.v"
`timescale 1ns/1ps

module tb_mnistTOPmlp_debug;
	localparam integer IN_NUM     =784;
	localparam integer HID_NUM    =128;
	localparam integer OUT_NUM    =10;
	localparam integer IN_WIDTH   =8;
	localparam integer W1_WIDTH   =8;
	localparam integer B1_WIDTH   =32;
	localparam integer ACC1_WIDTH =32;
	localparam integer A1_WIDTH   =12;
	localparam integer W2_WIDTH   =8;
	localparam integer B2_WIDTH   =32;
	localparam integer OUT_WIDTH  =32;

	integer expected_label_int;
	reg[3:0] EXPECTED_LABEL;

	initial begin
		expected_label_int = 0;
		if($value$plusargs("EXPECTED_LABEL=%d",expected_label_int)) EXPECTED_LABEL =expected_label_int[3:0];
		else EXPECTED_LABEL = 4'd0;
		$display("EXPECTED_LABEL = %0d",EXPECTED_LABEL);
	end

	reg[(IN_NUM*IN_WIDTH-1):0] imgFlat;
	wire[3:0] predDigit;
	//System-Verilog Type
	reg[7:0] sampleMem [0:IN_NUM-1];

	integer i;
	integer failCount;

	mnistTOPmlp #(
		.inNum(IN_NUM),.hidNum(HID_NUM),.outNum(OUT_NUM),
		.inWidth(IN_WIDTH),.w1Width(W1_WIDTH),.b1Width(B1_WIDTH),.accWidth(ACC1_WIDTH),
		.a1Width(A1_WIDTH),.w2Width(W2_WIDTH),.b2Width(B2_WIDTH),.outWidth(OUT_WIDTH))
		dut(.imgFlat(imgFlat),.predDigit(predDigit));

	initial begin
		$dumpfile("mnist_out.vcd");
		$dumpvars(0, tb_mnistTOPmlp_debug);
	end

	task print_acc1;
		integer k;
		begin
			$write("accFlat = [");
			for(k=0;k<HID_NUM;k=k+1)begin
				$write("%0d",$signed(dut.accFlat[(k*ACC1_WIDTH)+:ACC1_WIDTH]));
				if(k !=HID_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_relu1;
		integer k;
		begin
			$write("relu1Flat = [");
			for(k=0;k<HID_NUM;k=k+1)begin
				$write("%0d",$signed(dut.reluFlat[(k*ACC1_WIDTH)+:ACC1_WIDTH]));
				if(k !=HID_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_act1;
		integer k;
		begin
			$write("actFlat = [");
			for(k=0; k<HID_NUM; k=k+1)begin
				$write("%0d",dut.actFlat[(k*A1_WIDTH)+:A1_WIDTH]);
				if(k !=HID_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_acc2;
		integer k;
		begin
			$write("outFlat = [");
			for(k=0;k<OUT_NUM;k=k+1) begin
				$write("%0d",$signed(dut.outFlat[(k*OUT_WIDTH)+:OUT_WIDTH]));
				if(k !=OUT_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_input_head;
		integer k;
		begin
			$write("imgFlat[0:31] = [");
			for(k=0;k<32;k=k+1) begin
				$write("%0d",imgFlat[(k*IN_WIDTH)+:IN_WIDTH]);
				if(k !=31) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_case_debug;
		begin
			$display("--------------------------------------------------");
			$display("DEBUG CASE");
			$display("predDigit      = %0d",predDigit);
			$display("EXPECTED_LABEL = %0d",EXPECTED_LABEL);
			print_input_head();
			print_acc1();
			print_relu1();
			print_act1();
			print_acc2();
			$display("--------------------------------------------------");
		end
	endtask

	initial begin
		failCount =0;
		imgFlat   ={(IN_NUM*IN_WIDTH){1'b0}};
		// mnist_sample.mem:
		// 784줄, 각 줄마다 8bit hex 값 하나
		// 예:
		// 00
		// 00
		// 1f
		// ...
		$readmemh("mnist_sample.mem",sampleMem);
		// pack sampleMem[k] -> imgFlat[(k*8)+:8]
		for(i=0;i<IN_NUM;i=i+1) begin
			imgFlat[(i*IN_WIDTH)+:IN_WIDTH] =sampleMem[i];
		end
		#10;
		if(predDigit !==EXPECTED_LABEL) begin
			failCount =failCount+1;
			$display("FAIL : pred=%0d expected=%0d",predDigit,EXPECTED_LABEL);
			//print_case_debug();
		end
		else begin
			$display("PASS : pred=%0d expected=%0d",predDigit,EXPECTED_LABEL);
			//print_case_debug();
		end
		$display("========================================");
		$display("TEST DONE");
		//$display("FAIL = %0d", failCount);
		$display("========================================");
		$finish;
	end

endmodule