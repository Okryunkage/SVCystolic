`timescale 1ns/1ps

module fcLayerDDR #(
    parameter ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter tile     = 8,
    parameter inNum    = 784,
    parameter outNum   = 64,

    parameter inWidth  = 8,
    parameter wWidth   = 8,
    parameter bWidth   = 32,
    parameter accWidth = 32,
    parameter inSigned = 0
)(
    input  wire                         clk,
    input  wire                         rst,       // active-high reset
    input  wire                         start,

    // DDR base addresses
    input  wire [ADDR_WIDTH-1:0]         imageBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         weightBaseAddr,
    input  wire [ADDR_WIDTH-1:0]         biasBaseAddr,

    // DDR read interface to mig_ui128
    output reg  [ADDR_WIDTH-1:0]         ddrAddr,
    output reg                          ddrRstrobe,
    input  wire [127:0]                  ddrData,
    input  wire                         ddrReady,
    input  wire                         ddrTransactionComplete,

    output reg                          busy,
    output reg                          done,

    output reg signed [(outNum*accWidth-1):0] outFlat,

    // Address information actually used by this FC layer
    output reg [ADDR_WIDTH-1:0]          imageLastAddr,
    output reg [ADDR_WIDTH-1:0]          weightLastAddr,
    output reg [ADDR_WIDTH-1:0]          biasLastAddr,
    output reg [ADDR_WIDTH-1:0]          lastReadAddr,

    output reg                          configError,
    output reg                          ddrReadError
);

    localparam integer DDR_BYTES = 16;

    localparam integer numTile = outNum / tile;
    localparam integer tileIdxW = $clog2(numTile);
    localparam integer inIdxW   = $clog2(inNum);

    localparam integer INPUT_BYTES_TOTAL = inNum;
    localparam integer INPUT_LINES       = (INPUT_BYTES_TOTAL + DDR_BYTES - 1) / DDR_BYTES;

    localparam integer W_BITS_PER_ENTRY  = tile * wWidth;
    localparam integer W_BYTES_PER_ENTRY = (W_BITS_PER_ENTRY + 7) / 8;
    localparam integer W_BYTES_TOTAL     = inNum * outNum * ((wWidth + 7) / 8);
    localparam integer W_LINES_TOTAL     = (W_BYTES_TOTAL + DDR_BYTES - 1) / DDR_BYTES;

    localparam integer B_BITS_PER_TILE   = tile * bWidth;
    localparam integer B_BYTES_PER_TILE  = (B_BITS_PER_TILE + 7) / 8;
    localparam integer B_LINES_PER_TILE  = (B_BYTES_PER_TILE + DDR_BYTES - 1) / DDR_BYTES;
    localparam integer B_BYTES_TOTAL     = outNum * ((bWidth + 7) / 8);
    localparam integer B_LINES_TOTAL     = (B_BYTES_TOTAL + DDR_BYTES - 1) / DDR_BYTES;

    localparam [4:0] S_IDLE       = 5'd0;
    localparam [4:0] S_LOAD_X_REQ = 5'd1;
    localparam [4:0] S_LOAD_X_WAIT= 5'd2;

    localparam [4:0] S_BIAS_REQ   = 5'd3;
    localparam [4:0] S_BIAS_WAIT  = 5'd4;
    localparam [4:0] S_BIAS_INIT  = 5'd5;

    localparam [4:0] S_W_REQ      = 5'd6;
    localparam [4:0] S_W_WAIT     = 5'd7;
    localparam [4:0] S_MAC        = 5'd8;

    localparam [4:0] S_WRITE_OUT  = 5'd9;
    localparam [4:0] S_DONE       = 5'd10;
    localparam [4:0] S_ERROR      = 5'd11;

    reg [4:0] state;

    reg [31:0] xLineIdx;
    reg [31:0] biasLineIdx;

    reg [(inIdxW-1):0]   inIdx;
    reg [(tileIdxW-1):0] tileIdx;

    reg [127:0] rdBuf;
    reg [255:0] biasBuf;

    reg [3:0] weightByteInLine;

    reg signed [(accWidth-1):0] acc [0:tile-1];

    reg [31:0] currWEntryIndex;
    reg [31:0] currWByteOffset;
    reg [31:0] currWLineIndex;

    integer i;

    // Small input cache.
    // The image input is loaded once from DDR, then reused for all output tiles.
    reg [(inWidth-1):0] xMem [0:inNum-1];

    function signed [(accWidth-1):0] inputExtend;
        input [(inWidth-1):0] inValue;
        begin
            if (inSigned)
                inputExtend = {{(accWidth-inWidth){inValue[inWidth-1]}}, inValue};
            else
                inputExtend = {{(accWidth-inWidth){1'b0}}, inValue};
        end
    endfunction

    function signed [(accWidth-1):0] weightExtend;
        input [(wWidth-1):0] inValue;
        begin
            weightExtend = {{(accWidth-wWidth){inValue[wWidth-1]}}, inValue};
        end
    endfunction

    function signed [(accWidth-1):0] biasExtend;
        input [(bWidth-1):0] inValue;
        begin
            biasExtend = {{(accWidth-bWidth){inValue[bWidth-1]}}, inValue};
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;

            ddrAddr      <= {ADDR_WIDTH{1'b0}};
            ddrRstrobe   <= 1'b0;

            outFlat      <= {(outNum*accWidth){1'b0}};

            imageLastAddr <= {ADDR_WIDTH{1'b0}};
            weightLastAddr <= {ADDR_WIDTH{1'b0}};
            biasLastAddr <= {ADDR_WIDTH{1'b0}};
            lastReadAddr <= {ADDR_WIDTH{1'b0}};

            configError  <= 1'b0;
            ddrReadError <= 1'b0;

            xLineIdx     <= 32'd0;
            biasLineIdx  <= 32'd0;
            inIdx        <= {inIdxW{1'b0}};
            tileIdx      <= {tileIdxW{1'b0}};

            rdBuf        <= 128'd0;
            biasBuf      <= 256'd0;
            weightByteInLine <= 4'd0;

            currWEntryIndex <= 32'd0;
            currWByteOffset <= 32'd0;
            currWLineIndex  <= 32'd0;

            for (i = 0; i < tile; i = i + 1)
                acc[i] <= {accWidth{1'b0}};
        end
        else begin
            done       <= 1'b0;
            ddrRstrobe <= 1'b0;

            case (state)

                S_IDLE: begin
                    busy <= 1'b0;
                    configError  <= 1'b0;
                    ddrReadError <= 1'b0;

                    if (start) begin
                        busy    <= 1'b1;
                        outFlat <= {(outNum*accWidth){1'b0}};

                        // This first version assumes byte-aligned 8-bit input/weight
                        // and 32-bit bias.
                        if ((inWidth != 8) ||
                            (wWidth  != 8) ||
                            (bWidth  != 32) ||
                            ((outNum % tile) != 0) ||
                            (W_BITS_PER_ENTRY > 128) ||
                            (B_BITS_PER_TILE  > 256)) begin
                            configError <= 1'b1;
                            state       <= S_ERROR;
                        end
                        else begin
                            xLineIdx    <= 32'd0;
                            tileIdx     <= {tileIdxW{1'b0}};
                            inIdx       <= {inIdxW{1'b0}};
                            biasLineIdx <= 32'd0;

                            imageLastAddr  <= imageBaseAddr  + ((INPUT_LINES   - 1) * ADDR_STRIDE);
                            weightLastAddr <= weightBaseAddr + ((W_LINES_TOTAL - 1) * ADDR_STRIDE);
                            biasLastAddr   <= biasBaseAddr   + ((B_LINES_TOTAL - 1) * ADDR_STRIDE);

                            state <= S_LOAD_X_REQ;
                        end
                    end
                end

                // ------------------------------------------------------------
                // Load image input vector from DDR into xMem.
                // ------------------------------------------------------------
                S_LOAD_X_REQ: begin
                    if (ddrReady) begin
                        ddrAddr      <= imageBaseAddr + (xLineIdx * ADDR_STRIDE);
                        lastReadAddr <= imageBaseAddr + (xLineIdx * ADDR_STRIDE);
                        ddrRstrobe   <= 1'b1;
                        state        <= S_LOAD_X_WAIT;
                    end
                end

                S_LOAD_X_WAIT: begin
                    if (ddrTransactionComplete) begin
                        rdBuf <= ddrData;

                        for (i = 0; i < DDR_BYTES; i = i + 1) begin
                            if ((xLineIdx * DDR_BYTES + i) < inNum) begin
                                xMem[xLineIdx * DDR_BYTES + i] <= ddrData[(i*8)+:8];
                            end
                        end

                        if (xLineIdx == (INPUT_LINES - 1)) begin
                            tileIdx     <= {tileIdxW{1'b0}};
                            biasLineIdx <= 32'd0;
                            state       <= S_BIAS_REQ;
                        end
                        else begin
                            xLineIdx <= xLineIdx + 32'd1;
                            state    <= S_LOAD_X_REQ;
                        end
                    end
                end

                // ------------------------------------------------------------
                // Load one bias tile from DDR.
                // For tile=8 and bWidth=32, one bias tile is 256 bits,
                // so it requires two 128-bit DDR reads.
                // ------------------------------------------------------------
                S_BIAS_REQ: begin
                    if (ddrReady) begin
                        ddrAddr      <= biasBaseAddr +
                                        (((tileIdx * B_LINES_PER_TILE) + biasLineIdx) * ADDR_STRIDE);
                        lastReadAddr <= biasBaseAddr +
                                        (((tileIdx * B_LINES_PER_TILE) + biasLineIdx) * ADDR_STRIDE);
                        ddrRstrobe   <= 1'b1;
                        state        <= S_BIAS_WAIT;
                    end
                end

                S_BIAS_WAIT: begin
                    if (ddrTransactionComplete) begin
                        if (biasLineIdx == 32'd0)
                            biasBuf[127:0] <= ddrData;
                        else
                            biasBuf[255:128] <= ddrData;

                        if (biasLineIdx == (B_LINES_PER_TILE - 1)) begin
                            state <= S_BIAS_INIT;
                        end
                        else begin
                            biasLineIdx <= biasLineIdx + 32'd1;
                            state       <= S_BIAS_REQ;
                        end
                    end
                end

                S_BIAS_INIT: begin
                    for (i = 0; i < tile; i = i + 1) begin
                        acc[i] <= biasExtend(biasBuf[(i*bWidth)+:bWidth]);
                    end

                    inIdx <= {inIdxW{1'b0}};
                    state <= S_W_REQ;
                end

                // ------------------------------------------------------------
                // Read one weight tile entry from DDR.
                // For tile=8 and wWidth=8, one entry is 8 bytes.
                // Two entries fit in one 128-bit DDR line.
                // This simple version may read the same DDR line twice.
                // ------------------------------------------------------------
                S_W_REQ: begin
                    currWEntryIndex <= (tileIdx * inNum) + inIdx;
                    currWByteOffset <= ((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY;
                    currWLineIndex  <= (((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY) >> 4;
                    weightByteInLine <= ((((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY) & 32'hF);

                    if ((((((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY) & 32'hF)
                         + W_BYTES_PER_ENTRY) > DDR_BYTES) begin
                        ddrReadError <= 1'b1;
                        state        <= S_ERROR;
                    end
                    else if (ddrReady) begin
                        ddrAddr <= weightBaseAddr +
                                   (((((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY) >> 4)
                                    * ADDR_STRIDE);

                        lastReadAddr <= weightBaseAddr +
                                        (((((tileIdx * inNum) + inIdx) * W_BYTES_PER_ENTRY) >> 4)
                                         * ADDR_STRIDE);

                        ddrRstrobe <= 1'b1;
                        state      <= S_W_WAIT;
                    end
                end

                S_W_WAIT: begin
                    if (ddrTransactionComplete) begin
                        rdBuf <= ddrData;
                        state <= S_MAC;
                    end
                end

                // ------------------------------------------------------------
                // MAC:
                //   acc[i] += input[inIdx] * weight[tile lane i][inIdx]
                // ------------------------------------------------------------
                S_MAC: begin
                    for (i = 0; i < tile; i = i + 1) begin
                        acc[i] <= acc[i]
                                + $signed(inputExtend(xMem[inIdx]))
                                * $signed(weightExtend(
                                    rdBuf[(weightByteInLine*8) + (i*wWidth) +: wWidth]
                                  ));
                    end

                    if (inIdx == (inNum - 1)) begin
                        state <= S_WRITE_OUT;
                    end
                    else begin
                        inIdx <= inIdx + 1'b1;
                        state <= S_W_REQ;
                    end
                end

                // ------------------------------------------------------------
                // Store one output tile into outFlat.
                // ------------------------------------------------------------
                S_WRITE_OUT: begin
                    for (i = 0; i < tile; i = i + 1) begin
                        outFlat[((tileIdx*tile+i)*accWidth)+:accWidth] <= acc[i];
                    end

                    if (tileIdx == (numTile - 1)) begin
                        state <= S_DONE;
                    end
                    else begin
                        tileIdx     <= tileIdx + 1'b1;
                        biasLineIdx <= 32'd0;
                        inIdx       <= {inIdxW{1'b0}};
                        state       <= S_BIAS_REQ;
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