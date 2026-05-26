`timescale 1ns/1ps

module ddrADDRbookP #(
    parameter ADDRwidth = 27,
    parameter [ADDRwidth-1:0] RESETbaseADDR = {ADDRwidth{1'b0}},

    parameter [7:0] PACKETimg    = 8'h01,
    parameter [7:0] PACKETparam  = 8'h02,
    parameter [7:0] PACKETparamW = 8'h00,
    parameter [7:0] PACKETparamB = 8'h01,
    parameter [7:0] incLABELmask = 8'h01,

    // Address mode:
    // 0: pStartAddr is byte address.
    //    labelStartAddr = pStartAddr + imageBytes
    //
    // 1: pStartAddr is MIG app_addr style address.
    //    Assumption: 16 payload bytes per write word,
    //                app_addr increases by 8 per 16 bytes.
    //    labelStartAddr = pStartAddr + ceil(imageBytes/16)*8
    parameter integer ADDR_MODE = 1
)(
    input  wire                  clk,
    input  wire                  rst,

    // Optional clear for sticky error flags.
    input  wire                  clear,

    // From ddrPackW128
    input  wire                  writeDone,
    input  wire [3:0]            writerErrorFlags,
    input  wire [ADDRwidth-1:0]  pStartAddr,
    input  wire [ADDRwidth-1:0]  pNextAddr,

    // wMetaInfo = {
    //     packetType[8],
    //     flags[8],
    //     layerID[8],
    //     paramType[8],
    //     bitWidth[16],
    //     elemCount[32],
    //     batchID[32],
    //     batchSize[16],
    //     vectorLEN[16]
    // }
    input  wire [143:0]          wMetaInfo,
    input  wire [31:0]           wPayloadBytes,

    // Current allocator pointer mirror.
    output reg  [ADDRwidth-1:0]  nextFreeAddr,

    // validFlags[0] = image
    // validFlags[1] = label
    // validFlags[2] = fc1 weight
    // validFlags[3] = fc1 bias
    // validFlags[4] = fc2 weight
    // validFlags[5] = fc2 bias
    output reg  [5:0]            validFlags,

    // Slot mapping order follows validFlags.
    output reg  [6*ADDRwidth-1:0] startADDRbook,

    // Payload byte count for each slot.
    output reg  [6*32-1:0]        payloadBytesBook,

    // bookErrorFlags[0] = addressBookError
    // bookErrorFlags[1] = unknownPacketError
    // bookErrorFlags[2] = writerReportedError
    output reg  [2:0]             bookErrorFlags
);

    localparam integer SLOTimage = 0;
    localparam integer SLOTlabel = 1;
    localparam integer SLOTfc1W  = 2;
    localparam integer SLOTfc1B  = 3;
    localparam integer SLOTfc2W  = 4;
    localparam integer SLOTfc2B  = 5;

    localparam integer BOOKerr      = 0;
    localparam integer UNKNOWNerr   = 1;
    localparam integer WRITERrepErr = 2;

    // ------------------------------------------------------------
    // Stage 0 decode wires from captured metadata
    // ------------------------------------------------------------

    reg                         s0_valid;
    reg                         s0_writerError;
    reg [ADDRwidth-1:0]         s0_pStartAddr;
    reg [ADDRwidth-1:0]         s0_pNextAddr;
    reg [143:0]                 s0_wMetaInfo;
    reg [31:0]                  s0_wPayloadBytes;

    wire [7:0]  s0_packetType;
    wire [7:0]  s0_flags;
    wire [7:0]  s0_layerID;
    wire [7:0]  s0_paramType;
    wire [15:0] s0_batchSize;
    wire [15:0] s0_vectorLEN;

    assign s0_packetType = s0_wMetaInfo[143:136];
    assign s0_flags      = s0_wMetaInfo[135:128];
    assign s0_layerID    = s0_wMetaInfo[127:120];
    assign s0_paramType  = s0_wMetaInfo[119:112];
    assign s0_batchSize  = s0_wMetaInfo[31:16];
    assign s0_vectorLEN  = s0_wMetaInfo[15:0];

    wire s0_isImage;
    wire s0_isParam;
    wire s0_isFc1Weight;
    wire s0_isFc1Bias;
    wire s0_isFc2Weight;
    wire s0_isFc2Bias;
    wire s0_incLABEL;

    assign s0_isImage = (s0_packetType == PACKETimg);
    assign s0_isParam = (s0_packetType == PACKETparam);

    assign s0_isFc1Weight =
        s0_isParam && (s0_layerID == 8'd1) && (s0_paramType == PACKETparamW);

    assign s0_isFc1Bias =
        s0_isParam && (s0_layerID == 8'd1) && (s0_paramType == PACKETparamB);

    assign s0_isFc2Weight =
        s0_isParam && (s0_layerID == 8'd2) && (s0_paramType == PACKETparamW);

    assign s0_isFc2Bias =
        s0_isParam && (s0_layerID == 8'd2) && (s0_paramType == PACKETparamB);

    assign s0_incLABEL = ((s0_flags & incLABELmask) != 8'd0);

    // ------------------------------------------------------------
    // Stage 1: classification register + image byte calculation
    // ------------------------------------------------------------

    reg                         s1_valid;
    reg                         s1_writerError;
    reg [ADDRwidth-1:0]         s1_pStartAddr;
    reg [ADDRwidth-1:0]         s1_pNextAddr;
    reg [31:0]                  s1_wPayloadBytes;

    reg                         s1_isImage;
    reg                         s1_isFc1Weight;
    reg                         s1_isFc1Bias;
    reg                         s1_isFc2Weight;
    reg                         s1_isFc2Bias;
    reg                         s1_incLABEL;

    reg [31:0]                  s1_imageBytes;
    reg [31:0]                  s1_labelBytes;

    // ------------------------------------------------------------
    // Stage 2: address offset + label start address calculation
    // ------------------------------------------------------------

    reg                         s2_valid;
    reg                         s2_writerError;
    reg [ADDRwidth-1:0]         s2_pStartAddr;
    reg [ADDRwidth-1:0]         s2_pNextAddr;
    reg [31:0]                  s2_wPayloadBytes;

    reg                         s2_isImage;
    reg                         s2_isFc1Weight;
    reg                         s2_isFc1Bias;
    reg                         s2_isFc2Weight;
    reg                         s2_isFc2Bias;
    reg                         s2_incLABEL;

    reg [31:0]                  s2_imageBytes;
    reg [31:0]                  s2_labelBytes;
    reg [ADDRwidth-1:0]         s2_labelStartAddr;

    wire [31:0] imageAddrOffsetCalc32;

    generate
        if (ADDR_MODE == 0) begin : GEN_BYTE_ADDR
            // pStartAddr is byte address.
            assign imageAddrOffsetCalc32 = s1_imageBytes;
        end
        else begin : GEN_MIG_ADDR
            // pStartAddr is MIG app_addr style address.
            // 16 bytes per packed write word, app_addr +8 per 16 bytes.
            //
            // ceil(imageBytes / 16) * 8
            assign imageAddrOffsetCalc32 =
                ((s1_imageBytes + 32'd15) >> 4) << 3;
        end
    endgenerate

    // ------------------------------------------------------------
    // Pipeline + book update
    // ------------------------------------------------------------

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            nextFreeAddr     <= RESETbaseADDR;
            validFlags       <= 6'd0;
            startADDRbook    <= {(6*ADDRwidth){1'b0}};
            payloadBytesBook <= {(6*32){1'b0}};
            bookErrorFlags   <= 3'd0;

            s0_valid         <= 1'b0;
            s0_writerError   <= 1'b0;
            s0_pStartAddr    <= {ADDRwidth{1'b0}};
            s0_pNextAddr     <= {ADDRwidth{1'b0}};
            s0_wMetaInfo     <= 144'd0;
            s0_wPayloadBytes <= 32'd0;

            s1_valid         <= 1'b0;
            s1_writerError   <= 1'b0;
            s1_pStartAddr    <= {ADDRwidth{1'b0}};
            s1_pNextAddr     <= {ADDRwidth{1'b0}};
            s1_wPayloadBytes <= 32'd0;

            s1_isImage       <= 1'b0;
            s1_isFc1Weight   <= 1'b0;
            s1_isFc1Bias     <= 1'b0;
            s1_isFc2Weight   <= 1'b0;
            s1_isFc2Bias     <= 1'b0;
            s1_incLABEL      <= 1'b0;

            s1_imageBytes    <= 32'd0;
            s1_labelBytes    <= 32'd0;

            s2_valid         <= 1'b0;
            s2_writerError   <= 1'b0;
            s2_pStartAddr    <= {ADDRwidth{1'b0}};
            s2_pNextAddr     <= {ADDRwidth{1'b0}};
            s2_wPayloadBytes <= 32'd0;

            s2_isImage       <= 1'b0;
            s2_isFc1Weight   <= 1'b0;
            s2_isFc1Bias     <= 1'b0;
            s2_isFc2Weight   <= 1'b0;
            s2_isFc2Bias     <= 1'b0;
            s2_incLABEL      <= 1'b0;

            s2_imageBytes    <= 32'd0;
            s2_labelBytes    <= 32'd0;
            s2_labelStartAddr <= {ADDRwidth{1'b0}};
        end
        else begin
            // ----------------------------------------------------
            // Sticky error clear
            // ----------------------------------------------------
            if (clear) begin
                bookErrorFlags <= 3'd0;
            end

            // ----------------------------------------------------
            // Stage 0: capture writeDone transaction
            // ----------------------------------------------------
            s0_valid         <= writeDone;
            s0_writerError   <= |writerErrorFlags;
            s0_pStartAddr    <= pStartAddr;
            s0_pNextAddr     <= pNextAddr;
            s0_wMetaInfo     <= wMetaInfo;
            s0_wPayloadBytes <= wPayloadBytes;

            // ----------------------------------------------------
            // Stage 1: decode/classify + multiply
            // ----------------------------------------------------
            s1_valid         <= s0_valid;
            s1_writerError   <= s0_writerError;
            s1_pStartAddr    <= s0_pStartAddr;
            s1_pNextAddr     <= s0_pNextAddr;
            s1_wPayloadBytes <= s0_wPayloadBytes;

            s1_isImage       <= s0_isImage;
            s1_isFc1Weight   <= s0_isFc1Weight;
            s1_isFc1Bias     <= s0_isFc1Bias;
            s1_isFc2Weight   <= s0_isFc2Weight;
            s1_isFc2Bias     <= s0_isFc2Bias;
            s1_incLABEL      <= s0_incLABEL;

            // imageBytes = batchSize * vectorLEN
            // labelBytes = batchSize if label is included
            s1_imageBytes <= {16'd0, s0_batchSize} * {16'd0, s0_vectorLEN};
            s1_labelBytes <= s0_incLABEL ? {16'd0, s0_batchSize} : 32'd0;

            // ----------------------------------------------------
            // Stage 2: label start address calculation
            // ----------------------------------------------------
            s2_valid         <= s1_valid;
            s2_writerError   <= s1_writerError;
            s2_pStartAddr    <= s1_pStartAddr;
            s2_pNextAddr     <= s1_pNextAddr;
            s2_wPayloadBytes <= s1_wPayloadBytes;

            s2_isImage       <= s1_isImage;
            s2_isFc1Weight   <= s1_isFc1Weight;
            s2_isFc1Bias     <= s1_isFc1Bias;
            s2_isFc2Weight   <= s1_isFc2Weight;
            s2_isFc2Bias     <= s1_isFc2Bias;
            s2_incLABEL      <= s1_incLABEL;

            s2_imageBytes    <= s1_imageBytes;
            s2_labelBytes    <= s1_labelBytes;

            s2_labelStartAddr
                <= s1_pStartAddr + imageAddrOffsetCalc32[ADDRwidth-1:0];

            // ----------------------------------------------------
            // Commit stage:
            // Uses previous cycle's s2_* values.
            // Therefore address book update happens a few cycles
            // after writeDone, but timing path is much shorter.
            // ----------------------------------------------------
            if (s2_valid) begin
                if (s2_writerError) begin
                    bookErrorFlags[BOOKerr]      <= 1'b1;
                    bookErrorFlags[WRITERrepErr] <= 1'b1;
                end
                else begin
                    nextFreeAddr <= s2_pNextAddr;

                    if (s2_isImage) begin
                        validFlags[SLOTimage] <= 1'b1;

                        startADDRbook[SLOTimage*ADDRwidth +: ADDRwidth]
                            <= s2_pStartAddr;

                        // Store only pure image bytes, excluding label bytes.
                        payloadBytesBook[SLOTimage*32 +: 32]
                            <= s2_imageBytes;

                        if (s2_incLABEL) begin
                            validFlags[SLOTlabel] <= 1'b1;

                            startADDRbook[SLOTlabel*ADDRwidth +: ADDRwidth]
                                <= s2_labelStartAddr;

                            payloadBytesBook[SLOTlabel*32 +: 32]
                                <= s2_labelBytes;
                        end
                        else begin
                            validFlags[SLOTlabel] <= 1'b0;

                            startADDRbook[SLOTlabel*ADDRwidth +: ADDRwidth]
                                <= {ADDRwidth{1'b0}};

                            payloadBytesBook[SLOTlabel*32 +: 32]
                                <= 32'd0;
                        end
                    end
                    else if (s2_isFc1Weight) begin
                        validFlags[SLOTfc1W] <= 1'b1;

                        startADDRbook[SLOTfc1W*ADDRwidth +: ADDRwidth]
                            <= s2_pStartAddr;

                        payloadBytesBook[SLOTfc1W*32 +: 32]
                            <= s2_wPayloadBytes;
                    end
                    else if (s2_isFc1Bias) begin
                        validFlags[SLOTfc1B] <= 1'b1;

                        startADDRbook[SLOTfc1B*ADDRwidth +: ADDRwidth]
                            <= s2_pStartAddr;

                        payloadBytesBook[SLOTfc1B*32 +: 32]
                            <= s2_wPayloadBytes;
                    end
                    else if (s2_isFc2Weight) begin
                        validFlags[SLOTfc2W] <= 1'b1;

                        startADDRbook[SLOTfc2W*ADDRwidth +: ADDRwidth]
                            <= s2_pStartAddr;

                        payloadBytesBook[SLOTfc2W*32 +: 32]
                            <= s2_wPayloadBytes;
                    end
                    else if (s2_isFc2Bias) begin
                        validFlags[SLOTfc2B] <= 1'b1;

                        startADDRbook[SLOTfc2B*ADDRwidth +: ADDRwidth]
                            <= s2_pStartAddr;

                        payloadBytesBook[SLOTfc2B*32 +: 32]
                            <= s2_wPayloadBytes;
                    end
                    else begin
                        bookErrorFlags[BOOKerr]    <= 1'b1;
                        bookErrorFlags[UNKNOWNerr] <= 1'b1;
                    end
                end
            end
        end
    end

endmodule