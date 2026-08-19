`timescale 1ns/1ps
`default_nettype none

// ============================================================
// controller.v  —  ILA/debug/samp_sel 제거 버전
//
// SWEEP_EN=0: FIXED_XOR_NUM_SEL 고정, SW0으로 1회 측정 후 IDLE
// SWEEP_EN=1: xor_num_sel = 3,5,...,51 자동 sweep
//
// 헤더 프로토콜:
//   [0x55 × PRE_HEADER]
//   [(AA A5 5A A2)(CFG) × START_REP]
//   [payload TOTAL_BITS/8 bytes]
//   [(DE AD BE EF)(CFG) × END_REP]
// ============================================================

module controller #(
    parameter integer TOTAL_BITS        = 10_000_000,
    parameter integer FIFO_BYTES        = 4096,
    parameter integer ADDR_W            = $clog2(FIFO_BYTES),
    parameter integer GAP_CYCLES        = 100_000,

    parameter integer SWEEP_EN          = 0,
    parameter integer FIXED_XOR_NUM_SEL = 51,

    parameter integer PRE_HEADER        = 256,
    parameter integer START_REP         = 5,
    parameter integer END_REP           = 5
)(
    input  wire       clk,
    input  wire       sw0,
    input  wire       btnc,
    input  wire       rng_bit,
    input  wire       uart_busy,

    output reg        uart_rst   = 1'b1,
    output reg        uart_start = 1'b0,
    output reg  [7:0] uart_data  = 8'h00,

    output reg  [5:0] xor_num_sel = FIXED_XOR_NUM_SEL[5:0]
);

    // ============================================================
    // SW0 상승 에지 (3단 동기화)
    // ============================================================
    reg [2:0] sw_sync = 3'b0;
    always @(posedge clk) sw_sync <= {sw_sync[1:0], sw0};
    wire start_pulse = sw_sync[1] & ~sw_sync[2];

    // ============================================================
    // BTNC 상승 에지 (리셋)
    // ============================================================
    reg [2:0] btn_sync = 3'b0;
    always @(posedge clk) btn_sync <= {btn_sync[1:0], btnc};
    wire rst_pulse = btn_sync[1] & ~btn_sync[2];

    // ============================================================
    // UART reset stretch
    // ============================================================
    localparam integer UART_RST_CYCLES = 5000;
    reg [15:0] uart_rst_cnt = 16'd0;

    // ============================================================
    // FIFO (LUTRAM: FIFO_BYTES가 작아서 BRAM 불가)
    // ============================================================
    (* ram_style = "distributed" *) reg [7:0] fifo_mem [0:FIFO_BYTES-1];

    reg [ADDR_W-1:0] wr_ptr    = {ADDR_W{1'b0}};
    reg [ADDR_W-1:0] rd_ptr    = {ADDR_W{1'b0}};
    reg [ADDR_W:0]   fifo_count = {(ADDR_W+1){1'b0}};

    wire fifo_full  = (fifo_count == FIFO_BYTES[ADDR_W:0]);
    wire fifo_empty = (fifo_count == {(ADDR_W+1){1'b0}});

    localparam integer TARGET_BYTES = (TOTAL_BITS + 7) / 8;

    reg [31:0] produced_bits = 32'd0;
    reg [31:0] sent_bytes    = 32'd0;

    // ============================================================
    // 1bit → 8bit 패킹
    // ============================================================
    reg [7:0] pack_byte = 8'd0;
    reg [2:0] pack_cnt  = 3'd0;

    // ============================================================
    // FIFO read pipeline
    // ============================================================
    reg [7:0] rd_data  = 8'h00;
    reg       rd_valid = 1'b0;

    // ============================================================
    // UART pending
    // ============================================================
    reg [7:0] pending_byte = 8'h00;
    reg       pending      = 1'b0;

    // ============================================================
    // FSM
    // ============================================================
    localparam [3:0]
        S_IDLE   = 4'd0,
        S_PRE    = 4'd1,
        S_START  = 4'd2,
        S_STREAM = 4'd3,
        S_END    = 4'd4,
        S_GAP    = 4'd5,
        S_NEXT   = 4'd6;

    reg [3:0]  state         = S_IDLE;
    reg        producer_done = 1'b0;
    reg        drain_done    = 1'b0;
    reg [31:0] gap_cnt       = 32'd0;
    reg [15:0] preh_cnt      = 16'd0;
    reg [2:0]  start_rep_cnt = 3'd0;
    reg [2:0]  end_rep_cnt   = 3'd0;
    reg [2:0]  blk_idx       = 3'd0;

    wire [31:0] inflight = sent_bytes + (rd_valid ? 32'd1 : 32'd0);
    wire [7:0]  wr_data_full = {rng_bit, pack_byte[6:0]};
    wire        allow_stream = (state == S_STREAM) && !uart_rst;
    wire        can_enqueue  = (!pending && !uart_busy && !uart_rst);

    // CFG 바이트: xor_num_sel만 (samp_sel 제거)
    wire [7:0] cfg_byte = {2'd0, xor_num_sel};

    // START 매직: AA A5 5A A2
    function automatic [7:0] start_magic(input [2:0] i);
        case (i)
            3'd0: start_magic = 8'hAA;
            3'd1: start_magic = 8'hA5;
            3'd2: start_magic = 8'h5A;
            default: start_magic = 8'hA2;
        endcase
    endfunction

    // END 매직: DE AD BE EF
    function automatic [7:0] end_magic(input [2:0] i);
        case (i)
            3'd0: end_magic = 8'hDE;
            3'd1: end_magic = 8'hAD;
            3'd2: end_magic = 8'hBE;
            default: end_magic = 8'hEF;
        endcase
    endfunction

    // push/pop fire
    wire pop_fire =
        allow_stream && !rd_valid && !fifo_empty &&
        (inflight < TARGET_BYTES[31:0]);

    wire push_full_fire =
        allow_stream && !producer_done &&
        (produced_bits < TOTAL_BITS[31:0]) &&
        !fifo_full && (pack_cnt == 3'd7);

    wire push_flush_fire =
        allow_stream && !producer_done &&
        (produced_bits >= TOTAL_BITS[31:0]) &&
        ((TOTAL_BITS % 8) != 0) &&
        (pack_cnt != 3'd0) && !fifo_full;

    wire push_fire = push_full_fire | push_flush_fire;

    // ============================================================
    // 메인 always
    // ============================================================
    always @(posedge clk) begin
        uart_start <= 1'b0;

        // UART reset stretch
        if (rst_pulse) begin
            uart_rst     <= 1'b1;
            uart_rst_cnt <= 16'd0;
        end else if (uart_rst) begin
            if (uart_rst_cnt == UART_RST_CYCLES[15:0])
                uart_rst <= 1'b0;
            else
                uart_rst_cnt <= uart_rst_cnt + 16'd1;
        end

        // 글로벌 리셋
        if (rst_pulse) begin
            state         <= S_IDLE;
            gap_cnt       <= 32'd0;
            preh_cnt      <= 16'd0;
            start_rep_cnt <= 3'd0;
            end_rep_cnt   <= 3'd0;
            blk_idx       <= 3'd0;
            wr_ptr        <= {ADDR_W{1'b0}};
            rd_ptr        <= {ADDR_W{1'b0}};
            fifo_count    <= {(ADDR_W+1){1'b0}};
            produced_bits <= 32'd0;
            sent_bytes    <= 32'd0;
            pack_byte     <= 8'd0;
            pack_cnt      <= 3'd0;
            rd_data       <= 8'h00;
            rd_valid      <= 1'b0;
            pending_byte  <= 8'h00;
            pending       <= 1'b0;
            uart_data     <= 8'h00;
            producer_done <= 1'b0;
            drain_done    <= 1'b0;
            xor_num_sel   <= FIXED_XOR_NUM_SEL[5:0];

        end else begin

            // ── UART 발사 ────────────────────────────────────────
            if (pending && !uart_busy && !uart_rst) begin
                uart_start <= 1'b1;
                uart_data  <= pending_byte;
                pending    <= 1'b0;
            end

            // ── FIFO pop → rd_data ───────────────────────────────
            if (pop_fire) begin
                rd_data  <= fifo_mem[rd_ptr];
                rd_ptr   <= rd_ptr + 1'b1;
                rd_valid <= 1'b1;
            end

            // ── rd_data → pending ────────────────────────────────
            if (allow_stream && rd_valid && !pending && !uart_busy) begin
                pending_byte <= rd_data;
                pending      <= 1'b1;
                rd_valid     <= 1'b0;
                sent_bytes   <= sent_bytes + 32'd1;
            end

            // ── Producer: bit 수집 → FIFO ────────────────────────
            if (allow_stream && !producer_done) begin
                if (produced_bits < TOTAL_BITS[31:0]) begin
                    if (!fifo_full) begin
                        pack_byte[pack_cnt] <= rng_bit;
                        if (pack_cnt == 3'd7) begin
                            fifo_mem[wr_ptr] <= wr_data_full;
                            wr_ptr    <= wr_ptr + 1'b1;
                            pack_cnt  <= 3'd0;
                            pack_byte <= 8'd0;
                        end else begin
                            pack_cnt <= pack_cnt + 3'd1;
                        end
                        produced_bits <= produced_bits + 32'd1;
                    end
                end else begin
                    if ((TOTAL_BITS % 8) != 0 && pack_cnt != 3'd0) begin
                        if (!fifo_full) begin
                            fifo_mem[wr_ptr] <= pack_byte;
                            wr_ptr        <= wr_ptr + 1'b1;
                            pack_cnt      <= 3'd0;
                            pack_byte     <= 8'd0;
                            producer_done <= 1'b1;
                        end
                    end else begin
                        producer_done <= 1'b1;
                    end
                end
            end

            // ── fifo_count ───────────────────────────────────────
            case ({push_fire, pop_fire})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: ;
            endcase

            // ── drain_done ───────────────────────────────────────
            if (state == S_STREAM) begin
                if ((sent_bytes >= TARGET_BYTES[31:0]) &&
                     fifo_empty && !rd_valid && !pending)
                    drain_done <= 1'b1;
            end

            // ── FSM ──────────────────────────────────────────────
            case (state)

                S_IDLE: begin
                    if (start_pulse && !uart_rst) begin
                        wr_ptr        <= {ADDR_W{1'b0}};
                        rd_ptr        <= {ADDR_W{1'b0}};
                        fifo_count    <= {(ADDR_W+1){1'b0}};
                        produced_bits <= 32'd0;
                        sent_bytes    <= 32'd0;
                        pack_byte     <= 8'd0;
                        pack_cnt      <= 3'd0;
                        rd_data       <= 8'h00;
                        rd_valid      <= 1'b0;
                        pending       <= 1'b0;
                        pending_byte  <= 8'h00;
                        producer_done <= 1'b0;
                        drain_done    <= 1'b0;
                        preh_cnt      <= 16'd0;
                        start_rep_cnt <= 3'd0;
                        end_rep_cnt   <= 3'd0;
                        blk_idx       <= 3'd0;
                        xor_num_sel   <= FIXED_XOR_NUM_SEL[5:0];
                        state         <= S_PRE;
                    end
                end

                // PRE: 0x55 × PRE_HEADER
                S_PRE: begin
                    if (can_enqueue) begin
                        pending_byte <= 8'h55;
                        pending      <= 1'b1;
                        if (preh_cnt == (PRE_HEADER - 1)) begin
                            preh_cnt      <= 16'd0;
                            start_rep_cnt <= 3'd0;
                            blk_idx       <= 3'd0;
                            state         <= S_START;
                        end else begin
                            preh_cnt <= preh_cnt + 16'd1;
                        end
                    end
                end

                // START: (AA A5 5A A2)(CFG) × START_REP
                S_START: begin
                    if (can_enqueue) begin
                        if (blk_idx <= 3'd3)
                            pending_byte <= start_magic(blk_idx);
                        else
                            pending_byte <= cfg_byte;  // blk_idx==4
                        pending <= 1'b1;

                        if (blk_idx == 3'd4) begin
                            blk_idx <= 3'd0;
                            if (start_rep_cnt == (START_REP - 1))
                                state <= S_STREAM;
                            else
                                start_rep_cnt <= start_rep_cnt + 3'd1;
                        end else begin
                            blk_idx <= blk_idx + 3'd1;
                        end
                    end
                end

                S_STREAM: begin
                    if (producer_done && drain_done) begin
                        end_rep_cnt <= 3'd0;
                        blk_idx     <= 3'd0;
                        state       <= S_END;
                    end
                end

                // END: (DE AD BE EF)(CFG) × END_REP
                S_END: begin
                    if (can_enqueue) begin
                        if (blk_idx <= 3'd3)
                            pending_byte <= end_magic(blk_idx);
                        else
                            pending_byte <= cfg_byte;  // blk_idx==4
                        pending <= 1'b1;

                        if (blk_idx == 3'd4) begin
                            blk_idx <= 3'd0;
                            if (end_rep_cnt == (END_REP - 1)) begin
                                gap_cnt <= 32'd0;
                                state   <= S_GAP;
                            end else begin
                                end_rep_cnt <= end_rep_cnt + 3'd1;
                            end
                        end else begin
                            blk_idx <= blk_idx + 3'd1;
                        end
                    end
                end

                S_GAP: begin
                    if (gap_cnt >= GAP_CYCLES[31:0])
                        state <= S_NEXT;
                    else
                        gap_cnt <= gap_cnt + 32'd1;
                end

                // NEXT: sweep 또는 IDLE 복귀
                S_NEXT: begin
                    wr_ptr        <= {ADDR_W{1'b0}};
                    rd_ptr        <= {ADDR_W{1'b0}};
                    fifo_count    <= {(ADDR_W+1){1'b0}};
                    produced_bits <= 32'd0;
                    sent_bytes    <= 32'd0;
                    pack_byte     <= 8'd0;
                    pack_cnt      <= 3'd0;
                    rd_data       <= 8'h00;
                    rd_valid      <= 1'b0;
                    pending       <= 1'b0;
                    pending_byte  <= 8'h00;
                    producer_done <= 1'b0;
                    drain_done    <= 1'b0;
                    preh_cnt      <= 16'd0;
                    start_rep_cnt <= 3'd0;
                    end_rep_cnt   <= 3'd0;
                    blk_idx       <= 3'd0;

                    if (SWEEP_EN != 0) begin
                        if (xor_num_sel < 6'd51) begin
                            xor_num_sel <= xor_num_sel + 6'd2;
                            state       <= S_PRE;
                        end else begin
                            xor_num_sel <= FIXED_XOR_NUM_SEL[5:0];
                            state       <= S_IDLE;
                        end
                    end else begin
                        xor_num_sel <= FIXED_XOR_NUM_SEL[5:0];
                        state       <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
