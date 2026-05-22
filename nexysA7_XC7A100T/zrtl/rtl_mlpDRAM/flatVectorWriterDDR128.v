`timescale 1ns/1ps

module flatVectorWriterDDR128 #(
    parameter integer ADDR_WIDTH = 27,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE = 27'd8,

    parameter integer NUMBER     = 64,
    parameter integer ELEM_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    input  wire [ADDR_WIDTH-1:0]         baseAddr,
    input  wire [(NUMBER*ELEM_WIDTH-1):0] inFlat,

    output reg  [ADDR_WIDTH-1:0]         ddrAddr,
    output reg  [127:0]                  ddrData,
    output reg                          ddrWstrobe,
    input  wire                         ddrReady,
    input  wire                         ddrTransactionComplete,

    output reg                          busy,
    output reg                          done,

    output reg  [ADDR_WIDTH-1:0]         lastAddr,
    output reg  [ADDR_WIDTH-1:0]         nextAddr,
    output reg                          addrValid,

    output reg                          configError
);

    localparam integer TOTAL_BITS  = NUMBER * ELEM_WIDTH;
    localparam integer TOTAL_BYTES = (TOTAL_BITS + 7) / 8;
    localparam integer WORD_BYTES  = 16;
    localparam integer WORD_COUNT  = (TOTAL_BYTES + WORD_BYTES - 1) / WORD_BYTES;

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_ISSUE = 2'd1;
    localparam [1:0] S_WAIT  = 2'd2;
    localparam [1:0] S_DONE  = 2'd3;

    reg [1:0] state;
    reg [31:0] wordIdx;

    integer b;
    integer byteIdx;

    function [127:0] makeWord;
        input [31:0] widx;
        reg [127:0] tmp;
        integer k;
        integer globalByte;
        begin
            tmp = 128'd0;
            for (k = 0; k < WORD_BYTES; k = k + 1) begin
                globalByte = widx * WORD_BYTES + k;
                if (globalByte < TOTAL_BYTES) begin
                    tmp[(k*8)+:8] = inFlat[(globalByte*8)+:8];
                end
            end
            makeWord = tmp;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_IDLE;
            wordIdx     <= 32'd0;

            ddrAddr     <= {ADDR_WIDTH{1'b0}};
            ddrData     <= 128'd0;
            ddrWstrobe  <= 1'b0;

            busy        <= 1'b0;
            done        <= 1'b0;

            lastAddr    <= {ADDR_WIDTH{1'b0}};
            nextAddr    <= {ADDR_WIDTH{1'b0}};
            addrValid   <= 1'b0;

            configError <= 1'b0;
        end
        else begin
            ddrWstrobe <= 1'b0;
            done       <= 1'b0;

            case (state)

                S_IDLE: begin
                    busy      <= 1'b0;
                    addrValid <= 1'b0;
                    wordIdx   <= 32'd0;

                    if (start) begin
                        busy <= 1'b1;

                        if ((ELEM_WIDTH % 8) != 0) begin
                            configError <= 1'b1;
                            state       <= S_DONE;
                        end
                        else begin
                            configError <= 1'b0;
                            state       <= S_ISSUE;
                        end
                    end
                end

                S_ISSUE: begin
                    if (ddrReady) begin
                        ddrAddr    <= baseAddr + wordIdx * ADDR_STRIDE;
                        ddrData    <= makeWord(wordIdx);
                        ddrWstrobe <= 1'b1;

                        lastAddr   <= baseAddr + wordIdx * ADDR_STRIDE;
                        nextAddr   <= baseAddr + (wordIdx + 32'd1) * ADDR_STRIDE;

                        state      <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (ddrTransactionComplete) begin
                        if (wordIdx == (WORD_COUNT - 1)) begin
                            addrValid <= 1'b1;
                            state     <= S_DONE;
                        end
                        else begin
                            wordIdx <= wordIdx + 32'd1;
                            state   <= S_ISSUE;
                        end
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule