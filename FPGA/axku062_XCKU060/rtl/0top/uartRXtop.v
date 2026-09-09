`timescale 1ns/1ps

module uartRXtop #(
    parameter integer CLK_FREQ   =200_000_000,
    parameter integer BAUDRATE   =1_000_000,
    parameter integer OVERSAMPLE =20,
    parameter integer ACCWIDTH   =24)(
    input  wire boardCLKp,
    input  wire boardCLKn,
    input  wire UARTRX,
    input  wire KEY1,
    output reg  [3:0] LED);

    wire clk;
    clockGen CLKGEN0(.boardCLKp(boardCLKp),.boardCLKn(boardCLKn),.clock(clk));

    wire rst;
    assign rst =~KEY1;
    wire baudtick;
    wire ostick;
    baudtickgen #(.CLK(CLK_FREQ),.baudrate(BAUDRATE),.oversample(OVERSAMPLE),.ACCwidth(ACCWIDTH))
	BAUDGEN0(.clk(clk),.rst(rst),.ostick(ostick),.baudtick(baudtick));

    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;
    wire       rx_error;
    receive #(.bits(8),.oversample(OVERSAMPLE)) 
		RX0(.clk(clk),.tick(ostick),.en(1'b1),.in(UARTRX),.rst(rst),.out(rx_data),.done(rx_done),.busy(rx_busy),.error(rx_error));

    always @(posedge clk)begin
        if(rst) LED <= 4'b0000;
        else if(rx_done&&!rx_error) LED <=rx_data[3:0];
    end
endmodule