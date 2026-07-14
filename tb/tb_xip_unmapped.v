// Gate-level functional check of FLATTENED UNMAPPED netlist
// Includes SPI<->QSPI switch + APB bit-bang program
`timescale 1ns / 10ps

module tb_xip_unmapped;
    reg hclk = 1'b0;
    always #5 hclk = ~hclk;
    wire pclk = hclk;

    reg hresetn = 1'b0, presetn = 1'b0;
    reg  [15:0] haddr, hwdata, pwdata;
    reg  [ 1:0] htrans;
    reg         hwrite, hsel, hready;
    reg  [ 2:0] hsize;
    wire [15:0] hrdata, prdata;
    wire        hreadyout, hresp, pready, pslverr;
    reg  [ 7:0] paddr;
    reg         psel, penable, pwrite;
    reg [5:0] page_sel;
    reg       page_is_flash;

    wire spi_sck, spi_cs_n, spi_reset_n;
    wire spi_io0, spi_io1, spi_io2, spi_io3, spi_ds;

    integer errors, i;
    reg [7:0] exp_mem [0:(1<<20)-1];
    reg bb_cs_r, bb_sck_r;
    reg [3:0] bb_oe_r, bb_out_r;

    zxip_top u_xip (
        .hclk(hclk), .hresetn(hresetn), .pclk(pclk), .presetn(presetn),
        .haddr(haddr), .htrans(htrans), .hwrite(hwrite), .hsize(hsize),
        .hsel(hsel), .hready(hready), .hwdata(hwdata),
        .hrdata(hrdata), .hreadyout(hreadyout), .hresp(hresp),
        .phys_valid(1'b0), .phys_i(20'h0),
        .fixed_page(6'h0), .page_sel(page_sel), .page_is_flash(page_is_flash),
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

    task apb_read;
        input  [7:0]  addr;
        output [15:0] data;
        begin
            @(posedge pclk);
            paddr = addr; pwrite = 0; psel = 1; penable = 0;
            @(posedge pclk); penable = 1;
            @(posedge pclk); while (!pready) @(posedge pclk);
            data = prdata;
            psel = 0; penable = 0;
        end
    endtask

    task ahb_read16;
        input  [15:0] addr;
        output [15:0] data;
        integer guard;
        reg seen_low;
        begin
            guard = 0;
            @(posedge hclk);
            while (!hreadyout) begin
                @(posedge hclk);
                guard = guard + 1;
                if (guard > 200000) begin errors = errors + 1; data = 16'hxxxx; disable ahb_read16; end
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
                    #1; data = hrdata; disable ahb_read16;
                end
                guard = guard + 1;
                if (guard > 1000000) begin
                    $display("TIMEOUT data addr=%h", addr);
                    errors = errors + 1; data = 16'hxxxx; disable ahb_read16;
                end
            end
        end
    endtask

    function [15:0] exp_half;
        input [19:0] phys;
        reg [19:0] a;
        begin
            a = {phys[19:1], 1'b0};
            exp_half = {exp_mem[a+1], exp_mem[a]};
        end
    endfunction

    task check_read;
        input [15:0] cpu_addr;
        input [19:0] phys;
        input [255:0] tag;
        reg [15:0] got, exp;
        begin
            ahb_read16(cpu_addr, got);
            exp = exp_half(phys);
            if (got !== exp) begin
                $display("FAIL %0s cpu=%h got=%h exp=%h", tag, cpu_addr, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %0s cpu=%h data=%h", tag, cpu_addr, got);
        end
    endtask

    task cache_inv;
        reg [15:0] ctrl;
        begin
            apb_read(8'h00, ctrl);
            apb_write(8'h00, ctrl | 16'h0004);
        end
    endtask

    task bb_apply;
        begin
            apb_write(8'h12, {12'b0, bb_out_r});
            apb_write(8'h10, {10'b0, bb_oe_r, bb_sck_r, bb_cs_r});
            #20;
        end
    endtask
    task bb_enter;
        begin
            apb_write(8'h00, 16'h0002);
            bb_cs_r = 1; bb_sck_r = 0; bb_oe_r = 4'b0001; bb_out_r = 0;
            bb_apply;
        end
    endtask
    task bb_tx_bit;
        input b;
        begin
            bb_oe_r = 4'b0001; bb_out_r = {3'b0, b};
            bb_sck_r = 0; bb_apply;
            bb_sck_r = 1; bb_apply;
            bb_sck_r = 0; bb_apply;
        end
    endtask
    task bb_rx_bit;
        output b;
        reg [15:0] r;
        begin
            bb_oe_r = 4'b0;
            bb_sck_r = 0; bb_apply;
            bb_sck_r = 1; bb_apply;
            apb_read(8'h12, r);
            b = r[5];
            bb_sck_r = 0; bb_apply;
        end
    endtask
    task bb_tx_byte;
        input [7:0] data;
        integer k;
        begin for (k = 7; k >= 0; k = k - 1) bb_tx_bit(data[k]); end
    endtask
    task bb_rx_byte;
        output [7:0] data;
        integer k;
        reg bitv;
        begin
            data = 0;
            for (k = 7; k >= 0; k = k - 1) begin bb_rx_bit(bitv); data[k] = bitv; end
        end
    endtask
    task bb_select;   begin bb_cs_r = 0; bb_sck_r = 0; bb_apply; end endtask
    task bb_deselect; begin bb_cs_r = 1; bb_sck_r = 0; bb_oe_r = 0; bb_apply; #50; end endtask
    task bb_cmd;
        input [7:0] cmd;
        begin bb_select; bb_tx_byte(cmd); bb_deselect; end
    endtask
    task bb_wren; begin bb_cmd(8'h06); end endtask
    task bb_ulbpr; begin bb_wren; bb_cmd(8'h98); end endtask
    task bb_rdsr;
        output [7:0] sr;
        begin bb_select; bb_tx_byte(8'h05); bb_rx_byte(sr); bb_deselect; end
    endtask
    task bb_wait_ready;
        reg [7:0] sr;
        integer guard;
        begin
            guard = 0; sr = 8'h01;
            while (sr[0]) begin
                bb_rdsr(sr);
                guard = guard + 1;
                if (guard > 200) begin
                    $display("FAIL BB ready timeout");
                    errors = errors + 1;
                    sr = 0;
                end
            end
        end
    endtask
    task bb_page_program4;
        input [23:0] addr;
        input [7:0] b0, b1, b2, b3;
        begin
            bb_wren;
            bb_select;
            bb_tx_byte(8'h02);
            bb_tx_byte(addr[23:16]); bb_tx_byte(addr[15:8]); bb_tx_byte(addr[7:0]);
            bb_tx_byte(b0); bb_tx_byte(b1); bb_tx_byte(b2); bb_tx_byte(b3);
            bb_deselect;
            bb_wait_ready;
        end
    endtask
    task bb_spi_read2;
        input [23:0] addr;
        output [7:0] b0, b1;
        begin
            bb_select;
            bb_tx_byte(8'h03);
            bb_tx_byte(addr[23:16]); bb_tx_byte(addr[15:8]); bb_tx_byte(addr[7:0]);
            bb_rx_byte(b0); bb_rx_byte(b1);
            bb_deselect;
        end
    endtask

    initial begin
        errors = 0;
        haddr = 0; htrans = 0; hwrite = 0; hsize = 1; hsel = 0; hready = 1; hwdata = 0;
        paddr = 0; psel = 0; penable = 0; pwrite = 0; pwdata = 0;
        page_sel = 0; page_is_flash = 1;
        bb_cs_r = 1; bb_sck_r = 0; bb_oe_r = 0; bb_out_r = 0;

        for (i = 0; i < (1<<20); i = i + 1)
            exp_mem[i] = i[7:0] ^ i[15:8] ^ i[19:16];

        hresetn = 0; presetn = 0;
        #100; hresetn = 1; presetn = 1; #500;

        for (i = 0; i < (1<<20); i = i + 1)
            u_flash.I0.memory[i] = exp_mem[i];
        for (i = 0; i <= u_flash.I0.PROTECT_REG_MSB; i = i + 1)
            u_flash.I0.protect[i] = 1'b0;
        u_flash.I0.IOC = 1'b1;

        $display("===== UNMAPPED: SPI =====");
        apb_write(8'h00, 16'h0801);
        apb_write(8'h04, 16'h0008);
        apb_write(8'h06, 16'h0008);
        check_read(16'h0000, 20'h00000, "UM SPI miss");
        check_read(16'h0002, 20'h00002, "UM SPI hit");

        $display("===== UNMAPPED: SPI -> QSPI =====");
        cache_inv();
        apb_write(8'h00, 16'h0949);
        apb_write(8'h06, 16'h0004);
        apb_write(8'h08, 16'h00A0);
        check_read(16'h0000, 20'h00000, "UM SPI2QSPI");
        check_read(16'h0004, 20'h00004, "UM QSPI hit");

        $display("===== UNMAPPED: QSPI -> SPI =====");
        cache_inv();
        apb_write(8'h00, 16'h0811);
        apb_write(8'h00, 16'h0801);
        apb_write(8'h06, 16'h0008);
        check_read(16'h0000, 20'h00000, "UM QSPI2SPI");

        $display("===== UNMAPPED: BB program =====");
        bb_enter;
        bb_ulbpr;
        bb_page_program4(24'h00_9000, 8'hA5, 8'h5A, 8'hC3, 8'h3C);
        begin : bb_v
            reg [7:0] r0, r1, r2, r3;
            bb_spi_read2(24'h00_9000, r0, r1);
            bb_spi_read2(24'h00_9002, r2, r3);
            exp_mem[20'h09000] = r0;
            exp_mem[20'h09001] = r1;
            exp_mem[20'h09002] = r2;
            exp_mem[20'h09003] = r3;
            $display("PASS UM BB readback %h %h %h %h", r0, r1, r2, r3);
        end
        // SPI XIP verify via paged window page=2, offset 0x1000
        bb_cs_r = 1; bb_sck_r = 0; bb_oe_r = 0; bb_apply;
        apb_write(8'h00, 16'h0801);
        apb_write(8'h06, 16'h0008);
        cache_inv();
        page_sel = 6'd2;
        check_read(16'h9000, 20'h09000, "UM XIP after BB");

        // QSPI after program
        cache_inv();
        apb_write(8'h00, 16'h0949);
        apb_write(8'h06, 16'h0004);
        apb_write(8'h08, 16'h00A0);
        check_read(16'h9000, 20'h09000, "UM QSPI after BB");

        if (errors == 0)
            $display("ALL UNMAPPED NETLIST CHECKS PASSED (switch+BB)");
        else
            $display("UNMAPPED CHECKS FAILED: %0d errors", errors);
        $finish;
    end

    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
