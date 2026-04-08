`timescale 1ns/1ps

module tickgen#(
	parameter integer CLK =100_000_000,
	parameter integer baudrate =1_000_000,
	parameter integer oversample =20,
	parameter integer ACCwidth =24
)(
	input wire clk,
	input wire rst,
	output reg ostick,
	output reg baudtick
);
	localparam [63:0] scale =(64'd1<<ACCwidth);
	localparam [63:0] baudINC =((baudrate*scale)+(CLK/2))/CLK;
	localparam [63:0] osINC   =(((baudrate*oversample)*scale)+(CLK/2))/CLK;
    
	reg [(ACCwidth-1):0] baudACC={ACCwidth{1'b0}};
	reg [(ACCwidth-1):0] osACC={ACCwidth{1'b0}};

	wire [ACCwidth:0] baudSUM ={1'b0, baudACC}+baudINC[ACCwidth:0];
	wire [ACCwidth:0] osSUM   ={1'b0, osACC}  +osINC[ACCwidth:0];

	always@(posedge clk)begin
		if(rst)begin
			baudACC  <={ACCwidth{1'b0}};
			osACC    <={ACCwidth{1'b0}};
			baudtick <=1'b0;
			ostick   <=1'b0;
		end
		else begin
			{baudtick,baudACC} <=baudSUM;
			{ostick,osACC}     <=osSUM;
		end
	end
endmodule

module baudtickgen#(
    parameter integer CLK        =100_000_000,
    parameter integer baudrate   =1_000_000,
    parameter integer oversample =20,
    parameter integer ACCwidth   =24)(
    input  wire clk,
    input  wire rst,
    output wire ostick,
    output wire baudtick
);
    tickgen #(.CLK(CLK),.TICK(baudrate),.ACCwidth(ACCwidth)) baudtickgen(.clk(clk),.rst(rst),.tick(baudtick));
    tickgen #(.CLK(CLK),.TICK(baudrate*oversample),.ACCwidth(ACCwidth)) ostickgen(.clk(clk),.rst(rst),.tick(ostick));
endmodule