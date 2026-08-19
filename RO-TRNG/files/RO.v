(* keep_hierarchy = "yes", dont_touch = "true" *)
module RO #(
    parameter integer NINV = 13
)(    
    input wire en,
    output wire raw_ro
);

    (* dont_touch = "yes" *) wire [NINV:0] x;
    (* dont_touch = "yes" *) wire y;
    
    genvar i;       // generation 전용 index 변수
    generate
        for (i = 0; i < NINV; i = i + 1) begin : g_inv      // g_inv[0].u_inv, g_inv[1].u_inv ....
            (* keep = "true", dont_touch = "yes" *)
            LUT1 #(.INIT(2'b01)) u_inv (                    // LUT1 --> 1 input LUT   .INIT -> truth table : 2'b01 
                .O (x[i+1]),
                .I0(x[i])   
            );
        end
    endgenerate
    
    assign y        = x[NINV];
    assign x[0]     = en & y;
    assign raw_ro   = x[NINV];
        
endmodule
