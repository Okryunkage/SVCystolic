`timescale 1ns/1ps

module topmodule #(
	parameter integer CLK_FREQ   =200_000_000,
	parameter integer BAUDRATE   =1_000_000,
	parameter integer OVERSAMPLE =20,
	parameter integer ACCWIDTH   =24)(
	input  wire boardCLKp,
	input  wire boardCLKn,
	input  wire KEY1,
	output wire UART_TX);
	wire clk;

	clockGen CLKGEN0(.boardCLKp(boardCLKp),.boardCLKn(boardCLKn),.clock(clk));
	wire rst = 1'b0;
	wire baudtick;
	wire ostick;
	baudtickgen #(.CLK(CLK_FREQ),.baudrate(BAUDRATE),.oversample(OVERSAMPLE),.ACCwidth(ACCWIDTH))
		BAUDGEN0(.clk(clk),.rst(rst),.ostick(ostick),.baudtick(baudtick));
	
	wire key_pressed_level;
	assign key_pressed_level =~KEY1;
	wire key_pressed_pulse;
	SYNCpulse KEYPULSE0(.clk(clk),.rst(rst),.signal(key_pressed_level),.SYNCsig(key_pressed_pulse));

	reg tx_req =1'b0;
	wire tx_done;
	wire tx_busy;
	wire tx_start;
	assign tx_start =tx_req&baudtick&~tx_busy;
	always @(posedge clk)begin
		if(rst) tx_req <=1'b0;
		else begin
			if(key_pressed_pulse) tx_req <=1'b1;
			else if(tx_start) tx_req <=1'b0;
		end
	end

	transmit #(.bits(8)) TX0(
		.clk  (clk),
		.tick (baudtick),
		.en   (1'b1),
		.start(tx_start),
		.in   (8'h30),
		.out  (UART_TX),
		.done (tx_done),
		.busy (tx_busy));
endmodule