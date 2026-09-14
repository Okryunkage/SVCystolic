// Auto-generated fixed-point parameters for Verilog
// Model: 8 -> 32 -> 5
//
// IMPORTANT:
// fc1 weight/bias scaling : real ~= int / 2^W1_FRAC
// fc2 weight scaling      : real ~= int / 2^W2_FRAC
// fc2 bias scaling        : real ~= int / 2^(W1_FRAC + W2_FRAC)
//
/*
localparam integer IN_N_FILE   = 8;
localparam integer HID_N_FILE  = 32;
localparam integer OUT_N_FILE  = 5;

localparam integer W1_W_FILE   = 8;
localparam integer B1_W_FILE   = 16;
localparam integer W2_W_FILE   = 8;
localparam integer B2_W_FILE   = 32;

localparam integer W1_FRAC_FILE = 4;
localparam integer B1_FRAC_FILE = 4;
localparam integer W2_FRAC_FILE = 4;
localparam integer B2_FRAC_FILE = 8;
*/

localparam integer FC1_WW = 2048;
localparam integer FC1_BW = 512;
localparam integer FC2_WW = 1280;
localparam integer FC2_BW = 160;

localparam [FC1_WW-1:0] fc1_w_flat = { 8'h18, 8'hF6, 8'hFC, 8'h12, 8'hE7, 8'hF3, 8'hFA, 8'hED, 8'hDD, 8'h24, 8'h11, 8'h0B, 8'hDF, 8'hE9, 8'h12, 8'h0B, 8'h18, 8'h07, 8'hFF, 8'h02, 8'h17, 8'h11, 8'h1B, 8'h01, 8'h09, 8'h1E, 8'hF3, 8'hE9, 8'hF7, 8'hE4, 8'hF3, 8'hE9, 8'h1E, 8'h13, 8'h0C, 8'h03, 8'h22, 8'h14, 8'h09, 8'h02, 8'h01, 8'h00, 8'hFF, 8'h01, 8'hFF, 8'h00, 8'h01, 8'h02, 8'h05, 8'hA1, 8'h2B, 8'h14, 8'hF1, 8'hA1, 8'h2B, 8'h16, 8'h03, 8'hD3, 8'h20, 8'h09, 8'hF6, 8'hCF, 8'h20, 8'h0A, 8'h01, 8'h00, 8'h21, 8'hD7, 8'hFF, 8'hFF, 8'hDE, 8'h22, 8'h00, 8'h2B, 8'hDB, 8'hF1, 8'hFB, 8'h34, 8'hDA, 8'hF1, 8'hEA, 8'h07, 8'h14, 8'h25, 8'h13, 8'h09, 8'hF8, 8'hD1, 8'h0E, 8'hC9, 8'hFC, 8'hF8, 8'hDD, 8'hC9, 8'hFB, 8'hFA, 8'hFF, 8'h00, 8'h25, 8'h0B, 8'h00, 8'h00, 8'h25, 8'hD8, 8'hFB, 8'hFB, 8'hFC, 8'hFD, 8'hFE, 8'h02, 8'hFD, 8'hFB, 8'h1A, 8'h13, 8'h1B, 8'h13, 8'h1E, 8'h16, 8'h0D, 8'hF6, 8'hFF, 8'h04, 8'h00, 8'hFC, 8'h01, 8'hFF, 8'hFB, 8'hFE, 8'hE0, 8'h04, 8'hFE, 8'hD2, 8'hF4, 8'h03, 8'hFF, 8'h22, 8'h03, 8'hFE, 8'h1C, 8'hD3, 8'h02, 8'hFE, 8'h1C, 8'hCE, 8'h2E, 8'hE4, 8'hF4, 8'hFB, 8'hCA, 8'hE7, 8'hF4, 8'hF9, 8'hD2, 8'h09, 8'h0D, 8'h0D, 8'hE4, 8'h10, 8'h0E, 8'h08, 8'hDC, 8'hE2, 8'h06, 8'h07, 8'hE2, 8'h0D, 8'h06, 8'h06, 8'hEF, 8'hFE, 8'hFF, 8'h24, 8'hEF, 8'hFD, 8'hFD, 8'hD9, 8'hFE, 8'hE2, 8'h06, 8'h24, 8'h01, 8'hE2, 8'h05, 8'h23, 8'h20, 8'hFD, 8'h20, 8'hEA, 8'h0D, 8'hF8, 8'h14, 8'h0F, 8'h02, 8'h02, 8'h1B, 8'h0A, 8'hFD, 8'h01, 8'hDD, 8'h1D, 8'h17, 8'h10, 8'h19, 8'h0E, 8'h27, 8'h15, 8'h0B, 8'hF6, 8'hCD, 8'h0F, 8'h0E, 8'h09, 8'hDC, 8'h17, 8'h11, 8'h09, 8'h00, 8'h00, 8'h35, 8'hD6, 8'h01, 8'hFF, 8'hC9, 8'hE8, 8'h0B, 8'hD1, 8'hEA, 8'hEC, 8'hF2, 8'h3A, 8'hEA, 8'hEC, 8'h05, 8'h02, 8'h1F, 8'h1F, 8'hFB, 8'h02, 8'h1C, 8'h02, 8'h01, 8'h00, 8'hCA, 8'hE7, 8'h01, 8'hFF, 8'h30, 8'hE2, 8'h2B, 8'hE7, 8'hF5, 8'hFA, 8'hD0, 8'hE7, 8'hF5, 8'hFB };
localparam [FC1_BW-1:0] fc1_b_flat = { 16'h0017, 16'h0009, 16'hFFE8, 16'h0022, 16'hFFD4, 16'hFFFB, 16'hFFF2, 16'h001C, 16'h0009, 16'hFFF4, 16'hFFF0, 16'h002E, 16'hFFF9, 16'hFFFB, 16'hFFFA, 16'hFFFB, 16'h0015, 16'h0012, 16'h0009, 16'h0016, 16'h0029, 16'h0019, 16'hFFF5, 16'hFFFD, 16'hFFFC, 16'hFFFC, 16'h0017, 16'h000C, 16'h0009, 16'hFFDE, 16'h0007, 16'h0007 };

localparam [FC2_WW-1:0] fc2_w_flat = { 8'hFC, 8'hE7, 8'h15, 8'hD0, 8'h1D, 8'hFF, 8'hCD, 8'hFB, 8'h04, 8'h1F, 8'hF0, 8'hFD, 8'hF0, 8'hFC, 8'h14, 8'h02, 8'hDE, 8'h08, 8'hDF, 8'hED, 8'hE3, 8'hE9, 8'hF0, 8'h19, 8'hF7, 8'h12, 8'hEA, 8'hE6, 8'hCA, 8'h1F, 8'hE0, 8'hDF, 8'hCE, 8'h1C, 8'hF1, 8'hE7, 8'hE7, 8'hFE, 8'h05, 8'hED, 8'hF6, 8'h0E, 8'hE6, 8'hD0, 8'hF9, 8'hFD, 8'h0C, 8'h02, 8'h15, 8'h0A, 8'h57, 8'hEE, 8'h2F, 8'h21, 8'hFC, 8'h02, 8'hFB, 8'h11, 8'hD5, 8'h07, 8'hDE, 8'h11, 8'h06, 8'h4C, 8'h00, 8'h10, 8'h05, 8'h2F, 8'h07, 8'h02, 8'h72, 8'hC3, 8'h02, 8'hB3, 8'hFD, 8'hC3, 8'hFA, 8'h00, 8'h07, 8'hFE, 8'hFB, 8'hF5, 8'h0E, 8'hFD, 8'h0A, 8'hFA, 8'hDC, 8'hFA, 8'h02, 8'h04, 8'h08, 8'hF0, 8'h3E, 8'hFC, 8'hEE, 8'h16, 8'hF5, 8'h03, 8'h0A, 8'hF6, 8'hFE, 8'h01, 8'h03, 8'h02, 8'hC8, 8'hFA, 8'hE3, 8'hF8, 8'h43, 8'h01, 8'hFF, 8'h02, 8'h05, 8'hBC, 8'h0C, 8'hFF, 8'h00, 8'hF0, 8'hFD, 8'h07, 8'h2B, 8'hFD, 8'h06, 8'h47, 8'hFA, 8'hCD, 8'h37, 8'h06, 8'h1C, 8'hFE, 8'h00, 8'hE2, 8'h01, 8'h01, 8'h03, 8'h0C, 8'h27, 8'hF8, 8'h21, 8'hEC, 8'h19, 8'hFF, 8'hFC, 8'h01, 8'h2A, 8'hC7, 8'hFD, 8'hE6, 8'hF4, 8'h2B, 8'hD9, 8'h15, 8'hE6, 8'hFF, 8'h10, 8'hE0, 8'hF0, 8'hE1, 8'hF9, 8'h0D };
localparam [FC2_BW-1:0] fc2_b_flat = { 32'hFFFFFF66, 32'hFFFFFFA4, 32'h0000002A, 32'hFFFFFF59, 32'h00000023 };
