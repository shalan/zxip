// SPDX-License-Identifier: Apache-2.0
// AHB-Lite RO slave 16-bit for XiP (Verilog-2005)
`timescale 1ns / 1ps

module zxip_ahb_slave (
    input  wire        hclk,
    input  wire        hresetn,

    input  wire [15:0] haddr,
    input  wire [1:0]  htrans,
    input  wire        hwrite,
    input  wire [2:0]  hsize,
    input  wire        hsel,
    input  wire        hready,
    input  wire [15:0] hwdata,
    output reg  [15:0] hrdata,
    output reg         hreadyout,
    output reg         hresp,

    input  wire        xip_region,
    input  wire [19:0] phys,
    input  wire        xip_en,

    // Cache
    output reg         lookup_req,
    output reg [19:0]  lookup_phys,
    output reg         lookup_half,
    input  wire        lookup_hit,
    input  wire        lookup_miss,
    input  wire [15:0] lookup_rdata,
    input  wire        lookup_ready
);

    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam AS_IDLE  = 2'd0;
    localparam AS_WAIT1 = 2'd1; // ignore stale lookup_ready
    localparam AS_WAIT2 = 2'd2;
    localparam AS_ERROR = 2'd3;

    reg [1:0] astate;
    reg       pend_write_err;
    reg       a_half;   // 1 = halfword (or larger) access
    reg       a_addr0;  // HADDR[0] for byte-lane placement

    wire xfer = hsel & hready & hreadyout & ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            hrdata         <= 16'h0;
            hreadyout      <= 1'b1;
            hresp          <= 1'b0;
            lookup_req     <= 1'b0;
            lookup_phys    <= 20'h0;
            lookup_half    <= 1'b1;
            astate         <= AS_IDLE;
            pend_write_err <= 1'b0;
            a_half         <= 1'b1;
            a_addr0        <= 1'b0;
        end else begin
            lookup_req <= 1'b0;

            case (astate)
                AS_IDLE: begin
                    hreadyout <= 1'b1;
                    hresp     <= 1'b0;
                    if (xfer) begin
                        if (!xip_region || !xip_en) begin
                            // Not for us or disabled — OK zero (or let decoder not select)
                            hrdata <= 16'h0;
                        end else if (hwrite) begin
                            // ERROR response: two-cycle AHB error
                            hreadyout      <= 1'b0;
                            hresp          <= 1'b1;
                            pend_write_err <= 1'b1;
                            astate         <= AS_ERROR;
                        end else begin
                            lookup_req  <= 1'b1;
                            lookup_phys <= phys;
                            lookup_half <= (hsize >= 3'b001); // halfword or larger as half
                            a_half      <= (hsize >= 3'b001);
                            a_addr0     <= haddr[0];
                            hreadyout   <= 1'b0;
                            astate      <= AS_WAIT1;
                        end
                    end
                end

                // Drop any sticky ready from previous access
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
                        // Cache returns byte in [7:0]; AHB needs correct byte lane.
                        if (a_half)
                            hrdata = lookup_rdata;
                        else if (a_addr0)
                            hrdata = {lookup_rdata[7:0], 8'h00};
                        else
                            hrdata = {8'h00, lookup_rdata[7:0]};
                        hreadyout <= 1'b1;
                        astate    <= AS_IDLE;
                    end
                end

                AS_ERROR: begin
                    // Second cycle of ERROR with HREADY=1
                    hresp     <= 1'b1;
                    hreadyout <= 1'b1;
                    astate    <= AS_IDLE;
                    pend_write_err <= 1'b0;
                end

                default: astate <= AS_IDLE;
            endcase
        end
    end

endmodule
