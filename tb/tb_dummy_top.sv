// ==============================================================================
// Testbench para Validação da Operação XOR de 128 bits
// ==============================================================================
`timescale 1ns/1ps

module tb_dummy_top;

    logic         clk;
    logic         rst_n;
    logic         start;
    logic [127:0] data_in;
    logic [127:0] key_in;
    logic [127:0] data_out;
    logic         valid;

    // Instanciação do módulo RTL
    dummy_top dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .data_in (data_in),
        .key_in  (key_in),
        .data_out(data_out),
        .valid   (valid)
    );

    // Geração de Clock (100 MHz)
    always #5 clk = ~clk;

    // Estímulos de Teste
    initial begin
        clk     = 0;
        rst_n   = 0;
        start   = 0;
        data_in = 128'h0;
        key_in  = 128'h0;

        #20;
        rst_n = 1; // Libera o Reset
        #10;

        // Vetor de Teste: Plaintext e Key de 128 bits
        data_in = 128'h0123456789ABCDEF0123456789ABCDEF;
        key_in  = 128'hFEDCBA9876543210FEDCBA9876543210;
        start   = 1'b1;

        #10;
        start   = 1'b0;

        // Aguarda a flag de saída válida
        wait(valid);
        
        $display("\n==================================================");
        $display("[TEST] Entrada  (Data) : 0x%h", data_in);
        $display("[TEST] Chave    (Key)  : 0x%h", key_in);
        $display("[TEST] Resultado (XOR) : 0x%h", data_out);

        // Verificação automática (Self-Checking)
        if (data_out == (data_in ^ key_in)) begin
            $display("[SUCCESS] Operacao XOR de 128 bits Validada!");
        end else begin
            $display("[ERROR] Resultado incorreto!");
        end
        $display("==================================================\n");

        #20;
        $finish;
    end

endmodule
