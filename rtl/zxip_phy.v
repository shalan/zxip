// SPDX-License-Identifier: Apache-2.0
// SPI/QSPI pad PHY — SCK generation, OE mux, 1-1-1 shift (Phase 2)
// Verilog-2005. Mode 0: idle SCK low; MOSI change on falling; sample on rising.
`timescale 1ns / 1ps

module zxip_phy (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  clkdiv,

    // Owner select
    input  wire        bb_active,
    input  wire        bb_cs_n,
    input  wire        bb_sck,
    input  wire [3:0]  bb_oe,
    input  wire [3:0]  bb_out,

    // Engine pad intent
    input  wire        eng_active,   // fill in progress
    input  wire        eng_cs_n,
    input  wire        eng_sck_en,   // run free-running divided SCK while 1
    input  wire        eng_mosi,     // IO0 level when driving
    input  wire        eng_io0_oe,
    input  wire        eng_io1_oe,
    input  wire        eng_io2_oe,
    input  wire        eng_io3_oe,
    input  wire [2:0] eng_io_out,   // IO[3:1] when driven (quad later)

    // Pad side
    output wire        spi_sck,
    output wire        spi_cs_n,
    output wire        spi_reset_n,
    input  wire        rst_n_pad,    // external reset pass-through
    inout  wire        spi_io0,
    inout  wire        spi_io1,
    inout  wire        spi_io2,
    inout  wire        spi_io3,
    inout  wire        spi_ds,

    // Sampled inputs (registered on eng SCK rising for engine)
    output wire        sck_rise,
    output wire        sck_fall,
    output wire        sck_level,
    output wire [3:0]  io_in
);

    // -----------------------------------------------------------------
    // Divided SCK for engine (idle low)
    // -----------------------------------------------------------------
    reg [7:0] div_cnt;
    reg       sck_r;
    reg       sck_r_d;

    wire [7:0] div_use = (clkdiv < 8'd2) ? 8'd2 : clkdiv;
    wire [7:0] half    = {1'b0, div_use[7:1]}; // div_use/2

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 8'd0;
            sck_r   <= 1'b0;
            sck_r_d <= 1'b0;
        end else begin
            sck_r_d <= sck_r;
            if (!eng_active || !eng_sck_en || bb_active) begin
                div_cnt <= 8'd0;
                sck_r   <= 1'b0;
            end else begin
                if (div_cnt >= (div_use - 8'd1)) begin
                    div_cnt <= 8'd0;
                    sck_r   <= 1'b0;
                end else begin
                    div_cnt <= div_cnt + 8'd1;
                    // high for second half
                    if (div_cnt == (half - 8'd1))
                        sck_r <= 1'b1;
                end
            end
        end
    end

    assign sck_level = sck_r;
    assign sck_rise  =  eng_sck_en & eng_active & ~bb_active &  sck_r & ~sck_r_d;
    assign sck_fall  =  eng_sck_en & eng_active & ~bb_active & ~sck_r &  sck_r_d;

    // -----------------------------------------------------------------
    // Pad mux
    // -----------------------------------------------------------------
    wire        cs_n_mux = bb_active ? bb_cs_n : (eng_active ? eng_cs_n : 1'b1);
    wire        sck_mux  = bb_active ? bb_sck  : (eng_active & eng_sck_en ? sck_r : 1'b0);

    wire [3:0] oe_mux = bb_active ? bb_oe :
                        eng_active ? {eng_io3_oe, eng_io2_oe, eng_io1_oe, eng_io0_oe} :
                        4'b0000;

    wire [3:0] out_mux = bb_active ? bb_out :
                         {eng_io_out[2], eng_io_out[1], eng_io_out[0], eng_mosi};

    assign spi_sck     = sck_mux;
    assign spi_cs_n    = cs_n_mux;
    assign spi_reset_n = rst_n_pad;

    assign spi_io0 = oe_mux[0] ? out_mux[0] : 1'bz;
    assign spi_io1 = oe_mux[1] ? out_mux[1] : 1'bz;
    assign spi_io2 = oe_mux[2] ? out_mux[2] : 1'bz;
    assign spi_io3 = oe_mux[3] ? out_mux[3] : 1'bz;
    assign spi_ds  = 1'bz;

    assign io_in = {spi_io3, spi_io2, spi_io1, spi_io0};

endmodule
