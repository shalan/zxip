// SPDX-License-Identifier: Apache-2.0
// RO direct-mapped cache, phys-tagged + next-line prefetch (Verilog-2005)
// Geometry: XIP_CACHE_LINES (8|16) x XIP_LINE_BYTES (8|16)
// Host beat width: HOST_DW 16|32 (parameter)
`timescale 1ns / 1ps

module zxip_cache #(
    parameter integer HOST_DW = 16
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        inv_all,
    input  wire        prefetch_en,

    input  wire        lookup_req,
    input  wire [19:0] lookup_phys,
    // AHB HSIZE: 000=byte, 001=half, 010=word (word only if HOST_DW>=32)
    input  wire [2:0]  lookup_size,
    output reg         lookup_hit,
    output reg         lookup_miss,
    output reg [HOST_DW-1:0] lookup_rdata,
    output reg         lookup_ready,

    output reg         fill_req,
    output reg [19:0]  fill_phys,
    input  wire        fill_busy,
    input  wire        fill_done,
    input  wire [127:0] fill_line,
    input  wire        fill_err
);

    `include "zxip_pkg_params.vh"

    localparam integer NUM_LINES  = `XIP_CACHE_LINES;
    localparam integer LINE_BYTES = `XIP_LINE_BYTES;
    localparam integer LINE_BITS  = LINE_BYTES * 8;
    localparam integer OFF_W      = (LINE_BYTES == 16) ? 4 : 3;
    localparam integer IDX_W      = (NUM_LINES  == 16) ? 4 : 3;
    localparam integer TAG_W      = 20 - OFF_W - IDX_W;
    localparam [13:0]  LAST_LINE_IN_WIN = (14'h3FFF >> OFF_W);

    // synthesis translate_off
    initial begin
        if (HOST_DW != 16 && HOST_DW != 32) begin
            $display("ERROR: zxip_cache HOST_DW must be 16 or 32 (got %0d)", HOST_DW);
            $finish;
        end
        if (HOST_DW == 32 && LINE_BYTES < 4) begin
            $display("ERROR: zxip_cache HOST_DW=32 needs LINE_BYTES >= 4");
            $finish;
        end
    end
    // synthesis translate_on

    reg                valid [0:NUM_LINES-1];
    reg [TAG_W-1:0]    tag   [0:NUM_LINES-1];
    reg [LINE_BITS-1:0] data [0:NUM_LINES-1];

    integer i;

    wire [IDX_W-1:0] idx       = lookup_phys[OFF_W +: IDX_W];
    wire [TAG_W-1:0] tag_w     = lookup_phys[19 : (OFF_W+IDX_W)];
    wire [OFF_W-1:0] off       = lookup_phys[OFF_W-1:0];
    wire [19:0]      line_base = {lookup_phys[19:OFF_W], {OFF_W{1'b0}}};

    localparam CS_IDLE    = 3'd0;
    localparam CS_MISS    = 3'd1;
    localparam CS_WAIT    = 3'd2;
    localparam CS_REPLY   = 3'd3;
    localparam CS_REPLY2  = 3'd4;
    localparam CS_PF_MISS = 3'd5;
    localparam CS_PF_WAIT = 3'd6;

    reg [2:0]          cstate;
    reg [19:0]         pend_phys;
    reg [2:0]          pend_size;
    reg [IDX_W-1:0]    pend_idx;
    reg [TAG_W-1:0]    pend_tag;
    reg [OFF_W-1:0]    pend_off;
    reg [HOST_DW-1:0]  pend_rdata;

    reg                pf_pending;
    reg [19:0]         pf_phys;
    reg                demand_fill;
    reg                dem_hold;
    reg [19:0]         dem_phys;
    reg [2:0]          dem_size;

    wire [IDX_W-1:0] dem_idx = dem_phys[OFF_W +: IDX_W];
    wire [TAG_W-1:0] dem_tag = dem_phys[19 : (OFF_W+IDX_W)];
    wire [OFF_W-1:0] dem_off = dem_phys[OFF_W-1:0];
    wire [19:0]      dem_base = {dem_phys[19:OFF_W], {OFF_W{1'b0}}};

    wire [IDX_W-1:0] pf_idx  = pf_phys[OFF_W +: IDX_W];
    wire [TAG_W-1:0] pf_tag  = pf_phys[19 : (OFF_W+IDX_W)];

    // Little-endian extract; size = HSIZE
    function [HOST_DW-1:0] extract_beat;
        input [LINE_BITS-1:0] line;
        input [OFF_W-1:0]     byte_off;
        input [2:0]           size;
        reg   [OFF_W-1:0]     bo;
        reg   [31:0]          w32;
        begin
            extract_beat = {HOST_DW{1'b0}};
            if (size == `XIP_HSIZE_BYTE) begin
                extract_beat[7:0] = line[byte_off*8 +: 8];
            end else if (size == `XIP_HSIZE_HALF) begin
                bo = {byte_off[OFF_W-1:1], 1'b0};
                extract_beat[15:0] = {line[(bo+1)*8 +: 8], line[bo*8 +: 8]};
            end else begin
                // word (or treat larger as word when HOST_DW>=32)
                bo = {byte_off[OFF_W-1:2], 2'b00};
                w32 = {line[(bo+3)*8 +: 8], line[(bo+2)*8 +: 8],
                       line[(bo+1)*8 +: 8], line[bo*8 +: 8]};
                if (HOST_DW >= 32)
                    extract_beat = w32[HOST_DW-1:0];
                else
                    extract_beat[15:0] = w32[15:0];
            end
        end
    endfunction

    function automatic in_window_next;
        input [19:0] base;
        reg   [13:0] li;
        begin
            li = base[13:0] >> OFF_W;
            in_window_next = (li != LAST_LINE_IN_WIN);
        end
    endfunction

    wire [19:0]      next_line = line_base + LINE_BYTES;
    wire [IDX_W-1:0] next_idx  = next_line[OFF_W +: IDX_W];
    wire [TAG_W-1:0] next_tag  = next_line[19 : (OFF_W+IDX_W)];
    wire             next_hit  = valid[next_idx] && (tag[next_idx] == next_tag);
    wire             can_pf    = prefetch_en && in_window_next(line_base) && !next_hit;

    wire [19:0]      pf_next     = pf_phys + LINE_BYTES;
    wire [IDX_W-1:0] pf_next_idx = pf_next[OFF_W +: IDX_W];
    wire [TAG_W-1:0] pf_next_tag = pf_next[19 : (OFF_W+IDX_W)];
    wire             pf_can_chain = prefetch_en && in_window_next(pf_phys) &&
                                    !(valid[pf_next_idx] && tag[pf_next_idx] == pf_next_tag);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i]   <= {TAG_W{1'b0}};
                data[i]  <= {LINE_BITS{1'b0}};
            end
            cstate       <= CS_IDLE;
            lookup_hit   <= 1'b0;
            lookup_miss  <= 1'b0;
            lookup_rdata <= {HOST_DW{1'b0}};
            lookup_ready <= 1'b0;
            fill_req     <= 1'b0;
            fill_phys    <= 20'h0;
            pend_phys    <= 20'h0;
            pend_size    <= 3'b001;
            pend_idx     <= {IDX_W{1'b0}};
            pend_tag     <= {TAG_W{1'b0}};
            pend_off     <= {OFF_W{1'b0}};
            pend_rdata   <= {HOST_DW{1'b0}};
            pf_pending   <= 1'b0;
            pf_phys      <= 20'h0;
            demand_fill  <= 1'b0;
            dem_hold     <= 1'b0;
            dem_phys     <= 20'h0;
            dem_size     <= 3'b001;
        end else begin
            lookup_hit  <= 1'b0;
            lookup_miss <= 1'b0;
            fill_req    <= 1'b0;

            if (inv_all) begin
                for (i = 0; i < NUM_LINES; i = i + 1)
                    valid[i] <= 1'b0;
                pf_pending <= 1'b0;
                dem_hold   <= 1'b0;
            end

            case (cstate)
                CS_IDLE: begin
                    if (lookup_req || dem_hold) begin
                        lookup_ready <= 1'b0;
                        if (dem_hold) begin
                            if (valid[dem_idx] && tag[dem_idx] == dem_tag) begin
                                lookup_hit <= 1'b1;
                                pend_rdata <= extract_beat(data[dem_idx], dem_off, dem_size);
                                dem_hold <= 1'b0;
                                if (prefetch_en && in_window_next(dem_base)) begin
                                    pf_phys    <= dem_base + LINE_BYTES;
                                    pf_pending <= 1'b1;
                                end
                                cstate <= CS_REPLY;
                            end else begin
                                lookup_miss  <= 1'b1;
                                pend_phys    <= dem_phys;
                                pend_size    <= dem_size;
                                pend_idx     <= dem_idx;
                                pend_tag     <= dem_tag;
                                pend_off     <= dem_off;
                                fill_phys    <= dem_base;
                                fill_req     <= 1'b1;
                                demand_fill  <= 1'b1;
                                pf_pending   <= 1'b0;
                                dem_hold     <= 1'b0;
                                cstate       <= CS_MISS;
                            end
                        end else if (valid[idx] && tag[idx] == tag_w) begin
                            lookup_hit <= 1'b1;
                            pend_rdata <= extract_beat(data[idx], off, lookup_size);
                            if (can_pf) begin
                                pf_pending <= 1'b1;
                                pf_phys    <= next_line;
                            end
                            cstate <= CS_REPLY;
                        end else begin
                            lookup_miss  <= 1'b1;
                            pend_phys    <= lookup_phys;
                            pend_size    <= lookup_size;
                            pend_idx     <= idx;
                            pend_tag     <= tag_w;
                            pend_off     <= off;
                            fill_phys    <= line_base;
                            fill_req     <= 1'b1;
                            demand_fill  <= 1'b1;
                            pf_pending   <= 1'b0;
                            cstate       <= CS_MISS;
                        end
                    end else if (pf_pending && prefetch_en && !fill_busy) begin
                        fill_phys   <= pf_phys;
                        fill_req    <= 1'b1;
                        demand_fill <= 1'b0;
                        cstate      <= CS_PF_MISS;
                    end
                end

                CS_MISS: begin
                    if (fill_busy || fill_done) begin
                        fill_req <= 1'b0;
                        cstate   <= CS_WAIT;
                    end else begin
                        fill_req  <= 1'b1;
                        fill_phys <= {pend_phys[19:OFF_W], {OFF_W{1'b0}}};
                    end
                end

                CS_WAIT: begin
                    if (fill_done) begin
                        if (!fill_err) begin
                            valid[pend_idx] <= 1'b1;
                            tag[pend_idx]   <= pend_tag;
                            data[pend_idx]  <= fill_line[LINE_BITS-1:0];
                            pend_rdata <= extract_beat(fill_line[LINE_BITS-1:0], pend_off, pend_size);
                            if (prefetch_en && in_window_next({pend_phys[19:OFF_W], {OFF_W{1'b0}}})) begin
                                pf_phys    <= {pend_phys[19:OFF_W], {OFF_W{1'b0}}} + LINE_BYTES;
                                pf_pending <= 1'b1;
                            end
                        end else begin
                            // sticky error pattern in low halfword
                            pend_rdata <= {{HOST_DW-16{1'b0}}, 16'hDEAD};
                        end
                        cstate <= CS_REPLY;
                    end
                end

                CS_REPLY: begin
                    lookup_rdata <= pend_rdata;
                    cstate       <= CS_REPLY2;
                end

                CS_REPLY2: begin
                    lookup_ready <= 1'b1;
                    cstate       <= CS_IDLE;
                end

                CS_PF_MISS: begin
                    if (lookup_req) begin
                        dem_hold     <= 1'b1;
                        dem_phys     <= lookup_phys;
                        dem_size     <= lookup_size;
                        lookup_ready <= 1'b0;
                    end
                    if (fill_busy || fill_done) begin
                        fill_req <= 1'b0;
                        cstate   <= CS_PF_WAIT;
                    end else begin
                        fill_req  <= 1'b1;
                        fill_phys <= pf_phys;
                    end
                end

                CS_PF_WAIT: begin
                    if (lookup_req) begin
                        dem_hold     <= 1'b1;
                        dem_phys     <= lookup_phys;
                        dem_size     <= lookup_size;
                        lookup_ready <= 1'b0;
                    end
                    if (fill_done) begin
                        if (!fill_err) begin
                            valid[pf_idx] <= 1'b1;
                            tag[pf_idx]   <= pf_tag;
                            data[pf_idx]  <= fill_line[LINE_BITS-1:0];
                            if (pf_can_chain && !dem_hold) begin
                                pf_phys    <= pf_next;
                                pf_pending <= 1'b1;
                            end else
                                pf_pending <= 1'b0;
                        end else
                            pf_pending <= 1'b0;
                        cstate <= CS_IDLE;
                    end
                end

                default: cstate <= CS_IDLE;
            endcase
        end
    end

endmodule
