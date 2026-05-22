`timescale 1ns/1ps

module mlpBatchDDR #(
    parameter integer ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter integer FC1_IN      = 784,
    parameter integer FC1_OUT     = 64,
    parameter integer FC1_TILE    = 8,

    parameter integer FC2_IN      = 64,
    parameter integer FC2_OUT     = 10,
    parameter integer FC2_TILE    = 2,

    parameter integer IN_WIDTH    = 8,
    parameter integer W_WIDTH     = 8,
    parameter integer B_WIDTH     = 32,
    parameter integer ACC_WIDTH   = 32,

    parameter integer FC1_REQUANT_SHIFT = 10
)(
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    input  wire [15:0]                  batchSize,

    // DDR address map
    input  wire [ADDR_WIDTH-1:0]         imageBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         fc1WeightBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         fc1BiasBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         fc1ActBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         fc2WeightBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         fc2BiasBaseAddr,

    // Shared DDR interface to mig_ui128
    output reg  [ADDR_WIDTH-1:0]         ddrAddr,
    output reg  [127:0]                  ddrWriteData,
    input  wire [127:0]                  ddrReadData,
    output reg                          ddrRstrobe,
    output reg                          ddrWstrobe,
    input  wire                         ddrReady,
    input  wire                         ddrTransactionComplete,

    output reg                          busy,
    output reg                          done,

    // Prediction stream
    output reg                          predValid,
    output reg  [15:0]                  predBatchIndex,
    output reg  [($clog2(FC2_OUT)-1):0] predIndex,

    output reg                          error
);

    localparam integer DDR_BYTES = 16;

    localparam integer IMAGE_BYTES       = FC1_IN * (IN_WIDTH / 8);
    localparam integer IMAGE_WORDS       = (IMAGE_BYTES + DDR_BYTES - 1) / DDR_BYTES;
    localparam integer IMAGE_ADDR_STRIDE = IMAGE_WORDS * ADDR_STRIDE;

    localparam integer FC1_ACT_BYTES       = FC1_OUT * 1;
    localparam integer FC1_ACT_WORDS       = (FC1_ACT_BYTES + DDR_BYTES - 1) / DDR_BYTES;
    localparam integer FC1_ACT_ADDR_STRIDE = FC1_ACT_WORDS * ADDR_STRIDE;

    localparam [3:0] S_IDLE          = 4'd0;
    localparam [3:0] S_FC1_START     = 4'd1;
    localparam [3:0] S_FC1_RUN       = 4'd2;
    localparam [3:0] S_ACT_WR_START  = 4'd3;
    localparam [3:0] S_ACT_WR_RUN    = 4'd4;
    localparam [3:0] S_FC2_START     = 4'd5;
    localparam [3:0] S_FC2_RUN       = 4'd6;
    localparam [3:0] S_DONE          = 4'd7;
    localparam [3:0] S_ERROR         = 4'd8;

    reg [3:0] state;

    reg [15:0] fc1BatchIdx;
    reg [15:0] fc2BatchIdx;

    reg fc1Start;
    reg fc2Start;
    reg actWrStart;

    reg [ADDR_WIDTH-1:0] fc1ImageAddr;
    reg [ADDR_WIDTH-1:0] fc2InputAddr;
    reg [ADDR_WIDTH-1:0] actWriteAddr;

    wire fc1Busy;
    wire fc1Done;
    wire fc1ConfigError;
    wire fc1DdrReadError;

    wire fc2Busy;
    wire fc2Done;
    wire fc2ConfigError;
    wire fc2DdrReadError;

    wire [(FC1_OUT*ACC_WIDTH-1):0] fc1OutFlat;
    wire [(FC1_OUT*ACC_WIDTH-1):0] fc1ReluFlat;
    wire [(FC1_OUT*IN_WIDTH-1):0]  fc1ActFlat;

    wire [(FC2_OUT*ACC_WIDTH-1):0] fc2OutFlat;
    wire [($clog2(FC2_OUT)-1):0]   fc2ArgmaxIndex;

    wire [ADDR_WIDTH-1:0] fc1DdrAddr;
    wire                  fc1DdrRstrobe;

    wire [ADDR_WIDTH-1:0] fc2DdrAddr;
    wire                  fc2DdrRstrobe;

    wire [ADDR_WIDTH-1:0] actWrDdrAddr;
    wire [127:0]          actWrDdrData;
    wire                  actWrDdrWstrobe;
    wire                  actWrDone;
    wire                  actWrConfigError;

    wire fc1DdrReady;
    wire fc1DdrComplete;
    wire fc2DdrReady;
    wire fc2DdrComplete;
    wire actWrDdrReady;
    wire actWrDdrComplete;

    assign fc1DdrReady     = (state == S_FC1_RUN)    ? ddrReady               : 1'b0;
    assign fc1DdrComplete  = (state == S_FC1_RUN)    ? ddrTransactionComplete : 1'b0;

    assign actWrDdrReady    = (state == S_ACT_WR_RUN) ? ddrReady               : 1'b0;
    assign actWrDdrComplete = (state == S_ACT_WR_RUN) ? ddrTransactionComplete : 1'b0;

    assign fc2DdrReady     = (state == S_FC2_RUN)    ? ddrReady               : 1'b0;
    assign fc2DdrComplete  = (state == S_FC2_RUN)    ? ddrTransactionComplete : 1'b0;

    // ------------------------------------------------------------
    // FC1
    // ------------------------------------------------------------
    fcLayerDDR #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),

        .tile(FC1_TILE),
        .inNum(FC1_IN),
        .outNum(FC1_OUT),

        .inWidth(IN_WIDTH),
        .wWidth(W_WIDTH),
        .bWidth(B_WIDTH),
        .accWidth(ACC_WIDTH),
        .inSigned(0)
    ) FC1 (
        .clk(clk),
        .rst(rst),
        .start(fc1Start),

        .imageBaseAddr(fc1ImageAddr),
        .weightBaseAddr(fc1WeightBaseAddr),
        .biasBaseAddr(fc1BiasBaseAddr),

        .ddrAddr(fc1DdrAddr),
        .ddrRstrobe(fc1DdrRstrobe),
        .ddrData(ddrReadData),
        .ddrReady(fc1DdrReady),
        .ddrTransactionComplete(fc1DdrComplete),

        .busy(fc1Busy),
        .done(fc1Done),
        .outFlat(fc1OutFlat),

        .imageLastAddr(),
        .weightLastAddr(),
        .biasLastAddr(),
        .lastReadAddr(),

        .configError(fc1ConfigError),
        .ddrReadError(fc1DdrReadError)
    );

    // ------------------------------------------------------------
    // ReLU + unsigned requantization for fc1 activation
    // ------------------------------------------------------------
    relu #(
        .number(FC1_OUT),
        .width(ACC_WIDTH)
    ) RELU1 (
        .inFlat(fc1OutFlat),
        .outFlat(fc1ReluFlat)
    );

    requantUsign #(
        .number(FC1_OUT),
        .inWidth(ACC_WIDTH),
        .outWidth(IN_WIDTH),
        .shift(FC1_REQUANT_SHIFT)
    ) REQUANT1 (
        .inFlat(fc1ReluFlat),
        .outFlat(fc1ActFlat)
    );

    // ------------------------------------------------------------
    // Write fc1 activation vector back to DDR
    // ------------------------------------------------------------
    flatVectorWriterDDR128 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),
        .NUMBER(FC1_OUT),
        .ELEM_WIDTH(IN_WIDTH)
    ) FC1_ACT_WRITER (
        .clk(clk),
        .rst(rst),

        .start(actWrStart),
        .baseAddr(actWriteAddr),
        .inFlat(fc1ActFlat),

        .ddrAddr(actWrDdrAddr),
        .ddrData(actWrDdrData),
        .ddrWstrobe(actWrDdrWstrobe),
        .ddrReady(actWrDdrReady),
        .ddrTransactionComplete(actWrDdrComplete),

        .busy(),
        .done(actWrDone),

        .lastAddr(),
        .nextAddr(),
        .addrValid(),

        .configError(actWrConfigError)
    );

    // ------------------------------------------------------------
    // FC2
    // ------------------------------------------------------------
    fcLayerDDR #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),

        .tile(FC2_TILE),
        .inNum(FC2_IN),
        .outNum(FC2_OUT),

        .inWidth(IN_WIDTH),
        .wWidth(W_WIDTH),
        .bWidth(B_WIDTH),
        .accWidth(ACC_WIDTH),
        .inSigned(0)
    ) FC2 (
        .clk(clk),
        .rst(rst),
        .start(fc2Start),

        .imageBaseAddr(fc2InputAddr),
        .weightBaseAddr(fc2WeightBaseAddr),
        .biasBaseAddr(fc2BiasBaseAddr),

        .ddrAddr(fc2DdrAddr),
        .ddrRstrobe(fc2DdrRstrobe),
        .ddrData(ddrReadData),
        .ddrReady(fc2DdrReady),
        .ddrTransactionComplete(fc2DdrComplete),

        .busy(fc2Busy),
        .done(fc2Done),
        .outFlat(fc2OutFlat),

        .imageLastAddr(),
        .weightLastAddr(),
        .biasLastAddr(),
        .lastReadAddr(),

        .configError(fc2ConfigError),
        .ddrReadError(fc2DdrReadError)
    );

    argmax #(
        .width(ACC_WIDTH),
        .number(FC2_OUT)
    ) ARGMAX0 (
        .inFlat(fc2OutFlat),
        .outIndex(fc2ArgmaxIndex)
    );

    // ------------------------------------------------------------
    // DDR mux
    // Only one block may access DDR at a time.
    // ------------------------------------------------------------
    always @(*) begin
        ddrAddr      = {ADDR_WIDTH{1'b0}};
        ddrRstrobe   = 1'b0;
        ddrWstrobe   = 1'b0;
        ddrWriteData = 128'd0;

        case (state)
            S_FC1_RUN: begin
                ddrAddr    = fc1DdrAddr;
                ddrRstrobe = fc1DdrRstrobe;
            end

            S_ACT_WR_RUN: begin
                ddrAddr      = actWrDdrAddr;
                ddrWriteData = actWrDdrData;
                ddrWstrobe   = actWrDdrWstrobe;
            end

            S_FC2_RUN: begin
                ddrAddr    = fc2DdrAddr;
                ddrRstrobe = fc2DdrRstrobe;
            end

            default: begin
                ddrAddr      = {ADDR_WIDTH{1'b0}};
                ddrRstrobe   = 1'b0;
                ddrWstrobe   = 1'b0;
                ddrWriteData = 128'd0;
            end
        endcase
    end

    // ------------------------------------------------------------
    // Main batch controller
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= S_IDLE;

            busy           <= 1'b0;
            done           <= 1'b0;
            error          <= 1'b0;

            fc1BatchIdx    <= 16'd0;
            fc2BatchIdx    <= 16'd0;

            fc1Start       <= 1'b0;
            fc2Start       <= 1'b0;
            actWrStart     <= 1'b0;

            fc1ImageAddr   <= {ADDR_WIDTH{1'b0}};
            fc2InputAddr   <= {ADDR_WIDTH{1'b0}};
            actWriteAddr   <= {ADDR_WIDTH{1'b0}};

            predValid      <= 1'b0;
            predBatchIndex <= 16'd0;
            predIndex      <= {($clog2(FC2_OUT)){1'b0}};
        end
        else begin
            done       <= 1'b0;
            predValid  <= 1'b0;

            fc1Start   <= 1'b0;
            fc2Start   <= 1'b0;
            actWrStart <= 1'b0;

            case (state)

                S_IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;

                    if (start) begin
                        busy        <= 1'b1;
                        fc1BatchIdx <= 16'd0;
                        fc2BatchIdx <= 16'd0;
                        state       <= S_FC1_START;
                    end
                end

                // ------------------------------------------------
                // Run fc1 for each image in the batch.
                // ------------------------------------------------
                S_FC1_START: begin
                    fc1ImageAddr <= imageBaseAddr + fc1BatchIdx * IMAGE_ADDR_STRIDE;
                    fc1Start     <= 1'b1;
                    state        <= S_FC1_RUN;
                end

                S_FC1_RUN: begin
                    if (fc1ConfigError || fc1DdrReadError) begin
                        error <= 1'b1;
                        state <= S_ERROR;
                    end
                    else if (fc1Done) begin
                        state <= S_ACT_WR_START;
                    end
                end

                // ------------------------------------------------
                // Write requantized fc1 activation to DDR.
                // ------------------------------------------------
                S_ACT_WR_START: begin
                    actWriteAddr <= fc1ActBaseAddr + fc1BatchIdx * FC1_ACT_ADDR_STRIDE;
                    actWrStart   <= 1'b1;
                    state        <= S_ACT_WR_RUN;
                end

                S_ACT_WR_RUN: begin
                    if (actWrConfigError) begin
                        error <= 1'b1;
                        state <= S_ERROR;
                    end
                    else if (actWrDone) begin
                        if (fc1BatchIdx == (batchSize - 1)) begin
                            fc2BatchIdx <= 16'd0;
                            state       <= S_FC2_START;
                        end
                        else begin
                            fc1BatchIdx <= fc1BatchIdx + 16'd1;
                            state       <= S_FC1_START;
                        end
                    end
                end

                // ------------------------------------------------
                // Run fc2 for each stored fc1 activation.
                // ------------------------------------------------
                S_FC2_START: begin
                    fc2InputAddr <= fc1ActBaseAddr + fc2BatchIdx * FC1_ACT_ADDR_STRIDE;
                    fc2Start     <= 1'b1;
                    state        <= S_FC2_RUN;
                end

                S_FC2_RUN: begin
                    if (fc2ConfigError || fc2DdrReadError) begin
                        error <= 1'b1;
                        state <= S_ERROR;
                    end
                    else if (fc2Done) begin
                        predValid      <= 1'b1;
                        predBatchIndex <= fc2BatchIdx;
                        predIndex      <= fc2ArgmaxIndex;

                        if (fc2BatchIdx == (batchSize - 1)) begin
                            state <= S_DONE;
                        end
                        else begin
                            fc2BatchIdx <= fc2BatchIdx + 16'd1;
                            state       <= S_FC2_START;
                        end
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                S_ERROR: begin
                    busy <= 1'b0;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule