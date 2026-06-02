`include "uartPacketDec_rev.v"
`timescale 1ns/1ps

module tb_uartPacketDec_rev;

	reg clk;
	reg rst;
	reg rxDone;
	reg [7:0] rxData;

	wire headerValid;
	wire [7:0] version;
	wire [7:0] packetType;
	wire [7:0] flags;

	wire [31:0] batchID;
	wire [15:0] batchSize;
	wire [15:0] vectorLEN;

	wire [7:0] layerID;
	wire [7:0] paramType;
	wire [15:0] bitWidth;
	wire [31:0] elemCount;

	wire [31:0] payloadLEN;

	wire payloadValid;
	wire [7:0] payloadData;
	wire [31:0] payloadIndex;

	wire payloadImage;
	wire payloadLabel;
	wire payloadParam;
	wire payloadWeight;
	wire payloadBias;

	wire packetDone;
	wire packetError;
	wire checksumError;
	wire headerError;

	wire [7:0] rxChecksum;
	wire [7:0] cmChecksum;

	wire busy;

	localparam [7:0] SOF0        = 8'hAA;
	localparam [7:0] SOF1        = 8'h55;
	localparam [7:0] VERSION     = 8'd1;

	localparam [7:0] PACKET_IMG  = 8'h01;
	localparam [7:0] PACKET_PARAM= 8'h02;

	localparam [7:0] PARAM_WEIGHT= 8'h00;
	localparam [7:0] PARAM_BIAS  = 8'h01;

	localparam [7:0] FLAG_LABEL  = 8'h01;
	localparam [7:0] FLAG_SIGNED = 8'h01;

	uartPacketDec_rev DUT (
		.clk(clk),
		.rst(rst),
		.rxDone(rxDone),
		.rxData(rxData),

		.headerValid(headerValid),
		.version(version),
		.packetType(packetType),
		.flags(flags),

		.batchID(batchID),
		.batchSize(batchSize),
		.vectorLEN(vectorLEN),

		.layerID(layerID),
		.paramType(paramType),
		.bitWidth(bitWidth),
		.elemCount(elemCount),

		.payloadLEN(payloadLEN),

		.payloadValid(payloadValid),
		.payloadData(payloadData),
		.payloadIndex(payloadIndex),

		.payloadImage(payloadImage),
		.payloadLabel(payloadLabel),
		.payloadParam(payloadParam),
		.payloadWeight(payloadWeight),
		.payloadBias(payloadBias),

		.packetDone(packetDone),
		.packetError(packetError),
		.checksumError(checksumError),
		.headerError(headerError),

		.rxChecksum(rxChecksum),
		.cmChecksum(cmChecksum),

		.busy(busy)
	);

	initial begin
		clk = 1'b0;
		forever #5 clk = ~clk;
	end

	integer errorCount;

	integer payloadCount;
	integer imageCount;
	integer labelCount;
	integer paramCount;
	integer weightCount;
	integer biasCount;
	integer doneCount;
	integer headerCount;
	integer packetErrorCount;
	integer checksumErrorCount;
	integer headerErrorCount;

	reg [7:0] observedPayload [0:255];

	always @(posedge clk) begin
		if (rst) begin
			payloadCount       <= 0;
			imageCount         <= 0;
			labelCount         <= 0;
			paramCount         <= 0;
			weightCount        <= 0;
			biasCount          <= 0;
			doneCount          <= 0;
			headerCount        <= 0;
			packetErrorCount   <= 0;
			checksumErrorCount <= 0;
			headerErrorCount   <= 0;
		end
		else begin
			if (headerValid)
				headerCount <= headerCount + 1;

			if (payloadValid) begin
				observedPayload[payloadCount] <= payloadData;
				payloadCount <= payloadCount + 1;

				if (payloadImage)
					imageCount <= imageCount + 1;

				if (payloadLabel)
					labelCount <= labelCount + 1;

				if (payloadParam)
					paramCount <= paramCount + 1;

				if (payloadWeight)
					weightCount <= weightCount + 1;

				if (payloadBias)
					biasCount <= biasCount + 1;
			end

			if (packetDone)
				doneCount <= doneCount + 1;

			if (packetError)
				packetErrorCount <= packetErrorCount + 1;

			if (checksumError)
				checksumErrorCount <= checksumErrorCount + 1;

			if (headerError)
				headerErrorCount <= headerErrorCount + 1;
		end
	end

	task clear_counters;
		begin
			@(posedge clk);
			payloadCount       = 0;
			imageCount         = 0;
			labelCount         = 0;
			paramCount         = 0;
			weightCount        = 0;
			biasCount          = 0;
			doneCount          = 0;
			headerCount        = 0;
			packetErrorCount   = 0;
			checksumErrorCount = 0;
			headerErrorCount   = 0;
		end
	endtask

	task check_equal_int;
		input [1023:0] name;
		input integer actual;
		input integer expected;
		begin
			if (actual !== expected) begin
				$display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
				errorCount = errorCount + 1;
			end
			else begin
				$display("[PASS] %0s = %0d", name, actual);
			end
		end
	endtask

	task check_equal_hex8;
		input [1023:0] name;
		input [7:0] actual;
		input [7:0] expected;
		begin
			if (actual !== expected) begin
				$display("[FAIL] %0s actual=0x%02h expected=0x%02h", name, actual, expected);
				errorCount = errorCount + 1;
			end
			else begin
				$display("[PASS] %0s = 0x%02h", name, actual);
			end
		end
	endtask

	task send_byte;
		input [7:0] b;
		begin
			@(posedge clk);
			rxData <= b;
			rxDone <= 1'b1;

			@(posedge clk);
			rxDone <= 1'b0;
			rxData <= 8'h00;

			// one idle cycle between received bytes
			@(posedge clk);
		end
	endtask

	task send_sof;
		begin
			send_byte(SOF0);
			send_byte(SOF1);
		end
	endtask

	task send_image_packet_with_label;
		reg [7:0] checksum;
		reg [31:0] batch_id;
		reg [15:0] batch_size;
		reg [15:0] vector_len;
		reg [31:0] payload_len;
		integer i;
		reg [7:0] payload [0:9];
		begin
			$display("\n--- TEST 1: IMAGE packet with labels ---");

			clear_counters();

			batch_id    = 32'h11223344;
			batch_size  = 16'd2;
			vector_len  = 16'd4;
			payload_len = 32'd10;

			payload[0] = 8'h10;
			payload[1] = 8'h11;
			payload[2] = 8'h12;
			payload[3] = 8'h13;
			payload[4] = 8'h20;
			payload[5] = 8'h21;
			payload[6] = 8'h22;
			payload[7] = 8'h23;
			payload[8] = 8'h03; // label 0
			payload[9] = 8'h07; // label 1

			checksum = 8'd0;

			send_sof();

			send_byte(VERSION);       checksum = checksum + VERSION;
			send_byte(PACKET_IMG);    checksum = checksum + PACKET_IMG;
			send_byte(FLAG_LABEL);    checksum = checksum + FLAG_LABEL;

			send_byte(batch_id[7:0]);    checksum = checksum + batch_id[7:0];
			send_byte(batch_id[15:8]);   checksum = checksum + batch_id[15:8];
			send_byte(batch_id[23:16]);  checksum = checksum + batch_id[23:16];
			send_byte(batch_id[31:24]);  checksum = checksum + batch_id[31:24];

			send_byte(batch_size[7:0]);  checksum = checksum + batch_size[7:0];
			send_byte(batch_size[15:8]); checksum = checksum + batch_size[15:8];

			send_byte(vector_len[7:0]);  checksum = checksum + vector_len[7:0];
			send_byte(vector_len[15:8]); checksum = checksum + vector_len[15:8];

			send_byte(payload_len[7:0]);    checksum = checksum + payload_len[7:0];
			send_byte(payload_len[15:8]);   checksum = checksum + payload_len[15:8];
			send_byte(payload_len[23:16]);  checksum = checksum + payload_len[23:16];
			send_byte(payload_len[31:24]);  checksum = checksum + payload_len[31:24];

			for (i = 0; i < 10; i = i + 1) begin
				send_byte(payload[i]);
				checksum = checksum + payload[i];
			end

			send_byte(checksum);

			repeat (5) @(posedge clk);

			check_equal_int("headerCount", headerCount, 1);
			check_equal_int("doneCount", doneCount, 1);
			check_equal_int("packetErrorCount", packetErrorCount, 0);
			check_equal_int("payloadCount", payloadCount, 10);
			check_equal_int("imageCount", imageCount, 10);
			check_equal_int("labelCount", labelCount, 2);

			check_equal_int("batchSize", batchSize, 2);
			check_equal_int("vectorLEN", vectorLEN, 4);
			check_equal_int("payloadLEN", payloadLEN, 10);

			check_equal_hex8("observedPayload[0]", observedPayload[0], 8'h10);
			check_equal_hex8("observedPayload[8]", observedPayload[8], 8'h03);
			check_equal_hex8("observedPayload[9]", observedPayload[9], 8'h07);
		end
	endtask

	task send_param_weight_packet;
		reg [7:0] checksum;
		reg [7:0] layer_id;
		reg [7:0] param_type;
		reg [15:0] bit_width;
		reg [31:0] elem_count;
		reg [31:0] payload_len;
		integer i;
		reg [7:0] payload [0:3];
		begin
			$display("\n--- TEST 2: PARAM WEIGHT packet, 8-bit signed ---");

			clear_counters();

			layer_id    = 8'd1;
			param_type  = PARAM_WEIGHT;
			bit_width   = 16'd8;
			elem_count  = 32'd4;
			payload_len = 32'd4;

			payload[0] = 8'h01;
			payload[1] = 8'hFE;
			payload[2] = 8'h03;
			payload[3] = 8'hFC;

			checksum = 8'd0;

			send_sof();

			send_byte(VERSION);       checksum = checksum + VERSION;
			send_byte(PACKET_PARAM);  checksum = checksum + PACKET_PARAM;
			send_byte(FLAG_SIGNED);   checksum = checksum + FLAG_SIGNED;

			send_byte(layer_id);      checksum = checksum + layer_id;
			send_byte(param_type);    checksum = checksum + param_type;

			send_byte(bit_width[7:0]);   checksum = checksum + bit_width[7:0];
			send_byte(bit_width[15:8]);  checksum = checksum + bit_width[15:8];

			send_byte(elem_count[7:0]);    checksum = checksum + elem_count[7:0];
			send_byte(elem_count[15:8]);   checksum = checksum + elem_count[15:8];
			send_byte(elem_count[23:16]);  checksum = checksum + elem_count[23:16];
			send_byte(elem_count[31:24]);  checksum = checksum + elem_count[31:24];

			send_byte(payload_len[7:0]);    checksum = checksum + payload_len[7:0];
			send_byte(payload_len[15:8]);   checksum = checksum + payload_len[15:8];
			send_byte(payload_len[23:16]);  checksum = checksum + payload_len[23:16];
			send_byte(payload_len[31:24]);  checksum = checksum + payload_len[31:24];

			for (i = 0; i < 4; i = i + 1) begin
				send_byte(payload[i]);
				checksum = checksum + payload[i];
			end

			send_byte(checksum);

			repeat (5) @(posedge clk);

			check_equal_int("headerCount", headerCount, 1);
			check_equal_int("doneCount", doneCount, 1);
			check_equal_int("packetErrorCount", packetErrorCount, 0);
			check_equal_int("payloadCount", payloadCount, 4);
			check_equal_int("paramCount", paramCount, 4);
			check_equal_int("weightCount", weightCount, 4);
			check_equal_int("biasCount", biasCount, 0);

			check_equal_int("layerID", layerID, 1);
			check_equal_int("paramType", paramType, PARAM_WEIGHT);
			check_equal_int("bitWidth", bitWidth, 8);
			check_equal_int("elemCount", elemCount, 4);
			check_equal_int("payloadLEN", payloadLEN, 4);

			check_equal_hex8("observedPayload[1]", observedPayload[1], 8'hFE);
		end
	endtask

	task send_param_bias_packet;
		reg [7:0] checksum;
		reg [7:0] layer_id;
		reg [7:0] param_type;
		reg [15:0] bit_width;
		reg [31:0] elem_count;
		reg [31:0] payload_len;
		integer i;
		reg [7:0] payload [0:7];
		begin
			$display("\n--- TEST 3: PARAM BIAS packet, 32-bit signed ---");

			clear_counters();

			layer_id    = 8'd1;
			param_type  = PARAM_BIAS;
			bit_width   = 16'd32;
			elem_count  = 32'd2;
			payload_len = 32'd8;

			// little-endian 32-bit values:
			// 0x000007A4 -> A4 07 00 00
			// 0xFFFFFFF6 -> F6 FF FF FF
			payload[0] = 8'hA4;
			payload[1] = 8'h07;
			payload[2] = 8'h00;
			payload[3] = 8'h00;
			payload[4] = 8'hF6;
			payload[5] = 8'hFF;
			payload[6] = 8'hFF;
			payload[7] = 8'hFF;

			checksum = 8'd0;

			send_sof();

			send_byte(VERSION);       checksum = checksum + VERSION;
			send_byte(PACKET_PARAM);  checksum = checksum + PACKET_PARAM;
			send_byte(FLAG_SIGNED);   checksum = checksum + FLAG_SIGNED;

			send_byte(layer_id);      checksum = checksum + layer_id;
			send_byte(param_type);    checksum = checksum + param_type;

			send_byte(bit_width[7:0]);   checksum = checksum + bit_width[7:0];
			send_byte(bit_width[15:8]);  checksum = checksum + bit_width[15:8];

			send_byte(elem_count[7:0]);    checksum = checksum + elem_count[7:0];
			send_byte(elem_count[15:8]);   checksum = checksum + elem_count[15:8];
			send_byte(elem_count[23:16]);  checksum = checksum + elem_count[23:16];
			send_byte(elem_count[31:24]);  checksum = checksum + elem_count[31:24];

			send_byte(payload_len[7:0]);    checksum = checksum + payload_len[7:0];
			send_byte(payload_len[15:8]);   checksum = checksum + payload_len[15:8];
			send_byte(payload_len[23:16]);  checksum = checksum + payload_len[23:16];
			send_byte(payload_len[31:24]);  checksum = checksum + payload_len[31:24];

			for (i = 0; i < 8; i = i + 1) begin
				send_byte(payload[i]);
				checksum = checksum + payload[i];
			end

			send_byte(checksum);

			repeat (5) @(posedge clk);

			check_equal_int("headerCount", headerCount, 1);
			check_equal_int("doneCount", doneCount, 1);
			check_equal_int("packetErrorCount", packetErrorCount, 0);
			check_equal_int("payloadCount", payloadCount, 8);
			check_equal_int("paramCount", paramCount, 8);
			check_equal_int("weightCount", weightCount, 0);
			check_equal_int("biasCount", biasCount, 8);

			check_equal_int("paramType", paramType, PARAM_BIAS);
			check_equal_int("bitWidth", bitWidth, 32);
			check_equal_int("elemCount", elemCount, 2);
			check_equal_int("payloadLEN", payloadLEN, 8);

			check_equal_hex8("observedPayload[0]", observedPayload[0], 8'hA4);
			check_equal_hex8("observedPayload[4]", observedPayload[4], 8'hF6);
		end
	endtask

	task send_bad_checksum_packet;
		reg [7:0] checksum;
		reg [7:0] layer_id;
		reg [7:0] param_type;
		reg [15:0] bit_width;
		reg [31:0] elem_count;
		reg [31:0] payload_len;
		reg [7:0] payload0;
		begin
			$display("\n--- TEST 4: Bad checksum packet ---");

			clear_counters();

			layer_id    = 8'd2;
			param_type  = PARAM_WEIGHT;
			bit_width   = 16'd8;
			elem_count  = 32'd1;
			payload_len = 32'd1;
			payload0    = 8'h55;

			checksum = 8'd0;

			send_sof();

			send_byte(VERSION);       checksum = checksum + VERSION;
			send_byte(PACKET_PARAM);  checksum = checksum + PACKET_PARAM;
			send_byte(FLAG_SIGNED);   checksum = checksum + FLAG_SIGNED;

			send_byte(layer_id);      checksum = checksum + layer_id;
			send_byte(param_type);    checksum = checksum + param_type;

			send_byte(bit_width[7:0]);   checksum = checksum + bit_width[7:0];
			send_byte(bit_width[15:8]);  checksum = checksum + bit_width[15:8];

			send_byte(elem_count[7:0]);    checksum = checksum + elem_count[7:0];
			send_byte(elem_count[15:8]);   checksum = checksum + elem_count[15:8];
			send_byte(elem_count[23:16]);  checksum = checksum + elem_count[23:16];
			send_byte(elem_count[31:24]);  checksum = checksum + elem_count[31:24];

			send_byte(payload_len[7:0]);    checksum = checksum + payload_len[7:0];
			send_byte(payload_len[15:8]);   checksum = checksum + payload_len[15:8];
			send_byte(payload_len[23:16]);  checksum = checksum + payload_len[23:16];
			send_byte(payload_len[31:24]);  checksum = checksum + payload_len[31:24];

			send_byte(payload0);
			checksum = checksum + payload0;

			// intentionally wrong checksum
			send_byte(checksum + 8'h01);

			repeat (5) @(posedge clk);

			check_equal_int("headerCount", headerCount, 1);
			check_equal_int("doneCount", doneCount, 0);
			check_equal_int("packetErrorCount", packetErrorCount, 1);
			check_equal_int("checksumErrorCount", checksumErrorCount, 1);
			check_equal_int("headerErrorCount", headerErrorCount, 0);
		end
	endtask

	task send_bad_header_length_packet;
		reg [7:0] checksum;
		reg [7:0] layer_id;
		reg [7:0] param_type;
		reg [15:0] bit_width;
		reg [31:0] elem_count;
		reg [31:0] payload_len;
		begin
			$display("\n--- TEST 5: Bad header payload length ---");

			clear_counters();

			layer_id    = 8'd1;
			param_type  = PARAM_WEIGHT;
			bit_width   = 16'd8;
			elem_count  = 32'd4;

			// This is intentionally wrong.
			// Expected payload_len = elem_count * ceil(bit_width/8) = 4.
			payload_len = 32'd5;

			checksum = 8'd0;

			send_sof();

			send_byte(VERSION);       checksum = checksum + VERSION;
			send_byte(PACKET_PARAM);  checksum = checksum + PACKET_PARAM;
			send_byte(FLAG_SIGNED);   checksum = checksum + FLAG_SIGNED;

			send_byte(layer_id);      checksum = checksum + layer_id;
			send_byte(param_type);    checksum = checksum + param_type;

			send_byte(bit_width[7:0]);   checksum = checksum + bit_width[7:0];
			send_byte(bit_width[15:8]);  checksum = checksum + bit_width[15:8];

			send_byte(elem_count[7:0]);    checksum = checksum + elem_count[7:0];
			send_byte(elem_count[15:8]);   checksum = checksum + elem_count[15:8];
			send_byte(elem_count[23:16]);  checksum = checksum + elem_count[23:16];
			send_byte(elem_count[31:24]);  checksum = checksum + elem_count[31:24];

			send_byte(payload_len[7:0]);    checksum = checksum + payload_len[7:0];
			send_byte(payload_len[15:8]);   checksum = checksum + payload_len[15:8];
			send_byte(payload_len[23:16]);  checksum = checksum + payload_len[23:16];
			send_byte(payload_len[31:24]);  checksum = checksum + payload_len[31:24];

			// Header error should occur immediately after header.
			// No payload/checksum is needed because DUT returns to waitSOF0s.
			repeat (5) @(posedge clk);

			check_equal_int("headerCount", headerCount, 0);
			check_equal_int("doneCount", doneCount, 0);
			check_equal_int("packetErrorCount", packetErrorCount, 1);
			check_equal_int("headerErrorCount", headerErrorCount, 1);
		end
	endtask

	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0, tb_uartPacketDec_rev);

		errorCount = 0;

		rst    = 1'b1;
		rxDone = 1'b0;
		rxData = 8'h00;

		repeat (5) @(posedge clk);
		rst = 1'b0;
		repeat (5) @(posedge clk);

		send_image_packet_with_label();
		send_param_weight_packet();
		send_param_bias_packet();
		send_bad_checksum_packet();
		send_bad_header_length_packet();

		$display("\n========================================");
		if (errorCount == 0) begin
			$display("ALL TESTS PASSED");
		end
		else begin
			$display("TEST FAILED: errorCount = %0d", errorCount);
		end
		$display("========================================\n");

		#100;
		$finish;
	end

endmodule