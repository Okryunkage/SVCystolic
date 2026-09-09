`timescale 1ns/1ps

module mnistMlpDdrTop #(
    parameter integer ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,

    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01,

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
    input  wire                         boardclk,
    input  wire                         migclk,
    input  wire                         rst,

    // UART receiver output
    input  wire                         rxDone,
    input  wire [7:0]                   rxData,

    // Start inference after image and parameters are loaded
    input  wire                         inferStart,
    input  wire [15:0]                  inferBatchSize,

    // Status
    output wire                         loadBusy,
    output wire                         inferBusy,
    output wire                         topBusy,
    output reg                          topError,

    // Prediction output
    output wire                         predValid,
    output wire [15:0]                  predBatchIndex,
    output wire [($clog2(FC2_OUT)-1):0] predIndex,

    // Address book outputs
    output reg [ADDR_WIDTH-1:0]          image_start_addr,
    output reg [ADDR_WIDTH-1:0]          image_last_addr,

    output reg [ADDR_WIDTH-1:0]          fc1_weight_start_addr,
    output reg [ADDR_WIDTH-1:0]          fc1_weight_last_addr,
    output reg [ADDR_WIDTH-1:0]          fc1_bias_start_addr,
    output reg [ADDR_WIDTH-1:0]          fc1_bias_last_addr,

    output reg [ADDR_WIDTH-1:0]          fc2_weight_start_addr,
    output reg [ADDR_WIDTH-1:0]          fc2_weight_last_addr,
    output reg [ADDR_WIDTH-1:0]          fc2_bias_start_addr,
    output reg [ADDR_WIDTH-1:0]          fc2_bias_last_addr,

    output reg [ADDR_WIDTH-1:0]          fc1_act_start_addr,
    output reg [ADDR_WIDTH-1:0]          fc1_act_last_addr,

    output reg [ADDR_WIDTH-1:0]          next_free_addr,

    // DDR2 physical interface
    inout  wire [15:0]                  ddr2_dq,
    inout  wire [1:0]                   ddr2_dqs_n,
    inout  wire [1:0]                   ddr2_dqs_p,
    output wire [12:0]                  ddr2_addr,
    output wire [2:0]                   ddr2_ba,
    output wire                         ddr2_ras_n,
    output wire                         ddr2_cas_n,
    output wire                         ddr2_we_n,
    output wire [0:0]                   ddr2_ck_p,
    output wire [0:0]                   ddr2_ck_n,
    output wire [0:0]                   ddr2_cke,
    output wire [0:0]                   ddr2_cs_n,
    output wire [1:0]                   ddr2_dm,
    output wire [0:0]                   ddr2_odt);

    wire rst_n;
    assign rst_n = ~rst;

    // ============================================================
    // Address calculation for fc1 activation region
    // ============================================================

    localparam integer DDR_BYTES = 16;

    localparam integer FC1_ACT_BYTES_PER_SAMPLE =
        FC1_OUT * (IN_WIDTH / 8);

    localparam integer FC1_ACT_WORDS_PER_SAMPLE =
        (FC1_ACT_BYTES_PER_SAMPLE + DDR_BYTES - 1) / DDR_BYTES;

    localparam [ADDR_WIDTH-1:0] FC1_ACT_ADDR_STRIDE =
        FC1_ACT_WORDS_PER_SAMPLE * ADDR_STRIDE;

    wire [ADDR_WIDTH-1:0] fc1_act_total_span;
    wire [ADDR_WIDTH-1:0] fc1_act_next_addr_calc;
    wire [ADDR_WIDTH-1:0] fc1_act_last_addr_calc;

    assign fc1_act_total_span =
        inferBatchSize * FC1_ACT_ADDR_STRIDE;

    assign fc1_act_next_addr_calc =
        next_free_addr + fc1_act_total_span;

    assign fc1_act_last_addr_calc =
        next_free_addr + fc1_act_total_span - ADDR_STRIDE;

    // ============================================================
    // UART packet decoder
    // ============================================================

    wire        dec_headerValid;
    wire [7:0]  dec_version;
    wire [7:0]  dec_packetType;
    wire [7:0]  dec_flags;

    wire [31:0] dec_batchID;
    wire [15:0] dec_batchSize;
    wire [15:0] dec_vectorLEN;

    wire [7:0]  dec_layerID;
    wire [7:0]  dec_paramType;
    wire [15:0] dec_bitWidth;
    wire [31:0] dec_elemCount;

    wire [31:0] dec_payloadLEN;

    wire        dec_payloadValid;
    wire [7:0]  dec_payloadData;
    wire [31:0] dec_payloadIndex;

    wire        dec_payloadImage;
    wire        dec_payloadLabel;
    wire        dec_payloadParam;
    wire        dec_payloadWeight;
    wire        dec_payloadBias;

    wire        dec_packetDone;
    wire        dec_packetError;
    wire        dec_checksumError;
    wire        dec_headerError;
    wire        dec_busy;

    wire [7:0]  dec_rxChecksum;
    wire [7:0]  dec_cmChecksum;

    uartPacketDec #(
        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS)
    ) UART_DEC (
        .clk(boardclk),
        .rst(rst),
        .rxDone(rxDone),
        .rxData(rxData),

        .headerValid(dec_headerValid),

        .version(dec_version),
        .packetType(dec_packetType),
        .flags(dec_flags),

        .batchID(dec_batchID),
        .batchSize(dec_batchSize),
        .vectorLEN(dec_vectorLEN),

        .layerID(dec_layerID),
        .paramType(dec_paramType),
        .bitWidth(dec_bitWidth),
        .elemCount(dec_elemCount),

        .payloadLEN(dec_payloadLEN),

        .payloadValid(dec_payloadValid),
        .payloadData(dec_payloadData),
        .payloadIndex(dec_payloadIndex),

        .payloadImage(dec_payloadImage),
        .payloadLabel(dec_payloadLabel),
        .payloadParam(dec_payloadParam),
        .payloadWeight(dec_payloadWeight),
        .payloadBias(dec_payloadBias),

        .packetDone(dec_packetDone),
        .packetError(dec_packetError),
        .checksumError(dec_checksumError),
        .headerError(dec_headerError),

        .rxChecksum(dec_rxChecksum),
        .cmChecksum(dec_cmChecksum),

        .busy(dec_busy)
    );

    // ============================================================
    // DDR packet writer for UART-loaded image/weight/bias packets
    // ============================================================

    wire [ADDR_WIDTH-1:0] loader_ddr_addr;
    wire [127:0]          loader_ddr_data;
    wire                  loader_ddr_wstrobe;

    wire                  loader_writeDone;
    wire [ADDR_WIDTH-1:0] loader_allocPtr;
    wire [ADDR_WIDTH-1:0] loader_packetStartAddr;
    wire [ADDR_WIDTH-1:0] loader_packetLastAddr;
    wire [ADDR_WIDTH-1:0] loader_packetNextAddr;
    wire                  loader_packetLastAddrValid;

    wire [7:0]            loader_writtenPacketType;
    wire [7:0]            loader_writtenFlags;
    wire [7:0]            loader_writtenLayerID;
    wire [7:0]            loader_writtenParamType;
    wire [15:0]           loader_writtenBitWidth;
    wire [31:0]           loader_writtenElemCount;
    wire [31:0]           loader_writtenBatchID;
    wire [15:0]           loader_writtenBatchSize;
    wire [15:0]           loader_writtenVectorLEN;

    wire [31:0]           loader_writtenPayloadBytes;
    wire [31:0]           loader_writtenWordCount;

    wire                  loader_writerError;
    wire                  loader_overflowError;
    wire                  loader_lengthError;
    wire                  loader_unexpectedError;
    wire                  loader_busy;

    reg                   loader_baseAddrLoad;
    reg  [ADDR_WIDTH-1:0] loader_baseAddrValue;

    wire                  loader_ddr_ready;
    wire                  loader_ddr_complete;

    ddrPacketWriter128 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),
        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS)
    ) UART_DDR_WRITER (
        .clk(boardclk),
        .rst(rst),

        .baseAddrLoad(loader_baseAddrLoad),
        .baseAddrValue(loader_baseAddrValue),

        .headerValid(dec_headerValid),
        .packetType(dec_packetType),
        .flags(dec_flags),
        .payloadLEN(dec_payloadLEN),

        .layerID(dec_layerID),
        .paramType(dec_paramType),
        .bitWidth(dec_bitWidth),
        .elemCount(dec_elemCount),

        .batchID(dec_batchID),
        .batchSize(dec_batchSize),
        .vectorLEN(dec_vectorLEN),

        .payloadValid(dec_payloadValid),
        .payloadData(dec_payloadData),
        .payloadIndex(dec_payloadIndex),

        .packetDone(dec_packetDone),
        .packetError(dec_packetError),

        .ddrAddr(loader_ddr_addr),
        .ddrData(loader_ddr_data),
        .ddrWstrobe(loader_ddr_wstrobe),
        .ddrReady(loader_ddr_ready),
        .ddrTransactionComplete(loader_ddr_complete),

        .allocPtr(loader_allocPtr),

        .writeDone(loader_writeDone),
        .packetStartAddr(loader_packetStartAddr),
        .packetLastAddr(loader_packetLastAddr),
        .packetNextAddr(loader_packetNextAddr),
        .packetLastAddrValid(loader_packetLastAddrValid),

        .writtenPacketType(loader_writtenPacketType),
        .writtenFlags(loader_writtenFlags),
        .writtenLayerID(loader_writtenLayerID),
        .writtenParamType(loader_writtenParamType),
        .writtenBitWidth(loader_writtenBitWidth),
        .writtenElemCount(loader_writtenElemCount),
        .writtenBatchID(loader_writtenBatchID),
        .writtenBatchSize(loader_writtenBatchSize),
        .writtenVectorLEN(loader_writtenVectorLEN),

        .writtenPayloadBytes(loader_writtenPayloadBytes),
        .writtenWordCount(loader_writtenWordCount),

        .writerError(loader_writerError),
        .overflowError(loader_overflowError),
        .lengthError(loader_lengthError),
        .unexpectedError(loader_unexpectedError),

        .busy(loader_busy)
    );

    assign loadBusy = dec_busy | loader_busy;

    // ============================================================
    // MLP batch inference block
    // ============================================================

    wire [ADDR_WIDTH-1:0] mlp_ddr_addr;
    wire [127:0]          mlp_ddr_wdata;
    wire                  mlp_ddr_rstrobe;
    wire                  mlp_ddr_wstrobe;

    wire                  mlp_ddr_ready;
    wire                  mlp_ddr_complete;

    reg                   mlp_start;
    wire                  mlp_busy;
    wire                  mlp_done;
    wire                  mlp_error;

    mlpBatchDDR #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STRIDE(ADDR_STRIDE),

        .FC1_IN(FC1_IN),
        .FC1_OUT(FC1_OUT),
        .FC1_TILE(FC1_TILE),

        .FC2_IN(FC2_IN),
        .FC2_OUT(FC2_OUT),
        .FC2_TILE(FC2_TILE),

        .IN_WIDTH(IN_WIDTH),
        .W_WIDTH(W_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),

        .FC1_REQUANT_SHIFT(FC1_REQUANT_SHIFT)
    ) MLP_BATCH (
        .clk(boardclk),
        .rst(rst),

        .start(mlp_start),
        .batchSize(inferBatchSize),

        .imageBaseAddr(image_start_addr),
        .fc1WeightBaseAddr(fc1_weight_start_addr),
        .fc1BiasBaseAddr(fc1_bias_start_addr),
        .fc1ActBaseAddr(fc1_act_start_addr),
        .fc2WeightBaseAddr(fc2_weight_start_addr),
        .fc2BiasBaseAddr(fc2_bias_start_addr),

        .ddrAddr(mlp_ddr_addr),
        .ddrWriteData(mlp_ddr_wdata),
        .ddrReadData(ddr_data_out),
        .ddrRstrobe(mlp_ddr_rstrobe),
        .ddrWstrobe(mlp_ddr_wstrobe),
        .ddrReady(mlp_ddr_ready),
        .ddrTransactionComplete(mlp_ddr_complete),

        .busy(mlp_busy),
        .done(mlp_done),

        .predValid(predValid),
        .predBatchIndex(predBatchIndex),
        .predIndex(predIndex),

        .error(mlp_error)
    );

    assign inferBusy = mlp_busy;
    assign topBusy   = loadBusy | mlp_busy;

    // ============================================================
    // Shared DDR2 UI mux
    // ============================================================

    reg [ADDR_WIDTH-1:0] ddr_mux_addr;
    reg [127:0]          ddr_mux_wdata;
    reg                  ddr_mux_rstrobe;
    reg                  ddr_mux_wstrobe;

    wire [127:0]         ddr_data_out;
    wire                 ddr_transaction_complete;
    wire                 ddr_ready;

    reg                  infer_active;

    always @(*) begin
        ddr_mux_addr    = {ADDR_WIDTH{1'b0}};
        ddr_mux_wdata   = 128'd0;
        ddr_mux_rstrobe = 1'b0;
        ddr_mux_wstrobe = 1'b0;

        if (infer_active) begin
            ddr_mux_addr    = mlp_ddr_addr;
            ddr_mux_wdata   = mlp_ddr_wdata;
            ddr_mux_rstrobe = mlp_ddr_rstrobe;
            ddr_mux_wstrobe = mlp_ddr_wstrobe;
        end
        else begin
            ddr_mux_addr    = loader_ddr_addr;
            ddr_mux_wdata   = loader_ddr_data;
            ddr_mux_rstrobe = 1'b0;
            ddr_mux_wstrobe = loader_ddr_wstrobe;
        end
    end

    assign loader_ddr_ready    = (!infer_active) ? ddr_ready : 1'b0;
    assign loader_ddr_complete = (!infer_active) ? ddr_transaction_complete : 1'b0;

    assign mlp_ddr_ready       = (infer_active) ? ddr_ready : 1'b0;
    assign mlp_ddr_complete    = (infer_active) ? ddr_transaction_complete : 1'b0;

    // Your existing MIG wrapper.
    // It uses boardclk-domain rstrobe/wstrobe and returns transaction_complete.
    mig_ui128 DDR2_UI (
        .migclk(migclk),
        .rst_n(rst_n),

        .boardclk(boardclk),
        .addr(ddr_mux_addr),
        .data_in(ddr_mux_wdata),
        .data_out(ddr_data_out),

        .rstrobe(ddr_mux_rstrobe),
        .wstrobe(ddr_mux_wstrobe),
        .transaction_complete(ddr_transaction_complete),
        .ready(ddr_ready),

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

    // ============================================================
    // Address book + inference launch controller
    // ============================================================

    localparam [1:0] TOP_IDLE      = 2'd0;
    localparam [1:0] TOP_MLP_START = 2'd1;
    localparam [1:0] TOP_MLP_RUN   = 2'd2;

    reg [1:0] topState;

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            topState <= TOP_IDLE;

            image_start_addr      <= {ADDR_WIDTH{1'b0}};
            image_last_addr       <= {ADDR_WIDTH{1'b0}};

            fc1_weight_start_addr <= {ADDR_WIDTH{1'b0}};
            fc1_weight_last_addr  <= {ADDR_WIDTH{1'b0}};
            fc1_bias_start_addr   <= {ADDR_WIDTH{1'b0}};
            fc1_bias_last_addr    <= {ADDR_WIDTH{1'b0}};

            fc2_weight_start_addr <= {ADDR_WIDTH{1'b0}};
            fc2_weight_last_addr  <= {ADDR_WIDTH{1'b0}};
            fc2_bias_start_addr   <= {ADDR_WIDTH{1'b0}};
            fc2_bias_last_addr    <= {ADDR_WIDTH{1'b0}};

            fc1_act_start_addr    <= {ADDR_WIDTH{1'b0}};
            fc1_act_last_addr     <= {ADDR_WIDTH{1'b0}};

            next_free_addr        <= {ADDR_WIDTH{1'b0}};

            infer_active          <= 1'b0;
            mlp_start             <= 1'b0;

            loader_baseAddrLoad   <= 1'b0;
            loader_baseAddrValue  <= {ADDR_WIDTH{1'b0}};

            topError              <= 1'b0;
        end
        else begin
            mlp_start           <= 1'b0;
            loader_baseAddrLoad <= 1'b0;

            if (dec_headerError || dec_checksumError ||
                loader_writerError || loader_overflowError ||
                loader_lengthError || loader_unexpectedError ||
                mlp_error) begin
                topError <= 1'b1;
            end

            // ----------------------------------------------------
            // Address book update after a UART packet is written.
            // ----------------------------------------------------
            if (loader_writeDone) begin
                next_free_addr <= loader_packetNextAddr;

                if (loader_writtenPacketType == PACKET_TYPE_IMAGE) begin
                    image_start_addr <= loader_packetStartAddr;
                    image_last_addr  <= loader_packetLastAddr;
                end
                else if (loader_writtenPacketType == PACKET_TYPE_PARAM) begin
                    if ((loader_writtenLayerID == 8'd1) &&
                        (loader_writtenParamType == PARAM_TYPE_WEIGHT)) begin
                        fc1_weight_start_addr <= loader_packetStartAddr;
                        fc1_weight_last_addr  <= loader_packetLastAddr;
                    end
                    else if ((loader_writtenLayerID == 8'd1) &&
                             (loader_writtenParamType == PARAM_TYPE_BIAS)) begin
                        fc1_bias_start_addr <= loader_packetStartAddr;
                        fc1_bias_last_addr  <= loader_packetLastAddr;
                    end
                    else if ((loader_writtenLayerID == 8'd2) &&
                             (loader_writtenParamType == PARAM_TYPE_WEIGHT)) begin
                        fc2_weight_start_addr <= loader_packetStartAddr;
                        fc2_weight_last_addr  <= loader_packetLastAddr;
                    end
                    else if ((loader_writtenLayerID == 8'd2) &&
                             (loader_writtenParamType == PARAM_TYPE_BIAS)) begin
                        fc2_bias_start_addr <= loader_packetStartAddr;
                        fc2_bias_last_addr  <= loader_packetLastAddr;
                    end
                end
            end

            // ----------------------------------------------------
            // Inference controller
            // ----------------------------------------------------
            case (topState)

                TOP_IDLE: begin
                    infer_active <= 1'b0;

                    if (inferStart && !loadBusy) begin
                        if (inferBatchSize == 16'd0) begin
                            topError <= 1'b1;
                        end
                        else begin
                            // Reserve DDR region for fc1 activation batch.
                            fc1_act_start_addr <= next_free_addr;
                            fc1_act_last_addr  <= fc1_act_last_addr_calc;

                            infer_active <= 1'b1;
                            topState     <= TOP_MLP_START;
                        end
                    end
                end

                TOP_MLP_START: begin
                    // One-cycle start pulse for mlpBatchDDR.
                    mlp_start <= 1'b1;
                    topState  <= TOP_MLP_RUN;
                end

                TOP_MLP_RUN: begin
                    infer_active <= 1'b1;

                    if (mlp_done) begin
                        infer_active <= 1'b0;

                        // After fc1 activations are written, advance global allocator.
                        next_free_addr       <= fc1_act_next_addr_calc;

                        // Also update the UART DDR writer's internal allocator.
                        // This prevents later UART packets from overwriting fc1 activations.
                        loader_baseAddrLoad  <= 1'b1;
                        loader_baseAddrValue <= fc1_act_next_addr_calc;

                        topState <= TOP_IDLE;
                    end
                end

                default: begin
                    topState <= TOP_IDLE;
                end

            endcase
        end
    end

endmodule