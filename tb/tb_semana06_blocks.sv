`timescale 1ns/1ps

module tb_semana06_blocks;
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

    // Clock de referência de 2 GHz
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
        #20ns;
        ext_mem_en    = 1'b1;
        ext_mem_we    = 1'b1;
        ext_mem_addr  = addr;
        ext_mem_wdata = data;
        #50ns;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
    endtask

    task automatic mem_read_32(input logic [9:0] addr, output logic [31:0] data);
        #20ns;
        ext_mem_en   = 1'b1;
        ext_mem_we   = 1'b0;
        ext_mem_addr = addr;
        #50ns;
        data         = ext_mem_rdata;
        ext_mem_en   = 1'b0;
    endtask

    task automatic program_common_cfg(
        input logic [2:0]   mode_v,
        input logic         decrypt_v,
        input logic [31:0]  nblocks_v,
        input logic [127:0] iv_v
    );
        // KEY = 2b7e1516_28aed2a6_abf71588_09cf4f3c
        spi_write(6'h00, 32'h2b7e1516);
        spi_write(6'h01, 32'h28aed2a6);
        spi_write(6'h02, 32'habf71588);
        spi_write(6'h03, 32'h09cf4f3c);

        spi_write(6'h04, iv_v[127:96]);
        spi_write(6'h05, iv_v[95:64]);
        spi_write(6'h06, iv_v[63:32]);
        spi_write(6'h07, iv_v[31:0]);

        // COUNTER = 64'h00000000_00000001 (combinado com IV[127:64] em CTR)
        spi_write(6'h08, 32'h00000000);
        spi_write(6'h09, 32'h00000001);

        // NUM_BLOCKS
        spi_write(6'h0A, nblocks_v);

        // AES_CONTROL sem START ainda: {27'b0, mode_v, decrypt_v, 1'b0}
        spi_write(6'h0B, {27'd0, mode_v, decrypt_v, 1'b0});
    endtask

    task automatic run_block_vector_test(
        input string mode_name,
        input logic [2:0] mode_v,
        input logic decrypt_v,
        input int nblocks,
        input string in_file,
        input string exp_file,
        input logic [127:0] iv_v
    );
        logic [31:0] in_words  [0:1023];
        logic [31:0] exp_words [0:1023];
        logic [31:0] got_w;
        logic [31:0] st_val;
        int total_words;
        int poll_cnt;
        int max_polls;

        total_words = nblocks * 4;
        $readmemh(in_file,  in_words);
        $readmemh(exp_file, exp_words);

        // 1. Garante posse externa (MEM_SEL_AES=0, PLL_EN=1, DIV=/8 -> 0x0E) e carrega entrada
        spi_write(6'h0E, 32'h0000_000E);
        for (int w = 0; w < total_words; w++) begin
            mem_write_32(10'(w), in_words[w]);
        end

        // 2. Configura chave, IV, contador, NUM_BLOCKS e modo/direcao
        program_common_cfg(mode_v, decrypt_v, 32'(nblocks), iv_v);

        // 3. Entrega memória ao AES (MEM_SEL_AES=1 -> 0x0F) e dispara START (bit 0 = 1)
        spi_write(6'h0E, 32'h0000_000F);
        spi_write(6'h0B, {27'd0, mode_v, decrypt_v, 1'b1});

        // 4. Aguarda DONE (bit 1) com timeout escalonado por quantidade de blocos
        poll_cnt  = 0;
        max_polls = (nblocks >= 256) ? 10000 : 500;
        do begin
            #200ns;
            spi_read(6'h0C, st_val);
            poll_cnt++;
            if (poll_cnt > max_polls) begin
                $fatal(1, "[TIMEOUT] %s dec=%0b nblk=%0d STATUS=0x%08h", mode_name, decrypt_v, nblocks, st_val);
            end
        end while (st_val[1] == 1'b0);

        if (st_val[2] !== 1'b0) begin
            $fatal(1, "[FAIL] %s dec=%0b nblk=%0d: ERROR inesperado (STATUS=0x%08h)", mode_name, decrypt_v, nblocks, st_val);
        end
        if (st_val[15:8] !== 8'(nblocks)) begin
            $fatal(1, "[FAIL] %s dec=%0b nblk=%0d: BLOCKS_DONE=%0d esperado=%0d", mode_name, decrypt_v, nblocks, st_val[15:8], nblocks);
        end

        // 5. Devolve memória ao host (0x0E) e confere saída in-place
        spi_write(6'h0E, 32'h0000_000E);
        for (int w = 0; w < total_words; w++) begin
            mem_read_32(10'(w), got_w);
            if (got_w !== exp_words[w]) begin
                $fatal(1, "[FAIL] %s dec=%0b nblk=%0d addr=%0d: got=0x%08h exp=0x%08h",
                       mode_name, decrypt_v, nblocks, w, got_w, exp_words[w]);
            end
        end

        $display("[PASS] %s (%s) | %0d bloco(s) | STATUS=0x%08h | BLOCKS_DONE=%0d",
                 mode_name, decrypt_v ? "DEC" : "ENC", nblocks, st_val, st_val[15:8]);
    endtask

    task automatic run_invalid_cfg_test(
        input string tag,
        input logic [2:0]  mode_v,
        input logic [31:0] nblocks_v
    );
        logic [31:0] marker_w;
        logic [31:0] got_w;
        logic [31:0] st_val;

        marker_w = 32'hA5A5_5A5A;
        spi_write(6'h0E, 32'h0000_000E);
        mem_write_32(10'd0, marker_w);

        program_common_cfg(mode_v, 1'b1, nblocks_v, 128'h00010203_04050607_08090a0b_0c0d0e0f);
        spi_write(6'h0E, 32'h0000_000F);
        spi_write(6'h0B, {27'd0, mode_v, 1'b1, 1'b1});

        #2000ns;
        spi_read(6'h0C, st_val);

        if (st_val[2] !== 1'b1) begin
            $fatal(1, "[FAIL] Caso invalido (%s): ERROR (bit 2) nao setado! STATUS=0x%08h", tag, st_val);
        end
        if (st_val[1] !== 1'b0) begin
            $fatal(1, "[FAIL] Caso invalido (%s): DONE (bit 1) deveria ser 0! STATUS=0x%08h", tag, st_val);
        end

        spi_write(6'h0E, 32'h0000_000E);
        mem_read_32(10'd0, got_w);
        if (got_w !== marker_w) begin
            $fatal(1, "[FAIL] Caso invalido (%s): memoria alterada (got=0x%08h)", tag, got_w);
        end

        $display("[PASS] Configuracao invalida rejeitada (%s): STATUS=0x%08h", tag, st_val);
    endtask

    initial begin
        rst_n         = 1'b0;
        spi_sclk      = 1'b0;
        spi_cs_n      = 1'b1;
        spi_mosi      = 1'b0;
        ext_mem_en    = 1'b0;
        ext_mem_we    = 1'b0;
        ext_mem_addr  = 10'd0;
        ext_mem_wdata = 32'd0;

        #50ns;
        rst_n = 1'b1;

        // Habilita PLL (0x0E) e aguarda lock
        spi_write(6'h0E, 32'h0000_000E);
        wait (pll_locked_o == 1'b1);
        $display("[INFO] PLL travado @ %0t", $time);

        // 1. Testes de configuração inválida (NUM_BLOCKS fora de 1..256 e MODE reservado / W10)
        run_invalid_cfg_test("NUM_BLOCKS=0",   3'b000, 32'd0);
        run_invalid_cfg_test("NUM_BLOCKS=257", 3'b000, 32'd257);
        run_invalid_cfg_test("MODE=111_RES",   3'b111, 32'd1);
        run_invalid_cfg_test("MODE=010_PCBC",  3'b010, 32'd1);

        // 2. Modos ECB (000), CBC (001) e CTR (101) — ENC e DEC para 1, 2 e 256 blocos
        run_block_vector_test("ECB", 3'b000, 1'b1, 1,   "tb/vectors_w06/pt_1.hex",   "tb/vectors_w06/ecb_enc_1.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("ECB", 3'b000, 1'b0, 1,   "tb/vectors_w06/ecb_enc_1.hex","tb/vectors_w06/ecb_dec_1.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("ECB", 3'b000, 1'b1, 2,   "tb/vectors_w06/pt_2.hex",   "tb/vectors_w06/ecb_enc_2.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("ECB", 3'b000, 1'b0, 2,   "tb/vectors_w06/ecb_enc_2.hex","tb/vectors_w06/ecb_dec_2.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("ECB", 3'b000, 1'b1, 256, "tb/vectors_w06/pt_256.hex", "tb/vectors_w06/ecb_enc_256.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("ECB", 3'b000, 1'b0, 256, "tb/vectors_w06/ecb_enc_256.hex","tb/vectors_w06/ecb_dec_256.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);

        run_block_vector_test("CBC", 3'b001, 1'b1, 1,   "tb/vectors_w06/pt_1.hex",   "tb/vectors_w06/cbc_enc_1.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("CBC", 3'b001, 1'b0, 1,   "tb/vectors_w06/cbc_enc_1.hex","tb/vectors_w06/cbc_dec_1.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("CBC", 3'b001, 1'b1, 2,   "tb/vectors_w06/pt_2.hex",   "tb/vectors_w06/cbc_enc_2.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("CBC", 3'b001, 1'b0, 2,   "tb/vectors_w06/cbc_enc_2.hex","tb/vectors_w06/cbc_dec_2.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("CBC", 3'b001, 1'b1, 256, "tb/vectors_w06/pt_256.hex", "tb/vectors_w06/cbc_enc_256.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);
        run_block_vector_test("CBC", 3'b001, 1'b0, 256, "tb/vectors_w06/cbc_enc_256.hex","tb/vectors_w06/cbc_dec_256.hex", 128'h00010203_04050607_08090a0b_0c0d0e0f);

        run_block_vector_test("CTR", 3'b101, 1'b1, 1,   "tb/vectors_w06/pt_1.hex",   "tb/vectors_w06/ctr_enc_1.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);
        run_block_vector_test("CTR", 3'b101, 1'b0, 1,   "tb/vectors_w06/ctr_enc_1.hex","tb/vectors_w06/ctr_dec_1.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);
        run_block_vector_test("CTR", 3'b101, 1'b1, 2,   "tb/vectors_w06/pt_2.hex",   "tb/vectors_w06/ctr_enc_2.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);
        run_block_vector_test("CTR", 3'b101, 1'b0, 2,   "tb/vectors_w06/ctr_enc_2.hex","tb/vectors_w06/ctr_dec_2.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);
        run_block_vector_test("CTR", 3'b101, 1'b1, 256, "tb/vectors_w06/pt_256.hex", "tb/vectors_w06/ctr_enc_256.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);
        run_block_vector_test("CTR", 3'b101, 1'b0, 256, "tb/vectors_w06/ctr_enc_256.hex","tb/vectors_w06/ctr_dec_256.hex", 128'hf0f1f2f3_f4f5f6f7_08090a0b_0c0d0e0f);

        $display("[ALL PASS] Semana 6 concluida: ECB, CBC e CTR (ENC/DEC) para 1, 2 e 256 blocos + erros validados!");
        $finish;
    end
endmodule
