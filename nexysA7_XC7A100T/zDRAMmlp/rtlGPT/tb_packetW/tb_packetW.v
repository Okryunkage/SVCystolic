`include "ddrPacketWriter128.v"
`timescale 1ns/1ps

module tb_ddrPacketWriter128;

    localparam ADDR_WIDTH = 27;
    localparam [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8;

    reg clk;
    reg rst;

    // ------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------
    reg                   baseAddrLoad;
    reg  [ADDR_WIDTH-1:0] baseAddrValue;

    reg                   headerValid;
    reg  [7:0]            packetType;
    reg  [7:0]            flags;
    reg  [31:0]           payloadLEN;

    reg  [7:0]            layerID;
    reg  [7:0]            paramType;
    reg  [15:0]           bitWidth;
    reg  [31:0]           elemCount;

    reg  [31:0]           batchID;
    reg  [15:0]           batchSize;
    reg  [15:0]           vectorLEN;

    reg                   payloadValid;
    reg  [7:0]            payloadData;
    reg  [31:0]           payloadIndex;

    reg                   packetDone;
    reg                   packetError;

    reg                   ddrReady;
    reg                   ddrTransactionComplete;

    // ------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] ddrAddr;
    wire [127:0]          ddrData;
    wire                  ddrWstrobe;

    wire [ADDR_WIDTH-1:0] allocPtr;

    wire                  writeDone;
    wire [ADDR_WIDTH-1:0] packetStartAddr;
    wire [ADDR_WIDTH-1:0] packetLastAddr;
    wire [ADDR_WIDTH-1:0] packetNextAddr;
    wire                  packetLastAddrValid;

    wire [7:0]            writtenPacketType;
    wire [7:0]            writtenFlags;
    wire [7:0]            writtenLayerID;
    wire [7:0]            writtenParamType;
    wire [15:0]           writtenBitWidth;
    wire [31:0]           writtenElemCount;
    wire [31:0]           writtenBatchID;
    wire [15:0]           writtenBatchSize;
    wire [15:0]           writtenVectorLEN;

    wire [31:0]           writtenPayloadBytes;
    wire [31:0]           writtenWordCount;

    wire                  writerError;
    wire                  overflowError;
    wire                  lengthError;
    wire                  unexpectedError;

    wire                  busy;

    // ------------------------------------------------------------
    // DUT instance
    // ------------------------------------------------------------
    ddrPacketWriter128 #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .ADDR_STRIDE (ADDR_STRIDE)
    ) dut (
        .clk                    (clk),
        .rst                    (rst),

        .baseAddrLoad           (baseAddrLoad),
        .baseAddrValue          (baseAddrValue),

        .headerValid            (headerValid),
        .packetType             (packetType),
        .flags                  (flags),
        .payloadLEN             (payloadLEN),

        .layerID                (layerID),
        .paramType              (paramType),
        .bitWidth               (bitWidth),
        .elemCount              (elemCount),

        .batchID                (batchID),
        .batchSize              (batchSize),
        .vectorLEN              (vectorLEN),

        .payloadValid           (payloadValid),
        .payloadData            (payloadData),
        .payloadIndex           (payloadIndex),

        .packetDone             (packetDone),
        .packetError            (packetError),

        .ddrAddr                (ddrAddr),
        .ddrData                (ddrData),
        .ddrWstrobe             (ddrWstrobe),
        .ddrReady               (ddrReady),
        .ddrTransactionComplete (ddrTransactionComplete),

        .allocPtr               (allocPtr),

        .writeDone              (writeDone),
        .packetStartAddr        (packetStartAddr),
        .packetLastAddr         (packetLastAddr),
        .packetNextAddr         (packetNextAddr),
        .packetLastAddrValid    (packetLastAddrValid),

        .writtenPacketType      (writtenPacketType),
        .writtenFlags           (writtenFlags),
        .writtenLayerID         (writtenLayerID),
        .writtenParamType       (writtenParamType),
        .writtenBitWidth        (writtenBitWidth),
        .writtenElemCount       (writtenElemCount),
        .writtenBatchID         (writtenBatchID),
        .writtenBatchSize       (writtenBatchSize),
        .writtenVectorLEN       (writtenVectorLEN),

        .writtenPayloadBytes    (writtenPayloadBytes),
        .writtenWordCount       (writtenWordCount),

        .writerError            (writerError),
        .overflowError          (overflowError),
        .lengthError            (lengthError),
        .unexpectedError        (unexpectedError),

        .busy                   (busy)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 100 MHz
    end

    // ------------------------------------------------------------
    // VCD
    // ------------------------------------------------------------
    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, tb_ddrPacketWriter128);
    end

    // ------------------------------------------------------------
    // Simple DDR transaction complete model
    //
    // ddrTransactionComplete is asserted a few cycles after ddrWstrobe.
    // This mimics a simple mig_ui128 wrapper response.
    // ------------------------------------------------------------
    reg [2:0] completeShift;

    always @(posedge clk) begin
        if (rst) begin
            completeShift <= 3'b000;
            ddrTransactionComplete <= 1'b0;
        end
        else begin
            completeShift <= {completeShift[1:0], ddrWstrobe};
            ddrTransactionComplete <= completeShift[2];
        end
    end

    // ------------------------------------------------------------
    // Expected DDR write checker
    // ------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] expAddr [0:255];
    reg [127:0]          expData [0:255];

    integer expTotal;
    integer expSeen;
    integer errorCount;

    task fail;
        input [1023:0] msg;
        begin
            $display("FAIL: %0s", msg);
            errorCount = errorCount + 1;
            $finish;
        end
    endtask

    task expect_write;
        input [ADDR_WIDTH-1:0] addr;
        input [127:0]          data;
        begin
            expAddr[expTotal] = addr;
            expData[expTotal] = data;
            expTotal = expTotal + 1;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (!rst && ddrWstrobe) begin
            if (expSeen >= expTotal) begin
                $display("Unexpected DDR write:");
                $display("  addr = %h", ddrAddr);
                $display("  data = %h", ddrData);
                fail("More DDR writes than expected");
            end

            if (ddrAddr !== expAddr[expSeen]) begin
                $display("DDR address mismatch at write %0d", expSeen);
                $display("  expected = %h", expAddr[expSeen]);
                $display("  actual   = %h", ddrAddr);
                fail("DDR address mismatch");
            end

            if (ddrData !== expData[expSeen]) begin
                $display("DDR data mismatch at write %0d", expSeen);
                $display("  expected = %h", expData[expSeen]);
                $display("  actual   = %h", ddrData);
                fail("DDR data mismatch");
            end

            $display("DDR WRITE OK: index=%0d addr=%h data=%h",
                     expSeen, ddrAddr, ddrData);

            expSeen = expSeen + 1;
        end
    end

    // ------------------------------------------------------------
    // Utility: make 128-bit word from sequential bytes.
    //
    // Byte 0 goes to [7:0].
    // Byte 1 goes to [15:8].
    // ...
    // This matches set_byte_128() inside ddrPacketWriter128.
    // ------------------------------------------------------------
    function [127:0] make_seq_word;
        input integer startByte;
        input integer byteCount;
        integer i;
        begin
            make_seq_word = 128'd0;
            for (i = 0; i < byteCount; i = i + 1) begin
                make_seq_word[i*8 +: 8] = (startByte + i) & 8'hFF;
            end
        end
    endfunction

    // ------------------------------------------------------------
    // Input driving tasks
    // ------------------------------------------------------------
    task clear_inputs;
        begin
            baseAddrLoad  = 1'b0;
            baseAddrValue = {ADDR_WIDTH{1'b0}};

            headerValid   = 1'b0;
            packetType    = 8'd0;
            flags         = 8'd0;
            payloadLEN    = 32'd0;

            layerID       = 8'd0;
            paramType     = 8'd0;
            bitWidth      = 16'd0;
            elemCount     = 32'd0;

            batchID       = 32'd0;
            batchSize     = 16'd0;
            vectorLEN     = 16'd0;

            payloadValid  = 1'b0;
            payloadData   = 8'd0;
            payloadIndex  = 32'd0;

            packetDone    = 1'b0;
            packetError   = 1'b0;

            ddrReady      = 1'b1;
        end
    endtask

    task load_base_addr;
        input [ADDR_WIDTH-1:0] addr;
        begin
            @(negedge clk);
            baseAddrValue = addr;
            baseAddrLoad  = 1'b1;

            @(negedge clk);
            baseAddrLoad  = 1'b0;
            baseAddrValue = {ADDR_WIDTH{1'b0}};

            @(posedge clk);
            #1;
            if (allocPtr !== addr) begin
                $display("allocPtr load mismatch");
                $display("  expected = %h", addr);
                $display("  actual   = %h", allocPtr);
                fail("baseAddrLoad failed");
            end
        end
    endtask

    task send_header_image;
        input [31:0] plen;
        input [31:0] bid;
        input [15:0] bsize;
        input [15:0] vlen;
        begin
            @(negedge clk);

            headerValid = 1'b1;
            packetType  = 8'h01;
            flags       = 8'h01;
            payloadLEN  = plen;

            layerID     = 8'd0;
            paramType   = 8'd0;
            bitWidth    = 16'd8;
            elemCount   = 32'd0;

            batchID     = bid;
            batchSize   = bsize;
            vectorLEN   = vlen;

            @(negedge clk);
            headerValid = 1'b0;
        end
    endtask

    task send_header_param;
        input [31:0] plen;
        input [7:0]  lyr;
        input [7:0]  ptype;
        input [15:0] bw;
        input [31:0] elems;
        begin
            @(negedge clk);

            headerValid = 1'b1;
            packetType  = 8'h02;
            flags       = 8'h00;
            payloadLEN  = plen;

            layerID     = lyr;
            paramType   = ptype;
            bitWidth    = bw;
            elemCount   = elems;

            batchID     = 32'd0;
            batchSize   = 16'd0;
            vectorLEN   = 16'd0;

            @(negedge clk);
            headerValid = 1'b0;
        end
    endtask

    task send_payload_byte;
        input [7:0]  data;
        input [31:0] index;
        begin
            @(negedge clk);
            payloadValid = 1'b1;
            payloadData  = data;
            payloadIndex = index;

            @(negedge clk);
            payloadValid = 1'b0;
            payloadData  = 8'd0;
            payloadIndex = 32'd0;
        end
    endtask

    task send_payload_seq;
        input integer startByte;
        input integer byteCount;
        integer i;
        begin
            for (i = 0; i < byteCount; i = i + 1) begin
                send_payload_byte((startByte + i) & 8'hFF, i);
            end
        end
    endtask

    // ------------------------------------------------------------
    // IMPORTANT:
    //
    // packetDone and writeDone may occur very close together,
    // especially when payloadLEN == 0.
    //
    // Therefore, do not call:
    //   pulse_packet_done();
    //   wait_write_done();
    //
    // The writeDone pulse may already be gone before wait_write_done()
    // starts. This task asserts packetDone and waits for writeDone
    // at the same time.
    // ------------------------------------------------------------
    task pulse_packet_done_and_wait_write_done;
        integer i;
        integer found;
        begin
            found = 0;

            @(negedge clk);
            packetDone  = 1'b1;
            packetError = 1'b0;

            for (i = 0; i < 200; i = i + 1) begin
                @(posedge clk);
                #1;

                if (writeDone) begin
                    found = 1;
                    i = 200;
                end
            end

            @(negedge clk);
            packetDone  = 1'b0;
            packetError = 1'b0;

            if (!found) begin
                fail("writeDone timeout");
            end
        end
    endtask

    task check_no_error;
        begin
            if (writerError || overflowError || lengthError || unexpectedError) begin
                $display("writerError     = %b", writerError);
                $display("overflowError   = %b", overflowError);
                $display("lengthError     = %b", lengthError);
                $display("unexpectedError = %b", unexpectedError);
                fail("Unexpected writer error");
            end
        end
    endtask

    task check_all_expected_writes_seen;
        begin
            if (expSeen !== expTotal) begin
                $display("Expected write count mismatch");
                $display("  expected = %0d", expTotal);
                $display("  seen     = %0d", expSeen);
                fail("Not all expected DDR writes occurred");
            end
        end
    endtask

    // ------------------------------------------------------------
    // Test 1: image packet, 16-byte exact payload
    // Expected: one 128-bit DDR write
    // ------------------------------------------------------------
    task test_image_16bytes;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 1: IMAGE packet, 16-byte exact write");

            base = 27'h0001000;
            load_base_addr(base);

            expect_write(base, make_seq_word(0, 16));

            send_header_image(
                32'd16,      // payloadLEN
                32'd7,       // batchID
                16'd1,       // batchSize
                16'd16       // vectorLEN
            );

            send_payload_seq(0, 16);
            pulse_packet_done_and_wait_write_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPacketType !== 8'h01) fail("writtenPacketType mismatch");
            if (writtenPayloadBytes !== 32'd16) fail("writtenPayloadBytes mismatch");
            if (writtenWordCount !== 32'd1) fail("writtenWordCount mismatch");

            if (packetStartAddr !== base) fail("packetStartAddr mismatch");
            if (packetLastAddr !== base) fail("packetLastAddr mismatch");
            if (packetNextAddr !== base + ADDR_STRIDE) fail("packetNextAddr mismatch");
            if (allocPtr !== base + ADDR_STRIDE) fail("allocPtr mismatch");
            if (packetLastAddrValid !== 1'b1) fail("packetLastAddrValid mismatch");

            if (writtenBatchID !== 32'd7) fail("writtenBatchID mismatch");
            if (writtenBatchSize !== 16'd1) fail("writtenBatchSize mismatch");
            if (writtenVectorLEN !== 16'd16) fail("writtenVectorLEN mismatch");

            $display("TEST 1 PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Test 2: parameter packet, 20-byte partial payload
    // Expected: two 128-bit DDR writes
    //   write 0: 16 valid bytes
    //   write 1: 4 valid bytes + zero padding
    // ------------------------------------------------------------
    task test_param_20bytes_partial;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 2: PARAM packet, 20-byte partial write");

            base = 27'h0002000;
            load_base_addr(base);

            expect_write(base,               make_seq_word(8'h10, 16));
            expect_write(base + ADDR_STRIDE, make_seq_word(8'h20, 4));

            send_header_param(
                32'd20,      // payloadLEN
                8'd1,        // layerID
                8'h00,       // paramType: weight
                16'd8,       // bitWidth
                32'd20       // elemCount
            );

            send_payload_seq(8'h10, 20);
            pulse_packet_done_and_wait_write_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPacketType !== 8'h02) fail("writtenPacketType mismatch");
            if (writtenLayerID !== 8'd1) fail("writtenLayerID mismatch");
            if (writtenParamType !== 8'h00) fail("writtenParamType mismatch");
            if (writtenBitWidth !== 16'd8) fail("writtenBitWidth mismatch");
            if (writtenElemCount !== 32'd20) fail("writtenElemCount mismatch");

            if (writtenPayloadBytes !== 32'd20) fail("writtenPayloadBytes mismatch");
            if (writtenWordCount !== 32'd2) fail("writtenWordCount mismatch");

            if (packetStartAddr !== base) fail("packetStartAddr mismatch");
            if (packetLastAddr !== base + ADDR_STRIDE) fail("packetLastAddr mismatch");
            if (packetNextAddr !== base + (ADDR_STRIDE * 2)) fail("packetNextAddr mismatch");
            if (allocPtr !== base + (ADDR_STRIDE * 2)) fail("allocPtr mismatch");
            if (packetLastAddrValid !== 1'b1) fail("packetLastAddrValid mismatch");

            $display("TEST 2 PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Test 3: image packet, 32-byte exact payload
    // Expected: two full 128-bit DDR writes
    // ------------------------------------------------------------
    task test_image_32bytes;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 3: IMAGE packet, 32-byte exact write");

            base = 27'h0003000;
            load_base_addr(base);

            expect_write(base,               make_seq_word(8'h40, 16));
            expect_write(base + ADDR_STRIDE, make_seq_word(8'h50, 16));

            send_header_image(
                32'd32,
                32'd9,
                16'd2,
                16'd16
            );

            send_payload_seq(8'h40, 32);
            pulse_packet_done_and_wait_write_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPayloadBytes !== 32'd32) fail("writtenPayloadBytes mismatch");
            if (writtenWordCount !== 32'd2) fail("writtenWordCount mismatch");

            if (packetStartAddr !== base) fail("packetStartAddr mismatch");
            if (packetLastAddr !== base + ADDR_STRIDE) fail("packetLastAddr mismatch");
            if (packetNextAddr !== base + (ADDR_STRIDE * 2)) fail("packetNextAddr mismatch");
            if (allocPtr !== base + (ADDR_STRIDE * 2)) fail("allocPtr mismatch");

            $display("TEST 3 PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Test 4: zero-length payload
    // Expected: no DDR write, but writeDone should occur
    // ------------------------------------------------------------
    task test_zero_payload;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 4: zero-length payload");

            base = 27'h0004000;
            load_base_addr(base);

            send_header_image(
                32'd0,
                32'd11,
                16'd0,
                16'd0
            );

            pulse_packet_done_and_wait_write_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPayloadBytes !== 32'd0) fail("writtenPayloadBytes mismatch");
            if (writtenWordCount !== 32'd0) fail("writtenWordCount mismatch");

            if (packetStartAddr !== base) fail("packetStartAddr mismatch");
            if (packetNextAddr !== base) fail("packetNextAddr mismatch");
            if (allocPtr !== base) fail("allocPtr mismatch");

            $display("TEST 4 PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Main
    // ------------------------------------------------------------
    initial begin
        errorCount = 0;
        expTotal   = 0;
        expSeen    = 0;

        clear_inputs();

        rst = 1'b1;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        test_image_16bytes();
        test_param_20bytes_partial();
        test_image_32bytes();
        test_zero_payload();

        repeat (10) @(posedge clk);

        check_all_expected_writes_seen();

        if (errorCount == 0) begin
            $display("");
            $display("====================================================");
            $display("PASS: tb_ddrPacketWriter128 completed successfully");
            $display("====================================================");
        end
        else begin
            $display("");
            $display("FAIL: errorCount = %0d", errorCount);
        end

        $finish;
    end

endmodule