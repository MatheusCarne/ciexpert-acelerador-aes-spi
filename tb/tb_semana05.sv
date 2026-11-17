`timescale 1ns/1ps

module tb_semana05;

  // Sinais de clock e reset
  logic         clk;
  logic         rst_n;
  
  // Sinais de controle e dados do AES Top
  logic         start_i;
  logic         enc_dec_i;
  logic [127:0] key_i;
  logic [127:0] data_i;
  logic [127:0] data_o;
  logic         busy_o;
  logic         done_o;

  // Instanciação do Top-Level do AES
  minisoc_aes_top u_dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .start_i   (start_i),
    .enc_dec_i (enc_dec_i),
    .key_i     (key_i),
    .data_i    (data_i),
    .data_o    (data_o),
    .busy_o    (busy_o),
    .done_o    (done_o)
  );

  // Gerador de Clock (10ns período -> 100 MHz)
  always #5 clk = ~clk;

  // Vetores oficiais FIPS-197
  logic [127:0] master_key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
  logic [127:0] plaintext  = 128'h3243f6a8885a308d313198a2e0370734;
  logic [127:0] ciphertext = 128'h3925841d02dc09fbdc118597196a0b32;

  initial begin
    // Inicialização de sinais
    clk       = 0;
    rst_n     = 0;
    start_i   = 0;
    enc_dec_i = 1;
    key_i     = '0;
    data_i    = '0;

    // Aplicação do Reset Assíncrono
    #20;
    rst_n = 1;
    #20;

    $display("==================================================");
    $display(" INICIANDO TESTE DA FSM: CIFRAGEM (ENCRYPTION)    ");
    $display("==================================================");

    // Configura os dados de entrada para Cifragem
    @(posedge clk);
    key_i     = master_key;
    data_i    = plaintext;
    enc_dec_i = 1'b1; // Modo Cifragem
    start_i   = 1'b1; // Pulso de start de 1 ciclo
    
    @(posedge clk);
    start_i   = 1'b0; // Remove o pulso

    // Aguarda o sinal done_o ir para 1 (Fim do processamento)
    wait(done_o == 1'b1);
    @(posedge clk);

    if (data_o === ciphertext) begin
      $display("[PASS] Cifragem por FSM validada com sucesso!");
      $display("       Obtido:   %032h", data_o);
      $display("       Esperado: %032h", ciphertext);
    end else begin
      $display("[FAIL] Erro na Cifragem por FSM!");
      $display("       Obtido:   %032h", data_o);
      $display("       Esperado: %032h", ciphertext);
    end

    #40;

    $display("==================================================");
    $display(" INICIANDO TESTE DA FSM: DECRIPTACAO (DECRYPTION) ");
    $display("==================================================");

    // Configura os dados de entrada para Decriptação
    @(posedge clk);
    key_i     = master_key;
    data_i    = ciphertext;
    enc_dec_i = 1'b0; // Modo Decriptação
    start_i   = 1'b1; // Pulso de start
    
    @(posedge clk);
    start_i   = 1'b0;

    // Aguarda conclusão
    wait(done_o == 1'b1);
    @(posedge clk);

    if (data_o === plaintext) begin
      $display("[PASS] Decriptacao por FSM validada com sucesso!");
      $display("       Obtido:   %032h", data_o);
      $display("       Esperado: %032h", plaintext);
    end else begin
      $display("[FAIL] Erro na Decriptacao por FSM!");
      $display("       Obtido:   %032h", data_o);
      $display("       Esperado: %032h", plaintext);
    end

    #50;
    $display("==================================================");
    $display(" TESTES DA SEMANA 5 CONCLUÍDOS                    ");
    $display("==================================================");
    $finish;
  end

endmodule
