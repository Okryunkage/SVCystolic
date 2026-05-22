`timescale 1ns/1ps

module ddrAddressBook #(
    parameter ADDR_WIDTH = 27,

    parameter [ADDR_WIDTH-1:0] RESET_BASE_ADDR = {ADDR_WIDTH{1'b0}},

    parameter [7:0] PACKET_TYPE_IMAGE = 8'h01,
    parameter [7:0] PACKET_TYPE_PARAM = 8'h02,

    parameter [7:0] PARAM_TYPE_WEIGHT = 8'h00,
    parameter [7:0] PARAM_TYPE_BIAS   = 8'h01
)(
    input  wire                  clk,
    input  wire                  rst,

    // Optional software/manual clear for sticky errors.
    input  wire                  clear,

    // From ddrPacketWriter128
    input  wire                  writeDone,
    input  wire                  writerError,

    input  wire [ADDR_WIDTH-1:0] packetStartAddr,
    input  wire [ADDR_WIDTH-1:0] packetLastAddr,
    input  wire [ADDR_WIDTH-1:0] packetNextAddr,
    input  wire                  packetLastAddrValid,

    input  wire [7:0]            writtenPacketType,
    input  wire [7:0]            writtenFlags,
    input  wire [7:0]            writtenLayerID,
    input  wire [7:0]            writtenParamType,
    input  wire [15:0]           writtenBitWidth,
    input  wire [31:0]           writtenElemCount,
    input  wire [31:0]           writtenBatchID,
    input  wire [15:0]           writtenBatchSize,
    input  wire [15:0]           writtenVectorLEN,

    input  wire [31:0]           writtenPayloadBytes,
    input  wire [31:0]           writtenWordCount,

    // Current allocator pointer mirror.
    output reg  [ADDR_WIDTH-1:0] nextFreeAddr,

    // IMAGE packet address
    output reg                   imageValid,
    output reg  [ADDR_WIDTH-1:0] imageStartAddr,
    output reg  [ADDR_WIDTH-1:0] imageLastAddr,
    output reg  [ADDR_WIDTH-1:0] imageNextAddr,
    output reg  [31:0]           imagePayloadBytes,
    output reg  [31:0]           imageWordCount,
    output reg  [31:0]           imageBatchID,
    output reg  [15:0]           imageBatchSize,
    output reg  [15:0]           imageVectorLEN,
    output reg  [7:0]            imageFlags,

    // FC1 weight
    output reg                   fc1WeightValid,
    output reg  [ADDR_WIDTH-1:0] fc1WeightStartAddr,
    output reg  [ADDR_WIDTH-1:0] fc1WeightLastAddr,
    output reg  [ADDR_WIDTH-1:0] fc1WeightNextAddr,
    output reg  [15:0]           fc1WeightBitWidth,
    output reg  [31:0]           fc1WeightElemCount,
    output reg  [31:0]           fc1WeightPayloadBytes,
    output reg  [31:0]           fc1WeightWordCount,

    // FC1 bias
    output reg                   fc1BiasValid,
    output reg  [ADDR_WIDTH-1:0] fc1BiasStartAddr,
    output reg  [ADDR_WIDTH-1:0] fc1BiasLastAddr,
    output reg  [ADDR_WIDTH-1:0] fc1BiasNextAddr,
    output reg  [15:0]           fc1BiasBitWidth,
    output reg  [31:0]           fc1BiasElemCount,
    output reg  [31:0]           fc1BiasPayloadBytes,
    output reg  [31:0]           fc1BiasWordCount,

    // FC2 weight
    output reg                   fc2WeightValid,
    output reg  [ADDR_WIDTH-1:0] fc2WeightStartAddr,
    output reg  [ADDR_WIDTH-1:0] fc2WeightLastAddr,
    output reg  [ADDR_WIDTH-1:0] fc2WeightNextAddr,
    output reg  [15:0]           fc2WeightBitWidth,
    output reg  [31:0]           fc2WeightElemCount,
    output reg  [31:0]           fc2WeightPayloadBytes,
    output reg  [31:0]           fc2WeightWordCount,

    // FC2 bias
    output reg                   fc2BiasValid,
    output reg  [ADDR_WIDTH-1:0] fc2BiasStartAddr,
    output reg  [ADDR_WIDTH-1:0] fc2BiasLastAddr,
    output reg  [ADDR_WIDTH-1:0] fc2BiasNextAddr,
    output reg  [15:0]           fc2BiasBitWidth,
    output reg  [31:0]           fc2BiasElemCount,
    output reg  [31:0]           fc2BiasPayloadBytes,
    output reg  [31:0]           fc2BiasWordCount,

    // Sticky status
    output reg                   addressBookError,
    output reg                   unknownPacketError,
    output reg                   writerReportedError
);

    wire acceptedWrite;
    wire [ADDR_WIDTH-1:0] safeLastAddr;

    assign acceptedWrite = writeDone && !writerError;

    // For normal non-empty packets, packetLastAddrValid should be 1.
    // For zero-length packets, use packetStartAddr as a harmless fallback.
    assign safeLastAddr = packetLastAddrValid ? packetLastAddr : packetStartAddr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            nextFreeAddr <= RESET_BASE_ADDR;

            imageValid        <= 1'b0;
            imageStartAddr    <= {ADDR_WIDTH{1'b0}};
            imageLastAddr     <= {ADDR_WIDTH{1'b0}};
            imageNextAddr     <= {ADDR_WIDTH{1'b0}};
            imagePayloadBytes <= 32'd0;
            imageWordCount    <= 32'd0;
            imageBatchID      <= 32'd0;
            imageBatchSize    <= 16'd0;
            imageVectorLEN    <= 16'd0;
            imageFlags        <= 8'd0;

            fc1WeightValid        <= 1'b0;
            fc1WeightStartAddr    <= {ADDR_WIDTH{1'b0}};
            fc1WeightLastAddr     <= {ADDR_WIDTH{1'b0}};
            fc1WeightNextAddr     <= {ADDR_WIDTH{1'b0}};
            fc1WeightBitWidth     <= 16'd0;
            fc1WeightElemCount    <= 32'd0;
            fc1WeightPayloadBytes <= 32'd0;
            fc1WeightWordCount    <= 32'd0;

            fc1BiasValid        <= 1'b0;
            fc1BiasStartAddr    <= {ADDR_WIDTH{1'b0}};
            fc1BiasLastAddr     <= {ADDR_WIDTH{1'b0}};
            fc1BiasNextAddr     <= {ADDR_WIDTH{1'b0}};
            fc1BiasBitWidth     <= 16'd0;
            fc1BiasElemCount    <= 32'd0;
            fc1BiasPayloadBytes <= 32'd0;
            fc1BiasWordCount    <= 32'd0;

            fc2WeightValid        <= 1'b0;
            fc2WeightStartAddr    <= {ADDR_WIDTH{1'b0}};
            fc2WeightLastAddr     <= {ADDR_WIDTH{1'b0}};
            fc2WeightNextAddr     <= {ADDR_WIDTH{1'b0}};
            fc2WeightBitWidth     <= 16'd0;
            fc2WeightElemCount    <= 32'd0;
            fc2WeightPayloadBytes <= 32'd0;
            fc2WeightWordCount    <= 32'd0;

            fc2BiasValid        <= 1'b0;
            fc2BiasStartAddr    <= {ADDR_WIDTH{1'b0}};
            fc2BiasLastAddr     <= {ADDR_WIDTH{1'b0}};
            fc2BiasNextAddr     <= {ADDR_WIDTH{1'b0}};
            fc2BiasBitWidth     <= 16'd0;
            fc2BiasElemCount    <= 32'd0;
            fc2BiasPayloadBytes <= 32'd0;
            fc2BiasWordCount    <= 32'd0;

            addressBookError   <= 1'b0;
            unknownPacketError <= 1'b0;
            writerReportedError <= 1'b0;
        end
        else begin
            if (clear) begin
                addressBookError    <= 1'b0;
                unknownPacketError  <= 1'b0;
                writerReportedError <= 1'b0;
            end

            if (writeDone && writerError) begin
                addressBookError    <= 1'b1;
                writerReportedError <= 1'b1;
            end

            if (acceptedWrite) begin
                // Mirror allocator next pointer from the packet writer.
                nextFreeAddr <= packetNextAddr;

                if (writtenPacketType == PACKET_TYPE_IMAGE) begin
                    imageValid        <= 1'b1;
                    imageStartAddr    <= packetStartAddr;
                    imageLastAddr     <= safeLastAddr;
                    imageNextAddr     <= packetNextAddr;
                    imagePayloadBytes <= writtenPayloadBytes;
                    imageWordCount    <= writtenWordCount;
                    imageBatchID      <= writtenBatchID;
                    imageBatchSize    <= writtenBatchSize;
                    imageVectorLEN    <= writtenVectorLEN;
                    imageFlags        <= writtenFlags;
                end
                else if (writtenPacketType == PACKET_TYPE_PARAM) begin
                    if ((writtenLayerID == 8'd1) &&
                        (writtenParamType == PARAM_TYPE_WEIGHT)) begin
                        fc1WeightValid        <= 1'b1;
                        fc1WeightStartAddr    <= packetStartAddr;
                        fc1WeightLastAddr     <= safeLastAddr;
                        fc1WeightNextAddr     <= packetNextAddr;
                        fc1WeightBitWidth     <= writtenBitWidth;
                        fc1WeightElemCount    <= writtenElemCount;
                        fc1WeightPayloadBytes <= writtenPayloadBytes;
                        fc1WeightWordCount    <= writtenWordCount;
                    end
                    else if ((writtenLayerID == 8'd1) &&
                             (writtenParamType == PARAM_TYPE_BIAS)) begin
                        fc1BiasValid        <= 1'b1;
                        fc1BiasStartAddr    <= packetStartAddr;
                        fc1BiasLastAddr     <= safeLastAddr;
                        fc1BiasNextAddr     <= packetNextAddr;
                        fc1BiasBitWidth     <= writtenBitWidth;
                        fc1BiasElemCount    <= writtenElemCount;
                        fc1BiasPayloadBytes <= writtenPayloadBytes;
                        fc1BiasWordCount    <= writtenWordCount;
                    end
                    else if ((writtenLayerID == 8'd2) &&
                             (writtenParamType == PARAM_TYPE_WEIGHT)) begin
                        fc2WeightValid        <= 1'b1;
                        fc2WeightStartAddr    <= packetStartAddr;
                        fc2WeightLastAddr     <= safeLastAddr;
                        fc2WeightNextAddr     <= packetNextAddr;
                        fc2WeightBitWidth     <= writtenBitWidth;
                        fc2WeightElemCount    <= writtenElemCount;
                        fc2WeightPayloadBytes <= writtenPayloadBytes;
                        fc2WeightWordCount    <= writtenWordCount;
                    end
                    else if ((writtenLayerID == 8'd2) &&
                             (writtenParamType == PARAM_TYPE_BIAS)) begin
                        fc2BiasValid        <= 1'b1;
                        fc2BiasStartAddr    <= packetStartAddr;
                        fc2BiasLastAddr     <= safeLastAddr;
                        fc2BiasNextAddr     <= packetNextAddr;
                        fc2BiasBitWidth     <= writtenBitWidth;
                        fc2BiasElemCount    <= writtenElemCount;
                        fc2BiasPayloadBytes <= writtenPayloadBytes;
                        fc2BiasWordCount    <= writtenWordCount;
                    end
                    else begin
                        addressBookError   <= 1'b1;
                        unknownPacketError <= 1'b1;
                    end
                end
                else begin
                    addressBookError   <= 1'b1;
                    unknownPacketError <= 1'b1;
                end
            end
        end
    end

endmodule