(* keep_hierarchy = "yes", dont_touch = "true" *)
module DFF(
    input wire clk,
    input wire ce,
    input wire raw_ro,
    output reg sample_ro = 1'b0);

    always@(posedge clk)begin
        if(ce) sample_ro <=raw_ro;
    end   
endmodule
