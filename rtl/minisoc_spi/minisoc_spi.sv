// ============================================================================
// minisoc_spi.sv
// Front-end SPI Slave (Mode 0) com banco de registradores e sincronização CDC.
// ============================================================================
module minisoc_spi (
    // Domínio SPI (spi_sclk)
    input  logic        spi_sclk,
    input  logic        spi_cs_n,
    input  logic        spi_mosi,
    output logic        spi_miso,

    // Domínio Always-On (clk do sistema)
    input  logic        clk,
    input  logic        rst_n,

    // Interface com o Barramento / Registradores Internos
    output logic [5:0]  reg_addr_o,
    output logic [31:0] reg_wdata_o,
    output logic        reg_wr_en_o,
    output logic        reg_rd_en_o,
    input  logic [31:0] reg_rdata_i
);

    // Registrador de deslocamento de 40 bits (SPI Domain)
    logic [39:0] rx_shift_reg;
    logic [39:0] tx_shift_reg;
    logic [5:0]  bit_cnt;
    logic        frame_toggle_spi;

    // Sinais decodificados do frame de entrada
    logic        rx_rwb;
    logic [5:0]  rx_addr;
    logic [31:0] rx_data;

    assign rx_rwb  = rx_shift_reg[39];
    assign rx_addr = rx_shift_reg[38:33];
    assign rx_data = rx_shift_reg[31:0];

    // SPI Mode 0: Amostragem no MOSI na borda de subida de spi_sclk
    always_ff @(posedge spi_sclk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift_reg     <= '0;
            bit_cnt          <= '0;
            frame_toggle_spi <= 1'b0;
        end else if (spi_cs_n) begin
            rx_shift_reg     <= '0;
            bit_cnt          <= '0;
        end else begin
            rx_shift_reg <= {rx_shift_reg[38:0], spi_mosi};
            if (bit_cnt == 6'd39) begin
                bit_cnt          <= '0;
                frame_toggle_spi <= ~frame_toggle_spi; // Toggled exatamente no último bit do frame
            end else begin
                bit_cnt          <= bit_cnt + 1'b1;
            end
        end
    end

    // Captura reg_rdata_i no domínio clk quando reg_rd_en_o é assertado
    logic [39:0] tx_latch_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_latch_q <= '0;
        end else if (reg_rd_en_o) begin
            tx_latch_q <= {8'h00, reg_rdata_i};
        end
    end

    // Carrega tx_shift_reg ao desativar CS (posedge spi_cs_n) e desloca MSB-first em negedge spi_sclk
    always_ff @(negedge spi_sclk or posedge spi_cs_n or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg <= '0;
        end else if (spi_cs_n) begin
            tx_shift_reg <= tx_latch_q;
        end else begin
            tx_shift_reg <= {tx_shift_reg[38:0], 1'b0};
        end
    end

    // Atribuição de MISO ativada apenas quando CS está ativo
    assign spi_miso = (!spi_cs_n) ? tx_shift_reg[39] : 1'b0;

    // ----------------------------------------------------------------8<--------
    // Sincronização CDC por Toggle (de spi_sclk para clk)
    // ----------------------------------------------------------------8<--------
    logic [2:0] toggle_sync;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) toggle_sync <= '0;
        else toggle_sync <= {toggle_sync[1:0], frame_toggle_spi};
    end

    logic frame_detected_clk;
    assign frame_detected_clk = (toggle_sync[2] ^ toggle_sync[1]);

    // Registro de comandos capturados no domínio clk
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_addr_o  <= '0;
            reg_wdata_o <= '0;
            reg_wr_en_o <= 1'b0;
            reg_rd_en_o <= 1'b0;
        end else if (frame_detected_clk) begin
            reg_addr_o  <= (rx_addr == 6'h3F) ? 6'h00 : rx_addr; // Tratamento NOP
            reg_wdata_o <= rx_data;
            reg_wr_en_o <= rx_rwb;        // 1 = Escrita
            reg_rd_en_o <= ~rx_rwb;       // 0 = Leitura
        end else begin
            reg_wr_en_o <= 1'b0;
            reg_rd_en_o <= 1'b0;
        end
    end

endmodule
