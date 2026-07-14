// SPDX-License-Identifier: Apache-2.0
// ZXip QSPI flash controller top — Verilog-2005
//
// Parameters:
//   HOST_DW : AHB data width 16 (default) or 32 (RV32)
//   HOST_AW : AHB address width 16 (default) or 32
//
// When HOST_AW==16: fixed/paged window decode on HADDR[15:14] (legacy map).
// When HOST_AW==32: flat phys = HADDR[19:0] unless phys_valid supplies phys_i;
//                   fabric HSEL defines the flash aperture.
`timescale 1ns / 1ps

module zxip_top #(
    parameter integer HOST_DW = 16,
    parameter integer HOST_AW = 16
) (
    input  wire        hclk,
    input  wire        hresetn,
    input  wire        pclk,
    input  wire        presetn,

    input  wire [HOST_AW-1:0] haddr,
    input  wire [1:0]  htrans,
    input  wire        hwrite,
    input  wire [2:0]  hsize,
    input  wire        hsel,
    input  wire        hready,
    input  wire [HOST_DW-1:0] hwdata,
    output wire [HOST_DW-1:0] hrdata,
    output wire        hreadyout,
    output wire        hresp,

    input  wire        phys_valid,
    input  wire [19:0] phys_i,
    input  wire [5:0]  fixed_page,
    input  wire [5:0]  page_sel,
    input  wire        page_is_flash,

    input  wire [7:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [15:0] pwdata,
    output wire [15:0] prdata,
    output wire        pready,
    output wire        pslverr,

    output wire        spi_sck,
    output wire        spi_cs_n,
    output wire        spi_reset_n,
    inout  wire        spi_io0,
    inout  wire        spi_io1,
    inout  wire        spi_io2,
    inout  wire        spi_io3,
    inout  wire        spi_ds
);

    `include "zxip_pkg_params.vh"

    // synthesis translate_off
    initial begin
        if (HOST_DW != 16 && HOST_DW != 32) begin
            $display("ERROR: zxip_top HOST_DW must be 16 or 32 (got %0d)", HOST_DW);
            $finish;
        end
        if (HOST_AW != 16 && HOST_AW != 32) begin
            $display("ERROR: zxip_top HOST_AW must be 16 or 32 (got %0d)", HOST_AW);
            $finish;
        end
    end
    // synthesis translate_on

    // -----------------------------------------------------------------
    // Physical address
    // -----------------------------------------------------------------
    wire [5:0] fixed_page_csr;
    wire [5:0] fixed_page_use = fixed_page_csr;

    wire in_fixed = (haddr[15:14] == 2'b00);
    wire in_paged = (haddr[15:14] == 2'b10);

    wire [19:0] phys_dec_16 =
        in_fixed ? {fixed_page_use, haddr[13:0]} :
        (in_paged && page_is_flash) ? {page_sel, haddr[13:0]} :
        20'h0;

    // 32-bit: flat low 1 MB of HADDR unless external phys_i
    wire [19:0] phys_dec_32 = haddr[19:0];

    wire [19:0] phys_dec = (HOST_AW <= 16) ? phys_dec_16 : phys_dec_32;
    wire [19:0] phys     = phys_valid ? phys_i : phys_dec;
    wire        xip_region = phys_valid ? 1'b1 :
                             (HOST_AW <= 16) ? (in_fixed | (in_paged & page_is_flash)) :
                             1'b1; // fabric HSEL bounds the aperture

    // -----------------------------------------------------------------
    // CSR
    // -----------------------------------------------------------------
    wire        xip_en, bb_en, cont_en, xip_mode, dtr_en, mode_phase_en, prefetch_en;
    wire        cache_inv_pulse, exit_cont_pulse, soft_rst_pulse, err_clr_pulse;
    wire [1:0]  spi_cmd_sel;
    wire [7:0]  clkdiv;
    wire [5:0]  dummy_cycles;
    wire [7:0]  mode_stay, mode_exit;
    wire        fixed_page_lock;
    wire [7:0]  qspi_cmd_sdr, qspi_cmd_dtr;
    wire [3:0]  dtr_samp_dly;
    wire        dtr_samp_inv;
    wire        bb_active, bb_cs_n, bb_sck;
    wire [3:0]  bb_oe, bb_out;
    wire [3:0]  io_in;

    wire        fill_busy, fill_done, fill_err;
    wire        cont_active;
    reg         err_sticky;

    wire eng_rst_n = hresetn & ~soft_rst_pulse;

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn)
            err_sticky <= 1'b0;
        else if (err_clr_pulse || soft_rst_pulse)
            err_sticky <= 1'b0;
        else if (fill_err)
            err_sticky <= 1'b1;
    end

    zxip_apb_regs u_apb (
        .pclk            (pclk),
        .presetn         (presetn),
        .paddr           (paddr),
        .psel            (psel),
        .penable         (penable),
        .pwrite          (pwrite),
        .pwdata          (pwdata),
        .prdata          (prdata),
        .pready          (pready),
        .pslverr         (pslverr),
        .fill_busy       (fill_busy),
        .cont_active     (cont_active),
        .err_sticky      (err_sticky),
        .bb_io_in        (io_in),
        .xip_en          (xip_en),
        .bb_en           (bb_en),
        .cache_inv_pulse (cache_inv_pulse),
        .cont_en         (cont_en),
        .exit_cont_pulse (exit_cont_pulse),
        .soft_rst_pulse  (soft_rst_pulse),
        .xip_mode        (xip_mode),
        .dtr_en          (dtr_en),
        .mode_phase_en   (mode_phase_en),
        .prefetch_en     (prefetch_en),
        .spi_cmd_sel     (spi_cmd_sel),
        .clkdiv          (clkdiv),
        .dummy_cycles    (dummy_cycles),
        .mode_stay       (mode_stay),
        .mode_exit       (mode_exit),
        .fixed_page_csr  (fixed_page_csr),
        .fixed_page_lock (fixed_page_lock),
        .qspi_cmd_sdr    (qspi_cmd_sdr),
        .qspi_cmd_dtr    (qspi_cmd_dtr),
        .dtr_samp_dly    (dtr_samp_dly),
        .dtr_samp_inv    (dtr_samp_inv),
        .bb_active       (bb_active),
        .bb_cs_n         (bb_cs_n),
        .bb_sck          (bb_sck),
        .bb_oe           (bb_oe),
        .bb_out          (bb_out),
        .err_clr_pulse   (err_clr_pulse)
    );

    // -----------------------------------------------------------------
    // Cache + fill + phy
    // -----------------------------------------------------------------
    wire        lookup_req, lookup_hit, lookup_miss, lookup_ready;
    wire [2:0]  lookup_size;
    wire [19:0] lookup_phys;
    wire [HOST_DW-1:0] lookup_rdata;
    wire        c_fill_req;
    wire [19:0] c_fill_phys;
    wire [127:0] fill_line;

    wire        eng_active, eng_cs_n, eng_sck_en, eng_mosi;
    wire        eng_io0_oe, eng_io1_oe, eng_io2_oe, eng_io3_oe;
    wire [2:0]  eng_io_out;
    wire        sck_rise, sck_fall, sck_level;

    zxip_cache #(
        .HOST_DW(HOST_DW)
    ) u_cache (
        .clk          (hclk),
        .rst_n        (eng_rst_n),
        .inv_all      (cache_inv_pulse | soft_rst_pulse),
        .prefetch_en  (prefetch_en),
        .lookup_req   (lookup_req),
        .lookup_phys  (lookup_phys),
        .lookup_size  (lookup_size),
        .lookup_hit   (lookup_hit),
        .lookup_miss  (lookup_miss),
        .lookup_rdata (lookup_rdata),
        .lookup_ready (lookup_ready),
        .fill_req     (c_fill_req),
        .fill_phys    (c_fill_phys),
        .fill_busy    (fill_busy),
        .fill_done    (fill_done),
        .fill_line    (fill_line),
        .fill_err     (fill_err)
    );

    zxip_fill_fsm u_fill (
        .clk             (hclk),
        .rst_n           (eng_rst_n),
        .xip_en          (xip_en & ~bb_active),
        .xip_mode        (xip_mode),
        .dtr_en          (dtr_en),
        .spi_cmd_sel     (spi_cmd_sel),
        .dummy_cycles    (dummy_cycles),
        .qspi_cmd_sdr    (qspi_cmd_sdr),
        .qspi_cmd_dtr    (qspi_cmd_dtr),
        .cont_en         (cont_en),
        .mode_phase_en   (mode_phase_en),
        .mode_stay       (mode_stay),
        .mode_exit       (mode_exit),
        .exit_cont_pulse (exit_cont_pulse),
        .fill_req        (c_fill_req),
        .fill_phys       (c_fill_phys),
        .fill_busy       (fill_busy),
        .fill_done       (fill_done),
        .fill_line       (fill_line),
        .fill_err        (fill_err),
        .cont_active     (cont_active),
        .sck_rise        (sck_rise),
        .sck_fall        (sck_fall),
        .io_in           (io_in),
        .eng_active      (eng_active),
        .eng_cs_n        (eng_cs_n),
        .eng_sck_en      (eng_sck_en),
        .eng_mosi        (eng_mosi),
        .eng_io0_oe      (eng_io0_oe),
        .eng_io1_oe      (eng_io1_oe),
        .eng_io2_oe      (eng_io2_oe),
        .eng_io3_oe      (eng_io3_oe),
        .eng_io_out      (eng_io_out)
    );

    zxip_phy u_phy (
        .clk         (hclk),
        .rst_n       (hresetn),
        .clkdiv      (clkdiv),
        .bb_active   (bb_active),
        .bb_cs_n     (bb_cs_n),
        .bb_sck      (bb_sck),
        .bb_oe       (bb_oe),
        .bb_out      (bb_out),
        .eng_active  (eng_active),
        .eng_cs_n    (eng_cs_n),
        .eng_sck_en  (eng_sck_en),
        .eng_mosi    (eng_mosi),
        .eng_io0_oe  (eng_io0_oe),
        .eng_io1_oe  (eng_io1_oe),
        .eng_io2_oe  (eng_io2_oe),
        .eng_io3_oe  (eng_io3_oe),
        .eng_io_out  (eng_io_out),
        .spi_sck     (spi_sck),
        .spi_cs_n    (spi_cs_n),
        .spi_reset_n (spi_reset_n),
        .rst_n_pad   (hresetn),
        .spi_io0     (spi_io0),
        .spi_io1     (spi_io1),
        .spi_io2     (spi_io2),
        .spi_io3     (spi_io3),
        .spi_ds      (spi_ds),
        .sck_rise    (sck_rise),
        .sck_fall    (sck_fall),
        .sck_level   (sck_level),
        .io_in       (io_in)
    );

    zxip_ahb_slave #(
        .HOST_DW(HOST_DW),
        .HOST_AW(HOST_AW)
    ) u_ahb (
        .hclk         (hclk),
        .hresetn      (hresetn),
        .haddr        (haddr),
        .htrans       (htrans),
        .hwrite       (hwrite),
        .hsize        (hsize),
        .hsel         (hsel),
        .hready       (hready),
        .hwdata       (hwdata),
        .hrdata       (hrdata),
        .hreadyout    (hreadyout),
        .hresp        (hresp),
        .xip_region   (xip_region),
        .phys         (phys),
        .xip_en       (xip_en),
        .lookup_req   (lookup_req),
        .lookup_phys  (lookup_phys),
        .lookup_size  (lookup_size),
        .lookup_hit   (lookup_hit),
        .lookup_miss  (lookup_miss),
        .lookup_rdata (lookup_rdata),
        .lookup_ready (lookup_ready)
    );

    wire _u = |{fixed_page, fixed_page_lock, mode_exit, dtr_samp_dly, dtr_samp_inv,
                sck_level, lookup_hit, lookup_miss, bb_en, qspi_cmd_dtr};

endmodule
