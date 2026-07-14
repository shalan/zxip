// SPDX-License-Identifier: Apache-2.0
// APB CSR file for XiP controller (Verilog-2005)
`timescale 1ns / 1ps

module zxip_apb_regs (
    input  wire        pclk,
    input  wire        presetn,
    input  wire [7:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [15:0] pwdata,
    output wire [15:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Status inputs
    input  wire        fill_busy,
    input  wire        cont_active,
    input  wire        err_sticky,
    input  wire [3:0]  bb_io_in,

    // Controls
    output wire        xip_en,
    output wire        bb_en,
    output wire        cache_inv_pulse,
    output wire        cont_en,
    output wire        exit_cont_pulse,
    output wire        soft_rst_pulse,
    output wire        xip_mode,
    output wire        dtr_en,
    output wire        mode_phase_en,
    output wire        prefetch_en,
    output wire [1:0]  spi_cmd_sel,
    output wire [7:0]  clkdiv,
    output wire [5:0]  dummy_cycles,
    output wire [7:0]  mode_stay,
    output wire [7:0]  mode_exit,
    output wire [5:0]  fixed_page_csr,
    output wire        fixed_page_lock,
    output wire [7:0]  qspi_cmd_sdr,
    output wire [7:0]  qspi_cmd_dtr,
    output wire [3:0]  dtr_samp_dly,
    output wire        dtr_samp_inv,

    // Bit-bang (valid when bb_active)
    output wire        bb_active,
    output wire        bb_cs_n,
    output wire        bb_sck,
    output wire [3:0]  bb_oe,
    output wire [3:0]  bb_out,

    // Clear error (W1C on STATUS bit4 write 1)
    output wire        err_clr_pulse
);

    `include "zxip_pkg_params.vh"

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    wire apb_wr = psel & penable & pwrite;
    wire apb_rd = psel & penable & ~pwrite;

    reg        r_xip_en;
    reg        r_bb_en;
    reg        r_cont_en;
    reg        r_xip_mode;
    reg        r_dtr_en;
    reg        r_mode_phase_en;
    reg        r_prefetch_en;
    reg [1:0]  r_spi_cmd_sel;
    reg [7:0]  r_clkdiv;
    reg [5:0]  r_dummy;
    reg [7:0]  r_mode_stay;
    reg [7:0]  r_mode_exit;
    reg [5:0]  r_fixed_page;
    reg        r_fixed_lock;
    reg [7:0]  r_cmd_sdr;
    reg [7:0]  r_cmd_dtr;
    reg [3:0]  r_dtr_dly;
    reg        r_dtr_inv;
    reg        r_bb_cs_n;
    reg        r_bb_sck;
    reg [3:0]  r_bb_oe;
    reg [3:0]  r_bb_out;

    // One-cycle pulses from self-clearing CTRL bits
    reg cache_inv_r;
    reg exit_cont_r;
    reg soft_rst_r;
    reg err_clr_r;

    assign xip_en          = r_xip_en;
    assign bb_en           = r_bb_en;
    assign cont_en         = r_cont_en;
    assign xip_mode        = r_xip_mode;
    assign dtr_en          = r_dtr_en & r_xip_mode;
    assign mode_phase_en   = r_mode_phase_en;
    assign prefetch_en     = r_prefetch_en;
    assign spi_cmd_sel     = r_spi_cmd_sel;
    assign clkdiv          = r_clkdiv;
    assign dummy_cycles    = r_dummy;
    assign mode_stay       = r_mode_stay;
    assign mode_exit       = r_mode_exit;
    assign fixed_page_csr  = r_fixed_page;
    assign fixed_page_lock = r_fixed_lock;
    assign qspi_cmd_sdr    = r_cmd_sdr;
    assign qspi_cmd_dtr    = r_cmd_dtr;
    assign dtr_samp_dly    = r_dtr_dly;
    assign dtr_samp_inv    = r_dtr_inv;

    assign bb_active = r_bb_en & ~r_xip_en;
    assign bb_cs_n   = r_bb_cs_n;
    assign bb_sck    = r_bb_sck;
    assign bb_oe     = r_bb_oe;
    assign bb_out    = r_bb_out;

    assign cache_inv_pulse = cache_inv_r;
    assign exit_cont_pulse = exit_cont_r;
    assign soft_rst_pulse  = soft_rst_r;
    assign err_clr_pulse   = err_clr_r;

    wire [15:0] status_w = {
        9'b0,
        dtr_en,
        r_xip_mode,
        err_sticky,
        bb_active,
        r_xip_en,
        cont_active,
        fill_busy
    };

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            r_xip_en        <= 1'b1;
            r_bb_en         <= 1'b0;
            r_cont_en       <= 1'b0;
            r_xip_mode      <= 1'b0;
            r_dtr_en        <= 1'b0;
            r_mode_phase_en <= 1'b0;
            r_prefetch_en   <= 1'b1; // default on
            r_spi_cmd_sel   <= 2'b00;
            r_clkdiv        <= 8'd8;
            r_dummy         <= `XIP_DUMMY_DEFAULT;
            r_mode_stay     <= 8'hA0;
            r_mode_exit     <= 8'h00;
            r_fixed_page    <= 6'd0;
            r_fixed_lock    <= 1'b0;
            r_cmd_sdr       <= `XIP_CMD_QIO_SDR;
            r_cmd_dtr       <= `XIP_CMD_QIO_DTR;
            r_dtr_dly       <= 4'd0;
            r_dtr_inv       <= 1'b0;
            r_bb_cs_n       <= 1'b1;
            r_bb_sck        <= 1'b0;
            r_bb_oe         <= 4'b0;
            r_bb_out        <= 4'b0;
            cache_inv_r     <= 1'b0;
            exit_cont_r     <= 1'b0;
            soft_rst_r      <= 1'b0;
            err_clr_r       <= 1'b0;
        end else begin
            cache_inv_r <= 1'b0;
            exit_cont_r <= 1'b0;
            soft_rst_r  <= 1'b0;
            err_clr_r   <= 1'b0;

            if (apb_wr) begin
                case (paddr)
                    `XIP_REG_CTRL: begin
                        r_xip_en        <= pwdata[0];
                        r_bb_en         <= pwdata[1];
                        if (pwdata[2]) cache_inv_r <= 1'b1;
                        r_cont_en       <= pwdata[3];
                        if (pwdata[4]) exit_cont_r <= 1'b1;
                        if (pwdata[5]) soft_rst_r  <= 1'b1;
                        r_xip_mode      <= pwdata[6];
                        r_dtr_en        <= pwdata[7];
                        r_mode_phase_en <= pwdata[8];
                        r_prefetch_en   <= pwdata[11];
                        r_spi_cmd_sel   <= pwdata[10:9];
                    end
                    `XIP_REG_STATUS: begin
                        if (pwdata[4]) err_clr_r <= 1'b1;
                    end
                    `XIP_REG_CLKDIV: begin
                        r_clkdiv <= (pwdata[7:0] < 8'd2) ? 8'd2 : pwdata[7:0];
                    end
                    `XIP_REG_DUMMY: r_dummy <= pwdata[5:0];
                    `XIP_REG_MODE_STAY: r_mode_stay <= pwdata[7:0];
                    `XIP_REG_MODE_EXIT: r_mode_exit <= pwdata[7:0];
                    `XIP_REG_FIXED_PG: begin
                        if (!r_fixed_lock) begin
                            r_fixed_page <= pwdata[5:0];
                            r_fixed_lock <= pwdata[15];
                        end
                    end
                    `XIP_REG_QSPI_CMD: begin
                        r_cmd_sdr <= pwdata[7:0];
                        r_cmd_dtr <= pwdata[15:8];
                    end
                    `XIP_REG_BB_CTRL: begin
                        if (r_bb_en & ~r_xip_en) begin
                            r_bb_cs_n <= pwdata[0];
                            r_bb_sck  <= pwdata[1];
                            r_bb_oe   <= pwdata[5:2];
                        end
                    end
                    `XIP_REG_BB_IO: begin
                        if (r_bb_en & ~r_xip_en)
                            r_bb_out <= pwdata[3:0];
                    end
                    `XIP_REG_DTR_PHY: begin
                        r_dtr_dly <= pwdata[3:0];
                        r_dtr_inv <= pwdata[4];
                    end
                    default: ;
                endcase
            end
        end
    end

    // Combinational PRDATA (APB-safe)
    reg [15:0] prdata_r;
    always @* begin
        case (paddr)
            `XIP_REG_CTRL: prdata_r = {
                4'b0, r_prefetch_en, r_spi_cmd_sel, r_mode_phase_en, r_dtr_en, r_xip_mode,
                1'b0, 1'b0, r_cont_en, 1'b0, r_bb_en, r_xip_en
            };
            `XIP_REG_STATUS:    prdata_r = status_w;
            `XIP_REG_CLKDIV:    prdata_r = {8'b0, r_clkdiv};
            `XIP_REG_DUMMY:     prdata_r = {10'b0, r_dummy};
            `XIP_REG_MODE_STAY: prdata_r = {8'b0, r_mode_stay};
            `XIP_REG_MODE_EXIT: prdata_r = {8'b0, r_mode_exit};
            `XIP_REG_FIXED_PG:  prdata_r = {r_fixed_lock, 9'b0, r_fixed_page};
            `XIP_REG_QSPI_CMD:  prdata_r = {r_cmd_dtr, r_cmd_sdr};
            `XIP_REG_BB_CTRL:   prdata_r = {10'b0, r_bb_oe, r_bb_sck, r_bb_cs_n};
            `XIP_REG_BB_IO:     prdata_r = {8'b0, bb_io_in, r_bb_out};
            `XIP_REG_DTR_PHY:   prdata_r = {11'b0, r_dtr_inv, r_dtr_dly};
            default:            prdata_r = 16'h0000;
        endcase
    end
    assign prdata = prdata_r;

endmodule
