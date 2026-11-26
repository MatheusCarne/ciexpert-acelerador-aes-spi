`timescale 1ns/1ps

module tb_semana06_top;
    logic        clkin;
    logic        rst_n;
    logic        spi_sclk;
    logic        spi_cs_n;
    logic        spi_mosi;
    logic        spi_miso;
    logic        ext_mem_en;
    logic        ext_mem_we;
    logic [9:0]  ext_mem_addr;
    logic [31:0] ext_mem_wdata;
    logic [31:0] ext_mem_rdata;
    logic        pll_locked_o;

    minisoc_top dut (
        .clkin         (clkin),
        .rst_n         (rst_n),
        .spi_sclk      (spi_sclk),
        .spi_cs_n      (spi_cs_n),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso),
        .ext_mem_en    (ext_mem_en),
        .ext_mem_we    (ext_mem_we),
        .ext_mem_addr  (ext_mem_addr),
        .ext_mem_wdata (ext_mem_wdata),
        .ext_mem_rdata (ext_mem_rdata),
        .pll_locked_o  (pll_locked_o)
    );

    // Referência de 2 GHz (período 0.5 ns)
    initial begin
        clkin = 1'b0;
        forever #0.25ns clkin = ~clkin;
    end

    task automatic spi_send_40(input logic [39:0] frame, output logic [39:0] rx_frame);
        int i;
        rx_frame = 40'd0;
        spi_cs_n = 1'b0;
        for (i = 39; i >= 0; i--) begin
            spi_mosi = frame[i];
            #5ns;
            spi_sclk = 1'b1;
            #5ns;
            rx_frame[i] = spi_miso;
            spi_sclk = 1'b0;
        end
        #5ns;
        spi_cs_n = 1'b1;
        #20ns;
    endtask

    task automatic spi_write(input logic [5:0] addr, input logic [31:0] data);
        logic [39:0] tx, rx;
        tx = {1'b1, addr, 1'b0, data};
        spi_send_40(tx, rx);
    endtask

    task automatic spi_read(input logic [5:0] addr, output logic [31:0] data);
        logic [39:0] tx, rx, nop_tx;
        tx     = {1'b0, addr, 1'b0, 32'h0};
        nop_tx = {1'b0, 6'h3F, 1'b0, 32'h0};
        spi_send_40(tx, rx);
        spi_send_40(nop_tx, rx);
        data = rx[31:0];
    endtask

    task automatic mem_write_32(input logic [9:0] addr, input logic [31:0] data);
        @(posedge pll_locked_o);
        repeat (2) @(posedge spi_sclk);
        ext_mem_en    = 1'b1;
        ext_mem_we    = 1'b1;
        ext_mem_addr  = addr;
        ext_mem_wdata = data;
        #20ns;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
    endtask

    logic [31:0] rdata;
    logic [31:0] out_w0, out_w1, out_w2, out_w3;

    initial begin
        rst_n         = 1'b0;
        spi_sclk      = 1'b0;
        spi_cs_n      = 1'b1;
        spi_mosi      = 1'b0;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
        ext_mem_addr  = 10'd0;
        ext_mem_wdata = 32'd0;

        #20ns;
        rst_n = 1'b1;

        // Habilita PLL (MEM_SEL_AES=0, PLL_ENABLE=1, DIV=/8 -> 2'b11 << 2)
        spi_write(6'h0E, 32'h0000_000E);
        wait (pll_locked_o == 1'b1);
        $display("[PASS] PLL travado na Semana 6.");

        // Escreve chave NIST FIPS-197
        spi_write(6'h00, 32'h2b7e1516);
        spi_write(6'h01, 32'h28aed2a6);
        spi_write(6'h02, 32'habf71588);
        spi_write(6'h03, 32'h09cf4f3c);

        // Configura 1 bloco
        spi_write(6'h0A, 32'h0000_0001);

        // Carrega bloco de entrada na memória (endereços 0..3)
        mem_write_32(10'd0, 32'h3243f6a8);
        mem_write_32(10'd1, 32'h885a308d);
        mem_write_32(10'd2, 32'h313198a2);
        mem_write_32(10'd3, 32'he0370734);

        // Seleciona memória para AES (MEM_SEL_AES=1) e mantém PLL habilitado
        spi_write(6'h0E, 32'h0000_000F);

        // Dispara START (bit 0 de AES_CONTROL em 0x0B)
        spi_write(6'h0B, 32'h0000_0001);

        // Aguarda conclusão via AES_STATUS (0x0C)
        do begin
            #200ns;
            spi_read(6'h0C, rdata);
            $display("[POLL] AES_STATUS = 0x%08h @ %0t", rdata, $time);
        end while (rdata[1] == 1'b0);

        $display("[INFO] AES_STATUS final: 0x%08h", rdata);

        // Devolve memória para acesso externo (MEM_SEL_AES=0) e lê saída em 512..515
        spi_write(6'h0E, 32'h0000_000E);
        #20ns;
        ext_mem_en = 1'b1; ext_mem_we = 1'b0; ext_mem_addr = 10'd512; #20ns; out_w0 = ext_mem_rdata;
        ext_mem_addr = 10'd513; #20ns; out_w1 = ext_mem_rdata;
        ext_mem_addr = 10'd514; #20ns; out_w2 = ext_mem_rdata;
        ext_mem_addr = 10'd515; #20ns; out_w3 = ext_mem_rdata;
        ext_mem_en = 1'b0;

        $display("[INFO] Saida AES: %08h %08h %08h %08h", out_w0, out_w1, out_w2, out_w3);
        if ({out_w0, out_w1, out_w2, out_w3} == 128'h3925841d_02dc09fb_dc118597_196a0b32)
            $display("[PASS] Vetor FIPS-197 validado no minisoc_top!");
        else
            $display("[FAIL] Resultado divergente do esperado.");

        $finish;
    end
endmodule
