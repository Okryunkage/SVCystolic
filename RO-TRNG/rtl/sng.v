`timescale 1ns/1ps
`default_nettype none

module sng#(
    parameter integer LUTprob0 =4,
    parameter integer LUTprob1 =8,
    parameter integer LUTprob2 =12,
    parameter integer LUTprob3 =16)(
    
    input wire clk, rst, rawBit,
    input wire modelSel,
    input wire [3:0] probCTRL,
    output reg randomBit =1'b0,
    output reg randomValid =1'b0);

    reg[3:0] sampleShift =4'b0000;
    reg[1:0] sampleCount =2'b00;

    wire[3:0] sampleWord ={sampleShift[2:0], rawBit};

    function automatic LUTresult;
        input[3:0] randomValue;
        input[1:0] tableSelect;
        integer threshold;begin
            case(tableSelect)
                2'd0: threshold =LUTprob0;
                2'd1: threshold =LUTprob1;
                2'd2: threshold =LUTprob2;
                default: threshold =LUTprob3;
            endcase
            LUTresult =(randomValue<threshold);
        end
    endfunction
    (*keep="true"*) wire LUTbit =LUTresult(sampleWord,probCTRL[1:0]);

    function automatic muxResult;
        input[3:0] randomValue;
        input[3:0] probability;
        reg stage1, stage2;begin
            stage1 =randomValue[1]?(randomValue[0]&probability[0]):probability[1];
            stage2 =randomValue[2]?probability[2]:stage1;
            muxResult =randomValue[3]?probability[3]:stage2;
        end
    endfunction
    (*keep="true"*) wire MUXbit =muxResult(sampleWord,probCTRL);

    always@(posedge clk)begin
        randomValid <=1'b0;
        if(rst)begin
            sampleShift <=4'b0000;
            sampleCount <=2'b00;
            randomBit   <=1'b0;
        end
        else begin
            sampleShift <=sampleWord;
            if(sampleCount==2'd3)begin
                sampleCount <=2'd0;
                randomBit   <=modelSel?MUXbit:LUTbit;
                randomValid <=1'b1;
            end
            else begin
                sampleCount <=sampleCount+1'b1;
            end
        end
    end
endmodule

`default_nettype wire