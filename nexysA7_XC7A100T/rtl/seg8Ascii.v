`timescale 1ns/1ps

module seg8Ascii (
	input  wire        clk,
	input  wire        rst,
	input  wire        scanTick,
	input  wire [63:0] asciiData,
	output reg  [7:0]  an,   // active-low digit enable
	output reg  [6:0]  seg,  // {CA, CB, CC, CD, CE, CF, CG}, active-low
	output reg         dp    // active-low decimal point
);

	reg [2:0] digitIndex;
	reg [7:0] charValue;

	always@(posedge clk or posedge rst) begin
		if(rst) digitIndex <=3'd0;
		else if(scan_tick) digitIndex <=digitIndex+3'd1;
    end

	always@(*)begin
		an        =8'b1111_1111;
		dp        =1'b1;
		charValue =8'h20;

		case (digitIndex)
			3'd0: begin
            	an        =8'b1111_1110;
            	charValue =asciiData[7:0];
			end
			3'd1: begin
				an        =8'b1111_1101;
				charValue =asciiData[15:8];
			end
			3'd2: begin
				an        =8'b1111_1011;
				charValue =asciiData[23:16];
			end
			3'd3: begin
				an        =8'b1111_0111;
				charValue =asciiData[31:24];
			end
			3'd4: begin
				an        =8'b1110_1111;
				charValue =asciiData[39:32];
			end
			3'd5: begin
				an        =8'b1101_1111;
				charValue =asciiData[47:40];
			end
			3'd6: begin
				an        =8'b1011_1111;
				charValue =asciiData[55:48];
			end
			3'd7: begin
				an        =8'b0111_1111;
				charValue =asciiData[63:56];
			end
		endcase
	end

    function [6:0] ascii2seg;
		input [7:0] ch;begin
			case(ch)
				`ASCII_0: ascii2seg = `SEG_0;
				`ASCII_1: ascii2seg = `SEG_1;
				`ASCII_2: ascii2seg = `SEG_2;
				`ASCII_3: ascii2seg = `SEG_3;
				`ASCII_4: ascii2seg = `SEG_4;
				`ASCII_5: ascii2seg = `SEG_5;
				`ASCII_6: ascii2seg = `SEG_6;
				`ASCII_7: ascii2seg = `SEG_7;
				`ASCII_8: ascii2seg = `SEG_8;
				`ASCII_9: ascii2seg = `SEG_9;

				`ASCII_A: ascii2seg = `SEG_UC_A;
				`ASCII_B: ascii2seg = `SEG_UC_B;
				`ASCII_C: ascii2seg = `SEG_UC_C;
				`ASCII_D: ascii2seg = `SEG_UC_D;
				`ASCII_E: ascii2seg = `SEG_UC_E;
				`ASCII_F: ascii2seg = `SEG_UC_F;
				`ASCII_G: ascii2seg = `SEG_UC_G;
				`ASCII_H: ascii2seg = `SEG_UC_H;
				`ASCII_I: ascii2seg = `SEG_UC_I;
				`ASCII_J: ascii2seg = `SEG_UC_J;
				`ASCII_K: ascii2seg = `SEG_UC_K;
				`ASCII_L: ascii2seg = `SEG_UC_L;
				`ASCII_M: ascii2seg = `SEG_UC_M;
				`ASCII_N: ascii2seg = `SEG_UC_N;
				`ASCII_O: ascii2seg = `SEG_UC_O;
				`ASCII_P: ascii2seg = `SEG_UC_P;
				`ASCII_Q: ascii2seg = `SEG_UC_Q;
				`ASCII_R: ascii2seg = `SEG_UC_R;
				`ASCII_S: ascii2seg = `SEG_UC_S;
				`ASCII_T: ascii2seg = `SEG_UC_T;
				`ASCII_U: ascii2seg = `SEG_UC_U;
				`ASCII_V: ascii2seg = `SEG_UC_V;
				`ASCII_W: ascii2seg = `SEG_UC_W;
				`ASCII_X: ascii2seg = `SEG_UC_X;
				`ASCII_Y: ascii2seg = `SEG_UC_Y;
				`ASCII_Z: ascii2seg = `SEG_UC_Z;

				`ASCII_a: ascii2seg = `SEG_LC_A;
				`ASCII_b: ascii2seg = `SEG_LC_B;
				`ASCII_c: ascii2seg = `SEG_LC_C;
				`ASCII_d: ascii2seg = `SEG_LC_D;
				`ASCII_e: ascii2seg = `SEG_LC_E;
				`ASCII_f: ascii2seg = `SEG_LC_F;
				`ASCII_g: ascii2seg = `SEG_LC_G;
				`ASCII_h: ascii2seg = `SEG_LC_H;
				`ASCII_i: ascii2seg = `SEG_LC_I;
				`ASCII_j: ascii2seg = `SEG_LC_J;
				`ASCII_k: ascii2seg = `SEG_LC_K;
				`ASCII_l: ascii2seg = `SEG_LC_L;
				`ASCII_m: ascii2seg = `SEG_LC_M;
				`ASCII_n: ascii2seg = `SEG_LC_N;
				`ASCII_o: ascii2seg = `SEG_LC_O;
				`ASCII_p: ascii2seg = `SEG_LC_P;
				`ASCII_q: ascii2seg = `SEG_LC_Q;
				`ASCII_r: ascii2seg = `SEG_LC_R;
				`ASCII_s: ascii2seg = `SEG_LC_S;
				`ASCII_t: ascii2seg = `SEG_LC_T;
				`ASCII_u: ascii2seg = `SEG_LC_U;
				`ASCII_v: ascii2seg = `SEG_LC_V;
				`ASCII_w: ascii2seg = `SEG_LC_W;
				`ASCII_x: ascii2seg = `SEG_LC_X;
				`ASCII_y: ascii2seg = `SEG_LC_Y;
				`ASCII_z: ascii2seg = `SEG_LC_Z;

				`ASCII_SPACE: ascii2seg = `SEG_BLANK;
				`ASCII_MINUS: ascii2seg = `SEG_DASH;
				`ASCII_UNDER: ascii2seg = `SEG_UNDER;

				default: ascii2seg = `SEG_BLANK;
			endcase
		end
	endfunction

	always @(*) seg =ascii2seg(charValue);

endmodule
