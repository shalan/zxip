// SPDX-License-Identifier: Apache-2.0
// 32-bit AHB host smoke for ZXip (HOST_DW=32, HOST_AW=32) + SST26
// Flat phys = HADDR[19:0]; fabric always selects (hsel=1 in tests).
`timescale 1ns / 10ps

`include "zxip_pkg_params.vh"

module tb_zxip_ahb32;
    reg hclk = 1'b0;
    always #5 hclk = ~hclk;
    wire pclk = hclk;

    reg hresetn = 1'b0;
    reg presetn = 1'b0;

    reg  [31:0] haddr, hwdata;
    reg  [1:0]  htrans;
    reg         hwrite, hsel, hready;
    reg  [2:0]  hsize;
    wire [31:0] hrdata;
    wire        hreadyout, hresp;

    reg  [7:0]  paddr;
    reg         psel, penable, pwrite;
    reg  [15:0] pwdata;
    wire [15:0] prdata;
    wire        pready, pslverr;

    wire spi_sck, spi_cs_n, spi_reset_n;
    wire spi_io0, spi_io1, spi_io2, spi_io3, spi_ds;

    integer errors, i;
    reg [7:0] exp_mem [0:(1<<20)-1];

    zxip_top #(
        .HOST_DW(32),
        .HOST_AW(32)
    ) u_xip (
        .hclk(hclk), .hresetn(hresetn), .pclk(pclk), .presetn(presetn),
        .haddr(haddr), .htrans(htrans), .hwrite(hwrite), .hsize(hsize),
        .hsel(hsel), .hready(hready), .hwdata(hwdata),
        .hrdata(hrdata), .hreadyout(hreadyout), .hresp(hresp),
        .phys_valid(1'b0), .phys_i(20'h0),
        .fixed_page(6'h0), .page_sel(6'h0), .page_is_flash(1'b1),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n), .spi_reset_n(spi_reset_n),
        .spi_io0(spi_io0), .spi_io1(spi_io1), .spi_io2(spi_io2), .spi_io3(spi_io3),
        .spi_ds(spi_ds)
    );

    sst26wf080b u_flash (
        .SCK(spi_sck),
        .SIO({spi_io3, spi_io2, spi_io1, spi_io0}),
        .CEb(spi_cs_n)
    );
    defparam u_flash.I0.Tpp = 25_000;

    pullup (weak1) (spi_io0);
    pullup (weak1) (spi_io1);
    pullup (weak1) (spi_io2);
    pullup (weak1) (spi_io3);

    task apb_write;
        input [7:0]  addr;
        input [15:0] data;
        begin
            @(posedge pclk);
            paddr = addr; pwdata = data; pwrite = 1; psel = 1; penable = 0;
            @(posedge pclk); penable = 1;
            @(posedge pclk); while (!pready) @(posedge pclk);
            psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    task ahb_read32;
        input  [31:0] addr;
        output [31:0] data;
        integer guard;
        reg seen_low;
        begin
            guard = 0;
            @(posedge hclk);
            while (!hreadyout) begin
                @(posedge hclk);
                guard = guard + 1;
                if (guard > 100000) begin errors = errors + 1; data = 32'hxxxxxxxx; disable ahb_read32; end
            end
            haddr = addr; htrans = 2'b10; hwrite = 0; hsize = 3'b010; hsel = 1; hready = 1;
            @(posedge hclk);
            htrans = 2'b00; hsel = 0;
            guard = 0; seen_low = 0;
            while (1) begin
                @(posedge hclk);
                #0.1;
                if (!hreadyout) seen_low = 1;
                if (seen_low && hreadyout) begin
                    #1; data = hrdata; disable ahb_read32;
                end
                guard = guard + 1;
                if (guard > 500000) begin
                    $display("TIMEOUT word addr=%h", addr);
                    errors = errors + 1; data = 32'hxxxxxxxx; disable ahb_read32;
                end
            end
        end
    endtask

    task ahb_read16;
        input  [31:0] addr;
        output [15:0] data;
        integer guard;
        reg seen_low;
        reg [31:0] w;
        begin
            guard = 0;
            @(posedge hclk);
            while (!hreadyout) begin
                @(posedge hclk);
                guard = guard + 1;
                if (guard > 100000) begin errors = errors + 1; data = 16'hxxxx; disable ahb_read16; end
            end
            haddr = addr; htrans = 2'b10; hwrite = 0; hsize = 3'b001; hsel = 1; hready = 1;
            @(posedge hclk);
            htrans = 2'b00; hsel = 0;
            guard = 0; seen_low = 0;
            while (1) begin
                @(posedge hclk);
                #0.1;
                if (!hreadyout) seen_low = 1;
                if (seen_low && hreadyout) begin
                    #1; w = hrdata;
                    data = addr[1] ? w[31:16] : w[15:0];
                    disable ahb_read16;
                end
                guard = guard + 1;
                if (guard > 500000) begin
                    $display("TIMEOUT half addr=%h", addr);
                    errors = errors + 1; data = 16'hxxxx; disable ahb_read16;
                end
            end
        end
    endtask

    task check_word;
        input [31:0] addr;
        input [31:0] exp;
        input [255:0] tag;
        reg [31:0] got;
        begin
            ahb_read32(addr, got);
            if (got !== exp) begin
                $display("FAIL %0s addr=%h got=%h exp=%h", tag, addr, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %0s addr=%h data=%h", tag, addr, got);
        end
    endtask

    initial begin
        errors = 0;
        haddr = 0; htrans = 0; hwrite = 0; hsize = 3'b010; hsel = 0; hready = 1; hwdata = 0;
        paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;

        for (i = 0; i < (1<<20); i = i + 1)
            exp_mem[i] = i[7:0] ^ i[15:8] ^ i[19:16];

        hresetn = 0; presetn = 0;
        #100; hresetn = 1; presetn = 1; #200;

        for (i = 0; i < (1<<20); i = i + 1)
            u_flash.I0.memory[i] = exp_mem[i];
        for (i = 0; i <= u_flash.I0.PROTECT_REG_MSB; i = i + 1)
            u_flash.I0.protect[i] = 1'b0;
        u_flash.I0.IOC = 1'b1;

        $display("========== 32-bit AHB SPI baseline ==========");
        apb_write(8'h00, 16'h0801);
        apb_write(8'h04, 16'h0008);
        apb_write(8'h06, 16'h0008);

        // phys 0: bytes 00,01,02,03 → LE word = {03,02,01,00} with pattern
        // exp_mem[i] = i[7:0]^i[15:8]^i[19:16]; for i=0..3 → 0,1,2,3
        check_word(32'h0000_0000, 32'h03020100, "SPI word0");
        check_word(32'h0000_0004, 32'h07060504, "SPI word1 hit");
        check_word(32'h0000_0010, 32'h13121110, "SPI word line");

        $display("========== 32-bit AHB QSPI ==========");
        apb_write(8'h00, 16'h0805); // inv
        apb_write(8'h00, 16'h0949);
        apb_write(8'h06, 16'h0004);
        apb_write(8'h08, 16'h00A0);
        check_word(32'h0000_0000, 32'h03020100, "QSPI word0");
        check_word(32'h0000_0020, 32'h23222120, "QSPI word@0x20");

        // halfword on low/high
        begin : half_chk
            reg [15:0] h;
            ahb_read16(32'h0000_0002, h);
            if (h !== 16'h0302) begin
                $display("FAIL half@2 got=%h", h);
                errors = errors + 1;
            end else
                $display("PASS half@2 data=%h", h);
        end

        // unaligned word → ERROR
        begin : una
            integer g;
            reg saw_err;
            saw_err = 0;
            @(posedge hclk);
            while (!hreadyout) @(posedge hclk);
            haddr = 32'h0000_0001; htrans = 2'b10; hwrite = 0; hsize = 3'b010;
            hsel = 1; hready = 1;
            @(posedge hclk);
            htrans = 2'b00; hsel = 0;
            for (g = 0; g < 20; g = g + 1) begin
                @(posedge hclk);
                #0.1;
                if (hresp) saw_err = 1;
            end
            if (!saw_err) begin
                $display("FAIL unaligned word should ERROR");
                errors = errors + 1;
            end else
                $display("PASS unaligned word ERROR");
        end

        $display("========================================");
        if (errors == 0)
            $display("ALL TESTS PASSED (AHB32 suite)");
        else
            $display("FAILED with %0d errors", errors);
        $display("========================================");
        $finish;
    end
endmodule
