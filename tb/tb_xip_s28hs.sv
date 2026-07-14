// Co-simulation harness: zxip_top (Verilog-2005) + Infineon s28hs256m4.sv
// Example VIP only — see also tb_xip_sst26.v. Profile: specs.md §17.3
// Phase 0: POR smoke. Later phases drive AHB/APB BFMs (see RTL_PLAN.md).
`timescale 1ps / 1ps

module tb_xip_s28hs;
    // Clocks — use ns-scale periods expressed in ps
    reg hclk = 1'b0;
    reg pclk = 1'b0;
    always #5000 hclk = ~hclk; // 100 MHz
    always #5000 pclk = ~pclk;

    reg hresetn = 1'b0;
    reg presetn = 1'b0;

    // AHB stub idle
    reg  [15:0] haddr  = 16'h0;
    reg  [ 1:0] htrans = 2'b00;
    reg         hwrite = 1'b0;
    reg  [ 2:0] hsize  = 3'b001;
    reg         hsel   = 1'b0;
    reg         hready = 1'b1;
    reg  [15:0] hwdata = 16'h0;
    wire [15:0] hrdata;
    wire        hreadyout;
    wire        hresp;

    // APB idle
    reg  [ 7:0] paddr  = 8'h0;
    reg         psel   = 1'b0;
    reg         penable= 1'b0;
    reg         pwrite = 1'b0;
    reg  [15:0] pwdata = 16'h0;
    wire [15:0] prdata;
    wire        pready;
    wire        pslverr;

    // Pages
    reg [5:0] fixed_page    = 6'h0;
    reg [5:0] page_sel      = 6'h0;
    reg       page_is_flash = 1'b1;

    // SPI nets
    wire spi_sck, spi_cs_n, spi_reset_n;
    wire spi_io0, spi_io1, spi_io2, spi_io3, spi_ds;
    wire INTNeg;

    // Weak pull-ups on open lines (model + idle controller)
    pullup (spi_cs_n);
    pullup (spi_io0);
    pullup (spi_io1);
    pullup (spi_io2);
    pullup (spi_io3);
    pullup (spi_ds);
    pullup (INTNeg);

    zxip_top u_xip (
        .hclk        (hclk),
        .hresetn     (hresetn),
        .pclk        (pclk),
        .presetn     (presetn),
        .haddr       (haddr),
        .htrans      (htrans),
        .hwrite      (hwrite),
        .hsize       (hsize),
        .hsel        (hsel),
        .hready      (hready),
        .hwdata      (hwdata),
        .hrdata      (hrdata),
        .hreadyout   (hreadyout),
        .hresp       (hresp),
        .phys_valid  (1'b0),
        .phys_i      (20'h0),
        .fixed_page  (fixed_page),
        .page_sel    (page_sel),
        .page_is_flash(page_is_flash),
        .paddr       (paddr),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .pwdata      (pwdata),
        .prdata      (prdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .spi_sck     (spi_sck),
        .spi_cs_n    (spi_cs_n),
        .spi_reset_n (spi_reset_n),
        .spi_io0     (spi_io0),
        .spi_io1     (spi_io1),
        .spi_io2     (spi_io2),
        .spi_io3     (spi_io3),
        .spi_ds      (spi_ds)
    );

    // Vendor model — pin map per specs.md §17
    s28hs256m4 #(
        .UserPreload   (1),
        .mem_file_name ("s28hs256m4.mem"),
        .otp_file_name ("none"),
        .TimingModel   ("S28HS256MXXBHX4X0")
    ) u_flash (
        .SI       (spi_io0),
        .SO       (spi_io1),
        .DQ2      (spi_io2),
        .DQ3      (spi_io3),
        .SCK      (spi_sck),
        .CSNeg    (spi_cs_n),
        .DS       (spi_ds),
        .RESETNeg (spi_reset_n),
        .INTNeg   (INTNeg)
    );

    initial begin
        $display("[%0t] TB: assert reset", $time);
        hresetn = 1'b0;
        presetn = 1'b0;
        // Hold reset long enough for flash POR (model uses real delays)
        #1_000_000_000; // 1 us in 1ps timescale? 1e9 ps = 1 ms
        // Actually 1_000_000_000 ps = 1 ms
        hresetn = 1'b1;
        presetn = 1'b1;
        $display("[%0t] TB: deassert reset; CS_n=%b SCK=%b", $time, spi_cs_n, spi_sck);
        #10_000_000; // 10 us
        if (spi_cs_n !== 1'b1) begin
            $display("FAIL: CS# should idle high after reset");
            $fatal(1);
        end
        $display("PASS: Phase-0 POR smoke (controller idle, flash instantiated)");
        $display("NOTE: Functional AHB fill tests land in Phases 2+ (RTL_PLAN.md)");
        $finish;
    end

    // Safety timeout
    initial begin
        #50_000_000_000; // 50 ms
        $display("TIMEOUT");
        $fatal(1);
    end
endmodule
