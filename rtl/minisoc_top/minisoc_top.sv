// ============================================================================
// minisoc_top.sv
// Integração de nível superior: PLL Mock, SPI/Registradores, AES-128 e Memória.
// ============================================================================
module minisoc_top (
    input  logic        clkin,          // Referência de 2 GHz
    input  logic        rst_n,          // Reset assíncrono ativo em baixo

    // Interface SPI externa (Modo 0)
    input  logic        spi_sclk,
    input  logic        spi_cs_n,
    input  logic        spi_mosi,
    output logic        spi_miso,

    // Observabilidade / status externo
    output logic        pll_locked_o
);

    // ------------------------------------------------------------------------
    // 1. Mapa de Endereços (Seção 6)
    // ------------------------------------------------------------------------
    localparam logic [5:0] ADDR_KEY0           = 6'h00; // RW : cfg_key[127:96]
    localparam logic [5:0] ADDR_KEY1           = 6'h01; // RW : cfg_key[95:64]
    localparam logic [5:0] ADDR_KEY2           = 6'h02; // RW : cfg_key[63:32]
    localparam logic [5:0] ADDR_KEY3           = 6'h03; // RW : cfg_key[31:0]
    localparam logic [5:0] ADDR_IV0            = 6'h04; // RW : cfg_iv[127:96]
    localparam logic [5:0] ADDR_IV1            = 6'h05; // RW : cfg_iv[95:64]
    localparam logic [5:0] ADDR_IV2            = 6'h06; // RW : cfg_iv[63:32]
    localparam logic [5:0] ADDR_IV3            = 6'h07; // RW : cfg_iv[31:0]
    localparam logic [5:0] ADDR_COUNTER_HI     = 6'h08; // RW : cfg_counter[63:32]
    localparam logic [5:0] ADDR_COUNTER_LO     = 6'h09; // RW : cfg_counter[31:0]
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A; // RW : Quantidade de blocos AES de 128 bits (1..256)
    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B; // RW : START, DECRYPT, MODE
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C; // R  : BUSY, DONE, ERROR, BLOCKS_DONE
    localparam logic [5:0] ADDR_VERSION        = 6'h0D; // R  : Identificação da versão do front-end
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E; // RW : MEM_SEL_AES, PLL_ENABLE, PLL_DIV_SEL
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F; // R  : PLL_LOCKED
    localparam logic [5:0] ADDR_NOP            = 6'h3F; // -  : Fase de retorno de leitura SPI

    // Posições de bit convencionadas (ajuste se a especificação exigir outros bits)
    localparam int         BIT_AES_CTRL_START    = 0;
    localparam int         BIT_AES_CTRL_DECRYPT  = 1;
    localparam int         BIT_AES_CTRL_MODE     = 2;

    localparam int         BIT_AES_STAT_BUSY     = 0;
    localparam int         BIT_AES_STAT_DONE     = 1;
    localparam int         BIT_AES_STAT_ERROR    = 2;

    localparam int         BIT_SYS_CTRL_MEM_SEL  = 0;
    localparam int         BIT_SYS_CTRL_PLL_EN   = 1;

    localparam logic [31:0] VERSION_ID           = 32'h312e3030; // "1.00"

    // ------------------------------------------------------------------------
    // 2. Sinais internos
    // ------------------------------------------------------------------------
    logic         sys_clk;
    logic         pll_locked;

    logic [5:0]   reg_addr;
    logic [31:0]  reg_wdata;
    logic         reg_wr_en;
    logic         reg_rd_en;
    logic [31:0]  reg_rdata;

    // Registradores R/W
    logic [31:0]  key_q [0:3];
    logic [31:0]  iv_q  [0:3];
    logic [31:0]  counter_hi_q;
    logic [31:0]  counter_lo_q;
    logic [31:0]  num_blocks_q;
    logic [31:0]  aes_ctrl_q;
    logic [31:0]  sys_ctrl_q;

    // Campos derivados e controle/status do AES
    logic         aes_start_pulse;
    logic         aes_decrypt;
    logic [1:0]   aes_mode;
    logic         aes_busy;
    logic         aes_done;
    logic         aes_error_q;
    logic         aes_done_sticky_q;
    logic [15:0]  blocks_done_q;
    logic [127:0] aes_key_128;
    logic [127:0] aes_iv_128;
    logic [63:0]  aes_counter_64;
    logic [127:0] aes_block_in;
    logic [127:0] aes_block_out;

    // Campos derivados do SYSTEM_CONTROL
    logic         mem_sel_aes;
    logic         pll_enable;
    logic [1:0]   pll_div_sel;

    assign pll_locked_o = pll_locked;

    assign aes_key_128    = {key_q[0], key_q[1], key_q[2], key_q[3]};
    assign aes_iv_128     = {iv_q[0], iv_q[1], iv_q[2], iv_q[3]};
    assign aes_counter_64 = {counter_hi_q, counter_lo_q};

    assign aes_decrypt    = aes_ctrl_q[BIT_AES_CTRL_DECRYPT];
    assign aes_mode       = aes_ctrl_q[BIT_AES_CTRL_MODE+1:BIT_AES_CTRL_MODE];

    assign mem_sel_aes    = sys_ctrl_q[BIT_SYS_CTRL_MEM_SEL];
    assign pll_enable     = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN];
    assign pll_div_sel    = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN+2:BIT_SYS_CTRL_PLL_EN+1];

    // ------------------------------------------------------------------------
    // 3. PLL Mock (referência 2 GHz -> sys_clk)
    // ------------------------------------------------------------------------
    minisoc_pll_mock u_pll_mock (
        .clkin       (clkin),
        .rst_n       (rst_n),
        .enable      (pll_enable),
        .pll_div_sel (pll_div_sel),
        .clkout      (sys_clk),
        .locked      (pll_locked)
    );

    // ------------------------------------------------------------------------
    // 4. Front-end SPI (domínio spi_sclk -> sys_clk via toggle)
    // ------------------------------------------------------------------------
    minisoc_spi u_spi (
        .spi_sclk    (spi_sclk),
        .spi_cs_n    (spi_cs_n),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .reg_addr_o  (reg_addr),
        .reg_wdata_o (reg_wdata),
        .reg_wr_en_o (reg_wr_en),
        .reg_rd_en_o (reg_rd_en),
        .reg_rdata_i (reg_rdata)
    );

    // ------------------------------------------------------------------------
    // 5. Banco de Registradores (domínio sys_clk)
    // ------------------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                key_q[i] <= 32'h0;
                iv_q[i]  <= 32'h0;
            end
            counter_hi_q      <= 32'h0;
            counter_lo_q      <= 32'h0;
            num_blocks_q      <= 32'h1;
            aes_ctrl_q        <= 32'h0;
            sys_ctrl_q        <= 32'h0000_0002; // PLL_ENABLE = 1 no reset (ajuste se necessário)
            aes_start_pulse   <= 1'b0;
            aes_done_sticky_q <= 1'b0;
            aes_error_q       <= 1'b0;
            blocks_done_q     <= 16'h0;
        end else begin
            // START é write-one-pulse: dura apenas 1 ciclo de sys_clk
            aes_start_pulse <= 1'b0;

            // Limpa flags ao iniciar nova execução; atualiza ao concluir bloco/operação
            if (aes_start_pulse) begin
                aes_done_sticky_q <= 1'b0;
                aes_error_q       <= (num_blocks_q == 32'd0) || (num_blocks_q > 32'd256);
                blocks_done_q     <= 16'h0;
            end else if (aes_done) begin
                aes_done_sticky_q <= 1'b1;
                blocks_done_q     <= blocks_done_q + 16'd1;
            end

            // Escritas via barramento SPI
            if (reg_wr_en) begin
                case (reg_addr)
                    ADDR_KEY0:           key_q[0]        <= reg_wdata;
                    ADDR_KEY1:           key_q[1]        <= reg_wdata;
                    ADDR_KEY2:           key_q[2]        <= reg_wdata;
                    ADDR_KEY3:           key_q[3]        <= reg_wdata;
                    ADDR_IV0:            iv_q[0]         <= reg_wdata;
                    ADDR_IV1:            iv_q[1]         <= reg_wdata;
                    ADDR_IV2:            iv_q[2]         <= reg_wdata;
                    ADDR_IV3:            iv_q[3]         <= reg_wdata;
                    ADDR_COUNTER_HI:     counter_hi_q    <= reg_wdata;
                    ADDR_COUNTER_LO:     counter_lo_q    <= reg_wdata;
                    ADDR_NUM_BLOCKS:     num_blocks_q    <= reg_wdata;
                    ADDR_AES_CONTROL: begin
                        // Bit START nunca fica travado em 1 no registrador; vira pulso de 1 ciclo
                        aes_ctrl_q <= {
                            reg_wdata[31:BIT_AES_CTRL_MODE+2],
                            reg_wdata[BIT_AES_CTRL_MODE+1:BIT_AES_CTRL_DECRYPT],
                            1'b0
                        };
                        if (reg_wdata[BIT_AES_CTRL_START]) begin
                            aes_start_pulse <= 1'b1;
                        end
                    end
                    ADDR_SYSTEM_CONTROL: sys_ctrl_q      <= reg_wdata;
                    // ADDR_AES_STATUS, ADDR_VERSION, ADDR_SYSTEM_STATUS e ADDR_NOP
                    // não são alterados por escrita
                    default: ;
                endcase
            end
        end
    end

    // Mux de leitura do banco de registradores
    always_comb begin
        reg_rdata = 32'h0;
        if (reg_rd_en) begin
            case (reg_addr)
                ADDR_KEY0:           reg_rdata = key_q[0];
                ADDR_KEY1:           reg_rdata = key_q[1];
                ADDR_KEY2:           reg_rdata = key_q[2];
                ADDR_KEY3:           reg_rdata = key_q[3];
                ADDR_IV0:            reg_rdata = iv_q[0];
                ADDR_IV1:            reg_rdata = iv_q[1];
                ADDR_IV2:            reg_rdata = iv_q[2];
                ADDR_IV3:            reg_rdata = iv_q[3];
                ADDR_COUNTER_HI:     reg_rdata = counter_hi_q;
                ADDR_COUNTER_LO:     reg_rdata = counter_lo_q;
                ADDR_NUM_BLOCKS:     reg_rdata = num_blocks_q;
                ADDR_AES_CONTROL:    reg_rdata = aes_ctrl_q;
                ADDR_AES_STATUS: begin
                    reg_rdata = 32'h0;
                    reg_rdata[15:8]                = blocks_done_q[7:0];
                    reg_rdata[BIT_AES_STAT_ERROR]  = aes_error_q;
                    reg_rdata[BIT_AES_STAT_DONE]   = aes_done_sticky_q;
                    reg_rdata[BIT_AES_STAT_BUSY]   = aes_busy;
                end
                ADDR_VERSION:        reg_rdata = VERSION_ID;
                ADDR_SYSTEM_CONTROL: reg_rdata = sys_ctrl_q;
                ADDR_SYSTEM_STATUS:  reg_rdata = {31'b0, pll_locked};
                ADDR_NOP:            reg_rdata = 32'h0;
                default:             reg_rdata = 32'h0;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // 6. Núcleo Criptográfico AES-128
    // ------------------------------------------------------------------------
    minisoc_aes_top u_aes_top (
        .clk_i     (sys_clk),
        .rst_n_i   (rst_n),
        .start_i   (aes_start_pulse),
        .enc_dec_i (aes_decrypt),
        .key_i     (aes_key_128),
        .data_i    (aes_block_in),
        .data_o    (aes_block_out),
        .busy_o    (aes_busy),
        .done_o    (aes_done)
    );

    // TODO (Semana 6 - Memória e Arbitragem):
    // - Usar `mem_sel_aes` e `aes_busy` para chavear o acesso à `minisoc_memory`
    // - Montar `aes_block_in` (4 palavras de 32 bits) e gravar `aes_block_out`
    // - Tratar `aes_mode` (ECB/CTR/CBC, se aplicável) e `aes_iv_128` / `aes_counter_64`

endmodule
