`timescale 1ps/1ps

module example_top #(
//traffic generator (test Read/Write Pattern Gen) Parameters
   parameter PORT_MODE             = "BI_MODE",
   parameter DATA_MODE             = 4'b0010,
   parameter TST_MEM_INSTR_MODE    = "R_W_INSTR_MODE",
   parameter EYE_TEST              = "FALSE",
   parameter DATA_PATTERN          = "DGEN_ALL",
   parameter CMD_PATTERN           = "CGEN_ALL",
   parameter CMD_WDT               = 'h3FF,
   parameter WR_WDT                = 'h1FFF,
   parameter RD_WDT                = 'h3FF,
   parameter SEL_VICTIM_LINE       = 0,
   parameter BEGIN_ADDRESS         = 32'h00000000,
   parameter END_ADDRESS           = 32'h00ffffff,
   parameter PRBS_EADDR_MASK_POS   = 32'hff000000,
//Memory Composer Parameter
   parameter BANK_WIDTH            = 3,        //Memory Bank Address Width. bank==8 in this case)
   parameter COL_WIDTH             = 10,       //Memory COlumn Address Width
   parameter CS_WIDTH              = 1,        //Chip Select Width. Single Chip in this case.
   parameter DQ_WIDTH              = 16,       //Externel DDR dataBus Width. 16Bit interface in this case.
   parameter DQS_WIDTH             = 2,        //Data strobe Width. (Synchronous Signal for DQ capture timing) One DQS per 8bit in this case.
   parameter DQS_CNT_WIDTH         = 1,        //ceillog2(DQS_WIDTH). Necessary Bit-Width for indexing DQS_WIDTH.
   parameter DRAM_WIDTH            = 8,        //DQ Width per DRAM component. One DQS per 8bit in this case.
   parameter RANKS                 = 1,        //Memory RANK
   parameter ROW_WIDTH             = 13,       //
   parameter ADDR_WIDTH            = 27,       //
   parameter BURST_MODE            = "8",      //
   parameter DRAM_TYPE             = "DDR2",   //
//Controller Option
   parameter ECC                   = "OFF",    //
   parameter ECC_TEST              = "OFF",    //
   parameter nBANK_MACHS           = 4,        //
   parameter nCK_PER_CLK           = 2,        //
   parameter DEBUG_PORT            = "OFF",    //
//Simulation Option
   parameter SIMULATION            = "FALSE",
   parameter TCQ                   = 100
   )(
   inout [15:0]						ddr2_dq,            //dataBus
   inout [1:0]						ddr2_dqs_n,         //DQ Strobe Negative
   inout [1:0]						ddr2_dqs_p,         //DQ Strobe Positive
   output [12:0]					ddr2_addr,          //Address (when ACTIVE=>row | READ/WRITE=>column | LOAD=>mode register setting)
   output [2:0]						ddr2_ba,            //Bank Address. Select Bank for given mode. In LOADE MODE, it used for selecting mode register
   output 							ddr2_ras_n,         //Active Low Signal for Core command
   output							ddr2_cas_n,         //Active Low Signal for Core command
   output							ddr2_we_n,          //Active Low Signal for Core command
   output [0:0]						ddr2_ck_p,          //Differencial Clock for DDR2
   output [0:0]						ddr2_ck_n,          //Differencial Clock for DDR2
   output [0:0]						ddr2_cke,           //Clock Enable
   output [0:0]						ddr2_cs_n,          //Chip Select. There is only one chip in this case, thus 0-width bus.
   output [1:0]						ddr2_dm,            //Write Data Mask. Select Byte that'll not be written.
   output [0:0]						ddr2_odt,           //On-Die Termination. If high, DDR2 internal terminal Resistor is turned-on for Signal Quality

   input							sys_clk_i,          //MIG system CLK
   output							tg_compare_error,   //Compare Error Signal for Test-Generator
   output							init_calib_complete,//Initialization Complete Signal for MIG PHY
   input							sys_rst             //
   );

function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction

  function integer STR_TO_INT;
    input [7:0] in;
    begin
      if(in == "8")
        STR_TO_INT = 8;
      else if(in == "4")
        STR_TO_INT = 4;
      else
        STR_TO_INT = 0;
    end
  endfunction

  localparam DATA_WIDTH            = 16;
  localparam RANK_WIDTH            = clogb2(RANKS);
  localparam PAYLOAD_WIDTH         = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
  localparam BURST_LENGTH          = STR_TO_INT(BURST_MODE);
  localparam APP_DATA_WIDTH        = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
  localparam APP_MASK_WIDTH        = APP_DATA_WIDTH / 8;

  localparam  TG_ADDR_WIDTH        = ((CS_WIDTH == 1) ? 0 : RANK_WIDTH) + BANK_WIDTH + ROW_WIDTH + COL_WIDTH;
  localparam MASK_SIZE             = DATA_WIDTH/8;

  wire [(2*nCK_PER_CLK)-1:0]            app_ecc_multiple_err;
  wire [(2*nCK_PER_CLK)-1:0]            app_ecc_single_err;
  wire [ADDR_WIDTH-1:0]                 app_addr;
  wire [2:0]                            app_cmd;
  wire                                  app_en;
  wire                                  app_rdy;
  wire [APP_DATA_WIDTH-1:0]             app_rd_data;
  wire                                  app_rd_data_end;
  wire                                  app_rd_data_valid;
  wire [APP_DATA_WIDTH-1:0]             app_wdf_data;
  wire                                  app_wdf_end;
  wire [APP_MASK_WIDTH-1:0]             app_wdf_mask;
  wire                                  app_wdf_rdy;
  wire                                  app_sr_active;
  wire                                  app_ref_ack;
  wire                                  app_zq_ack;
  wire                                  app_wdf_wren;
  wire [(64+(2*APP_DATA_WIDTH))-1:0]    error_status;
  wire [(PAYLOAD_WIDTH/8)-1:0]          cumlative_dq_lane_error;
  wire                                  mem_pattern_init_done;
  wire [47:0]                           tg_wr_data_counts;
  wire [47:0]                           tg_rd_data_counts;
  wire                                  modify_enable_sel;
  wire [2:0]                            data_mode_manual_sel;
  wire [2:0]                            addr_mode_manual_sel;
  wire [APP_DATA_WIDTH-1:0]             cmp_data;
  reg [63:0]                            cmp_data_r;
  wire                                  cmp_data_valid;
  reg                                   cmp_data_valid_r;
  wire                                  cmp_error;
  wire [(PAYLOAD_WIDTH/8)-1:0]          dq_error_bytelane_cmp;
  wire                                  clk;
  wire                                  rst;
  wire                                  dbg_sel_pi_incdec;
  wire                                  dbg_pi_f_inc;
  wire                                  dbg_pi_f_dec;
  wire                                  dbg_sel_po_incdec;
  wire                                  dbg_po_f_inc;
  wire                                  dbg_po_f_stg23_sel;
  wire                                  dbg_po_f_dec;
  wire                                  vio_modify_enable;
  wire [3:0]                            vio_data_mode_value;
  wire                                  vio_pause_traffic;
  wire [2:0]                            vio_addr_mode_value;
  wire [3:0]                            vio_instr_mode_value;
  wire [1:0]                            vio_bl_mode_value;
  wire [9:0]                            vio_fixed_bl_value;
  wire [2:0]                            vio_fixed_instr_value;
  wire                                  vio_data_mask_gen;
  wire                                  vio_tg_rst;
  wire                                  vio_dbg_sel_pi_incdec;
  wire                                  vio_dbg_pi_f_inc;
  wire                                  vio_dbg_pi_f_dec;
  wire                                  vio_dbg_sel_po_incdec;
  wire                                  vio_dbg_po_f_inc;
  wire                                  vio_dbg_po_f_stg23_sel;
  wire                                  vio_dbg_po_f_dec;

  memory #() u_memory(
       .ddr2_addr                      (ddr2_addr),
       .ddr2_ba                        (ddr2_ba),
       .ddr2_cas_n                     (ddr2_cas_n),
       .ddr2_ck_n                      (ddr2_ck_n),
       .ddr2_ck_p                      (ddr2_ck_p),
       .ddr2_cke                       (ddr2_cke),
       .ddr2_ras_n                     (ddr2_ras_n),
       .ddr2_we_n                      (ddr2_we_n),
       .ddr2_dq                        (ddr2_dq),
       .ddr2_dqs_n                     (ddr2_dqs_n),
       .ddr2_dqs_p                     (ddr2_dqs_p),
       .init_calib_complete            (init_calib_complete),
       .ddr2_cs_n                      (ddr2_cs_n),
       .ddr2_dm                        (ddr2_dm),
       .ddr2_odt                       (ddr2_odt),
       .app_addr                       (app_addr),
       .app_cmd                        (app_cmd),
       .app_en                         (app_en),
       .app_wdf_data                   (app_wdf_data),
       .app_wdf_end                    (app_wdf_end),
       .app_wdf_wren                   (app_wdf_wren),
       .app_rd_data                    (app_rd_data),
       .app_rd_data_end                (app_rd_data_end),
       .app_rd_data_valid              (app_rd_data_valid),
       .app_rdy                        (app_rdy),
       .app_wdf_rdy                    (app_wdf_rdy),
       .app_sr_req                     (1'b0),
       .app_ref_req                    (1'b0),
       .app_zq_req                     (1'b0),
       .app_sr_active                  (app_sr_active),
       .app_ref_ack                    (app_ref_ack),
       .app_zq_ack                     (app_zq_ack),
       .ui_clk                         (clk),
       .ui_clk_sync_rst                (rst),
       .app_wdf_mask                   (app_wdf_mask),

       .sys_clk_i                       (sys_clk_i),
       .sys_rst                        (sys_rst));

  mig_7series_v4_2_traffic_gen_top #
    (
     .TCQ                 (TCQ),
     .SIMULATION          (SIMULATION),
     .FAMILY              ("VIRTEX7"),
     .MEM_TYPE            (DRAM_TYPE),
     .TST_MEM_INSTR_MODE  (TST_MEM_INSTR_MODE),
     //.BL_WIDTH            (BL_WIDTH),
     .nCK_PER_CLK         (nCK_PER_CLK),
     .NUM_DQ_PINS         (PAYLOAD_WIDTH),
     .MEM_BURST_LEN       (BURST_LENGTH),
     .MEM_COL_WIDTH       (COL_WIDTH),
     .PORT_MODE           (PORT_MODE),
     .DATA_PATTERN        (DATA_PATTERN),
     .CMD_PATTERN         (CMD_PATTERN),
     .DATA_WIDTH          (APP_DATA_WIDTH),
     .ADDR_WIDTH          (TG_ADDR_WIDTH),
     .MASK_SIZE           (MASK_SIZE),
     .BEGIN_ADDRESS       (BEGIN_ADDRESS),
     .DATA_MODE           (DATA_MODE),
     .END_ADDRESS         (END_ADDRESS),
     .PRBS_EADDR_MASK_POS (PRBS_EADDR_MASK_POS),
     .SEL_VICTIM_LINE     (SEL_VICTIM_LINE),
     .CMD_WDT             (CMD_WDT),
     .RD_WDT              (RD_WDT),
     .WR_WDT              (WR_WDT),
     .EYE_TEST            (EYE_TEST)
     ) 
	 u_traffic_gen_top(
       .clk                  (clk),
       .rst                  (rst),
       .tg_only_rst          (po_win_tg_rst | vio_tg_rst),
       .manual_clear_error   (manual_clear_error),
       .memc_init_done       (init_calib_complete),
       .memc_cmd_full        (~app_rdy),
       .memc_cmd_en          (app_en),
       .memc_cmd_instr       (app_cmd),
       .memc_cmd_bl          (),
       .memc_cmd_addr        (app_addr),
       .memc_wr_en           (app_wdf_wren),
       .memc_wr_end          (app_wdf_end),
       .memc_wr_mask         (app_wdf_mask),
       .memc_wr_data         (app_wdf_data),
       .memc_wr_full         (~app_wdf_rdy),
       .memc_rd_en           (),
       .memc_rd_data         (app_rd_data),
       .memc_rd_empty        (~app_rd_data_valid),
       .qdr_wr_cmd_o         (),
       .qdr_rd_cmd_o         (),
       .vio_pause_traffic    (vio_pause_traffic),
       .vio_modify_enable    (vio_modify_enable),
       .vio_data_mode_value  (vio_data_mode_value),
       .vio_addr_mode_value  (vio_addr_mode_value),
       .vio_instr_mode_value (vio_instr_mode_value),
       .vio_bl_mode_value    (vio_bl_mode_value),
       .vio_fixed_bl_value   (vio_fixed_bl_value),
       .vio_fixed_instr_value(vio_fixed_instr_value),
       .vio_data_mask_gen    (vio_data_mask_gen),
       .fixed_addr_i         (32'b0),
       .fixed_data_i         (32'b0),
       .simple_data0         (32'b0),
       .simple_data1         (32'b0),
       .simple_data2         (32'b0),
       .simple_data3         (32'b0),
       .simple_data4         (32'b0),
       .simple_data5         (32'b0),
       .simple_data6         (32'b0),
       .simple_data7         (32'b0),
       .wdt_en_i             (wdt_en_w),
       .bram_cmd_i           (39'b0),
       .bram_valid_i         (1'b0),
       .bram_rdy_o           (),
       .cmp_data             (cmp_data),
       .cmp_data_valid       (cmp_data_valid),
       .cmp_error            (cmp_error),
       .wr_data_counts       (tg_wr_data_counts),
       .rd_data_counts       (tg_rd_data_counts),
       .dq_error_bytelane_cmp (dq_error_bytelane_cmp),
       .error                (tg_compare_error),
       .error_status         (error_status),
       .cumlative_dq_lane_error (cumlative_dq_lane_error),
       .cmd_wdt_err_o         (cmd_wdt_err_w),
       .wr_wdt_err_o          (wr_wdt_err_w),
       .rd_wdt_err_o          (rd_wdt_err_w),
       .mem_pattern_init_done   (mem_pattern_init_done)
       );

   assign vio_modify_enable     = 1'b0;
   assign vio_data_mode_value   = 4'b0010;
   assign vio_addr_mode_value   = 3'b011;
   assign vio_instr_mode_value  = 4'b0010;
   assign vio_bl_mode_value     = 2'b10;
   assign vio_fixed_bl_value    = 8'd16;
   assign vio_data_mask_gen     = 1'b0;
   assign vio_pause_traffic     = 1'b0;
   assign vio_fixed_instr_value = 3'b001;
   assign dbg_clear_error       = 1'b0;
   assign po_win_tg_rst         = 1'b0;
   assign vio_tg_rst            = 1'b0;
   assign wdt_en_w              = 1'b1;
   assign dbg_sel_pi_incdec       = 'b0;
   assign dbg_sel_po_incdec       = 'b0;
   assign dbg_pi_f_inc            = 'b0;
   assign dbg_pi_f_dec            = 'b0;
   assign dbg_po_f_inc            = 'b0;
   assign dbg_po_f_dec            = 'b0;
   assign dbg_po_f_stg23_sel      = 'b0;
endmodule