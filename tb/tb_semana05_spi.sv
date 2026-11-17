`timescale 1ns/1ps

module tb_semana05_spi;

    // Sinais de Clock e Reset
    logic clkin;
    logic clk; // Clock interno do sistema gerado pelo PLL
    logic rst_n;

    // Sinais do PLL Mock
    logic       pll_enable;
    logic [1:0] pll_div_sel;
    logic       pll_clkout;
    logic       pll_locked;

    // Sinais da Interface SPI
    logic       spi_sclk;
    logic       spi_cs_n;
    logic       spi_mosi;
    logic       spi_miso;

    // Sinais entre SPI e Banco de Registradores
    logic [5:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_wr_en;
    logic        reg_rd_en;
    logic [31:0] reg_rdata;

    // -------------------------------------------------------------------------
    // Instanciação do PLL Mock (`minisoc_pll_mock`)
    // -------------------------------------------------------------------------
    minisoc_pll_mock u_pll (
        .clkin       (clkin),
        .rst_n       (rst_n),
        .enable      (pll_enable),
        .pll_div_sel (pll_div_sel),
        .clkout      (pll_clkout),
        .locked      (pll_locked)
    );

    assign clk = pll_clkout;

    // -------------------------------------------------------------------------
    // Instanciação do Front-End SPI (`minisoc_spi`)
    // -------------------------------------------------------------------------
    minisoc_spi u_spi (
        .spi_sclk    (spi_sclk),
        .spi_cs_n    (spi_cs_n),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),
        .clk         (clk),
        .rst_n       (rst_n),
        .reg_addr_o  (reg_addr),
        .reg_wdata_o (reg_wdata),
        .reg_wr_en_o (reg_wr_en),
        .reg_rd_en_o (reg_rd_en),
        .reg_rdata_i (reg_rdata)
    );

    // -------------------------------------------------------------------------
    // Modelo Comportamental do Banco de Registradores (Seção 6)
    // -------------------------------------------------------------------------
    logic [31:0] regs [0:63];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            regs[6'h00] <= '0; // KEY0
            regs[6'h01] <= '0; // KEY1
            regs[6'h02] <= '0; // KEY2
            regs[6'h03] <= '0; // KEY3
            regs[6'h04] <= '0; // IV0
            regs[6'h05] <= '0; // IV1
            regs[6'h06] <= '0; // IV2
            regs[6'h07] <= '0; // IV3
            regs[6'h08] <= '0; // COUNTER_HI
            regs[6'h09] <= '0; // COUNTER_LO
            regs[6'h0A] <= '0; // NUM_BLOCKS
            regs[6'h0B] <= '0; // AES_CONTROL
            regs[6'h0C] <= 32'h00000001; // AES_STATUS (Pronto)
            regs[6'h0D] <= 32'h312E3030; // VERSION ("1.00")
            regs[6'h0E] <= '0; // SYSTEM_CONTROL
            regs[6'h0F] <= 32'h00000001; // SYSTEM_STATUS
        end else begin
            regs[6'h0B][0] <= 1'b0; // Auto-limpeza do pulso de START

            if (reg_wr_en) begin
                unique case (reg_addr)
                    6'h00, 6'h01, 6'h02, 6'h03,
                    6'h04, 6'h05, 6'h06, 6'h07,
                    6'h08, 6'h09, 6'h0A, 6'h0B,
                    6'h0E: regs[reg_addr] <= reg_wdata;
                    default: ; // Proteção contra escrita em Read-Only
                endcase
            end
        end
    end

    assign reg_rdata = regs[reg_addr];

    // -------------------------------------------------------------------------
    // Geradores de Clock
    // -------------------------------------------------------------------------
    always #1 clkin = ~clkin;

    initial spi_sclk = 1'b0;
    always #25 spi_sclk = ~spi_sclk; // 10 MHz SPI SCLK

    // -------------------------------------------------------------------------
    // Tarefas de Transação SPI (Escrita e Leitura em Duas Fases)
    // -------------------------------------------------------------------------
    task spi_write(input [5:0] addr, input [31:0] wdata);
        logic [39:0] frame;
        frame = {1'b1, addr, 1'b0, wdata}; // RWb = 1 (Escrita)
        
        @(negedge spi_sclk);
        spi_cs_n = 1'b0;
        for (int i = 39; i >= 0; i--) begin
            spi_mosi = frame[i];
            @(negedge spi_sclk);
        end
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #100;
    endtask

    task spi_read(input [5:0] addr, output [31:0] rdata);
        logic [39:0] frame_phase1;
        logic [39:0] frame_phase2;
        logic [39:0] rx_miso_data;

        // FASE 1: Seleciona o endereço (RWb = 0)
        frame_phase1 = {1'b0, addr, 1'b0, 32'h00000000};
        
        @(negedge spi_sclk);
        spi_cs_n = 1'b0;
        for (int i = 39; i >= 0; i--) begin
            spi_mosi = frame_phase1[i];
            @(negedge spi_sclk);
        end
        spi_cs_n = 1'b1;
        #100;

        // FASE 2: Envia NOP (0x3F) para capturar o dado deslocado no MISO
        frame_phase2 = {1'b0, 6'h3F, 1'b0, 32'h00000000};
        rx_miso_data = '0;

        @(negedge spi_sclk);
        spi_cs_n = 1'b0;
        for (int i = 39; i >= 0; i--) begin
            spi_mosi = frame_phase2[i];
            rx_miso_data = {rx_miso_data[38:0], spi_miso};
            @(negedge spi_sclk);
        end
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        
        rdata = rx_miso_data[31:0];
        #100;
    endtask

    // -------------------------------------------------------------------------
    // Sequência de Estímulos Principais
    // -------------------------------------------------------------------------
    initial begin
        logic [31:0] rval; // <--- Declarada no topo do bloco initial

        clkin       = 0;
        rst_n       = 0;
        pll_enable  = 0;
        pll_div_sel = 2'b00;
        spi_cs_n    = 1;
        spi_mosi    = 0;

        #100;
        rst_n = 1;
        #100;

        $display("================================================================");
        $display(" INICIANDO TESTBENCH DIRIGIDO - SEMANA 5 (SPI & PLL)          ");
        $display("================================================================");

        // 1. Validação do PLL Mock nos 4 divisores
        for (int div = 0; div < 4; div++) begin
            pll_div_sel = div[1:0];
            pll_enable  = 1'b1;
            
            @(posedge pll_locked);
            $display("[PASS] PLL travado com sucesso para PLL_DIV_SEL = %0b (Divisor /%0d)", pll_div_sel, (1 << pll_div_sel));
            
            pll_enable = 1'b0;
            #200;
        end

        // Reativa PLL com divisor /1 para as transações SPI
        pll_div_sel = 2'b00;
        pll_enable  = 1'b1;
        @(posedge pll_locked);

        // 2. Teste de Escrita e Leitura em Registradores R/W
        $display("\n[INFO] Executando Escrita e Leitura de Registradores via SPI...");
        
        spi_write(6'h00, 32'h2B7E1516); // KEY0
        spi_write(6'h01, 32'h28AED2A6); // KEY1
        spi_write(6'h02, 32'hABF71588); // KEY2
        spi_write(6'h03, 32'h09CF4F3C); // KEY3
        spi_write(6'h0A, 32'h00000004); // NUM_BLOCKS
        spi_write(6'h0B, 32'h00000001); // AES_CONTROL (START)

        spi_read(6'h00, rval);
        if (rval === 32'h2B7E1516) $display("[PASS] KEY0 lido corretamente: 0x%08h", rval);
        else                       $display("[FAIL] KEY0 incorreto. Obtido: 0x%08h", rval);

        spi_read(6'h01, rval);
        if (rval === 32'h28AED2A6) $display("[PASS] KEY1 lido corretamente: 0x%08h", rval);
        else                       $display("[FAIL] KEY1 incorreto. Obtido: 0x%08h", rval);

        spi_read(6'h0A, rval);
        if (rval === 32'h00000004) $display("[PASS] NUM_BLOCKS lido corretamente: 0x%08h", rval);
        else                       $display("[FAIL] NUM_BLOCKS incorreto. Obtido: 0x%08h", rval);

        // 3. Validação de Proteção Read-Only
        $display("\n[INFO] Testando proteção de Registradores Read-Only (VERSION)...");
        spi_read(6'h0D, rval);
        $display("[INFO] Versão original lida: 0x%08h", rval);
        
        spi_write(6'h0D, 32'hDEADBEEF); // Tentativa de escrita proibida
        
        spi_read(6'h0D, rval);
        if (rval === 32'h312E3030) $display("[PASS] Registrador Read-Only protegido com sucesso!");
        else                       $display("[FAIL] Segurança violada! VERSION foi modificado para 0x%08h", rval);

        $display("================================================================");
        $display(" TESTES DA SEMANA 5 CONCLUÍDOS COM SUCESSO                      ");
        $display("================================================================");
        $finish;
    end

endmodule
