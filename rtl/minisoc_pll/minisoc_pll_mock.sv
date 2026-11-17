// ============================================================================
// minisoc_pll_mock.sv
// Modelo de integração comportamental do PLL com divisores e atraso de lock.
// ============================================================================
module minisoc_pll_mock (
    input  logic        clkin,       // Referência de clock de entrada (ex: 2 GHz)
    input  logic        rst_n,       // Reset assíncrono ativo em baixo
    input  logic        enable,      // Habilitação do PLL
    input  logic [1:0]  pll_div_sel, // Seletor de divisão: 00=/1, 01=/2, 10=/4, 11=/8
    output logic        clkout,      // Clock de saída para o sistema
    output logic        locked       // Indicador de PLL travado
);

    // Contadores e divisores internos
    logic [3:0]   div_counter;
    logic         divided_clk;
    logic [7:0]   lock_delay_cnt;
    logic         internal_locked;

    // Divisor de clock baseado em pll_div_sel
    always_ff @(posedge clkin or negedge rst_n) begin
        if (!rst_n) begin
            div_counter <= '0;
            divided_clk <= 1'b0;
        end else if (enable && internal_locked) begin
            unique case (pll_div_sel)
                2'b00: begin // /1
                    divided_clk <= ~divided_clk; 
                end
                2'b01: begin // /2
                    if (div_counter == 4'd0) begin
                        divided_clk <= ~divided_clk;
                        div_counter <= 4'd1;
                    end else begin
                        div_counter <= 4'd0;
                    end
                end
                2'b10: begin // /4
                    if (div_counter == 4'd1) begin
                        divided_clk <= ~divided_clk;
                        div_counter <= 4'd0;
                    end else begin
                        div_counter <= div_counter + 1'b1;
                    end
                end
                2'b11: begin // /8
                    if (div_counter == 4'd3) begin
                        divided_clk <= ~divided_clk;
                        div_counter <= 4'd0;
                    end else begin
                        div_counter <= div_counter + 1'b1;
                    end
                end
                default: divided_clk <= clkin;
            endcase
        end else begin
            div_counter <= '0;
            divided_clk <= 1'b0;
        end
    end

    // Máquina/Contador para simular o tempo de travamento (Lock Time) pseudoaleatório
    always_ff @(posedge clkin or negedge rst_n) begin
        if (!rst_n) begin
            lock_delay_cnt  <= '0;
            internal_locked <= 1'b0;
        end else if (!enable) begin
            lock_delay_cnt  <= '0;
            internal_locked <= 1'b0;
        end else if (!internal_locked) begin
            // Simula contagem de ciclos até atingir o travamento
            if (lock_delay_cnt == 8'd32) begin // Valor parametrizável de ciclos para lock
                internal_locked <= 1'b1;
            end else begin
                lock_delay_cnt  <= lock_delay_cnt + 1'b1;
            end
        end
    end

    // Gated clock output: clock é bloqueado (0) enquanto desabilitado ou destravado
    assign clkout = (enable && internal_locked) ? divided_clk : 1'b0;
    assign locked = internal_locked;

endmodule
