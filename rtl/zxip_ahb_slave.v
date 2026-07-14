// SPDX-License-Identifier: Apache-2.0
// AHB-Lite RO slave for ZXip — HOST_DW 16|32, HOST_AW 16|32 (Verilog-2005)
`timescale 1ns / 1ps

module zxip_ahb_slave #(
    parameter integer HOST_DW = 16,
    parameter integer HOST_AW = 16
) (
    input  wire                   hclk,
    input  wire                   hresetn,

    input  wire [HOST_AW-1:0]     haddr,
    input  wire [1:0]             htrans,
    input  wire                   hwrite,
    input  wire [2:0]             hsize,
    input  wire                   hsel,
    input  wire                   hready,
    input  wire [HOST_DW-1:0]     hwdata,
    output reg  [HOST_DW-1:0]     hrdata,
    output reg                    hreadyout,
    output reg                    hresp,

    input  wire                   xip_region,
    input  wire [19:0]            phys,
    input  wire                   xip_en,

    output reg                    lookup_req,
    output reg  [19:0]            lookup_phys,
    output reg  [2:0]             lookup_size,
    input  wire                   lookup_hit,
    input  wire                   lookup_miss,
    input  wire [HOST_DW-1:0]     lookup_rdata,
    input  wire                   lookup_ready
);

    `include "zxip_pkg_params.vh"

    // synthesis translate_off
    initial begin
        if (HOST_DW != 16 && HOST_DW != 32) begin
            $display("ERROR: zxip_ahb_slave HOST_DW must be 16 or 32");
            $finish;
        end
        if (HOST_AW != 16 && HOST_AW != 32) begin
            $display("ERROR: zxip_ahb_slave HOST_AW must be 16 or 32");
            $finish;
        end
    end
    // synthesis translate_on

    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam AS_IDLE  = 2'd0;
    localparam AS_WAIT1 = 2'd1;
    localparam AS_WAIT2 = 2'd2;
    localparam AS_ERROR = 2'd3;

    reg [1:0] astate;
    reg [2:0] a_size;
    reg [1:0] a_lane;

    wire xfer = hsel & hready & hreadyout &
                ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));

    wire [2:0] size_eff =
        (HOST_DW < 32 && hsize >= `XIP_HSIZE_WORD) ? `XIP_HSIZE_HALF : hsize;

    wire unaligned =
        (size_eff == `XIP_HSIZE_HALF && haddr[0]) ||
        (size_eff == `XIP_HSIZE_WORD && (haddr[1:0] != 2'b00));

    // Build HRDATA from lookup_rdata (little-endian lane place)
    reg [HOST_DW-1:0] beat_placed;
    always @* begin
        beat_placed = {HOST_DW{1'b0}};
        if (HOST_DW == 16) begin
            if (a_size == `XIP_HSIZE_BYTE) begin
                if (a_lane[0])
                    beat_placed = {lookup_rdata[7:0], 8'h00};
                else
                    beat_placed = {8'h00, lookup_rdata[7:0]};
            end else
                beat_placed = lookup_rdata;
        end else begin
            // HOST_DW == 32
            if (a_size == `XIP_HSIZE_BYTE) begin
                case (a_lane)
                    2'b00: beat_placed = {24'h0, lookup_rdata[7:0]};
                    2'b01: beat_placed = {16'h0, lookup_rdata[7:0], 8'h0};
                    2'b10: beat_placed = {8'h0, lookup_rdata[7:0], 16'h0};
                    2'b11: beat_placed = {lookup_rdata[7:0], 24'h0};
                endcase
            end else if (a_size == `XIP_HSIZE_HALF) begin
                if (a_lane[1])
                    beat_placed = {lookup_rdata[15:0], 16'h0};
                else
                    beat_placed = {16'h0, lookup_rdata[15:0]};
            end else
                beat_placed = lookup_rdata;
        end
    end

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            hrdata      <= {HOST_DW{1'b0}};
            hreadyout   <= 1'b1;
            hresp       <= 1'b0;
            lookup_req  <= 1'b0;
            lookup_phys <= 20'h0;
            lookup_size <= 3'b001;
            astate      <= AS_IDLE;
            a_size      <= 3'b001;
            a_lane      <= 2'b00;
        end else begin
            lookup_req <= 1'b0;

            case (astate)
                AS_IDLE: begin
                    hreadyout <= 1'b1;
                    hresp     <= 1'b0;
                    if (xfer) begin
                        if (!xip_region || !xip_en) begin
                            hrdata <= {HOST_DW{1'b0}};
                        end else if (hwrite || unaligned) begin
                            hreadyout <= 1'b0;
                            hresp     <= 1'b1;
                            astate    <= AS_ERROR;
                        end else begin
                            lookup_req  <= 1'b1;
                            lookup_phys <= phys;
                            lookup_size <= size_eff;
                            a_size      <= size_eff;
                            a_lane      <= haddr[1:0];
                            hreadyout   <= 1'b0;
                            astate      <= AS_WAIT1;
                        end
                    end
                end

                AS_WAIT1: begin
                    hreadyout  <= 1'b0;
                    hresp      <= 1'b0;
                    lookup_req <= 1'b0;
                    astate     <= AS_WAIT2;
                end

                AS_WAIT2: begin
                    hreadyout <= 1'b0;
                    hresp     <= 1'b0;
                    if (lookup_ready) begin
                        hrdata    <= beat_placed;
                        hreadyout <= 1'b1;
                        astate    <= AS_IDLE;
                    end
                end

                AS_ERROR: begin
                    hresp     <= 1'b1;
                    hreadyout <= 1'b1;
                    astate    <= AS_IDLE;
                end

                default: astate <= AS_IDLE;
            endcase
        end
    end

    wire _uw = |hwdata | lookup_hit | lookup_miss;

endmodule
