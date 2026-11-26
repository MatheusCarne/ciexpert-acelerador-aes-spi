// ============================================================================
// minisoc_top.sv
// Integração Semana 6: PLL Mock, SPI/Regs, Memória 1024x32 e AES-128
// (ECB, CBC e CTR; escrita in-place; captura no START; validação de config).
// Nota v1.0 (W6): PCBC (3'b010), CFB (3'b011) e OFB (3'b100) ficam para W10.
// ============================================================================
module minisoc_top #(
    parameter int MEM_DEPTH  = 1024,
    parameter int MEM_ADDR_W = $clog2(MEM_DEPTH)
) (
    input  logic                  clkin,
    input  logic                  rst_n,

    // Interface SPI externa (Modo 0)
    input  logic                  spi_sclk,
    input  logic                  spi_cs_n,
    input  logic                  spi_mosi,
    output logic                  spi_miso,

    // Interface MEMORY DATA externa (quando MEM_SEL_AES == 0)
    input  logic                  ext_mem_en,
    input  logic                  ext_mem_we,
    input  logic [MEM_ADDR_W-1:0] ext_mem_addr,
    input  logic [31:0]           ext_mem_wdata,
    output logic [31:0]           ext_mem_rdata,

    // Observabilidade / status externo
    output logic                  pll_locked_o
);
    // ------------------------------------------------------------------------
    // 1. Mapa de Registradores (Seção 6)
    // ------------------------------------------------------------------------
    localparam logic [5:0] ADDR_KEY0           = 6'h00;
    localparam logic [5:0] ADDR_KEY1           = 6'h01;
    localparam logic [5:0] ADDR_KEY2           = 6'h02;
    localparam logic [5:0] ADDR_KEY3           = 6'h03;
    localparam logic [5:0] ADDR_IV0            = 6'h04;
    localparam logic [5:0] ADDR_IV1            = 6'h05;
    localparam logic [5:0] ADDR_IV2            = 6'h06;
    localparam logic [5:0] ADDR_IV3            = 6'h07;
    localparam logic [5:0] ADDR_COUNTER_HI     = 6'h08;
    localparam logic [5:0] ADDR_COUNTER_LO     = 6'h09;
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A;
    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B;
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C;
    localparam logic [5:0] ADDR_VERSION        = 6'h0D;
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E;
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F;
    localparam logic [5:0] ADDR_NOP            = 6'h3F;

    localparam int BIT_AES_CTRL_START   = 0;
    localparam int BIT_AES_CTRL_DECRYPT = 1; // 1: Cifrar (Cipher), 0: Decriptar (InvCipher)
    localparam int BIT_AES_CTRL_MODE_LO = 2; // bits [4:2] = MODE (3 bits)

    localparam int BIT_AES_STAT_BUSY    = 0;
    localparam int BIT_AES_STAT_DONE    = 1;
    localparam int BIT_AES_STAT_ERROR   = 2;

    localparam int BIT_SYS_CTRL_MEM_SEL = 0;
    localparam int BIT_SYS_CTRL_PLL_EN  = 1;

    // Modos suportados na Semana 6
    localparam logic [2:0] MODE_ECB = 3'b000;
    localparam logic [2:0] MODE_CBC = 3'b001;
    localparam logic [2:0] MODE_CTR = 3'b101;

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
    logic        mem_sel_aes;
    logic        pll_enable;
    logic [1:0]  pll_div_sel;

    // Snapshot capturado no START válido
    logic [127:0] cap_key_q;
    logic [127:0] cap_iv_q;
    logic [127:0] cap_ctr_q;
    logic [2:0]   cap_mode_q;
    logic         cap_enc_dec_q; // 1 = Cipher (enc), 0 = InvCipher (dec)
    logic [31:0]  cap_num_blocks_q;

    // Estado de encadeamento CBC / CTR e processamento por bloco
    logic [127:0] cbc_chain_q;
    logic [127:0] raw_block_q;
    logic [127:0] core_in_q;
    logic [127:0] core_out_q;
    logic [127:0] final_block_q;

    // Sinais do núcleo AES-128
    logic         core_start_pulse;
    logic         core_busy;
    logic         core_done;
    logic         core_enc_dec_sel;
    logic [127:0] core_data_in;
    logic [127:0] core_data_out;

    // Interface de memória para o engine AES
    logic                  aes_mem_en;
    logic                  aes_mem_we;
    logic [MEM_ADDR_W-1:0] aes_mem_addr;
    logic [31:0]           aes_mem_wdata;
    logic [31:0]           aes_mem_rdata;

    // Status e contadores
    logic        ctrl_busy;
    logic        ctrl_done_sticky;
    logic        ctrl_error;
    logic [15:0] blocks_done_q;
    logic [31:0] current_block_idx;
    logic [1:0]  word_idx;
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
    assign mem_sel_aes  = sys_ctrl_q[BIT_SYS_CTRL_MEM_SEL];
    assign pll_enable   = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN];
    assign pll_div_sel  = sys_ctrl_q[BIT_SYS_CTRL_PLL_EN+2:BIT_SYS_CTRL_PLL_EN+1];

    // Em CTR o núcleo AES sempre executa CIPH (enc_dec = 1); em ECB/CBC usa cap_enc_dec_q
    assign core_enc_dec_sel = (cap_mode_q == MODE_CTR) ? 1'b1 : cap_enc_dec_q;
    assign core_data_in     = core_in_q;

    assign {out_words[0], out_words[1], out_words[2], out_words[3]} = final_block_q;

    function automatic logic is_valid_config(input logic [31:0] nblk, input logic [2:0] mode_v);
        logic valid_nblk;
        logic valid_mode;
        valid_nblk = (nblk >= 32'd1) && (nblk <= 32'd256);
        valid_mode = (mode_v == MODE_ECB) || (mode_v == MODE_CBC) || (mode_v == MODE_CTR);
        return valid_nblk && valid_mode;
    endfunction

    function automatic logic [127:0] add_128_u64_inc(input logic [127:0] base_val, input logic [31:0] inc_val);
        return base_val + {96'd0, inc_val};
    endfunction

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
            sys_ctrl_q      <= 32'h0000_0002;
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
                            reg_wdata[31:BIT_AES_CTRL_MODE_LO+3],
                            reg_wdata[BIT_AES_CTRL_MODE_LO+2:BIT_AES_CTRL_DECRYPT],
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
    // 5. Sequenciador de Blocos (Leitura 4 palavras -> Processa -> In-Place)
    // ------------------------------------------------------------------------
    logic [127:0] loaded_block_w;
    logic [127:0] ctr_block_w;

    assign loaded_block_w = {in_words[0], in_words[1], in_words[2], in_words[3]};
    assign ctr_block_w    = add_128_u64_inc(cap_ctr_q, current_block_idx);

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
                    if (is_valid_config(num_blocks_q, aes_ctrl_q[BIT_AES_CTRL_MODE_LO+2:BIT_AES_CTRL_MODE_LO]))
                        next_state = ST_LOAD_REQ;
                    else
                        next_state = ST_FINISH;
                end
            end

            ST_LOAD_REQ: begin
                if (mem_sel_aes) begin
                    aes_mem_en   = 1'b1;
                    aes_mem_we   = 1'b0;
                    aes_mem_addr = MEM_ADDR_W'(current_block_idx * 4 + {30'd0, word_idx});
                    next_state   = ST_LOAD_WAIT;
                end
            end

            ST_LOAD_WAIT: begin
                next_state = (word_idx == 2'd3) ? ST_START_CORE : ST_LOAD_REQ;
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
                    // Escrita in-place na mesma região do bloco k (0 + k*4 + word_idx)
                    aes_mem_addr  = MEM_ADDR_W'(current_block_idx * 4 + {30'd0, word_idx});
                    aes_mem_wdata = out_words[word_idx];
                    next_state    = (word_idx == 2'd3) ? ST_NEXT_BLOCK : ST_STORE_REQ;
                end
            end

            ST_NEXT_BLOCK: begin
                if ((current_block_idx + 32'd1) >= cap_num_blocks_q)
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
            word_idx          <= 2'd0;
            cap_key_q         <= 128'h0;
            cap_iv_q          <= 128'h0;
            cap_ctr_q         <= 128'h0;
            cap_mode_q        <= MODE_ECB;
            cap_enc_dec_q     <= 1'b1;
            cap_num_blocks_q  <= 32'd1;
            cbc_chain_q       <= 128'h0;
            raw_block_q       <= 128'h0;
            core_in_q         <= 128'h0;
            core_out_q        <= 128'h0;
            final_block_q     <= 128'h0;
            for (int i = 0; i < 4; i++) begin
                in_words[i] <= 32'h0;
            end
        end else begin
            state_q <= next_state;

            if (cmd_start_pulse) begin
                // Captura configuração no START válido (Seção 8.3)
                cap_key_q        <= {key_q[0], key_q[1], key_q[2], key_q[3]};
                cap_iv_q         <= {iv_q[0], iv_q[1], iv_q[2], iv_q[3]};
                cap_ctr_q        <= {iv_q[0], iv_q[1], 64'd0} ^ {64'd0, counter_hi_q, counter_lo_q};
                cap_mode_q       <= aes_ctrl_q[BIT_AES_CTRL_MODE_LO+2:BIT_AES_CTRL_MODE_LO];
                cap_enc_dec_q    <= aes_ctrl_q[BIT_AES_CTRL_DECRYPT];
                cap_num_blocks_q <= num_blocks_q;
                cbc_chain_q      <= {iv_q[0], iv_q[1], iv_q[2], iv_q[3]};

                current_block_idx <= 32'h0;
                word_idx          <= 2'd0;
                blocks_done_q     <= 16'h0;
                ctrl_done_sticky  <= 1'b0;

                if (!is_valid_config(num_blocks_q, aes_ctrl_q[BIT_AES_CTRL_MODE_LO+2:BIT_AES_CTRL_MODE_LO])) begin
                    ctrl_error <= 1'b1;
                    ctrl_busy  <= 1'b0;
                end else begin
                    ctrl_error <= 1'b0;
                    ctrl_busy  <= 1'b1;
                end
            end else begin
                if (state_q == ST_LOAD_WAIT) begin
                    in_words[word_idx] <= aes_mem_rdata;
                    if (word_idx == 2'd3) begin
                        word_idx <= 2'd0;
                        // Prepara entrada do core conforme modo selecionado
                        case (cap_mode_q)
                            MODE_ECB: core_in_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata};
                            MODE_CBC: begin
                                raw_block_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata};
                                if (cap_enc_dec_q) // Cifragem CBC: P_i XOR C_{i-1}
                                    core_in_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata} ^ cbc_chain_q;
                                else               // Decriptação CBC: InvCipher(C_i)
                                    core_in_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata};
                            end
                            MODE_CTR: begin
                                raw_block_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata};
                                core_in_q   = ctr_block_w;
                            end
                            default:  core_in_q = {in_words[0], in_words[1], in_words[2], aes_mem_rdata};
                        endcase
                    end else begin
                        word_idx <= word_idx + 2'd1;
                    end
                end else if (state_q == ST_WAIT_CORE && core_done) begin
                    core_out_q <= core_data_out;
                    case (cap_mode_q)
                        MODE_ECB: final_block_q <= core_data_out;
                        MODE_CBC: begin
                            if (cap_enc_dec_q) begin
                                final_block_q <= core_data_out;
                                cbc_chain_q   <= core_data_out;
                            end else begin
                                final_block_q <= core_data_out ^ cbc_chain_q;
                                cbc_chain_q   <= raw_block_q;
                            end
                        end
                        MODE_CTR: final_block_q <= core_data_out ^ raw_block_q;
                        default:  final_block_q <= core_data_out;
                    endcase
                end else if (state_q == ST_STORE_REQ && mem_sel_aes) begin
                    if (word_idx == 2'd3)
                        word_idx <= 2'd0;
                    else
                        word_idx <= word_idx + 2'd1;
                end else if (state_q == ST_NEXT_BLOCK) begin
                    blocks_done_q     <= blocks_done_q + 16'd1;
                    current_block_idx <= current_block_idx + 32'd1;
                    word_idx          <= 2'd0;
                end else if (state_q == ST_FINISH) begin
                    if (!ctrl_error) begin
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

    minisoc_aes_top u_aes_top (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .start_i   (core_start_pulse),
        .enc_dec_i (core_enc_dec_sel),
        .key_i     (cap_key_q),
        .data_i    (core_data_in),
        .data_o    (core_data_out),
        .busy_o    (core_busy),
        .done_o    (core_done)
    );
endmodule
