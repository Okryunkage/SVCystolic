`timescale 1ns/1ps

//13 sampled physical ring oscillators, XOR combined, feeding the original LUT SNG.
//randomWord[0/1] are DROP decisions with nominal probabilities 2/16 and 3/16.
module lutRngSource(input logic clk,rst,
    output wire[3:0] randomWord, output wire randomValid);
    wire rawBit;
`ifdef RNG_SIMULATION
    //Simulation stimulus only: no zero-delay combinational oscillator model.
    logic[31:0] simState=32'h8f12c3a5;
    logic[31:0] nextState;
    always_comb begin
        nextState=simState^(simState<<13);
        nextState=nextState^(nextState>>17);
        nextState=nextState^(nextState<<5);
    end
    always_ff@(posedge clk)
        if(rst) simState<=32'h8f12c3a5;
        else simState<=nextState;
    assign rawBit=simState[0];
`else
    wire[12:0] rawROout;
    for(genvar i=0;i<13;i++)begin:GEN_RO
        (* keep_hierarchy="yes",dont_touch="true" *)
        RO#(.NINV(3)) uRO(.en(1'b1),.raw_ro(rawROout[i]));
    end
    (* ASYNC_REG="TRUE" *) logic[12:0] sampleMeta='0,sampleSync='0;
    logic rawRegistered=0;
    always_ff@(posedge clk)begin
        sampleMeta<=rawROout;
        sampleSync<=sampleMeta;
        if(rst) rawRegistered<=0;
        else rawRegistered<=^sampleSync;
    end
    assign rawBit=rawRegistered;
`endif
    wire drop1,drop2,valid1,valid2;
    sng_lut#(.prob0(2),.prob1(3),.prob2(2),.prob3(3)) layer1Sng(
        .clk(clk),.rst(rst),.rawBit(rawBit),.probSel(2'd0),
        .randomBit(drop1),.randomValid(valid1));
    sng_lut#(.prob0(2),.prob1(3),.prob2(2),.prob3(3)) layer2Sng(
        .clk(clk),.rst(rst),.rawBit(rawBit),.probSel(2'd1),
        .randomBit(drop2),.randomValid(valid2));
    assign randomWord={2'b00,drop2,drop1};
    assign randomValid=valid1 && valid2;
endmodule
