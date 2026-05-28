`timescale 1ns/1ps

module ddrReadbackTest #(
    parameter ADDRwidth = 27,

    // If the first payload byte is mapped to rdData[7:0], keep this 1.
    // If the first payload byte appears at rdData[127:120], set this to 0.
    parameter BYTE0_LSB = 1
)(
    input  wire                 clk,
    input  wire                 rst,

    input  wire                 start,
    input  wire                 clear,

    // MIG UI wrapper side
    input  wire                 ready,
    input  wire                 transaction_complete,
    input  wire [127:0]         rdData,

    output reg  [ADDRwidth-1:0] rdAddr,
    output reg                  rdStrobe,

    // Address-book outputs
    input  wire [ADDRwidth-1:0] imageStartAddr,
    input  wire [ADDRwidth-1:0] labelStartAddr,
    input  wire [ADDRwidth-1:0] fc1WeightStartAddr,
    input  wire [ADDRwidth-1:0] fc1BiasStartAddr,
    input  wire [ADDRwidth-1:0] fc2WeightStartAddr,
    input  wire [ADDRwidth-1:0] fc2BiasStartAddr,

    input  wire [31:0]          imagePayloadBytes,
    input  wire [31:0]          labelPayloadBytes,
    input  wire [31:0]          fc1WeightPayloadBytes,
    input  wire [31:0]          fc1BiasPayloadBytes,
    input  wire [31:0]          fc2WeightPayloadBytes,
    input  wire [31:0]          fc2BiasPayloadBytes,

    output wire                 busy,
    output reg                  done,
    output reg                  pass,
    output reg                  fail,

    // Debug outputs
    output reg  [2:0]           currentSlot,
    output reg  [2:0]           failSlot,
    output reg  [127:0]         lastReadData,
    output reg  [127:0]         lastExpectedData,
    output reg  [31:0]          lastValidBytes,
    output reg  [15:0]          mismatchMask
);

    localparam [2:0] SLOTimage = 3'd0;
    localparam [2:0] SLOTlabel = 3'd1;
    localparam [2:0] SLOTfc1W  = 3'd2;
    localparam [2:0] SLOTfc1B  = 3'd3;
    localparam [2:0] SLOTfc2W  = 3'd4;
    localparam [2:0] SLOTfc2B  = 3'd5;

    localparam [2:0] IDLEs  = 3'd0;
    localparam [2:0] ISSUEs = 3'd1;
    localparam [2:0] WAITs  = 3'd2;
    localparam [2:0] CHECKs = 3'd3;
    localparam [2:0] DONEs  = 3'd4;

    reg [2:0] state;

    assign busy = (state != IDLEs) && (state != DONEs);

    function [ADDRwidth-1:0] slotAddr;
        input [2:0] slot;
        begin
            case (slot)
                SLOTimage: slotAddr = imageStartAddr;
                SLOTlabel: slotAddr = labelStartAddr;
                SLOTfc1W : slotAddr = fc1WeightStartAddr;
                SLOTfc1B : slotAddr = fc1BiasStartAddr;
                SLOTfc2W : slotAddr = fc2WeightStartAddr;
                SLOTfc2B : slotAddr = fc2BiasStartAddr;
                default  : slotAddr = {ADDRwidth{1'b0}};
            endcase
        end
    endfunction

    function [31:0] slotBytes;
        input [2:0] slot;
        begin
            case (slot)
                SLOTimage: slotBytes = imagePayloadBytes;
                SLOTlabel: slotBytes = labelPayloadBytes;
                SLOTfc1W : slotBytes = fc1WeightPayloadBytes;
                SLOTfc1B : slotBytes = fc1BiasPayloadBytes;
                SLOTfc2W : slotBytes = fc2WeightPayloadBytes;
                SLOTfc2B : slotBytes = fc2BiasPayloadBytes;
                default  : slotBytes = 32'd0;
            endcase
        end
    endfunction

    function [31:0] clamp16;
        input [31:0] n;
        begin
            clamp16 = (n > 32'd16) ? 32'd16 : n;
        end
    endfunction

    function [7:0] readByte;
        input [127:0] word;
        input integer idx;
        begin
            if (BYTE0_LSB)
                readByte = word[idx*8 +: 8];
            else
                readByte = word[(15-idx)*8 +: 8];
        end
    endfunction

    function [7:0] expectedByte;
        input [2:0] slot;
        input integer idx;
        begin
            case (slot)
                // image = 00 01 02 ... 0F
                SLOTimage: expectedByte = idx[7:0];

                // label = 07
                SLOTlabel: expectedByte = (idx == 0) ? 8'h07 : 8'h00;

                // fc1 weight = 16 bytes of 0x11
                SLOTfc1W: expectedByte = 8'h11;

                // fc1 bias = 1,2,3,4 as little-endian int32
                SLOTfc1B: begin
                    case (idx)
                        0:  expectedByte = 8'h01;
                        1:  expectedByte = 8'h00;
                        2:  expectedByte = 8'h00;
                        3:  expectedByte = 8'h00;
                        4:  expectedByte = 8'h02;
                        5:  expectedByte = 8'h00;
                        6:  expectedByte = 8'h00;
                        7:  expectedByte = 8'h00;
                        8:  expectedByte = 8'h03;
                        9:  expectedByte = 8'h00;
                        10: expectedByte = 8'h00;
                        11: expectedByte = 8'h00;
                        12: expectedByte = 8'h04;
                        13: expectedByte = 8'h00;
                        14: expectedByte = 8'h00;
                        15: expectedByte = 8'h00;
                        default: expectedByte = 8'h00;
                    endcase
                end

                // fc2 weight = 8 bytes of 0x22
                SLOTfc2W: expectedByte = (idx < 8) ? 8'h22 : 8'h00;

                // fc2 bias = 9 as little-endian int32
                SLOTfc2B: begin
                    case (idx)
                        0: expectedByte = 8'h09;
                        1: expectedByte = 8'h00;
                        2: expectedByte = 8'h00;
                        3: expectedByte = 8'h00;
                        default: expectedByte = 8'h00;
                    endcase
                end

                default: expectedByte = 8'h00;
            endcase
        end
    endfunction

    function [127:0] expectedWordForBus;
        input [2:0] slot;
        integer i;
        begin
            expectedWordForBus = 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (BYTE0_LSB)
                    expectedWordForBus[i*8 +: 8] = expectedByte(slot, i);
                else
                    expectedWordForBus[(15-i)*8 +: 8] = expectedByte(slot, i);
            end
        end
    endfunction

    function [15:0] compareMask;
        input [127:0] got;
        input [2:0]   slot;
        input [31:0]  nbytes;
        integer i;
        begin
            compareMask = 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (i < nbytes) begin
                    if (readByte(got, i) != expectedByte(slot, i))
                        compareMask[i] = 1'b1;
                end
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= IDLEs;
            rdAddr           <= {ADDRwidth{1'b0}};
            rdStrobe         <= 1'b0;
            done             <= 1'b0;
            pass             <= 1'b0;
            fail             <= 1'b0;
            currentSlot      <= SLOTimage;
            failSlot         <= 3'd0;
            lastReadData     <= 128'd0;
            lastExpectedData <= 128'd0;
            lastValidBytes   <= 32'd0;
            mismatchMask     <= 16'd0;
        end
        else begin
            rdStrobe <= 1'b0;

            if (clear) begin
                state            <= IDLEs;
                done             <= 1'b0;
                pass             <= 1'b0;
                fail             <= 1'b0;
                currentSlot      <= SLOTimage;
                failSlot         <= 3'd0;
                lastReadData     <= 128'd0;
                lastExpectedData <= 128'd0;
                lastValidBytes   <= 32'd0;
                mismatchMask     <= 16'd0;
            end
            else begin
                case (state)
                    IDLEs: begin
                        if (start) begin
                            done        <= 1'b0;
                            pass        <= 1'b0;
                            fail        <= 1'b0;
                            currentSlot <= SLOTimage;
                            state       <= ISSUEs;
                        end
                    end

                    ISSUEs: begin
                        if (ready) begin
                            rdAddr   <= slotAddr(currentSlot);
                            rdStrobe <= 1'b1;
                            state    <= WAITs;
                        end
                    end

                    WAITs: begin
                        if (transaction_complete) begin
                            lastReadData     <= rdData;
                            lastExpectedData <= expectedWordForBus(currentSlot);
                            lastValidBytes   <= clamp16(slotBytes(currentSlot));
                            mismatchMask     <= compareMask(
                                                    rdData,
                                                    currentSlot,
                                                    clamp16(slotBytes(currentSlot))
                                                );
                            state <= CHECKs;
                        end
                    end

                    CHECKs: begin
                        if (mismatchMask != 16'd0) begin
                            fail     <= 1'b1;
                            pass     <= 1'b0;
                            done     <= 1'b1;
                            failSlot <= currentSlot;
                            state    <= DONEs;
                        end
                        else if (currentSlot == SLOTfc2B) begin
                            fail  <= 1'b0;
                            pass  <= 1'b1;
                            done  <= 1'b1;
                            state <= DONEs;
                        end
                        else begin
                            currentSlot <= currentSlot + 3'd1;
                            state       <= ISSUEs;
                        end
                    end

                    DONEs: begin
                        state <= DONEs;
                    end

                    default: begin
                        state <= IDLEs;
                    end
                endcase
            end
        end
    end

endmodule