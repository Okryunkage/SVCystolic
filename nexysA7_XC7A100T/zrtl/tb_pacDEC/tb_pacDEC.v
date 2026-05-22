`include "uartPacketDec_rev.v"
`include "ddrPacketWriter128.v"
`timescale 1ns/1ps

module tb_uartPacketDec_ddrPacketWriter128;

    localparam ADDR_WIDTH = 27;
    localparam [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8;

    localparam [7:0] SOF0 = 8'hAA;
    localparam [7:0] SOF1 = 8'h55;

    localparam [7:0] VERSION = 8'h01;

    localparam [7:0] PACKET_TYPE_IMAGE = 8'h01;
    localparam [7:0] PACKET_TYPE_PARAM = 8'h02;

    localparam [7:0] FLAG_INCLUDE_LABEL = 8'h01;

	localparam [7:0] FLAG_NO_LABEL      = 8'h00;

    reg clk;
    reg rst;

    // ------------------------------------------------------------
    // UART byte stream input to uartPacketDec
    // ------------------------------------------------------------
    reg        rxDone;
    reg [7:0]  rxData;

    // ------------------------------------------------------------
    // Decoded outputs from uartPacketDec
    // These wires connect directly to ddrPacketWriter128.
    // ------------------------------------------------------------
    wire                  headerValid;
    wire [7:0]            packetType;
    wire [7:0]            flags;
    wire [31:0]           payloadLEN;

    wire [7:0]            layerID;
    wire [7:0]            paramType;
    wire [15:0]           bitWidth;
    wire [31:0]           elemCount;

    wire [31:0]           batchID;
    wire [15:0]           batchSize;
    wire [15:0]           vectorLEN;

    wire                  payloadValid;
    wire [7:0]            payloadData;
    wire [31:0]           payloadIndex;

    wire                  packetDone;
    wire                  packetError;

    // ------------------------------------------------------------
    // DDR writer control
    // ------------------------------------------------------------
    reg                   baseAddrLoad;
    reg  [ADDR_WIDTH-1:0] baseAddrValue;

    // ------------------------------------------------------------
    // Mock DDR interface
    // ------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] ddrAddr;
    wire [127:0]          ddrData;
    wire                  ddrWstrobe;
    reg                   ddrReady;
    reg                   ddrTransactionComplete;

    // ------------------------------------------------------------
    // Writer outputs
    // ------------------------------------------------------------
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

    wire                  writerBusy;

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
        $dumpvars(0, tb_uartPacketDec_ddrPacketWriter128);
    end

    // ============================================================
    // uartPacketDec instance
    //
    // IMPORTANT:
    // If your actual uartPacketDec port names are different,
    // edit only this instance.
    // ============================================================
    uartPacketDec_rev uart_dec_i (
        .clk            (clk),
        .rst            (rst),

        .rxDone        (rxDone),
        .rxData         (rxData),

        .headerValid    (headerValid),
        .packetType     (packetType),
        .flags          (flags),
        .payloadLEN     (payloadLEN),

        .layerID        (layerID),
        .paramType      (paramType),
        .bitWidth       (bitWidth),
        .elemCount      (elemCount),

        .batchID        (batchID),
        .batchSize      (batchSize),
        .vectorLEN      (vectorLEN),

        .payloadValid   (payloadValid),
        .payloadData    (payloadData),
        .payloadIndex   (payloadIndex),

        .packetDone     (packetDone),
        .packetError    (packetError)
    );

    // ============================================================
    // ddrPacketWriter128 instance
    // ============================================================
    ddrPacketWriter128 #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .ADDR_STRIDE (ADDR_STRIDE)
    ) writer_i (
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

        .busy                   (writerBusy)
    );

    // ------------------------------------------------------------
    // Mock DDR transaction complete model
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
    // Byte 0 goes to [7:0], byte 1 to [15:8], ...
    // This matches ddrPacketWriter128 packing.
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
    // Checksum helper
    //
    // This assumes checksum is 8-bit sum of all bytes after SOF.
    // If your uartPacketDec uses a different checksum rule,
    // edit this function and the packet builder.
    // ------------------------------------------------------------
    function [7:0] sum8;
        input [7:0] cur;
        input [7:0] b;
        begin
            sum8 = cur + b;
        end
    endfunction

    // ------------------------------------------------------------
    // UART byte driver
    // ------------------------------------------------------------
    task send_uart_byte;
        input [7:0] b;
        begin
            @(negedge clk);
            rxData  = b;
            rxDone = 1'b1;

            @(negedge clk);
            rxDone = 1'b0;
            rxData  = 8'd0;

            // one idle cycle between received bytes
            @(negedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Send little-endian fields
    // ------------------------------------------------------------
    task send_u16_le;
        input [15:0] v;
        begin
            send_uart_byte(v[7:0]);
            send_uart_byte(v[15:8]);
        end
    endtask

    task send_u32_le;
        input [31:0] v;
        begin
            send_uart_byte(v[7:0]);
            send_uart_byte(v[15:8]);
            send_uart_byte(v[23:16]);
            send_uart_byte(v[31:24]);
        end
    endtask

    // ------------------------------------------------------------
    // Packet byte driver with checksum accumulation
    // SOF bytes are not included in checksum.
    // ------------------------------------------------------------
    reg [7:0] checksum;

    task send_packet_byte;
        input [7:0] b;
        begin
            checksum = checksum + b;
            send_uart_byte(b);
        end
    endtask

    task send_packet_u16_le;
        input [15:0] v;
        begin
            send_packet_byte(v[7:0]);
            send_packet_byte(v[15:8]);
        end
    endtask

    task send_packet_u32_le;
        input [31:0] v;
        begin
            send_packet_byte(v[7:0]);
            send_packet_byte(v[15:8]);
            send_packet_byte(v[23:16]);
            send_packet_byte(v[31:24]);
        end
    endtask

    // ------------------------------------------------------------
    // Send IMAGE packet
    //
    // Format assumed from the Python struct:
    //   SOF              2 bytes: AA 55
    //   version          1 byte
    //   packetType       1 byte
    //   flags            1 byte
    //   batchID          uint32 little-endian
    //   batchSize        uint16 little-endian
    //   vectorLEN        uint16 little-endian
    //   payloadLEN       uint32 little-endian
    //   payload          payloadLEN bytes
    //   checksum         uint8
    //
    // If your decoder includes SOF in checksum or uses two's complement
    // checksum, modify only the final checksum byte.
    // ------------------------------------------------------------
    task send_image_packet_seq;
        input [31:0] bid;
        input [15:0] bsize;
        input [15:0] vlen;
        input integer payloadBytes;
        input integer payloadStart;
        integer i;
        begin
            checksum = 8'd0;

            // SOF
            send_uart_byte(SOF0);
            send_uart_byte(SOF1);

            // Header
            send_packet_byte(VERSION);
            send_packet_byte(PACKET_TYPE_IMAGE);
            send_packet_byte(FLAG_NO_LABEL);
            send_packet_u32_le(bid);
            send_packet_u16_le(bsize);
            send_packet_u16_le(vlen);
            send_packet_u32_le(payloadBytes[31:0]);

            // Payload
            for (i = 0; i < payloadBytes; i = i + 1) begin
                send_packet_byte((payloadStart + i) & 8'hFF);
            end

            // Checksum
            send_uart_byte(checksum);
        end
    endtask

    // ------------------------------------------------------------
    // Base address load
    // ------------------------------------------------------------
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

    // ------------------------------------------------------------
    // Wait for writer writeDone
    // ------------------------------------------------------------
    task wait_writer_done;
        integer i;
        integer found;
        begin
            found = 0;

            for (i = 0; i < 1000; i = i + 1) begin
                @(posedge clk);
                #1;

                if (writeDone) begin
                    found = 1;
                    i = 1000;
                end
            end

            if (!found) begin
                fail("writeDone timeout");
            end
        end
    endtask

    task check_no_error;
        begin
            if (packetError) begin
                fail("uartPacketDec packetError asserted");
            end

            if (writerError || overflowError || lengthError || unexpectedError) begin
                $display("writerError     = %b", writerError);
                $display("overflowError   = %b", overflowError);
                $display("lengthError     = %b", lengthError);
                $display("unexpectedError = %b", unexpectedError);
                fail("ddrPacketWriter128 error asserted");
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
    // Clear inputs
    // ------------------------------------------------------------
    task clear_inputs;
        begin
            rxDone = 1'b0;
            rxData  = 8'd0;

            baseAddrLoad  = 1'b0;
            baseAddrValue = {ADDR_WIDTH{1'b0}};

            ddrReady = 1'b1;
        end
    endtask

    // ------------------------------------------------------------
    // Test 1: UART IMAGE packet, 16-byte payload
    // Expected DDR write:
    //   addr = base
    //   data = 0f0e0d0c0b0a09080706050403020100
    // ------------------------------------------------------------
    task test_uart_image_16bytes;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 1: UART -> decoder -> DDR writer, IMAGE 16 bytes");

            base = 27'h0001000;
            load_base_addr(base);

            expect_write(base, make_seq_word(0, 16));

            send_image_packet_seq(
                32'd7,    // batchID
                16'd1,    // batchSize
                16'd16,   // vectorLEN
                16,       // payloadBytes
                0         // payloadStart
            );

            wait_writer_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPacketType !== PACKET_TYPE_IMAGE) begin
                fail("writtenPacketType mismatch");
            end

            if (writtenFlags !== FLAG_NO_LABEL) begin
                fail("writtenFlags mismatch");
            end

            if (writtenPayloadBytes !== 32'd16) begin
                fail("writtenPayloadBytes mismatch");
            end

            if (writtenWordCount !== 32'd1) begin
                fail("writtenWordCount mismatch");
            end

            if (writtenBatchID !== 32'd7) begin
                fail("writtenBatchID mismatch");
            end

            if (writtenBatchSize !== 16'd1) begin
                fail("writtenBatchSize mismatch");
            end

            if (writtenVectorLEN !== 16'd16) begin
                fail("writtenVectorLEN mismatch");
            end

            if (packetStartAddr !== base) begin
                fail("packetStartAddr mismatch");
            end

            if (packetLastAddr !== base) begin
                fail("packetLastAddr mismatch");
            end

            if (packetNextAddr !== base + ADDR_STRIDE) begin
                fail("packetNextAddr mismatch");
            end

            if (allocPtr !== base + ADDR_STRIDE) begin
                fail("allocPtr mismatch");
            end

            $display("TEST 1 PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Test 2: UART IMAGE packet, 20-byte payload
    // Expected DDR writes:
    //   write 0: 16 bytes
    //   write 1: 4 bytes + zero padding
    // ------------------------------------------------------------
    task test_uart_image_20bytes_partial;
        reg [ADDR_WIDTH-1:0] base;
        begin
            $display("");
            $display("TEST 2: UART -> decoder -> DDR writer, IMAGE 20 bytes partial");

            base = 27'h0002000;
            load_base_addr(base);

            expect_write(base,               make_seq_word(8'h10, 16));
            expect_write(base + ADDR_STRIDE, make_seq_word(8'h20, 4));

            send_image_packet_seq(
                32'd8,    // batchID
                16'd1,    // batchSize
                16'd20,   // vectorLEN
                20,       // payloadBytes
                8'h10     // payloadStart
            );

            wait_writer_done();

            check_no_error();
            check_all_expected_writes_seen();

            if (writtenPacketType !== PACKET_TYPE_IMAGE) begin
                fail("writtenPacketType mismatch");
            end

            if (writtenPayloadBytes !== 32'd20) begin
                fail("writtenPayloadBytes mismatch");
            end

            if (writtenWordCount !== 32'd2) begin
                fail("writtenWordCount mismatch");
            end

            if (packetStartAddr !== base) begin
                fail("packetStartAddr mismatch");
            end

            if (packetLastAddr !== base + ADDR_STRIDE) begin
                fail("packetLastAddr mismatch");
            end

            if (packetNextAddr !== base + (ADDR_STRIDE * 2)) begin
                fail("packetNextAddr mismatch");
            end

            if (allocPtr !== base + (ADDR_STRIDE * 2)) begin
                fail("allocPtr mismatch");
            end

            $display("TEST 2 PASS");
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

        test_uart_image_16bytes();
        test_uart_image_20bytes_partial();

        repeat (20) @(posedge clk);

        check_all_expected_writes_seen();

        if (errorCount == 0) begin
            $display("");
            $display("==============================================================");
            $display("PASS: uartPacketDec + ddrPacketWriter128 integration test");
            $display("==============================================================");
        end
        else begin
            $display("");
            $display("FAIL: errorCount = %0d", errorCount);
        end

        $finish;
    end

endmodule