// SPDX-License-Identifier: Apache-2.0
// Flash line-fill engine: 1-1-1 (0x0B/0x03) + 1-4-4 (0xEB, mode, continuous)
// Verilog-2005
`timescale 1ns / 1ps

module zxip_fill_fsm (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        xip_en,
    input  wire        xip_mode,
    input  wire        dtr_en,
    input  wire [1:0]  spi_cmd_sel,
    input  wire [5:0]  dummy_cycles,
    input  wire [7:0]  qspi_cmd_sdr,
    input  wire [7:0]  qspi_cmd_dtr,
    input  wire        cont_en,
    input  wire        mode_phase_en,
    input  wire [7:0]  mode_stay,
    input  wire [7:0]  mode_exit,
    input  wire        exit_cont_pulse,

    input  wire        fill_req,
    input  wire [19:0] fill_phys,
    output reg         fill_busy,
    output reg         fill_done,
    output reg [127:0] fill_line,
    output reg         fill_err,
    output reg         cont_active,

    input  wire        sck_rise,
    input  wire        sck_fall,
    input  wire [3:0]  io_in,
    output reg         eng_active,
    output reg         eng_cs_n,
    output reg         eng_sck_en,
    output reg         eng_mosi,
    output reg         eng_io0_oe,
    output reg         eng_io1_oe,
    output reg         eng_io2_oe,
    output reg         eng_io3_oe,
    output reg [2:0]   eng_io_out
);

    `include "zxip_pkg_params.vh"

    localparam integer LINE_BYTES = `XIP_LINE_BYTES;
    localparam integer LINE_BITS  = LINE_BYTES * 8;
    localparam [4:0]   LAST_BYTE  = LINE_BYTES[4:0] - 5'd1;

    localparam ST_IDLE   = 4'd0;
    localparam ST_LEAD   = 4'd1;
    localparam ST_CMD    = 4'd2;
    localparam ST_ADDR1  = 4'd3;
    localparam ST_DUMMY1 = 4'd4;
    localparam ST_DATA1  = 4'd5;
    localparam ST_DONE   = 4'd6;
    localparam ST_DONE2  = 4'd7;
    localparam ST_QADDR  = 4'd8;
    localparam ST_QMODE  = 4'd9;
    localparam ST_QDUMMY = 4'd10;
    localparam ST_QDATA  = 4'd11;

    reg [3:0]   state;
    reg [5:0]   bits_left;
    reg [7:0]   cmd_r;
    reg [23:0]  addr_r;
    reg [5:0]   dummy_left;
    reg [4:0]   byte_idx;
    reg [2:0]   bit_idx;
    reg [7:0]   rx_byte;
    reg [LINE_BITS-1:0] line_r;
    reg         need_dummy;
    reg         skip_cmd;
    reg         is_qspi;
    reg [3:0]   nib_left;   // remaining nibbles after current is sampled
    reg [7:0]   mode_r;
    reg         mode_lo_next; // 0: current is high mode nibble; 1: current is low

    wire [7:0] spi_cmd = (spi_cmd_sel == 2'b01) ? `XIP_CMD_READ : `XIP_CMD_FAST_READ;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            fill_busy    <= 1'b0;
            fill_done    <= 1'b0;
            fill_line    <= {128{1'b0}};
            fill_err     <= 1'b0;
            cont_active  <= 1'b0;
            eng_active   <= 1'b0;
            eng_cs_n     <= 1'b1;
            eng_sck_en   <= 1'b0;
            eng_mosi     <= 1'b0;
            eng_io0_oe   <= 1'b0;
            eng_io1_oe   <= 1'b0;
            eng_io2_oe   <= 1'b0;
            eng_io3_oe   <= 1'b0;
            eng_io_out   <= 3'b0;
            bits_left    <= 6'd0;
            cmd_r        <= 8'h0;
            addr_r       <= 24'h0;
            dummy_left   <= 6'd0;
            byte_idx     <= 5'd0;
            bit_idx      <= 3'd0;
            rx_byte      <= 8'd0;
            line_r       <= {LINE_BITS{1'b0}};
            need_dummy   <= 1'b0;
            skip_cmd     <= 1'b0;
            is_qspi      <= 1'b0;
            nib_left     <= 4'd0;
            mode_r       <= 8'h0;
            mode_lo_next <= 1'b0;
        end else begin
            fill_done <= 1'b0;

            if (exit_cont_pulse)
                cont_active <= 1'b0;

            case (state)
                ST_IDLE: begin
                    eng_active <= 1'b0;
                    eng_cs_n   <= 1'b1;
                    eng_sck_en <= 1'b0;
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    eng_mosi   <= 1'b0;
                    eng_io_out <= 3'b0;
                    fill_busy  <= 1'b0;

                    if (fill_req && xip_en) begin
                        if (dtr_en && xip_mode) begin
                            fill_err  <= 1'b1;
                            fill_done <= 1'b1;
                        end else begin
                            fill_busy  <= 1'b1;
                            fill_err   <= 1'b0;
                            eng_active <= 1'b1;
                            eng_cs_n   <= 1'b0;
                            eng_sck_en <= 1'b0;
                            addr_r     <= {4'b0, fill_phys};
                            line_r     <= {LINE_BITS{1'b0}};
                            byte_idx   <= 5'd0;
                            is_qspi    <= xip_mode;
                            skip_cmd   <= xip_mode & cont_en & cont_active;
                            mode_r     <= mode_stay;
                            dummy_left <= (dummy_cycles == 6'd0) ? 6'd4 : dummy_cycles;

                            if (!xip_mode) begin
                                cmd_r      <= spi_cmd;
                                need_dummy <= (spi_cmd_sel != 2'b01);
                                dummy_left <= (dummy_cycles == 6'd0) ? 6'd1 : dummy_cycles;
                                eng_io0_oe <= 1'b1;
                                eng_mosi   <= spi_cmd[7];
                                bits_left  <= 6'd7;
                                state      <= ST_LEAD;
                            end else if (cont_en && cont_active) begin
                                // Continuous: start with addr[23:20] on all IOs
                                eng_io0_oe <= 1'b1;
                                eng_io1_oe <= 1'b1;
                                eng_io2_oe <= 1'b1;
                                eng_io3_oe <= 1'b1;
                                eng_mosi   <= 1'b0;       // addr[23:20] = 0
                                eng_io_out <= 3'b000;
                                nib_left   <= 4'd5;
                                state      <= ST_LEAD;
                            end else begin
                                cmd_r      <= qspi_cmd_sdr;
                                eng_io0_oe <= 1'b1;
                                eng_io1_oe <= 1'b0;
                                eng_io2_oe <= 1'b0;
                                eng_io3_oe <= 1'b0;
                                eng_mosi   <= qspi_cmd_sdr[7];
                                bits_left  <= 6'd7;
                                skip_cmd   <= 1'b0;
                                state      <= ST_LEAD;
                            end
                        end
                    end
                end

                ST_LEAD: begin
                    eng_sck_en <= 1'b1;
                    if (is_qspi && skip_cmd)
                        state <= ST_QADDR;
                    else
                        state <= ST_CMD;
                end

                ST_CMD: begin
                    eng_io0_oe <= 1'b1;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    if (sck_rise) begin
                        if (bits_left == 6'd0) begin
                            if (is_qspi) begin
                                eng_io0_oe <= 1'b1;
                                eng_io1_oe <= 1'b1;
                                eng_io2_oe <= 1'b1;
                                eng_io3_oe <= 1'b1;
                                {eng_io_out, eng_mosi} <= addr_r[23:20];
                                nib_left <= 4'd5;
                                state    <= ST_QADDR;
                            end else begin
                                eng_mosi  <= addr_r[23];
                                bits_left <= 6'd23;
                                state     <= ST_ADDR1;
                            end
                        end else begin
                            bits_left <= bits_left - 6'd1;
                            eng_mosi  <= cmd_r[bits_left - 6'd1];
                        end
                    end
                end

                ST_ADDR1: begin
                    eng_io0_oe <= 1'b1;
                    if (sck_rise) begin
                        if (bits_left == 6'd0) begin
                            eng_io0_oe <= 1'b0;
                            eng_mosi   <= 1'b0;
                            if (need_dummy) begin
                                bits_left <= dummy_left - 6'd1;
                                state     <= ST_DUMMY1;
                            end else begin
                                bit_idx  <= 3'd7;
                                byte_idx <= 5'd0;
                                rx_byte  <= 8'd0;
                                state    <= ST_DATA1;
                            end
                        end else begin
                            bits_left <= bits_left - 6'd1;
                            eng_mosi  <= addr_r[bits_left - 6'd1];
                        end
                    end
                end

                ST_DUMMY1: begin
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    if (sck_rise) begin
                        if (bits_left == 6'd0) begin
                            bit_idx  <= 3'd7;
                            byte_idx <= 5'd0;
                            rx_byte  <= 8'd0;
                            state    <= ST_DATA1;
                        end else
                            bits_left <= bits_left - 6'd1;
                    end
                end

                ST_DATA1: begin
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    if (sck_rise) begin
                        if (bit_idx == 3'd0) begin
                            line_r[byte_idx*8 +: 8] <= {rx_byte[6:0], io_in[1]};
                            if (byte_idx == LAST_BYTE) begin
                                eng_sck_en <= 1'b0;
                                eng_cs_n   <= 1'b1;
                                state      <= ST_DONE;
                            end else begin
                                byte_idx <= byte_idx + 5'd1;
                                bit_idx  <= 3'd7;
                                rx_byte  <= 8'd0;
                            end
                        end else begin
                            rx_byte <= {rx_byte[6:0], io_in[1]};
                            bit_idx <= bit_idx - 3'd1;
                        end
                    end
                end

                // ---- Quad address: current nibble already on pads ----
                ST_QADDR: begin
                    eng_io0_oe <= 1'b1;
                    eng_io1_oe <= 1'b1;
                    eng_io2_oe <= 1'b1;
                    eng_io3_oe <= 1'b1;
                    if (sck_rise) begin
                        if (nib_left == 4'd0) begin
                            if (mode_phase_en) begin
                                {eng_io_out, eng_mosi} <= mode_r[7:4];
                                mode_lo_next <= 1'b1;
                                state        <= ST_QMODE;
                            end else begin
                                eng_io0_oe <= 1'b0;
                                eng_io1_oe <= 1'b0;
                                eng_io2_oe <= 1'b0;
                                eng_io3_oe <= 1'b0;
                                if (dummy_left == 6'd0) begin
                                    nib_left <= 4'd0;
                                    byte_idx <= 5'd0;
                                    state    <= ST_QDATA;
                                end else begin
                                    bits_left <= dummy_left - 6'd1;
                                    state     <= ST_QDUMMY;
                                end
                            end
                        end else begin
                            nib_left <= nib_left - 4'd1;
                            case (nib_left)
                                4'd5: {eng_io_out, eng_mosi} <= addr_r[19:16];
                                4'd4: {eng_io_out, eng_mosi} <= addr_r[15:12];
                                4'd3: {eng_io_out, eng_mosi} <= addr_r[11:8];
                                4'd2: {eng_io_out, eng_mosi} <= addr_r[7:4];
                                4'd1: {eng_io_out, eng_mosi} <= addr_r[3:0];
                                default: {eng_io_out, eng_mosi} <= 4'h0;
                            endcase
                        end
                    end
                end

                ST_QMODE: begin
                    eng_io0_oe <= 1'b1;
                    eng_io1_oe <= 1'b1;
                    eng_io2_oe <= 1'b1;
                    eng_io3_oe <= 1'b1;
                    if (sck_rise) begin
                        if (mode_lo_next) begin
                            // high nibble just sampled → present low
                            {eng_io_out, eng_mosi} <= mode_r[3:0];
                            mode_lo_next <= 1'b0;
                        end else begin
                            // low nibble just sampled → dummy/data
                            eng_io0_oe <= 1'b0;
                            eng_io1_oe <= 1'b0;
                            eng_io2_oe <= 1'b0;
                            eng_io3_oe <= 1'b0;
                            if (cont_en && (mode_r[7:4] == 4'hA))
                                cont_active <= 1'b1;
                            else if (mode_phase_en)
                                cont_active <= 1'b0;
                            if (dummy_left == 6'd0) begin
                                nib_left <= 4'd0;
                                byte_idx <= 5'd0;
                                state    <= ST_QDATA;
                            end else begin
                                bits_left <= dummy_left - 6'd1;
                                state     <= ST_QDUMMY;
                            end
                        end
                    end
                end

                ST_QDUMMY: begin
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    if (sck_rise) begin
                        if (bits_left == 6'd0) begin
                            nib_left <= 4'd0;
                            byte_idx <= 5'd0;
                            state    <= ST_QDATA;
                        end else
                            bits_left <= bits_left - 6'd1;
                    end
                end

                // nib_left 0 = capture high nibble, 1 = capture low + store byte
                ST_QDATA: begin
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    if (sck_rise) begin
                        if (nib_left == 4'd0) begin
                            rx_byte  <= {io_in, 4'b0000};
                            nib_left <= 4'd1;
                        end else begin
                            line_r[byte_idx*8 +: 8] <= {rx_byte[7:4], io_in};
                            if (byte_idx == LAST_BYTE) begin
                                eng_sck_en <= 1'b0;
                                eng_cs_n   <= 1'b1;
                                state      <= ST_DONE;
                            end else begin
                                byte_idx <= byte_idx + 5'd1;
                                nib_left <= 4'd0;
                            end
                        end
                    end
                end

                ST_DONE: begin
                    eng_active <= 1'b0;
                    eng_cs_n   <= 1'b1;
                    eng_sck_en <= 1'b0;
                    eng_io0_oe <= 1'b0;
                    eng_io1_oe <= 1'b0;
                    eng_io2_oe <= 1'b0;
                    eng_io3_oe <= 1'b0;
                    // Zero-extends when LINE_BITS < 128
                    fill_line  <= line_r;
                    state      <= ST_DONE2;
                end

                ST_DONE2: begin
                    fill_busy <= 1'b0;
                    fill_done <= 1'b1;
                    state     <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
