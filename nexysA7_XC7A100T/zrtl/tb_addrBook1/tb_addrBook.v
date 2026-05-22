`include "ddrADDRbook.v"
`timescale 1ns/1ps

module tb_ddrAddressBook;

    localparam ADDR_WIDTH = 27;
    localparam [ADDR_WIDTH-1:0] RESET_BASE_ADDR = 27'h0001000;

    localparam [7:0] PACKET_TYPE_IMAGE = 8'h01;
    localparam [7:0] PACKET_TYPE_PARAM = 8'h02;

    localparam [7:0] PARAM_TYPE_WEIGHT = 8'h00;
    localparam [7:0] PARAM_TYPE_BIAS   = 8'h01;

    reg clk;
    reg rst;
    reg clear;

    reg                  writeDone;
    reg                  writerError;

    reg  [ADDR_WIDTH-1:0] packetStartAddr;
    reg  [ADDR_WIDTH-1:0] packetLastAddr;
    reg  [ADDR_WIDTH-1:0] packetNextAddr;
    reg                   packetLastAddrValid;

    reg  [7:0]            writtenPacketType;
    reg  [7:0]            writtenFlags;
    reg  [7:0]            writtenLayerID;
    reg  [7:0]            writtenParamType;
    reg  [15:0]           writtenBitWidth;
    reg  [31:0]           writtenElemCount;
    reg  [31:0]           writtenBatchID;
    reg  [15:0]           writtenBatchSize;
    reg  [15:0]           writtenVectorLEN;
    reg  [31:0]           writtenPayloadBytes;
    reg  [31:0]           writtenWordCount;

    wire [ADDR_WIDTH-1:0] nextFreeAddr;

    wire imageValid;
    wire [ADDR_WIDTH-1:0] imageStartAddr;
    wire [ADDR_WIDTH-1:0] imageLastAddr;
    wire [ADDR_WIDTH-1:0] imageNextAddr;
    wire [31:0] imagePayloadBytes;
    wire [31:0] imageWordCount;
    wire [31:0] imageBatchID;
    wire [15:0] imageBatchSize;
    wire [15:0] imageVectorLEN;
    wire [7:0]  imageFlags;

    wire fc1WeightValid;
    wire [ADDR_WIDTH-1:0] fc1WeightStartAddr;
    wire [ADDR_WIDTH-1:0] fc1WeightLastAddr;
    wire [ADDR_WIDTH-1:0] fc1WeightNextAddr;
    wire [15:0] fc1WeightBitWidth;
    wire [31:0] fc1WeightElemCount;
    wire [31:0] fc1WeightPayloadBytes;
    wire [31:0] fc1WeightWordCount;

    wire fc1BiasValid;
    wire [ADDR_WIDTH-1:0] fc1BiasStartAddr;
    wire [ADDR_WIDTH-1:0] fc1BiasLastAddr;
    wire [ADDR_WIDTH-1:0] fc1BiasNextAddr;
    wire [15:0] fc1BiasBitWidth;
    wire [31:0] fc1BiasElemCount;
    wire [31:0] fc1BiasPayloadBytes;
    wire [31:0] fc1BiasWordCount;

    wire fc2WeightValid;
    wire [ADDR_WIDTH-1:0] fc2WeightStartAddr;
    wire [ADDR_WIDTH-1:0] fc2WeightLastAddr;
    wire [ADDR_WIDTH-1:0] fc2WeightNextAddr;
    wire [15:0] fc2WeightBitWidth;
    wire [31:0] fc2WeightElemCount;
    wire [31:0] fc2WeightPayloadBytes;
    wire [31:0] fc2WeightWordCount;

    wire fc2BiasValid;
    wire [ADDR_WIDTH-1:0] fc2BiasStartAddr;
    wire [ADDR_WIDTH-1:0] fc2BiasLastAddr;
    wire [ADDR_WIDTH-1:0] fc2BiasNextAddr;
    wire [15:0] fc2BiasBitWidth;
    wire [31:0] fc2BiasElemCount;
    wire [31:0] fc2BiasPayloadBytes;
    wire [31:0] fc2BiasWordCount;

    wire addressBookError;
    wire unknownPacketError;
    wire writerReportedError;

    integer errorCount;

    ddrAddressBook #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .RESET_BASE_ADDR(RESET_BASE_ADDR),
        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .clear(clear),

        .writeDone(writeDone),
        .writerError(writerError),

        .packetStartAddr(packetStartAddr),
        .packetLastAddr(packetLastAddr),
        .packetNextAddr(packetNextAddr),
        .packetLastAddrValid(packetLastAddrValid),

        .writtenPacketType(writtenPacketType),
        .writtenFlags(writtenFlags),
        .writtenLayerID(writtenLayerID),
        .writtenParamType(writtenParamType),
        .writtenBitWidth(writtenBitWidth),
        .writtenElemCount(writtenElemCount),
        .writtenBatchID(writtenBatchID),
        .writtenBatchSize(writtenBatchSize),
        .writtenVectorLEN(writtenVectorLEN),
        .writtenPayloadBytes(writtenPayloadBytes),
        .writtenWordCount(writtenWordCount),

        .nextFreeAddr(nextFreeAddr),

        .imageValid(imageValid),
        .imageStartAddr(imageStartAddr),
        .imageLastAddr(imageLastAddr),
        .imageNextAddr(imageNextAddr),
        .imagePayloadBytes(imagePayloadBytes),
        .imageWordCount(imageWordCount),
        .imageBatchID(imageBatchID),
        .imageBatchSize(imageBatchSize),
        .imageVectorLEN(imageVectorLEN),
        .imageFlags(imageFlags),

        .fc1WeightValid(fc1WeightValid),
        .fc1WeightStartAddr(fc1WeightStartAddr),
        .fc1WeightLastAddr(fc1WeightLastAddr),
        .fc1WeightNextAddr(fc1WeightNextAddr),
        .fc1WeightBitWidth(fc1WeightBitWidth),
        .fc1WeightElemCount(fc1WeightElemCount),
        .fc1WeightPayloadBytes(fc1WeightPayloadBytes),
        .fc1WeightWordCount(fc1WeightWordCount),

        .fc1BiasValid(fc1BiasValid),
        .fc1BiasStartAddr(fc1BiasStartAddr),
        .fc1BiasLastAddr(fc1BiasLastAddr),
        .fc1BiasNextAddr(fc1BiasNextAddr),
        .fc1BiasBitWidth(fc1BiasBitWidth),
        .fc1BiasElemCount(fc1BiasElemCount),
        .fc1BiasPayloadBytes(fc1BiasPayloadBytes),
        .fc1BiasWordCount(fc1BiasWordCount),

        .fc2WeightValid(fc2WeightValid),
        .fc2WeightStartAddr(fc2WeightStartAddr),
        .fc2WeightLastAddr(fc2WeightLastAddr),
        .fc2WeightNextAddr(fc2WeightNextAddr),
        .fc2WeightBitWidth(fc2WeightBitWidth),
        .fc2WeightElemCount(fc2WeightElemCount),
        .fc2WeightPayloadBytes(fc2WeightPayloadBytes),
        .fc2WeightWordCount(fc2WeightWordCount),

        .fc2BiasValid(fc2BiasValid),
        .fc2BiasStartAddr(fc2BiasStartAddr),
        .fc2BiasLastAddr(fc2BiasLastAddr),
        .fc2BiasNextAddr(fc2BiasNextAddr),
        .fc2BiasBitWidth(fc2BiasBitWidth),
        .fc2BiasElemCount(fc2BiasElemCount),
        .fc2BiasPayloadBytes(fc2BiasPayloadBytes),
        .fc2BiasWordCount(fc2BiasWordCount),

        .addressBookError(addressBookError),
        .unknownPacketError(unknownPacketError),
        .writerReportedError(writerReportedError)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, tb_ddrAddressBook);
    end

    task fail;
        input [1023:0] msg;
        begin
            $display("FAIL: %0s", msg);
            errorCount = errorCount + 1;
            $finish;
        end
    endtask

    task expect_addr;
        input [1023:0] name;
        input [ADDR_WIDTH-1:0] actual;
        input [ADDR_WIDTH-1:0] expected;
        begin
            if (actual !== expected) begin
                $display("ADDR MISMATCH: %0s", name);
                $display("  expected = %h", expected);
                $display("  actual   = %h", actual);
                fail("address mismatch");
            end
            else begin
                $display("ADDR OK: %0s = %h", name, actual);
            end
        end
    endtask

    task expect_bit;
        input [1023:0] name;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $display("BIT MISMATCH: %0s expected=%b actual=%b",
                         name, expected, actual);
                fail("bit mismatch");
            end
            else begin
                $display("BIT OK: %0s = %b", name, actual);
            end
        end
    endtask

    task clear_inputs;
        begin
            clear = 1'b0;

            writeDone = 1'b0;
            writerError = 1'b0;

            packetStartAddr = {ADDR_WIDTH{1'b0}};
            packetLastAddr = {ADDR_WIDTH{1'b0}};
            packetNextAddr = {ADDR_WIDTH{1'b0}};
            packetLastAddrValid = 1'b0;

            writtenPacketType = 8'd0;
            writtenFlags = 8'd0;
            writtenLayerID = 8'd0;
            writtenParamType = 8'd0;
            writtenBitWidth = 16'd0;
            writtenElemCount = 32'd0;
            writtenBatchID = 32'd0;
            writtenBatchSize = 16'd0;
            writtenVectorLEN = 16'd0;
            writtenPayloadBytes = 32'd0;
            writtenWordCount = 32'd0;
        end
    endtask

    task send_write_done;
        input [7:0] packet_type;
        input [7:0] layer_id;
        input [7:0] param_type;
        input [ADDR_WIDTH-1:0] start_addr;
        input [ADDR_WIDTH-1:0] last_addr;
        input [ADDR_WIDTH-1:0] next_addr;
        input [15:0] bit_width;
        input [31:0] elem_count;
        input [31:0] payload_bytes;
        input [31:0] word_count;
        begin
            @(negedge clk);

            writtenPacketType = packet_type;
            writtenLayerID = layer_id;
            writtenParamType = param_type;
            writtenBitWidth = bit_width;
            writtenElemCount = elem_count;
            writtenPayloadBytes = payload_bytes;
            writtenWordCount = word_count;

            writtenFlags = 8'h00;
            writtenBatchID = 32'd0;
            writtenBatchSize = 16'd0;
            writtenVectorLEN = 16'd0;

            packetStartAddr = start_addr;
            packetLastAddr = last_addr;
            packetNextAddr = next_addr;
            packetLastAddrValid = 1'b1;

            writerError = 1'b0;
            writeDone = 1'b1;

            @(negedge clk);
            writeDone = 1'b0;
        end
    endtask

    task send_image_write_done;
        input [ADDR_WIDTH-1:0] start_addr;
        input [ADDR_WIDTH-1:0] last_addr;
        input [ADDR_WIDTH-1:0] next_addr;
        input [31:0] batch_id;
        input [15:0] batch_size;
        input [15:0] vector_len;
        input [31:0] payload_bytes;
        input [31:0] word_count;
        begin
            @(negedge clk);

            writtenPacketType = PACKET_TYPE_IMAGE;
            writtenFlags = 8'h00;
            writtenLayerID = 8'd0;
            writtenParamType = 8'd0;
            writtenBitWidth = 16'd8;
            writtenElemCount = 32'd0;
            writtenBatchID = batch_id;
            writtenBatchSize = batch_size;
            writtenVectorLEN = vector_len;
            writtenPayloadBytes = payload_bytes;
            writtenWordCount = word_count;

            packetStartAddr = start_addr;
            packetLastAddr = last_addr;
            packetNextAddr = next_addr;
            packetLastAddrValid = 1'b1;

            writerError = 1'b0;
            writeDone = 1'b1;

            @(negedge clk);
            writeDone = 1'b0;
        end
    endtask

    initial begin
        errorCount = 0;
        clear_inputs();

        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (3) @(posedge clk);
        #1;

        $display("");
        $display("CHECK reset state");
        expect_addr("nextFreeAddr", nextFreeAddr, RESET_BASE_ADDR);
        expect_bit("imageValid", imageValid, 1'b0);
        expect_bit("fc1WeightValid", fc1WeightValid, 1'b0);
        expect_bit("fc1BiasValid", fc1BiasValid, 1'b0);
        expect_bit("fc2WeightValid", fc2WeightValid, 1'b0);
        expect_bit("fc2BiasValid", fc2BiasValid, 1'b0);

        $display("");
        $display("TEST 1: FC1 weight");
        send_write_done(
            PACKET_TYPE_PARAM,
            8'd1,
            PARAM_TYPE_WEIGHT,
            27'h0001000,
            27'h0001000,
            27'h0001008,
            16'd8,
            32'd1024,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("fc1WeightValid", fc1WeightValid, 1'b1);
        expect_addr("fc1WeightStartAddr", fc1WeightStartAddr, 27'h0001000);
        expect_addr("fc1WeightLastAddr", fc1WeightLastAddr, 27'h0001000);
        expect_addr("nextFreeAddr", nextFreeAddr, 27'h0001008);

        $display("");
        $display("TEST 2: FC1 bias");
        send_write_done(
            PACKET_TYPE_PARAM,
            8'd1,
            PARAM_TYPE_BIAS,
            27'h0001008,
            27'h0001008,
            27'h0001010,
            16'd32,
            32'd64,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("fc1BiasValid", fc1BiasValid, 1'b1);
        expect_addr("fc1BiasStartAddr", fc1BiasStartAddr, 27'h0001008);
        expect_addr("fc1BiasLastAddr", fc1BiasLastAddr, 27'h0001008);
        expect_addr("nextFreeAddr", nextFreeAddr, 27'h0001010);

        $display("");
        $display("TEST 3: FC2 weight");
        send_write_done(
            PACKET_TYPE_PARAM,
            8'd2,
            PARAM_TYPE_WEIGHT,
            27'h0001010,
            27'h0001010,
            27'h0001018,
            16'd8,
            32'd640,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("fc2WeightValid", fc2WeightValid, 1'b1);
        expect_addr("fc2WeightStartAddr", fc2WeightStartAddr, 27'h0001010);
        expect_addr("fc2WeightLastAddr", fc2WeightLastAddr, 27'h0001010);
        expect_addr("nextFreeAddr", nextFreeAddr, 27'h0001018);

        $display("");
        $display("TEST 4: FC2 bias");
        send_write_done(
            PACKET_TYPE_PARAM,
            8'd2,
            PARAM_TYPE_BIAS,
            27'h0001018,
            27'h0001018,
            27'h0001020,
            16'd32,
            32'd10,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("fc2BiasValid", fc2BiasValid, 1'b1);
        expect_addr("fc2BiasStartAddr", fc2BiasStartAddr, 27'h0001018);
        expect_addr("fc2BiasLastAddr", fc2BiasLastAddr, 27'h0001018);
        expect_addr("nextFreeAddr", nextFreeAddr, 27'h0001020);

        $display("");
        $display("TEST 5: IMAGE");
        send_image_write_done(
            27'h0001020,
            27'h0001020,
            27'h0001028,
            32'd7,
            16'd1,
            16'd16,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("imageValid", imageValid, 1'b1);
        expect_addr("imageStartAddr", imageStartAddr, 27'h0001020);
        expect_addr("imageLastAddr", imageLastAddr, 27'h0001020);
        expect_addr("nextFreeAddr", nextFreeAddr, 27'h0001028);

        if (addressBookError) begin
            fail("addressBookError should be 0 before unknown packet test");
        end

        $display("");
        $display("TEST 6: Unknown PARAM should raise addressBookError");
        send_write_done(
            PACKET_TYPE_PARAM,
            8'd3,
            PARAM_TYPE_WEIGHT,
            27'h0002000,
            27'h0002000,
            27'h0002008,
            16'd8,
            32'd1,
            32'd16,
            32'd1
        );
        #1;
        expect_bit("addressBookError", addressBookError, 1'b1);
        expect_bit("unknownPacketError", unknownPacketError, 1'b1);
        expect_addr("known fc1WeightStartAddr unchanged",
                    fc1WeightStartAddr, 27'h0001000);

        @(negedge clk);
        clear = 1'b1;
        @(negedge clk);
        clear = 1'b0;
        #1;

        expect_bit("addressBookError after clear", addressBookError, 1'b0);
        expect_bit("unknownPacketError after clear", unknownPacketError, 1'b0);

        repeat (5) @(posedge clk);

        $display("");
        $display("====================================================");
        $display("PASS: tb_ddrAddressBook completed successfully");
        $display("====================================================");

        $finish;
    end

endmodule