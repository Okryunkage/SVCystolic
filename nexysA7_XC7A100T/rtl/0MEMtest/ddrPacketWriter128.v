`timescale 1ns/1ps

module ddrPacketWriter128 #(
    parameter ADDR_WIDTH = 27,

    // Address step per 128-bit DDR write transaction.
    // Use 8 if your MIG address convention increments by 8 per burst.
    // Use 16 if your address convention is byte-addressed per 128-bit word.
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,

    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01
)(
    input  wire                  clk,
    input  wire                  rst,   // active-high reset

    // Optional allocator control.
    // Use this to set the first DDR write address.
    input  wire                  baseAddrLoad,
    input  wire [ADDR_WIDTH-1:0] baseAddrValue,

    // Header information from uartPacketDec
    input  wire                  headerValid,
    input  wire [7:0]            packetType,
    input  wire [7:0]            flags,
    input  wire [31:0]           payloadLEN,

    // Parameter metadata
    input  wire [7:0]            layerID,
    input  wire [7:0]            paramType,
    input  wire [15:0]           bitWidth,
    input  wire [31:0]           elemCount,

    // Image metadata
    input  wire [31:0]           batchID,
    input  wire [15:0]           batchSize,
    input  wire [15:0]           vectorLEN,

    // Payload byte stream from uartPacketDec
    input  wire                  payloadValid,
    input  wire [7:0]            payloadData,
    input  wire [31:0]           payloadIndex,

    // Packet status from uartPacketDec
    input  wire                  packetDone,
    input  wire                  packetError,

    // Interface to mig_ui128
    output reg  [ADDR_WIDTH-1:0] ddrAddr,
    output reg  [127:0]          ddrData,
    output reg                   ddrWstrobe,
    input  wire                  ddrReady,
    input  wire                  ddrTransactionComplete,

    // Current allocator pointer.
    // This points to the first free DDR address.
    output reg  [ADDR_WIDTH-1:0] allocPtr,

    // Address result for the packet just written
    output reg                   writeDone,
    output reg  [ADDR_WIDTH-1:0] packetStartAddr,
    output reg  [ADDR_WIDTH-1:0] packetLastAddr,
    output reg  [ADDR_WIDTH-1:0] packetNextAddr,
    output reg                   packetLastAddrValid,

    // Packet metadata captured with the address result
    output reg  [7:0]            writtenPacketType,
    output reg  [7:0]            writtenFlags,
    output reg  [7:0]            writtenLayerID,
    output reg  [7:0]            writtenParamType,
    output reg  [15:0]           writtenBitWidth,
    output reg  [31:0]           writtenElemCount,
    output reg  [31:0]           writtenBatchID,
    output reg  [15:0]           writtenBatchSize,
    output reg  [15:0]           writtenVectorLEN,

    // Statistics
    output reg  [31:0]           writtenPayloadBytes,
    output reg  [31:0]           writtenWordCount,

    // Error outputs
    output reg                   writerError,
    output reg                   overflowError,
    output reg                   lengthError,
    output reg                   unexpectedError,

    output wire                  busy
);

    localparam [2:0] S_IDLE      = 3'd0;
    localparam [2:0] S_RX        = 3'd1;
    localparam [2:0] S_FLUSH     = 3'd2;
    localparam [2:0] S_WAIT_LAST = 3'd3;
    localparam [2:0] S_DROP      = 3'd4;

    reg [2:0] state;

    reg [127:0] packData;
    reg [3:0]   packByteCount;

    reg [ADDR_WIDTH-1:0] writeAddr;
    reg                  writeBusy;

    reg [31:0] rxPayloadByteCount;

    wire writeBusyEffective;
    wire [127:0] packDataWithByte;
    wire packWordFull;

    assign busy = (state != S_IDLE);

    // If ddrTransactionComplete is high in this cycle,
    // the previous write is considered completed for scheduling.
    assign writeBusyEffective = writeBusy && !ddrTransactionComplete;

    assign packDataWithByte = set_byte_128(packData, packByteCount, payloadData);
    assign packWordFull = (packByteCount == 4'd15);

    function [127:0] set_byte_128;
        input [127:0] din;
        input [3:0]   byte_index;
        input [7:0]   byte_value;
        reg [127:0] tmp;
        begin
            tmp = din;
            tmp[byte_index*8 +: 8] = byte_value;
            set_byte_128 = tmp;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state               <= S_IDLE;

            ddrAddr             <= {ADDR_WIDTH{1'b0}};
            ddrData             <= 128'd0;
            ddrWstrobe          <= 1'b0;

            allocPtr            <= {ADDR_WIDTH{1'b0}};

            packetStartAddr     <= {ADDR_WIDTH{1'b0}};
            packetLastAddr      <= {ADDR_WIDTH{1'b0}};
            packetNextAddr      <= {ADDR_WIDTH{1'b0}};
            packetLastAddrValid <= 1'b0;

            writeDone           <= 1'b0;

            writtenPacketType   <= 8'd0;
            writtenFlags        <= 8'd0;
            writtenLayerID      <= 8'd0;
            writtenParamType    <= 8'd0;
            writtenBitWidth     <= 16'd0;
            writtenElemCount    <= 32'd0;
            writtenBatchID      <= 32'd0;
            writtenBatchSize    <= 16'd0;
            writtenVectorLEN    <= 16'd0;

            writtenPayloadBytes <= 32'd0;
            writtenWordCount    <= 32'd0;

            writerError         <= 1'b0;
            overflowError       <= 1'b0;
            lengthError         <= 1'b0;
            unexpectedError     <= 1'b0;

            packData            <= 128'd0;
            packByteCount       <= 4'd0;

            writeAddr           <= {ADDR_WIDTH{1'b0}};
            writeBusy           <= 1'b0;

            rxPayloadByteCount  <= 32'd0;
        end
        else begin
            ddrWstrobe    <= 1'b0;
            writeDone     <= 1'b0;

            writerError   <= 1'b0;
            overflowError <= 1'b0;
            lengthError   <= 1'b0;
            unexpectedError <= 1'b0;

            if (baseAddrLoad && (state == S_IDLE)) begin
                allocPtr <= baseAddrValue;
            end

            if (writeBusy && ddrTransactionComplete) begin
                writeBusy <= 1'b0;
            end

            case (state)

                S_IDLE: begin
                    packData           <= 128'd0;
                    packByteCount      <= 4'd0;
                    rxPayloadByteCount <= 32'd0;

                    if (headerValid) begin
                        packetStartAddr     <= allocPtr;
                        packetLastAddr      <= allocPtr;
                        packetNextAddr      <= allocPtr;
                        packetLastAddrValid <= 1'b0;

                        writeAddr           <= allocPtr;

                        writtenPayloadBytes <= payloadLEN;
                        writtenWordCount    <= 32'd0;

                        writtenPacketType   <= packetType;
                        writtenFlags        <= flags;

                        writtenLayerID      <= layerID;
                        writtenParamType    <= paramType;
                        writtenBitWidth     <= bitWidth;
                        writtenElemCount    <= elemCount;

                        writtenBatchID      <= batchID;
                        writtenBatchSize    <= batchSize;
                        writtenVectorLEN    <= vectorLEN;

                        state <= S_RX;
                    end
                end

                S_RX: begin
                    if (payloadValid) begin
                        if (rxPayloadByteCount >= writtenPayloadBytes) begin
                            writerError <= 1'b1;
                            lengthError <= 1'b1;
                            state       <= S_DROP;
                        end
                        else begin
                            rxPayloadByteCount <= rxPayloadByteCount + 32'd1;

                            if (packWordFull) begin
                                if (writeBusyEffective || !ddrReady) begin
                                    writerError   <= 1'b1;
                                    overflowError <= 1'b1;
                                    state         <= S_DROP;
                                end
                                else begin
                                    ddrAddr    <= writeAddr;
                                    ddrData    <= packDataWithByte;
                                    ddrWstrobe <= 1'b1;

                                    writeBusy  <= 1'b1;

                                    packetLastAddr      <= writeAddr;
                                    packetNextAddr      <= writeAddr + ADDR_STRIDE;
                                    packetLastAddrValid <= 1'b1;

                                    writeAddr        <= writeAddr + ADDR_STRIDE;
                                    writtenWordCount <= writtenWordCount + 32'd1;

                                    packData      <= 128'd0;
                                    packByteCount <= 4'd0;
                                end
                            end
                            else begin
                                packData      <= packDataWithByte;
                                packByteCount <= packByteCount + 4'd1;
                            end
                        end
                    end

                    if (packetDone) begin
                        if (packetError) begin
                            writerError <= 1'b1;
                            state       <= S_DROP;
                        end
                        else if (rxPayloadByteCount != writtenPayloadBytes) begin
                            writerError <= 1'b1;
                            lengthError <= 1'b1;
                            state       <= S_DROP;
                        end
                        else if (packByteCount != 4'd0) begin
                            state <= S_FLUSH;
                        end
                        else if (writeBusyEffective) begin
                            state <= S_WAIT_LAST;
                        end
                        else begin
                            allocPtr       <= packetNextAddr;
                            writeDone      <= 1'b1;
                            state          <= S_IDLE;
                        end
                    end
                end

                // Write the final partial 128-bit word.
                // Unused upper bytes are zero-padded.
                S_FLUSH: begin
                    if (!writeBusyEffective && ddrReady) begin
                        ddrAddr    <= writeAddr;
                        ddrData    <= packData;
                        ddrWstrobe <= 1'b1;

                        writeBusy  <= 1'b1;

                        packetLastAddr      <= writeAddr;
                        packetNextAddr      <= writeAddr + ADDR_STRIDE;
                        packetLastAddrValid <= 1'b1;

                        writeAddr        <= writeAddr + ADDR_STRIDE;
                        writtenWordCount <= writtenWordCount + 32'd1;

                        packData      <= 128'd0;
                        packByteCount <= 4'd0;

                        state <= S_WAIT_LAST;
                    end
                end

                S_WAIT_LAST: begin
                    if (!writeBusyEffective) begin
                        allocPtr  <= packetNextAddr;
                        writeDone <= 1'b1;
                        state     <= S_IDLE;
                    end
                end

                // Error recovery state.
                // Ignore the rest of the current packet.
                S_DROP: begin
                    if (packetDone && !writeBusyEffective) begin
                        packData      <= 128'd0;
                        packByteCount <= 4'd0;
                        state         <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule