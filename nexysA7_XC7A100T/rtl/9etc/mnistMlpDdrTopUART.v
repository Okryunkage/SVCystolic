`timescale 1ns/1ps

module mnistMlpDdrTopUART #(
    parameter integer boardCLK   = 150_000_000,
    parameter integer oversample = 20,
    parameter integer baudrate   = 1_000_000,
    parameter integer ACCwidth   = 24,

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

    parameter integer FC1_REQUANT_SHIFT = 10,

    parameter integer MAX_BATCH = 256
)(
    input  wire                         boardclk,
    input  wire                         migclk,
    input  wire                         rst,

    input  wire                         uartRX,
    output wire                         uartTX,

    input  wire                         inferStart,
    input  wire [15:0]                  inferBatchSize,

    output wire                         loadBusy,
    output wire                         inferBusy,
    output wire                         topBusy,
    output reg                          topError,

    output wire                         predValid,
    output wire [15:0]                  predBatchIndex,
    output wire [($clog2(FC2_OUT)-1):0] predIndex,

    output reg  [15:0]                  correctCount,
    output reg                          accuracyTxBusy,
    output reg                          accuracyTxDone,

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
    output wire [0:0]                   ddr2_odt
);

    // ============================================================
    // UART TOP
    // ============================================================

    wire       uart_tx_start;
    wire [7:0] uart_tx_item;
    wire       uart_tx_done;
    wire       uart_tx_busy;

    wire [7:0] uart_rx_out;
    wire       uart_rx_done;
    wire       uart_rx_busy;
    wire       uart_rx_error;

    uartTOP #(
        .boardCLK(boardCLK),
        .oversample(oversample),
        .baudrate(baudrate),
        .ACCwidth(ACCwidth)
    ) UART0 (
        .clk(boardclk),
        .rst(rst),

        .uartRX(uartRX),
        .uartTX(uartTX),

        .TXstart(uart_tx_start),
        .TXitem(uart_tx_item),

        .TXdone(uart_tx_done),
        .TXbusy(uart_tx_busy),

        .RXout(uart_rx_out),
        .RXdone(uart_rx_done),
        .RXbusy(uart_rx_busy),
        .RXerror(uart_rx_error)
    );

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

    uartPacketDec_rev #(
        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS)
    ) UART_DEC (
        .clk(boardclk),
        .rst(rst),

        .rxDone(uart_rx_done),
        .rxData(uart_rx_out),

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
    // Label capture from UART image packet
    // Labels are stored after image bytes in image packet payload.
    // ============================================================

    reg [7:0]  labelMem [0:MAX_BATCH-1];
    reg [15:0] labelCount;
    reg        labelOverflow;

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            labelCount    <= 16'd0;
            labelOverflow <= 1'b0;
        end
        else begin
            if (dec_headerValid && (dec_packetType == PACKET_TYPE_IMAGE)) begin
                labelCount    <= 16'd0;
                labelOverflow <= 1'b0;
            end

            if (dec_payloadValid && dec_payloadLabel) begin
                if (labelCount < MAX_BATCH[15:0]) begin
                    labelMem[labelCount] <= dec_payloadData;
                    labelCount <= labelCount + 16'd1;
                end
                else begin
                    labelOverflow <= 1'b1;
                end
            end
        end
    end

    // ============================================================
    // UART packet writer to DDR
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
    assign topBusy   = loadBusy | mlp_busy | accuracyTxBusy;

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

    mig_ui128 DDR2_UI (
        .migclk(migclk),
        .rst_n(~rst),

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
    // Accuracy counter
    // ============================================================

    wire predCorrect;

    assign predCorrect =
        predValid &&
        (predBatchIndex < MAX_BATCH[15:0]) &&
        ({4'd0, predIndex} == labelMem[predBatchIndex]);

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            correctCount <= 16'd0;
        end
        else begin
            if (inferStart && !loadBusy && !infer_active) begin
                correctCount <= 16'd0;
            end
            else if (predValid) begin
                if (predCorrect)
                    correctCount <= correctCount + 16'd1;
            end
        end
    end

    // ============================================================
    // Accuracy UART TX FSM
    // Packet:
    //   AA 55 81 correct_lo correct_hi total_lo total_hi checksum
    // ============================================================

    localparam [7:0] TX_RESULT_TYPE = 8'h81;

    localparam [3:0] TX_IDLE  = 4'd0;
    localparam [3:0] TX_SEND  = 4'd1;
    localparam [3:0] TX_WAIT  = 4'd2;
    localparam [3:0] TX_DONE  = 4'd3;

    reg [3:0] txState;
    reg [3:0] txIndex;

    reg [15:0] reportCorrect;
    reg [15:0] reportTotal;
    reg [7:0]  reportChecksum;

    reg        tx_start_reg;
    reg [7:0]  tx_item_reg;

    assign uart_tx_start = tx_start_reg;
    assign uart_tx_item  = tx_item_reg;

    function [7:0] txReportByte;
        input [3:0] idx;
        begin
            case (idx)
                4'd0: txReportByte = 8'hAA;
                4'd1: txReportByte = 8'h55;
                4'd2: txReportByte = TX_RESULT_TYPE;
                4'd3: txReportByte = reportCorrect[7:0];
                4'd4: txReportByte = reportCorrect[15:8];
                4'd5: txReportByte = reportTotal[7:0];
                4'd6: txReportByte = reportTotal[15:8];
                4'd7: txReportByte = reportChecksum;
                default: txReportByte = 8'h00;
            endcase
        end
    endfunction

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            txState        <= TX_IDLE;
            txIndex        <= 4'd0;

            reportCorrect  <= 16'd0;
            reportTotal    <= 16'd0;
            reportChecksum <= 8'd0;

            tx_start_reg   <= 1'b0;
            tx_item_reg    <= 8'd0;

            accuracyTxBusy <= 1'b0;
            accuracyTxDone <= 1'b0;
        end
        else begin
            tx_start_reg   <= 1'b0;
            accuracyTxDone <= 1'b0;

            case (txState)

                TX_IDLE: begin
                    accuracyTxBusy <= 1'b0;
                    txIndex        <= 4'd0;

                    if (mlp_done) begin
                        accuracyTxBusy <= 1'b1;

                        reportCorrect <= correctCount;
                        reportTotal   <= inferBatchSize;

                        reportChecksum <=
                            TX_RESULT_TYPE +
                            correctCount[7:0] +
                            correctCount[15:8] +
                            inferBatchSize[7:0] +
                            inferBatchSize[15:8];

                        txState <= TX_SEND;
                    end
                end

                TX_SEND: begin
                    if (!uart_tx_busy) begin
                        tx_item_reg  <= txReportByte(txIndex);
                        tx_start_reg <= 1'b1;
                        txState      <= TX_WAIT;
                    end
                end

                TX_WAIT: begin
                    if (uart_tx_done) begin
                        if (txIndex == 4'd7) begin
                            txState <= TX_DONE;
                        end
                        else begin
                            txIndex <= txIndex + 4'd1;
                            txState <= TX_SEND;
                        end
                    end
                end

                TX_DONE: begin
                    accuracyTxBusy <= 1'b0;
                    accuracyTxDone <= 1'b1;
                    txState        <= TX_IDLE;
                end

                default: begin
                    txState <= TX_IDLE;
                end

            endcase
        end
    end

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

            if (uart_rx_error ||
                dec_headerError || dec_checksumError ||
                loader_writerError || loader_overflowError ||
                loader_lengthError || loader_unexpectedError ||
                labelOverflow ||
                mlp_error) begin
                topError <= 1'b1;
            end

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

            case (topState)

                TOP_IDLE: begin
                    infer_active <= 1'b0;

                    if (inferStart && !loadBusy && !accuracyTxBusy) begin
                        if ((inferBatchSize == 16'd0) ||
                            (inferBatchSize > MAX_BATCH[15:0]) ||
                            (labelCount < inferBatchSize)) begin
                            topError <= 1'b1;
                        end
                        else begin
                            fc1_act_start_addr <= next_free_addr;
                            fc1_act_last_addr  <= fc1_act_last_addr_calc;

                            infer_active <= 1'b1;
                            topState     <= TOP_MLP_START;
                        end
                    end
                end

                TOP_MLP_START: begin
                    mlp_start <= 1'b1;
                    topState  <= TOP_MLP_RUN;
                end

                TOP_MLP_RUN: begin
                    infer_active <= 1'b1;

                    if (mlp_done) begin
                        infer_active <= 1'b0;

                        next_free_addr       <= fc1_act_next_addr_calc;
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