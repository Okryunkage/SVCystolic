`ifndef SEVENSEG_VH
`define SEVENSEG_VH

// seg = {CA, CB, CC, CD, CE, CF, CG}
// active-low: 0 = ON, 1 = OFF

// digits
`define SEG_0 7'b0000001
`define SEG_1 7'b1001111
`define SEG_2 7'b0010010
`define SEG_3 7'b0000110
`define SEG_4 7'b1001100
`define SEG_5 7'b0100100
`define SEG_6 7'b0100000
`define SEG_7 7'b0001111
`define SEG_8 7'b0000000
`define SEG_9 7'b0000100

// symbols
`define SEG_BLANK  7'b1111111
`define SEG_DASH   7'b1111110   // '-'
`define SEG_UNDER  7'b1110111   // '_'

// uppercase letters (approximate where needed)
`define SEG_UC_A 7'b0001000
`define SEG_UC_B 7'b1100000   // shown like 'b'
`define SEG_UC_C 7'b0110001
`define SEG_UC_D 7'b1000010   // shown like 'd'
`define SEG_UC_E 7'b0110000
`define SEG_UC_F 7'b0111000
`define SEG_UC_G 7'b0100000   // approx
`define SEG_UC_H 7'b1001000
`define SEG_UC_I 7'b1001111   // shown like '1'
`define SEG_UC_J 7'b1000011
`define SEG_UC_K 7'b1001000   // approx as 'H'
`define SEG_UC_L 7'b1110001
`define SEG_UC_M 7'b0101011   // approx
`define SEG_UC_N 7'b1101010   // approx
`define SEG_UC_O 7'b0000001   // same as '0'
`define SEG_UC_P 7'b0011000
`define SEG_UC_Q 7'b0000100   // approx as '9'
`define SEG_UC_R 7'b1111010   // approx
`define SEG_UC_S 7'b0100100   // same as '5'
`define SEG_UC_T 7'b1110000   // approx
`define SEG_UC_U 7'b1000001
`define SEG_UC_V 7'b1000001   // same as 'U'
`define SEG_UC_W 7'b1000001   // approx
`define SEG_UC_X 7'b1001000   // approx as 'H'
`define SEG_UC_Y 7'b1000100
`define SEG_UC_Z 7'b0010010   // same as '2'

// lowercase letters
`define SEG_LC_A 7'b0001000
`define SEG_LC_B 7'b1100000
`define SEG_LC_C 7'b1110010   // small c approximation
`define SEG_LC_D 7'b1000010
`define SEG_LC_E 7'b0010000   // small e approximation
`define SEG_LC_F 7'b0111000
`define SEG_LC_G 7'b0000100   // approx
`define SEG_LC_H 7'b1101000
`define SEG_LC_I 7'b1001111
`define SEG_LC_J 7'b1000011
`define SEG_LC_K 7'b1001000   // approx
`define SEG_LC_L 7'b1110001
`define SEG_LC_M 7'b0101011   // approx
`define SEG_LC_N 7'b1101010
`define SEG_LC_O 7'b1100010
`define SEG_LC_P 7'b0011000
`define SEG_LC_Q 7'b0001100   // approx
`define SEG_LC_R 7'b1111010
`define SEG_LC_S 7'b0100100
`define SEG_LC_T 7'b1110000
`define SEG_LC_U 7'b1100011
`define SEG_LC_V 7'b1000001   // approx
`define SEG_LC_W 7'b1000001   // approx
`define SEG_LC_X 7'b1001000   // approx
`define SEG_LC_Y 7'b1000100
`define SEG_LC_Z 7'b0010010   // same as '2'

`endif