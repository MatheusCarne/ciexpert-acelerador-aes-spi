// ============================================================================
// minisoc_top.sv
// Integração Semana 6: PLL Mock, SPI/Regs, Memória Compartilhada e AES-128.
// ============================================================================
module minisoc_top #(
    parameter int MEM_DEPTH  = 1024,
    parameter int MEM_ADDR_W = $clog2(MEM_DEPTH)
) (
    input  logic        clkin,          // Referência de 2 GHz
    input  logic        rst_n,          // Reset assíncrono ativo em baixo

    // Interface SPI externa (Modo 0)
    input  logic        spi_sclk,
    input  logic        spi_cs_n,
    input  logic        spi_mosi,
    output logic        spi_miso,

    // Acesso externo direto à memória (para TB/host quando MEM_SEL_AES == 0)
    input  logic                  ext_mem_en,
    input  logic                  ext_mem_we,
    input  logic [MEM_ADDR_W-1:0] ext_mem_addr,
    input  logic [31:0]           ext_mem_wdata,
    output logic [31:0]           ext_mem_rdata,

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
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A; // RW : Quantidade de blocos AES (1..256)
    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B; // RW : START, DECRYPT, MODE
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C; // R  : BUSY, DONE, ERROR, BLOCKS_DONE
    localparam logic [5:0] ADDR_VERSION        = 6'h0D; // R  : Versão do front-end
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E; // RW : MEM_SEL_AES, PLL_ENABLE, PLL_DIV_SEL
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F; // R  : PLL_LOCKED
    localparam logic [5:0] ADDR_NOP            = 6'h3F; // -  : Fase de retorno de leitura SPI

    localparam int BIT_AES_CTRL_START   = 0;
    localparam int BIT_AES_CTRL_DECRYPT = 1; // 1: Cifrar (Cipher), 0: Decriptar (InvCipher)
    localparam int BIT_AES_CTRL_MODE    = 2;

    localparam int BIT_AES_STAT_BUSY    = 0;
    localparam int BIT_AES_STAT_DONE    = 1;
    localparam int BIT_AES_STAT_ERROR   = 2;

    localparam int BIT_SYS_CTRL_MEM_SEL = 0;
    localparam int BIT_SYS_CTRL_PLL_EN  = 1;

    localparam logic [31:0] VERSION_ID = 32'h312e3030;

    // ------------------------------------------------------------------------
    // 2. Sinais internos
    // ------------------------------------------------------------------------
    logic        sys_clk;
    logic        pll_locked;

    logic [5:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_wr_en;
    logic        reg_rd_en;
    logic [31:0] reg_rdata;

    logic [31:0] key_q [0:3];
    logic [31:0] iv_q  [0:3];
    logic [31:0] counter_hi_q;
    logic [31:0] counter_lo_q;
    logic [31:0] num_blocks_q;
    logic [31:0] aes_ctrl_q;
    logic [31:0] sys_ctrl_q;

    logic        cmd_start_pulse;
    logic        aes_decrypt;
    logic [1:0]  aes_mode;
    logic        mem_sel_aes;
    logic        pll_enable;
    logic [1:0]  pll_div_sel;

    logic [127:0] aes_key_128;
    logic [127:0] aes_iv_128;
    logic [63:0]  aes_counter_64;

    // Sinais do núcleo AES-128
    logic         core_start_pulse;
    logic         core_busy;
    logic         core_done;
    logic [127:0] core_data_in;
    logic [127:0] core_data_out;

    // Sinais da memória para o controlador de blocos AES
    logic                  aes_mem_en;
    logic                  aes_mem_we;
    logic [MEM_ADDR_W-1:0] aes_mem_addr;
    logic [31:0]           aes_mem_wdata;
    logic [31:0]           aes_mem_rdata;

    // Status e contadores do controlador de blocos
    logic        ctrl_busy;
    logic        ctrl_done_sticky;
    logic        ctrl_error;
    logic [15:0] blocks_done_q;
    logic [31:0] current_block_idx;
    logic [31:0] word_idx;
    logic [31:0] in_words  [0:3];
    logic [31:0] out_words [0:3];

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_LOAD_REQ,
        ST_LOAD_WAIT,
        ST_START_CORE,
        ST_WAIT_CORE,
        ST_STORE_REQ,
        ST_NEXT_BLOCK,
        ST_FINISH
    } blk_state_t;

    blk_state_t state_q, next_state;

    assign pll_locked_o = pll_locked;
    assign aes_key_128    = {key_q[0], key_q[1], key_q[2], key_q[3]};
    assign aes_iv_128     = {iv_q[0], iv_q[1], iv_q[2], iv_q[3]};
    assign aes_counter_64 = {counter_hi_q, counter_lo_q};

    logic        aes_enc_dec_sel; // 1 = Cipher (enc), 0 = InvCipher (dec)
    assign aes_enc_dec_sel = aes_ctrl_q[BIT_AES_CTRL_DECRYPT];
    assign aes_decrypt    = aes_enc_dec_sel;
    assign aes_mode       = aes_ctrl_q[BIT_AES_CTRL_MODE+1:BIT_AES_CTRL_MODE];

    assign mem_sel_aes    = sys_ctrl_q[BIT_SYS_CTRL_MEM_SEL];
    assign pll_enable     = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN];
    assign pll_div_sel    = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN+2:BIT_SYS_CTRL_PLL_EN+1];

    assign core_data_in   = {in_words[0], in_words[1], in_words[2], in_words[3]};
    assign {out_words[0], out_words[1], out_words[2], out_words[3]} = core_data_out;

    // ------------------------------------------------------------------------
    // 3. PLL Mock e SPI
    // ------------------------------------------------------------------------
    minisoc_pll_mock u_pll_mock (
        .clkin       (clkin),
        .rst_n       (rst_n),
        .enable      (pll_enable),
        .pll_div_sel (pll_div_sel),
        .clkout      (sys_clk),
        .locked      (pll_locked)
    );

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
    // 4. Banco de Registradores
    // ------------------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                key_q[i] <= 32'h0;
                iv_q[i]  <= 32'h0;
            end
            counter_hi_q    <= 32'h0;
            counter_lo_q    <= 32'h0;
            num_blocks_q    <= 32'h1;
            aes_ctrl_q      <= 32'h0;
            sys_ctrl_q      <= 32'h0000_0002; // PLL_ENABLE = 1 no reset
            cmd_start_pulse <= 1'b0;
        end else begin
            cmd_start_pulse <= 1'b0;

            if (reg_wr_en) begin
                case (reg_addr)
                    ADDR_KEY0:           key_q[0]     <= reg_wdata;
                    ADDR_KEY1:           key_q[1]     <= reg_wdata;
                    ADDR_KEY2:           key_q[2]     <= reg_wdata;
                    ADDR_KEY3:           key_q[3]     <= reg_wdata;
                    ADDR_IV0:            iv_q[0]      <= reg_wdata;
                    ADDR_IV1:            iv_q[1]      <= reg_wdata;
                    ADDR_IV2:            iv_q[2]      <= reg_wdata;
                    ADDR_IV3:            iv_q[3]      <= reg_wdata;
                    ADDR_COUNTER_HI:     counter_hi_q <= reg_wdata;
                    ADDR_COUNTER_LO:     counter_lo_q <= reg_wdata;
                    ADDR_NUM_BLOCKS:     num_blocks_q <= reg_wdata;
                    ADDR_AES_CONTROL: begin
                        aes_ctrl_q <= {
                            reg_wdata[31:BIT_AES_CTRL_MODE+2],
                            reg_wdata[BIT_AES_CTRL_MODE+1:BIT_AES_CTRL_DECRYPT],
                            1'b0
                        };
                        if (reg_wdata[BIT_AES_CTRL_START]) begin
                            cmd_start_pulse <= 1'b1;
                        end
                    end
                    ADDR_SYSTEM_CONTROL: sys_ctrl_q   <= reg_wdata;
                    default: ;
                endcase
            end
        end
    end

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
                    reg_rdata[15:8]               = blocks_done_q[7:0];
                    reg_rdata[BIT_AES_STAT_ERROR] = ctrl_error;
                    reg_rdata[BIT_AES_STAT_DONE]  = ctrl_done_sticky;
                    reg_rdata[BIT_AES_STAT_BUSY]  = ctrl_busy || core_busy;
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
    // 5. Sequenciador de Blocos e Arbitragem de Memória
    // Bloco k (0..num_blocks-1):
    //   Leitura de entrada : base 0 + k*4 + word_idx (0..3)
    //   Escrita de saída : base 512 + k*4 + word_idx (0..3) [ajuste se necessário]
    // ------------------------------------------------------------------------
    localparam int OUT_BASE_ADDR = MEM_DEPTH / 2;

    always_comb begin
        next_state       = state_q;
        aes_mem_en       = 1'b0;
        aes_mem_we       = 1'b0;
        aes_mem_addr     = '0;
        aes_mem_wdata    = 32'h0;
        core_start_pulse = 1'b0;

        case (state_q)
            ST_IDLE: begin
                if (cmd_start_pulse) begin
                    if ((num_blocks_q == 32'd0) || (num_blocks_q > 32'd256))
                        next_state = ST_FINISH;
                    else
                        next_state = ST_LOAD_REQ;
                end
            end

            ST_LOAD_REQ: begin
                if (mem_sel_aes) begin
                    aes_mem_en   = 1'b1;
                    aes_mem_we   = 1'b0;
                    aes_mem_addr = MEM_ADDR_W'(current_block_idx * 4 + word_idx);
                    next_state   = ST_LOAD_WAIT;
                end
            end

            ST_LOAD_WAIT: begin
                next_state = (word_idx == 32'd3) ? ST_START_CORE : ST_LOAD_REQ;
            end

            ST_START_CORE: begin
                core_start_pulse = 1'b1;
                next_state       = ST_WAIT_CORE;
            end

            ST_WAIT_CORE: begin
                if (core_done) begin
                    next_state = ST_STORE_REQ;
                end
            end

            ST_STORE_REQ: begin
                if (mem_sel_aes) begin
                    aes_mem_en    = 1'b1;
                    aes_mem_we    = 1'b1;
                    aes_mem_addr  = MEM_ADDR_W'(OUT_BASE_ADDR + current_block_idx * 4 + word_idx);
                    aes_mem_wdata = out_words[word_idx[1:0]];
                    next_state    = (word_idx == 32'd3) ? ST_NEXT_BLOCK : ST_STORE_REQ;
                end
            end

            ST_NEXT_BLOCK: begin
                if ((current_block_idx + 32'd1) >= num_blocks_q)
                    next_state = ST_FINISH;
                else
                    next_state = ST_LOAD_REQ;
            end

            ST_FINISH: begin
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q           <= ST_IDLE;
            ctrl_busy         <= 1'b0;
            ctrl_done_sticky  <= 1'b0;
            ctrl_error        <= 1'b0;
            blocks_done_q     <= 16'h0;
            current_block_idx <= 32'h0;
            word_idx          <= 32'h0;
            for (int i = 0; i < 4; i++) begin
                in_words[i] <= 32'h0;
            end
        end else begin
            state_q <= next_state;

            if (cmd_start_pulse) begin
                ctrl_done_sticky  <= 1'b0;
                current_block_idx <= 32'h0;
                word_idx          <= 32'h0;
                if ((num_blocks_q == 32'd0) || (num_blocks_q > 32'd256)) begin
                    ctrl_error <= 1'b1;
                    ctrl_busy  <= 1'b0;
                end else begin
                    ctrl_error <= 1'b0;
                    ctrl_busy  <= 1'b1;
                end
            end else begin
                if (state_q == ST_LOAD_WAIT) begin
                    in_words[word_idx[1:0]] <= aes_mem_rdata;
                    word_idx <= (word_idx == 32'd3) ? 32'd0 : (word_idx + 32'd1);
                end else if (state_q == ST_STORE_REQ && mem_sel_aes) begin
                    word_idx <= (word_idx == 32'd3) ? 32'd0 : (word_idx + 32'd1);
                end else if (state_q == ST_NEXT_BLOCK) begin
                    blocks_done_q     <= blocks_done_q + 16'd1;
                    current_block_idx <= current_block_idx + 32'd1;
                    word_idx          <= 32'd0;
                end else if (state_q == ST_FINISH) begin
                    if (!ctrl_error) begin
                        blocks_done_q    <= blocks_done_q + 16'd1;
                        ctrl_done_sticky <= 1'b1;
                    end
                    ctrl_busy <= 1'b0;
                end
            end
        end
    end

    minisoc_memory #(
        .DEPTH  (MEM_DEPTH),
        .ADDR_W (MEM_ADDR_W)
    ) u_mem (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .ext_en      (ext_mem_en),
        .ext_we      (ext_mem_we),
        .ext_addr    (ext_mem_addr),
        .ext_wdata   (ext_mem_wdata),
        .ext_rdata   (ext_mem_rdata),
        .aes_en      (aes_mem_en),
        .aes_we      (aes_mem_we),
        .aes_addr    (aes_mem_addr),
        .aes_wdata   (aes_mem_wdata),
        .aes_rdata   (aes_mem_rdata),
        .mem_sel_aes (mem_sel_aes)
    );

    // ------------------------------------------------------------------------
    // 6. Núcleo Criptográfico AES-128
    // ------------------------------------------------------------------------
    minisoc_aes_top u_aes_top (
        .clk     (sys_clk),
        .rst_n   (rst_n),
        .start_i   (core_start_pulse),
        .enc_dec_i (aes_decrypt),
        .key_i     (aes_key_128),
        .data_i    (core_data_in),
        .data_o    (core_data_out),
        .busy_o    (core_busy),
        .done_o    (core_done)
    );

endmodule
