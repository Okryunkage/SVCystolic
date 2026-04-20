`include "fc.v"
`include "relu.v"
`include "sign.v"
`include "adderTOPmlp.v"
`timescale 1ns/1ps
/*
module tb_adderTOPmlp;
	reg  [3:0] a;
	reg  [3:0] b;
	wire [4:0] out;

	reg  [4:0] expected;

	integer i;
	integer j;
	integer passCount;
	integer failCount;

	adderTOPmlp adder4(.a(a),.b(b),.out(out));

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0, tb_adderTOPmlp);
		
		a = 4'd0;
		b = 4'd0;
		expected = 5'd0;
		passCount = 0;
		failCount = 0;
		#10;
		for(i=0; i<16; i=i+1) begin
			for(j=0; j<16; j=j+1) begin
				a = i[3:0];
				b = j[3:0];
				expected = i + j;

				#1; // 조합회로 settle 시간

				if(out !== expected) begin
					failCount = failCount + 1;
					$display("FAIL : a=%0d b=%0d | out=%0d (%b) | expected=%0d (%b)",
							 i, j, out, out, expected, expected);
				end
				else begin
					passCount = passCount + 1;
					$display("PASS : a=%0d b=%0d | out=%0d (%b)",
							 i, j, out, out);
				end
			end
		end

		$display("========================================");
		$display("TEST DONE");
		$display("PASS = %0d", passCount);
		$display("FAIL = %0d", failCount);
		$display("========================================");

		$finish;
	end

endmodule
*/

module tb_adderTOPmlp_debug;

	localparam integer IN_NUM    = 8;
	localparam integer HID_NUM   = 32;
	localparam integer OUT_NUM   = 5;
	localparam integer IN_WIDTH  = 1;
	localparam integer W_WIDTH   = 8;
	localparam integer B1_WIDTH  = 16;
	localparam integer B2_WIDTH  = 32;
	localparam integer HID_WIDTH = 20;
	localparam integer OUT_WIDTH = 32;

	reg  [3:0] a;
	reg  [3:0] b;
	wire [4:0] out;

	reg  [4:0] expected;

	integer i, j;
	integer passCount;
	integer failCount;
	integer firstFailPrinted;

	adderTOPmlp #(
		.inNum(IN_NUM),
		.hidNum(HID_NUM),
		.outNum(OUT_NUM),
		.inWidth(IN_WIDTH),
		.wWidth(W_WIDTH),
		.b1Width(B1_WIDTH),
		.b2Width(B2_WIDTH),
		.hidWidth(HID_WIDTH),
		.outWidth(OUT_WIDTH)
	) dut (
		.a(a),
		.b(b),
		.out(out)
	);

	// waveform dump
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0, tb_adderTOPmlp_debug);
	end

	// ------------------------------------------------------------
	// task: print hidden/output vectors
	// ------------------------------------------------------------
	task print_z1;
		integer k;
		begin
			$write("z1_flat = [");
			for(k=0; k<HID_NUM; k=k+1) begin
				$write("%0d", $signed(dut.z1_flat[(k*HID_WIDTH) +: HID_WIDTH]));
				if(k != HID_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_h1;
		integer k;
		begin
			$write("h1_flat = [");
			for(k=0; k<HID_NUM; k=k+1) begin
				$write("%0d", $signed(dut.h1_flat[(k*HID_WIDTH) +: HID_WIDTH]));
				if(k != HID_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_z2;
		integer k;
		begin
			$write("z2_flat = [");
			for(k=0; k<OUT_NUM; k=k+1) begin
				$write("%0d", $signed(dut.z2_flat[(k*OUT_WIDTH) +: OUT_WIDTH]));
				if(k != OUT_NUM-1) $write(", ");
			end
			$write("]\n");
		end
	endtask

	task print_case_debug;
		begin
			$display("--------------------------------------------------");
			$display("DEBUG CASE");
			$display("a = %0d (%b)", a, a);
			$display("b = %0d (%b)", b, b);
			$display("inFlat = %b", dut.inFlat);
			$display("out    = %0d (%b)", out, out);
			$display("expected = %0d (%b)", expected, expected);

			print_z1();
			print_h1();
			print_z2();

			$display("--------------------------------------------------");
		end
	endtask

	// ------------------------------------------------------------
	// exhaustive test
	// ------------------------------------------------------------
	initial begin
		a = 4'd0;
		b = 4'd0;
		expected = 5'd0;
		passCount = 0;
		failCount = 0;
		firstFailPrinted = 0;

		#10;

		for(i=0; i<16; i=i+1) begin
			for(j=0; j<16; j=j+1) begin
				a = i[3:0];
				b = j[3:0];
				expected = i + j;

				#1; // combinational settle

				if(out !== expected) begin
					failCount = failCount + 1;
					$display("FAIL : a=%0d b=%0d | out=%0d (%b) | expected=%0d (%b)",
							 i, j, out, out, expected, expected);

					// 첫 실패 케이스에 대해 내부 상태 전체 출력
					if(firstFailPrinted == 0) begin
						firstFailPrinted = 1;
						print_case_debug();
					end
				end
				else begin
					passCount = passCount + 1;
				end
			end
		end

		$display("========================================");
		$display("TEST DONE");
		$display("PASS = %0d", passCount);
		$display("FAIL = %0d", failCount);
		$display("========================================");

		$finish;
	end

endmodule