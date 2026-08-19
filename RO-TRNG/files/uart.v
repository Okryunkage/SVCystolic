module uart #(
    parameter integer BASE_CLK      = 100_000_000, //100MHz--> BASE_CLK
    parameter integer BAUD          = 576000,
    
    parameter integer TOTAL_BITS    = 10_000_000,
    parameter integer FIFO_BYTES    = 4096 
)(
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire [7:0] tx_data,
    
    output reg busy,
    output reg tx       
);
    localparam integer DIV = BASE_CLK / BAUD;
    
    reg [9:0]   shreg   = 10'h3FF; // shreg = shift register, 10'h3FF = 0011 1111 1111 -> 11 1111 1111
    reg [15:0]  div_cnt = 16'd0;
    reg [3:0]   bit_cnt = 4'd0; 
    
    always @(posedge clk) begin
        if (rst) begin
            tx      <=  1'b1;
            busy    <=  1'b0;
            div_cnt <= 16'd0;
            bit_cnt <= 4'd0;
        
        end else begin
            if (!busy) begin        // busy = 0
                tx      <=  1'b1;
                if (tx_start) begin     // busy = 0 && tx_start = 1
                    shreg   <= {1'b1, tx_data, 1'b0};   // concatenation(연결) 문법 : {A(MSB), B, C(LSB)} --> [stop][D7 D6 D5 ... D1][START] : 데이터 전송 준비를 위해 shreg에 값 채워넣기.
                    busy    <= 1'b1;
                    div_cnt <= 16'd0;
                    bit_cnt <= 4'd0;
                end
            end else begin          // busy = 1
                if (div_cnt == DIV-1) begin
                    div_cnt <= 16'd0;
                    tx      <= shreg[0];
                    shreg   <= {1'b1, shreg[9:1]};
                    if(bit_cnt == 4'd9) begin   // 8N1 UART에서 stop 비트가 출력된 상황 --> 9번째 uart 출력
                        busy    <= 1'b0;
                        bit_cnt <= 4'd0;
                    end else begin
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                end else begin
                    div_cnt <= div_cnt + 16'd1;
                end
           end
      end
   end
endmodule
`default_nettype wire