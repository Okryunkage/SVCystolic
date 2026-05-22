`include "mnistMlpDdrTopUART.v"
`timescale 1ns/1ps

// ============================================================================
// Testbench for address book inside mnistMlpDdrTopUART
//
// This TB does not test UART packet parsing or DDR writing.
// Those were already tested in step 3.
//
// This TB directly forces the internal loader_* result wires and checks whether
// the top-level address book registers are updated correctly.
// ============================================================================

module tb_top_addressBook;

    localparam integer ADDR_WIDTH = 27;
    localparam [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8;

    localparam [7:0] PACKET_TYPE_IMAGE = 8'h01;
    localparam [7:0] PACKET_TYPE_PARAM = 8'h02;

    localparam [7:0] PARAM_TYPE_WEIGHT = 8'h00;
    localparam [7:0] PARAM_TYPE_BIAS   = 8'h01;

    reg boardclk;
    reg migclk;
    reg rst;

    reg uartRX;
    wire uartTX;

    reg inferStart;
    reg [15:0] inferBatchSize;

    wire loadBusy;
    wire inferBusy;
    wire topBusy;
    wire topError;

    wire predValid;
    wire [15:0] predBatchIndex;
    wire [3:0]  predIndex;

    wire [15:0] correctCount;
    wire accuracyTxBusy;
    wire accuracyTxDone;

    wire [ADDR_WIDTH-1:0] image_start_addr;
    wire [ADDR_WIDTH-1:0] image_last_addr;

    wire [ADDR_WIDTH-1:0] fc1_weight_start_addr;
    wire [ADDR_WIDTH-1:0] fc1_weight_last_addr;
    wire [ADDR_WIDTH-1:0] fc1_bias_start_addr;
    wire [ADDR_WIDTH-1:0] fc1_bias_last_addr;

    wire [ADDR_WIDTH-1:0] fc2_weight_start_addr;
    wire [ADDR_WIDTH-1:0] fc2_weight_last_addr;
    wire [ADDR_WIDTH-1:0] fc2_bias_start_addr;
    wire [ADDR_WIDTH-1:0] fc2_bias_last_addr;

    wire [ADDR_WIDTH-1:0] fc1_act_start_addr;
    wire [ADDR_WIDTH-1:0] fc1_act_last_addr;

    wire [ADDR_WIDTH-1:0] next_free_addr;

    wire [15:0] ddr2_dq;
    wire [1:0]  ddr2_dqs_n;
    wire [1:0]  ddr2_dqs_p;
    wire [12:0] ddr2_addr;
    wire [2:0]  ddr2_ba;
    wire        ddr2_ras_n;
    wire        ddr2_cas_n;
    wire        ddr2_we_n;
    wire [0:0]  ddr2_ck_p;
    wire [0:0]  ddr2_ck_n;
    wire [0:0]  ddr2_cke;
    wire [0:0]  ddr2_cs_n;
    wire [1:0]  ddr2_dm;
    wire [0:0]  ddr2_odt;

    integer errorCount;

    // ------------------------------------------------------------------------
    // Clocks
    // ------------------------------------------------------------------------
    initial begin
        boardclk = 1'b0;
        forever #5 boardclk = ~boardclk;     // 100 MHz for simulation
    end

    initial begin
        migclk = 1'b0;
        forever #3 migclk = ~migclk;
    end

    // ------------------------------------------------------------------------
    // VCD
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("out.vcd");
        $dumpvars(0, tb_top_addressBook);
    end

    // ------------------------------------------------------------------------
    // DUT
    // Use smaller parameters if you want faster/elaboration-light simulation.
    // Address book logic itself does not depend on FC sizes.
    // ------------------------------------------------------------------------
    mnistMlpDdrTopUART #(
        .boardCLK(100_000_000),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),

        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS),

        .FC1_IN(16),
        .FC1_OUT(8),
        .FC1_TILE(4),

        .FC2_IN(8),
        .FC2_OUT(10),
        .FC2_TILE(2),

        .MAX_BATCH(16)
    ) dut (
        .boardclk(boardclk),
        .migclk(migclk),
        .rst(rst),

        .uartRX(uartRX),
        .uartTX(uartTX),

        .inferStart(inferStart),
        .inferBatchSize(inferBatchSize),

        .loadBusy(loadBusy),
        .inferBusy(inferBusy),
        .topBusy(topBusy),
        .topError(topError),

        .predValid(predValid),
        .predBatchIndex(predBatchIndex),
        .predIndex(predIndex),

        .correctCount(correctCount),
        .accuracyTxBusy(accuracyTxBusy),
        .accuracyTxDone(accuracyTxDone),

        .image_start_addr(image_start_addr),
        .image_last_addr(image_last_addr),

        .fc1_weight_start_addr(fc1_weight_start_addr),
        .fc1_weight_last_addr(fc1_weight_last_addr),
        .fc1_bias_start_addr(fc1_bias_start_addr),
        .fc1_bias_last_addr(fc1_bias_last_addr),

        .fc2_weight_start_addr(fc2_weight_start_addr),
        .fc2_weight_last_addr(fc2_weight_last_addr),
        .fc2_bias_start_addr(fc2_bias_start_addr),
        .fc2_bias_last_addr(fc2_bias_last_addr),

        .fc1_act_start_addr(fc1_act_start_addr),
        .fc1_act_last_addr(fc1_act_last_addr),

        .next_free_addr(next_free_addr),

        .ddr2_dq(ddr2_dq),
        .ddr2_dqs_n(ddr2_dqs_n),
        .ddr2_dqs_p(ddr2_dqs_p),
        .ddr2_addr(ddr2_addr),
        .ddr2_ba(ddr2_ba),
        .ddr2_ras_n(ddr2_ras_n),
        .ddr2_cas_n(ddr2_cas_n),
        .ddr2_we_n(ddr2_we_n),
        .ddr2_ck_p(ddr2_ck_p),
        .ddr2_ck_n(ddr2_ck_n),
        .ddr2_cke(ddr2_cke),
        .ddr2_cs_n(ddr2_cs_n),
        .ddr2_dm(ddr2_dm),
        .ddr2_odt(ddr2_odt)
    );

    // ------------------------------------------------------------------------
    // Utility tasks
    // ------------------------------------------------------------------------
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
                $display("Address mismatch: %0s", name);
                $display("  expected = %h", expected);
                $display("  actual   = %h", actual);
                fail("address check failed");
            end
            else begin
                $display("ADDR OK: %0s = %h", name, actual);
            end
        end
    endtask

    task check_reset_values;
        begin
            $display("");
            $display("CHECK: reset values");

            expect_addr("image_start_addr",      image_start_addr,      27'd0);
            expect_addr("image_last_addr",       image_last_addr,       27'd0);

            expect_addr("fc1_weight_start_addr", fc1_weight_start_addr, 27'd0);
            expect_addr("fc1_weight_last_addr",  fc1_weight_last_addr,  27'd0);
            expect_addr("fc1_bias_start_addr",   fc1_bias_start_addr,   27'd0);
            expect_addr("fc1_bias_last_addr",    fc1_bias_last_addr,    27'd0);

            expect_addr("fc2_weight_start_addr", fc2_weight_start_addr, 27'd0);
            expect_addr("fc2_weight_last_addr",  fc2_weight_last_addr,  27'd0);
            expect_addr("fc2_bias_start_addr",   fc2_bias_start_addr,   27'd0);
            expect_addr("fc2_bias_last_addr",    fc2_bias_last_addr,    27'd0);

            expect_addr("next_free_addr",        next_free_addr,        27'd0);
        end
    endtask

    // ------------------------------------------------------------------------
    // Force one fake packet-write result into the top-level address book.
    //
    // This emulates the output of ddrPacketWriter128:
    //   loader_writeDone
    //   loader_packetStartAddr
    //   loader_packetLastAddr
    //   loader_packetNextAddr
    //   loader_writtenPacketType
    //   loader_writtenLayerID
    //   loader_writtenParamType
    // ------------------------------------------------------------------------
    task force_loader_write_done;
        input [7:0] packet_type;
        input [7:0] layer_id;
        input [7:0] param_type;
        input [ADDR_WIDTH-1:0] start_addr;
        input [ADDR_WIDTH-1:0] last_addr;
        input [ADDR_WIDTH-1:0] next_addr;
        begin
            @(negedge boardclk);

            force dut.loader_writtenPacketType = packet_type;
            force dut.loader_writtenLayerID    = layer_id;
            force dut.loader_writtenParamType  = param_type;

            force dut.loader_packetStartAddr   = start_addr;
            force dut.loader_packetLastAddr    = last_addr;
            force dut.loader_packetNextAddr    = next_addr;
            force dut.loader_packetLastAddrValid = 1'b1;

            force dut.loader_writeDone = 1'b1;

            // The address book samples loader_writeDone at this posedge.
            @(posedge boardclk);
            #1;

            force dut.loader_writeDone = 1'b0;

            @(negedge boardclk);

            release dut.loader_writtenPacketType;
            release dut.loader_writtenLayerID;
            release dut.loader_writtenParamType;

            release dut.loader_packetStartAddr;
            release dut.loader_packetLastAddr;
            release dut.loader_packetNextAddr;
            release dut.loader_packetLastAddrValid;

            release dut.loader_writeDone;

            @(posedge boardclk);
            #1;
        end
    endtask

    // ------------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------------
    initial begin
        errorCount = 0;

        uartRX = 1'b1;
        inferStart = 1'b0;
        inferBatchSize = 16'd0;

        rst = 1'b1;
        repeat (10) @(posedge boardclk);
        rst = 1'b0;
        repeat (5) @(posedge boardclk);
        #1;

        check_reset_values();

        // ------------------------------------------------------------
        // 1. FC1 weight
        // ------------------------------------------------------------
        $display("");
        $display("TEST 1: FC1 weight address update");

        force_loader_write_done(
            PACKET_TYPE_PARAM,
            8'd1,
            PARAM_TYPE_WEIGHT,
            27'h0001000,
            27'h0001000,
            27'h0001008
        );

        expect_addr("fc1_weight_start_addr", fc1_weight_start_addr, 27'h0001000);
        expect_addr("fc1_weight_last_addr",  fc1_weight_last_addr,  27'h0001000);
        expect_addr("next_free_addr",        next_free_addr,        27'h0001008);

        // ------------------------------------------------------------
        // 2. FC1 bias
        // ------------------------------------------------------------
        $display("");
        $display("TEST 2: FC1 bias address update");

        force_loader_write_done(
            PACKET_TYPE_PARAM,
            8'd1,
            PARAM_TYPE_BIAS,
            27'h0001008,
            27'h0001008,
            27'h0001010
        );

        expect_addr("fc1_bias_start_addr", fc1_bias_start_addr, 27'h0001008);
        expect_addr("fc1_bias_last_addr",  fc1_bias_last_addr,  27'h0001008);
        expect_addr("next_free_addr",      next_free_addr,      27'h0001010);

        // ------------------------------------------------------------
        // 3. FC2 weight
        // ------------------------------------------------------------
        $display("");
        $display("TEST 3: FC2 weight address update");

        force_loader_write_done(
            PACKET_TYPE_PARAM,
            8'd2,
            PARAM_TYPE_WEIGHT,
            27'h0001010,
            27'h0001010,
            27'h0001018
        );

        expect_addr("fc2_weight_start_addr", fc2_weight_start_addr, 27'h0001010);
        expect_addr("fc2_weight_last_addr",  fc2_weight_last_addr,  27'h0001010);
        expect_addr("next_free_addr",        next_free_addr,        27'h0001018);

        // ------------------------------------------------------------
        // 4. FC2 bias
        // ------------------------------------------------------------
        $display("");
        $display("TEST 4: FC2 bias address update");

        force_loader_write_done(
            PACKET_TYPE_PARAM,
            8'd2,
            PARAM_TYPE_BIAS,
            27'h0001018,
            27'h0001018,
            27'h0001020
        );

        expect_addr("fc2_bias_start_addr", fc2_bias_start_addr, 27'h0001018);
        expect_addr("fc2_bias_last_addr",  fc2_bias_last_addr,  27'h0001018);
        expect_addr("next_free_addr",      next_free_addr,      27'h0001020);

        // ------------------------------------------------------------
        // 5. IMAGE
        // ------------------------------------------------------------
        $display("");
        $display("TEST 5: IMAGE address update");

        force_loader_write_done(
            PACKET_TYPE_IMAGE,
            8'd0,
            8'd0,
            27'h0001020,
            27'h0001020,
            27'h0001028
        );

        expect_addr("image_start_addr", image_start_addr, 27'h0001020);
        expect_addr("image_last_addr",  image_last_addr,  27'h0001020);
        expect_addr("next_free_addr",   next_free_addr,   27'h0001028);

        // ------------------------------------------------------------
        // 6. Unknown PARAM should not overwrite known address entries.
        // Note: current RTL still updates next_free_addr for any loader_writeDone.
        // ------------------------------------------------------------
        $display("");
        $display("TEST 6: Unknown PARAM does not overwrite known address entries");

        force_loader_write_done(
            PACKET_TYPE_PARAM,
            8'd3,
            PARAM_TYPE_WEIGHT,
            27'h0002000,
            27'h0002000,
            27'h0002008
        );

        expect_addr("fc1_weight_start_addr unchanged", fc1_weight_start_addr, 27'h0001000);
        expect_addr("fc1_bias_start_addr unchanged",   fc1_bias_start_addr,   27'h0001008);
        expect_addr("fc2_weight_start_addr unchanged", fc2_weight_start_addr, 27'h0001010);
        expect_addr("fc2_bias_start_addr unchanged",   fc2_bias_start_addr,   27'h0001018);
        expect_addr("image_start_addr unchanged",      image_start_addr,      27'h0001020);
        expect_addr("next_free_addr updated",          next_free_addr,        27'h0002008);

        repeat (10) @(posedge boardclk);

        if (topError) begin
            fail("topError should not be asserted in address book test");
        end

        if (errorCount == 0) begin
            $display("");
            $display("====================================================");
            $display("PASS: top address book simulation completed");
            $display("====================================================");
        end

        $finish;
    end

endmodule


// ============================================================================
// Mock uartTOP
// ============================================================================

module uartTOP #(
    parameter integer boardCLK   = 100_000_000,
    parameter integer oversample = 20,
    parameter integer baudrate   = 1_000_000,
    parameter integer ACCwidth   = 24
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       uartRX,
    output wire       uartTX,

    input  wire       TXstart,
    input  wire [7:0] TXitem,

    output wire       TXdone,
    output wire       TXbusy,

    output wire [7:0] RXout,
    output wire       RXdone,
    output wire       RXbusy,
    output wire       RXerror
);

    assign uartTX  = 1'b1;

    assign TXdone  = 1'b0;
    assign TXbusy  = 1'b0;

    assign RXout   = 8'd0;
    assign RXdone  = 1'b0;
    assign RXbusy  = 1'b0;
    assign RXerror = 1'b0;

endmodule


// ============================================================================
// Mock uartPacketDec
//
// The uploaded top currently instantiates uartPacketDec, not uartPacketDec_rev.
// If you renamed the top to instantiate uartPacketDec_rev, rename this mock
// module accordingly or provide the same stub under uartPacketDec_rev.
// ============================================================================

module uartPacketDec_rev #(
    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,
    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       rxDone,
    input  wire [7:0] rxData,

    output wire       headerValid,

    output wire [7:0] version,
    output wire [7:0] packetType,
    output wire [7:0] flags,

    output wire [31:0] batchID,
    output wire [15:0] batchSize,
    output wire [15:0] vectorLEN,

    output wire [7:0]  layerID,
    output wire [7:0]  paramType,
    output wire [15:0] bitWidth,
    output wire [31:0] elemCount,

    output wire [31:0] payloadLEN,

    output wire        payloadValid,
    output wire [7:0]  payloadData,
    output wire [31:0] payloadIndex,

    output wire        payloadImage,
    output wire        payloadLabel,
    output wire        payloadParam,
    output wire        payloadWeight,
    output wire        payloadBias,

    output wire        packetDone,
    output wire        packetError,
    output wire        checksumError,
    output wire        headerError,

    output wire [7:0]  rxChecksum,
    output wire [7:0]  cmChecksum,

    output wire        busy
);

    assign headerValid = 1'b0;

    assign version     = 8'd0;
    assign packetType  = 8'd0;
    assign flags       = 8'd0;

    assign batchID     = 32'd0;
    assign batchSize   = 16'd0;
    assign vectorLEN   = 16'd0;

    assign layerID     = 8'd0;
    assign paramType   = 8'd0;
    assign bitWidth    = 16'd0;
    assign elemCount   = 32'd0;

    assign payloadLEN   = 32'd0;

    assign payloadValid = 1'b0;
    assign payloadData  = 8'd0;
    assign payloadIndex = 32'd0;

    assign payloadImage  = 1'b0;
    assign payloadLabel  = 1'b0;
    assign payloadParam  = 1'b0;
    assign payloadWeight = 1'b0;
    assign payloadBias   = 1'b0;

    assign packetDone    = 1'b0;
    assign packetError   = 1'b0;
    assign checksumError = 1'b0;
    assign headerError   = 1'b0;

    assign rxChecksum = 8'd0;
    assign cmChecksum = 8'd0;

    assign busy = 1'b0;

endmodule


// ============================================================================
// Mock ddrPacketWriter128
// ============================================================================

module ddrPacketWriter128 #(
    parameter ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,

    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  baseAddrLoad,
    input  wire [ADDR_WIDTH-1:0] baseAddrValue,

    input  wire                  headerValid,
    input  wire [7:0]            packetType,
    input  wire [7:0]            flags,
    input  wire [31:0]           payloadLEN,

    input  wire [7:0]            layerID,
    input  wire [7:0]            paramType,
    input  wire [15:0]           bitWidth,
    input  wire [31:0]           elemCount,

    input  wire [31:0]           batchID,
    input  wire [15:0]           batchSize,
    input  wire [15:0]           vectorLEN,

    input  wire                  payloadValid,
    input  wire [7:0]            payloadData,
    input  wire [31:0]           payloadIndex,

    input  wire                  packetDone,
    input  wire                  packetError,

    output wire [ADDR_WIDTH-1:0] ddrAddr,
    output wire [127:0]          ddrData,
    output wire                  ddrWstrobe,
    input  wire                  ddrReady,
    input  wire                  ddrTransactionComplete,

    output wire [ADDR_WIDTH-1:0] allocPtr,

    output wire                  writeDone,
    output wire [ADDR_WIDTH-1:0] packetStartAddr,
    output wire [ADDR_WIDTH-1:0] packetLastAddr,
    output wire [ADDR_WIDTH-1:0] packetNextAddr,
    output wire                  packetLastAddrValid,

    output wire [7:0]            writtenPacketType,
    output wire [7:0]            writtenFlags,
    output wire [7:0]            writtenLayerID,
    output wire [7:0]            writtenParamType,
    output wire [15:0]           writtenBitWidth,
    output wire [31:0]           writtenElemCount,
    output wire [31:0]           writtenBatchID,
    output wire [15:0]           writtenBatchSize,
    output wire [15:0]           writtenVectorLEN,

    output wire [31:0]           writtenPayloadBytes,
    output wire [31:0]           writtenWordCount,

    output wire                  writerError,
    output wire                  overflowError,
    output wire                  lengthError,
    output wire                  unexpectedError,

    output wire                  busy
);

    assign ddrAddr    = {ADDR_WIDTH{1'b0}};
    assign ddrData    = 128'd0;
    assign ddrWstrobe = 1'b0;

    assign allocPtr = {ADDR_WIDTH{1'b0}};

    assign writeDone           = 1'b0;
    assign packetStartAddr     = {ADDR_WIDTH{1'b0}};
    assign packetLastAddr      = {ADDR_WIDTH{1'b0}};
    assign packetNextAddr      = {ADDR_WIDTH{1'b0}};
    assign packetLastAddrValid = 1'b0;

    assign writtenPacketType = 8'd0;
    assign writtenFlags      = 8'd0;
    assign writtenLayerID    = 8'd0;
    assign writtenParamType  = 8'd0;
    assign writtenBitWidth   = 16'd0;
    assign writtenElemCount  = 32'd0;
    assign writtenBatchID    = 32'd0;
    assign writtenBatchSize  = 16'd0;
    assign writtenVectorLEN  = 16'd0;

    assign writtenPayloadBytes = 32'd0;
    assign writtenWordCount    = 32'd0;

    assign writerError     = 1'b0;
    assign overflowError   = 1'b0;
    assign lengthError     = 1'b0;
    assign unexpectedError = 1'b0;

    assign busy = 1'b0;

endmodule


// ============================================================================
// Mock mlpBatchDDR
// ============================================================================

module mlpBatchDDR #(
    parameter integer ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter integer FC1_IN    = 784,
    parameter integer FC1_OUT   = 64,
    parameter integer FC1_TILE  = 8,

    parameter integer FC2_IN    = 64,
    parameter integer FC2_OUT   = 10,
    parameter integer FC2_TILE  = 2,

    parameter integer IN_WIDTH  = 8,
    parameter integer W_WIDTH   = 8,
    parameter integer B_WIDTH   = 32,
    parameter integer ACC_WIDTH = 32,

    parameter integer FC1_REQUANT_SHIFT = 10
)(
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    input  wire [15:0]                  batchSize,

    input  wire [ADDR_WIDTH-1:0]        imageBaseAddr,
    input  wire [ADDR_WIDTH-1:0]        fc1WeightBaseAddr,
    input  wire [ADDR_WIDTH-1:0]        fc1BiasBaseAddr,
    input  wire [ADDR_WIDTH-1:0]        fc1ActBaseAddr,
    input  wire [ADDR_WIDTH-1:0]        fc2WeightBaseAddr,
    input  wire [ADDR_WIDTH-1:0]        fc2BiasBaseAddr,

    output wire [ADDR_WIDTH-1:0]        ddrAddr,
    output wire [127:0]                 ddrWriteData,
    input  wire [127:0]                 ddrReadData,
    output wire                         ddrRstrobe,
    output wire                         ddrWstrobe,
    input  wire                         ddrReady,
    input  wire                         ddrTransactionComplete,

    output wire                         busy,
    output wire                         done,

    output wire                         predValid,
    output wire [15:0]                  predBatchIndex,
    output wire [($clog2(FC2_OUT)-1):0] predIndex,

    output wire                         error
);

    assign ddrAddr      = {ADDR_WIDTH{1'b0}};
    assign ddrWriteData = 128'd0;
    assign ddrRstrobe   = 1'b0;
    assign ddrWstrobe   = 1'b0;

    assign busy = 1'b0;
    assign done = 1'b0;

    assign predValid = 1'b0;
    assign predBatchIndex = 16'd0;
    assign predIndex = {($clog2(FC2_OUT)){1'b0}};

    assign error = 1'b0;

endmodule


// ============================================================================
// Mock mig_ui128
// ============================================================================

module mig_ui128 (
    input  wire        migclk,
    input  wire        rst_n,

    input  wire        boardclk,
    input  wire [26:0] addr,
    input  wire [127:0] data_in,
    output wire [127:0] data_out,

    input  wire        rstrobe,
    input  wire        wstrobe,
    output wire        transaction_complete,
    output wire        ready,

    inout  wire [15:0] ddr2_dq,
    inout  wire [1:0]  ddr2_dqs_n,
    inout  wire [1:0]  ddr2_dqs_p,
    output wire [12:0] ddr2_addr,
    output wire [2:0]  ddr2_ba,
    output wire        ddr2_ras_n,
    output wire        ddr2_cas_n,
    output wire        ddr2_we_n,
    output wire [0:0]  ddr2_ck_p,
    output wire [0:0]  ddr2_ck_n,
    output wire [0:0]  ddr2_cke,
    output wire [0:0]  ddr2_cs_n,
    output wire [1:0]  ddr2_dm,
    output wire [0:0]  ddr2_odt
);

    assign data_out = 128'd0;
    assign ready = 1'b1;
    assign transaction_complete = 1'b0;

    assign ddr2_dq    = 16'hzzzz;
    assign ddr2_dqs_n = 2'bzz;
    assign ddr2_dqs_p = 2'bzz;

    assign ddr2_addr  = 13'd0;
    assign ddr2_ba    = 3'd0;
    assign ddr2_ras_n = 1'b1;
    assign ddr2_cas_n = 1'b1;
    assign ddr2_we_n  = 1'b1;
    assign ddr2_ck_p  = 1'b0;
    assign ddr2_ck_n  = 1'b0;
    assign ddr2_cke   = 1'b0;
    assign ddr2_cs_n  = 1'b1;
    assign ddr2_dm    = 2'b11;
    assign ddr2_odt   = 1'b0;

endmodule