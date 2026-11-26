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
            #25ns;
            spi_sclk = 1'b1;
            #25ns;
            rx_frame[i] = spi_miso;
            spi_sclk = 1'b0;
        end
        #25ns;
        spi_cs_n = 1'b1;
        #50ns;
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
        #100ns;
        spi_send_40(nop_tx, rx);
        data = rx[31:0];
    endtask

    task automatic mem_write_32(input logic [9:0] addr, input logic [31:0] data);
        wait (pll_locked_o == 1'b1);
        #20ns;
        ext_mem_en    = 1'b1;
        ext_mem_we    = 1'b1;
        ext_mem_addr  = addr;
        ext_mem_wdata = data;
        #50ns;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
    endtask

    logic [31:0] rdata;
    logic [31:0] out_w0, out_w1, out_w2, out_w3;
    int          poll_cnt;

    initial begin
        rst_n         = 1'b0;
        spi_sclk      = 1'b0;
        spi_cs_n      = 1'b1;
        spi_mosi      = 1'b0;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
        ext_mem_addr  = 10'd0;
        ext_mem_wdata = 32'd0;
        poll_cnt      = 0;

        if ($test$plusargs("MON")) begin
            $monitor("[MON @ %0t] st=%0d cmd_start=%b core_start=%b core_busy=%b core_done=%b ctrl_busy=%b done_sticky=%b",
                     $time, dut.state_q, dut.cmd_start_pulse, dut.core_start_pulse,
                     dut.core_busy, dut.core_done, dut.ctrl_busy, dut.ctrl_done_sticky);
        end

        #50ns;
        rst_n = 1'b1;

        // [STEP 1] Habilita PLL (MEM_SEL_AES=0, PLL_ENABLE=1, DIV=/8 -> 2'b11 << 2)
        $display("[STEP 1] Habilitando PLL @ %0t", $time);
        spi_write(6'h0E, 32'h0000_000E);
        wait (pll_locked_o == 1'b1);
        $display("[PASS] PLL travado na Semana 6 @ %0t", $time);

        // [STEP 2] Escreve chave AES-128 FIPS-197 (2b7e1516 28aed2a6 abf71588 09cf4f3c / 00010203..0c0d0e0f)
        $display("[STEP 2] Escrevendo chave AES-128 @ %0t", $time);
        spi_write(6'h00, 32'h2b7e1516);
        spi_write(6'h01, 32'h28aed2a6);
        spi_write(6'h02, 32'habf71588);
        spi_write(6'h03, 32'h09cf4f3c);

        // [STEP 3] Configura NUM_BLOCKS = 1 (registrador 0x0A)
        $display("[STEP 3] Configurando NUM_BLOCKS = 1 @ %0t", $time);
        spi_write(6'h0A, 32'h0000_0001);

        // [STEP 4] Garante MEM_SEL_AES=0 e escreve plaintext FIPS-197 em 0..3
        $display("[STEP 4] Escrevendo bloco de entrada na memoria @ %0t", $time);
        spi_write(6'h0E, 32'h0000_000E);
        #20ns;
        mem_write_32(10'd0, 32'h3243f6a8);
        mem_write_32(10'd1, 32'h885a308d);
        mem_write_32(10'd2, 32'h313198a2);
        mem_write_32(10'd3, 32'he0370734);

        // [STEP 5] Seleciona memória para AES (0x0E = 0x0F)
        $display("[STEP 5] Selecionando memoria para AES (0x0E = 0x0F) @ %0t", $time);
        spi_write(6'h0E, 32'h0000_000F);

        // [STEP 6] Dispara START (bit 0 = 1) e enc_dec_i = 1 (bit 1 = 1 -> Cipher) => 32'h0000_0003
        $display("[STEP 6] Disparando START cifragem (0x0B = 0x03) @ %0t", $time);
        spi_write(6'h0B, 32'h0000_0003);

        poll_cnt = 0;
        do begin
            #200ns;
            spi_read(6'h0C, rdata);
            poll_cnt++;
            if (poll_cnt > 100) begin
                $fatal(1, "[TIMEOUT] AES_STATUS nao setou DONE na cifragem.");
            end
        end while (rdata[1] == 1'b0);

        $display("[INFO] AES_STATUS final: 0x%08h", rdata);

        // Devolve memória para acesso externo (MEM_SEL_AES=0) e lê saída em 512..515
        spi_write(6'h0E, 32'h0000_000E);
        #50ns;
        ext_mem_en = 1'b1; ext_mem_we = 1'b0; ext_mem_addr = 10'd0; #50ns; out_w0 = ext_mem_rdata;
        ext_mem_addr = 10'd1; #50ns; out_w1 = ext_mem_rdata;
        ext_mem_addr = 10'd2; #50ns; out_w2 = ext_mem_rdata;
        ext_mem_addr = 10'd3; #50ns; out_w3 = ext_mem_rdata;
        ext_mem_en = 1'b0;

        $display("[INFO] Saida AES: %08h %08h %08h %08h", out_w0, out_w1, out_w2, out_w3);
        if ({out_w0, out_w1, out_w2, out_w3} == 128'h3925841d_02dc09fb_dc118597_196a0b32)
            $display("[PASS] Cifragem FIPS-197 validada no minisoc_top!");
        else
            $fatal(1, "[FAIL] Cifragem divergente do esperado.");

        // Teste de decriptação (InvCipher: bit 1 = 0, START = 1 -> 32'h0000_0001)
        $display("[STEP 7] Carregando ciphertext FIPS-197 para decriptacao @ %0t", $time);
        spi_write(6'h0E, 32'h0000_000E);
        #20ns;
        mem_write_32(10'd0, 32'h3925841d);
        mem_write_32(10'd1, 32'h02dc09fb);
        mem_write_32(10'd2, 32'hdc118597);
        mem_write_32(10'd3, 32'h196a0b32);

        spi_write(6'h0E, 32'h0000_000F);
        spi_write(6'h0B, 32'h0000_0001);

        poll_cnt = 0;
        do begin
            #200ns;
            spi_read(6'h0C, rdata);
            poll_cnt++;
            if (poll_cnt > 100) begin
                $fatal(1, "[TIMEOUT] AES_STATUS nao setou DONE na decriptacao.");
            end
        end while (rdata[1] == 1'b0);

        spi_write(6'h0E, 32'h0000_000E);
        #50ns;
        ext_mem_en = 1'b1; ext_mem_we = 1'b0; ext_mem_addr = 10'd0; #50ns; out_w0 = ext_mem_rdata;
        ext_mem_addr = 10'd1; #50ns; out_w1 = ext_mem_rdata;
        ext_mem_addr = 10'd2; #50ns; out_w2 = ext_mem_rdata;
        ext_mem_addr = 10'd3; #50ns; out_w3 = ext_mem_rdata;
        ext_mem_en = 1'b0;

        $display("[INFO] Saida Decriptacao AES: %08h %08h %08h %08h", out_w0, out_w1, out_w2, out_w3);
        if ({out_w0, out_w1, out_w2, out_w3} == 128'h3243f6a8_885a308d_313198a2_e0370734)
            $display("[PASS] Decriptacao FIPS-197 validada no minisoc_top!");
        else
            $fatal(1, "[FAIL] Decriptacao divergente do plaintext esperado.");

        $finish;
    end
endmodule
