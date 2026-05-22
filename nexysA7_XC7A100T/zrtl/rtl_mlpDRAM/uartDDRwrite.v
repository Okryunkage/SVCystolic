`timescale 1ns/1ps

module uartDDRwrite #(
    parameter integer boardclk   = 150_000_000,
    parameter integer oversample = 20,
    parameter integer baudrate   = 1_000_000,
    parameter integer ACCwidth   = 24,

    parameter integer ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,
    parameter [ADDR_WIDTH-1:0] INIT_BASE_ADDR = 27'h0000000,

    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,

    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01
)(
    input  wire        boardCLK,
    input  wire        migclk,
    input  wire        rst,

    input  wire        uartRX,
    output wire        uartTX,

    output wire [15:0] led,

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
	wire migclk;
	mmcm200 clkmmcm(.reset(1'b0),.clk_in1(boardCLK),.locked(locked),.clk_out1(migclk));
    // ============================================================
    // UART
    // ============================================================

    wire       uart_tx_start;
    wire [7:0] uart_tx_item;
    wire       uart_tx_done;
    wire       uart_tx_busy;

    (* MARK_DEBUG = "TRUE" *) wire [7:0] uart_rx_out;
    (* MARK_DEBUG = "TRUE" *) wire       uart_rx_done;
    (* MARK_DEBUG = "TRUE" *) wire       uart_rx_busy;
    (* MARK_DEBUG = "TRUE" *) wire       uart_rx_error;

    assign uart_tx_start = 1'b0;
    assign uart_tx_item  = 8'd0;

    uartTOP #(
        .boardCLK(boardclk),
        .oversample(oversample),
        .baudrate(baudrate),
        .ACCwidth(ACCwidth)
    ) UART0 (
        .clk(boardCLK),
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

    (* MARK_DEBUG = "TRUE" *) wire        dec_headerValid;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_version;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_packetType;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_flags;

    (* MARK_DEBUG = "TRUE" *) wire [31:0] dec_batchID;
    (* MARK_DEBUG = "TRUE" *) wire [15:0] dec_batchSize;
    (* MARK_DEBUG = "TRUE" *) wire [15:0] dec_vectorLEN;

    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_layerID;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_paramType;
    (* MARK_DEBUG = "TRUE" *) wire [15:0] dec_bitWidth;
    (* MARK_DEBUG = "TRUE" *) wire [31:0] dec_elemCount;

    (* MARK_DEBUG = "TRUE" *) wire [31:0] dec_payloadLEN;

    (* MARK_DEBUG = "TRUE" *) wire        dec_payloadValid;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_payloadData;
    (* MARK_DEBUG = "TRUE" *) wire [31:0] dec_payloadIndex;

    wire        dec_payloadImage;
    wire        dec_payloadLabel;
    wire        dec_payloadParam;
    wire        dec_payloadWeight;
    wire        dec_payloadBias;

    (* MARK_DEBUG = "TRUE" *) wire        dec_packetDone;
    (* MARK_DEBUG = "TRUE" *) wire        dec_packetError;
    (* MARK_DEBUG = "TRUE" *) wire        dec_checksumError;
    (* MARK_DEBUG = "TRUE" *) wire        dec_headerError;
    (* MARK_DEBUG = "TRUE" *) wire        dec_busy;

    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_rxChecksum;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]  dec_cmChecksum;

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
    // DDR packet writer
    // ============================================================

    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] loader_ddr_addr;
    (* MARK_DEBUG = "TRUE" *) wire [127:0]          loader_ddr_data;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_ddr_wstrobe;

    (* MARK_DEBUG = "TRUE" *) wire                  loader_writeDone;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] loader_allocPtr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] loader_packetStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] loader_packetLastAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] loader_packetNextAddr;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_packetLastAddrValid;

    (* MARK_DEBUG = "TRUE" *) wire [7:0]            loader_writtenPacketType;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]            loader_writtenFlags;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]            loader_writtenLayerID;
    (* MARK_DEBUG = "TRUE" *) wire [7:0]            loader_writtenParamType;
    (* MARK_DEBUG = "TRUE" *) wire [15:0]           loader_writtenBitWidth;
    (* MARK_DEBUG = "TRUE" *) wire [31:0]           loader_writtenElemCount;
    (* MARK_DEBUG = "TRUE" *) wire [31:0]           loader_writtenBatchID;
    (* MARK_DEBUG = "TRUE" *) wire [15:0]           loader_writtenBatchSize;
    (* MARK_DEBUG = "TRUE" *) wire [15:0]           loader_writtenVectorLEN;

    (* MARK_DEBUG = "TRUE" *) wire [31:0]           loader_writtenPayloadBytes;
    (* MARK_DEBUG = "TRUE" *) wire [31:0]           loader_writtenWordCount;

    (* MARK_DEBUG = "TRUE" *) wire                  loader_writerError;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_overflowError;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_lengthError;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_unexpectedError;
    (* MARK_DEBUG = "TRUE" *) wire                  loader_busy;

    reg                   loader_baseAddrLoad;
    reg  [ADDR_WIDTH-1:0] loader_baseAddrValue;

    (* MARK_DEBUG = "TRUE" *) wire loader_ddr_ready;
    (* MARK_DEBUG = "TRUE" *) wire loader_ddr_complete;

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

    // ============================================================
    // Load initial DDR base address into ddrPacketWriter128
    // ============================================================

    localparam [1:0] INIT_IDLE  = 2'd0;
    localparam [1:0] INIT_PULSE = 2'd1;
    localparam [1:0] INIT_DONE  = 2'd2;

    reg [1:0] initState;

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            initState <= INIT_IDLE;
            loader_baseAddrLoad  <= 1'b0;
            loader_baseAddrValue <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            loader_baseAddrLoad <= 1'b0;

            case (initState)
                INIT_IDLE: begin
                    loader_baseAddrValue <= INIT_BASE_ADDR;
                    initState <= INIT_PULSE;
                end

                INIT_PULSE: begin
                    loader_baseAddrLoad <= 1'b1;
                    loader_baseAddrValue <= INIT_BASE_ADDR;
                    initState <= INIT_DONE;
                end

                INIT_DONE: begin
                    loader_baseAddrLoad <= 1'b0;
                    loader_baseAddrValue <= INIT_BASE_ADDR;
                end

                default: begin
                    initState <= INIT_IDLE;
                end
            endcase
        end
    end

    // ============================================================
    // Address book
    // ============================================================

    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] nextFreeAddr;

    (* MARK_DEBUG = "TRUE" *) wire imageValid;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] imageStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] imageLastAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] imageNextAddr;

    (* MARK_DEBUG = "TRUE" *) wire fc1WeightValid;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc1WeightStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc1WeightLastAddr;

    (* MARK_DEBUG = "TRUE" *) wire fc1BiasValid;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc1BiasStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc1BiasLastAddr;

    (* MARK_DEBUG = "TRUE" *) wire fc2WeightValid;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc2WeightStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc2WeightLastAddr;

    (* MARK_DEBUG = "TRUE" *) wire fc2BiasValid;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc2BiasStartAddr;
    (* MARK_DEBUG = "TRUE" *) wire [ADDR_WIDTH-1:0] fc2BiasLastAddr;

    wire [ADDR_WIDTH-1:0] imageNextAddr_unused;
    wire [31:0] imagePayloadBytes;
    wire [31:0] imageWordCount;
    wire [31:0] imageBatchID;
    wire [15:0] imageBatchSize;
    wire [15:0] imageVectorLEN;
    wire [7:0]  imageFlags;

    wire [ADDR_WIDTH-1:0] fc1WeightNextAddr;
    wire [15:0] fc1WeightBitWidth;
    wire [31:0] fc1WeightElemCount;
    wire [31:0] fc1WeightPayloadBytes;
    wire [31:0] fc1WeightWordCount;

    wire [ADDR_WIDTH-1:0] fc1BiasNextAddr;
    wire [15:0] fc1BiasBitWidth;
    wire [31:0] fc1BiasElemCount;
    wire [31:0] fc1BiasPayloadBytes;
    wire [31:0] fc1BiasWordCount;

    wire [ADDR_WIDTH-1:0] fc2WeightNextAddr;
    wire [15:0] fc2WeightBitWidth;
    wire [31:0] fc2WeightElemCount;
    wire [31:0] fc2WeightPayloadBytes;
    wire [31:0] fc2WeightWordCount;

    wire [ADDR_WIDTH-1:0] fc2BiasNextAddr;
    wire [15:0] fc2BiasBitWidth;
    wire [31:0] fc2BiasElemCount;
    wire [31:0] fc2BiasPayloadBytes;
    wire [31:0] fc2BiasWordCount;

    (* MARK_DEBUG = "TRUE" *) wire addressBookError;
    (* MARK_DEBUG = "TRUE" *) wire unknownPacketError;
    (* MARK_DEBUG = "TRUE" *) wire writerReportedError;

    ddrAddressBook #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .RESET_BASE_ADDR(INIT_BASE_ADDR),
        .PACKET_TYPE_IMAGE(PACKET_TYPE_IMAGE),
        .PACKET_TYPE_PARAM(PACKET_TYPE_PARAM),
        .PARAM_TYPE_WEIGHT(PARAM_TYPE_WEIGHT),
        .PARAM_TYPE_BIAS(PARAM_TYPE_BIAS)
    ) ADDR_BOOK (
        .clk(boardclk),
        .rst(rst),
        .clear(1'b0),

        .writeDone(loader_writeDone),
        .writerError(loader_writerError),

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

    // ============================================================
    // DDR UI
    // ============================================================

    wire [127:0] ddr_data_out_unused;

    mig_ui128 DDR2_UI (
        .migclk(migclk),
        .rst_n(~rst),

        .boardclk(boardclk),
        .addr(loader_ddr_addr),
        .data_in(loader_ddr_data),
        .data_out(ddr_data_out_unused),

        .rstrobe(1'b0),
        .wstrobe(loader_ddr_wstrobe),
        .transaction_complete(loader_ddr_complete),
        .ready(loader_ddr_ready),

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
    // Sticky debug flags for LEDs
    // ============================================================

    reg seen_uart_rx_done;
    reg seen_header;
    reg seen_payload;
    reg seen_packet_done;
    reg seen_ddr_wstrobe;
    reg seen_ddr_complete;
    reg seen_write_done;
    reg seen_image;
    reg seen_fc1_weight;
    reg seen_fc1_bias;
    reg seen_fc2_weight;
    reg seen_fc2_bias;
    reg seen_error;

    always @(posedge boardclk or posedge rst) begin
        if (rst) begin
            seen_uart_rx_done <= 1'b0;
            seen_header       <= 1'b0;
            seen_payload      <= 1'b0;
            seen_packet_done  <= 1'b0;
            seen_ddr_wstrobe  <= 1'b0;
            seen_ddr_complete <= 1'b0;
            seen_write_done   <= 1'b0;
            seen_image        <= 1'b0;
            seen_fc1_weight   <= 1'b0;
            seen_fc1_bias     <= 1'b0;
            seen_fc2_weight   <= 1'b0;
            seen_fc2_bias     <= 1'b0;
            seen_error        <= 1'b0;
        end
        else begin
            if (uart_rx_done)
                seen_uart_rx_done <= 1'b1;

            if (dec_headerValid)
                seen_header <= 1'b1;

            if (dec_payloadValid)
                seen_payload <= 1'b1;

            if (dec_packetDone)
                seen_packet_done <= 1'b1;

            if (loader_ddr_wstrobe)
                seen_ddr_wstrobe <= 1'b1;

            if (loader_ddr_complete)
                seen_ddr_complete <= 1'b1;

            if (loader_writeDone)
                seen_write_done <= 1'b1;

            if (imageValid)
                seen_image <= 1'b1;

            if (fc1WeightValid)
                seen_fc1_weight <= 1'b1;

            if (fc1BiasValid)
                seen_fc1_bias <= 1'b1;

            if (fc2WeightValid)
                seen_fc2_weight <= 1'b1;

            if (fc2BiasValid)
                seen_fc2_bias <= 1'b1;

            if (uart_rx_error ||
                dec_packetError ||
                dec_checksumError ||
                dec_headerError ||
                loader_writerError ||
                loader_overflowError ||
                loader_lengthError ||
                loader_unexpectedError ||
                addressBookError) begin
                seen_error <= 1'b1;
            end
        end
    end

    assign LEDarr[0]  = loader_ddr_ready;
    assign LEDarr[1]  = seen_uart_rx_done;
    assign LEDarr[2]  = seen_header;
    assign LEDarr[3]  = seen_payload;
    assign LEDarr[4]  = seen_packet_done;
    assign LEDarr[5]  = seen_ddr_wstrobe;
    assign LEDarr[6]  = seen_ddr_complete;
    assign LEDarr[7]  = seen_write_done;

    assign LEDarr[8]  = imageValid;
    assign LEDarr[9]  = fc1WeightValid;
    assign LEDarr[10] = fc1BiasValid;
    assign LEDarr[11] = fc2WeightValid;
    assign LEDarr[12] = fc2BiasValid;

    assign LEDarr[13] = loader_busy | dec_busy;
    assign LEDarr[14] = seen_error;
    assign LEDarr[15] = rst;

endmodule