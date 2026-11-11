`timescale 1ns/1ps

module tb_semana04_dp;

  // Sinais do Datapath
  logic [127:0] state_in, state_out, rkey;
  logic         enc_dec, bypass_mc, load_cycle;

  minisoc_aes_dp u_dp (
    .state_i      (state_in),
    .rkey_i       (rkey),
    .enc_dec_i    (enc_dec),
    .bypass_mc_i  (bypass_mc),
    .load_cycle_i (load_cycle),
    .state_o      (state_out)
  );

  // Sinais do Key Expansion
  logic [127:0] master_key;
  logic [127:0] round_keys [0:10];

  minisoc_aes_key_exp u_key_exp (
    .key_i        (master_key),
    .round_keys_o (round_keys)
  );

  // Vetores de Referencia FIPS-197
  logic [127:0] plaintext  = 128'h3243f6a8885a308d313198a2e0370734;
  logic [127:0] ciphertext = 128'h3925841d02dc09fbdc118597196a0b32;
  
  logic [127:0] st_reg; // O nosso registrador de estado "virtual"

  initial begin
    master_key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    #5; // Aguarda geracao de chaves
    
    $display("========================================");
    $display(" INICIANDO TESTE CIFRAGEM (ENCRYPTION)");
    $display("========================================");
    
    // SETUP: Cifragem
    enc_dec = 1; bypass_mc = 0;
    
    // CICLO 0: Carregamento e AddRoundKey Inicial (K0)
    load_cycle = 1;
    state_in   = plaintext;
    rkey       = round_keys[0];
    #5 st_reg  = state_out; // Salva no registrador
    
    // LOOP: Rodadas 1 a 9
    load_cycle = 0;
    for (int i = 1; i <= 9; i++) begin
      state_in  = st_reg;
      rkey      = round_keys[i];
      #5 st_reg = state_out;
    end
    
    // RODADA 10: Bypass MixColumns e AddRoundKey (K10)
    bypass_mc = 1;
    state_in  = st_reg;
    rkey      = round_keys[10];
    #5 st_reg = state_out;
    
    if (st_reg === ciphertext) $display("[PASS] Cifragem validada! Resultado igual ao FIPS-197.");
    else                       $display("[FAIL] Erro Cifragem! Obtido: %032h", st_reg);


    $display("\n========================================");
    $display(" INICIANDO TESTE DECRIPTACAO (DECRYPTION)");
    $display("========================================");

    // SETUP: Decriptacao
    enc_dec = 0; bypass_mc = 0;
    
    // CICLO 0: Carregamento e AddRoundKey Inicial (K10)
    load_cycle = 1;
    state_in   = ciphertext;
    rkey       = round_keys[10];
    #5 st_reg  = state_out;
    
    // LOOP INVERSO: Rodadas 1 a 9 (Usa K9 ate K1)
    load_cycle = 0;
    for (int i = 1; i <= 9; i++) begin
      state_in  = st_reg;
      rkey      = round_keys[10-i]; // Chaves decrescentes
      #5 st_reg = state_out;
    end
    
    // RODADA 10: Bypass InvMixColumns e AddRoundKey (K0)
    bypass_mc = 1;
    state_in  = st_reg;
    rkey      = round_keys[0];
    #5 st_reg = state_out;
    
    if (st_reg === plaintext) $display("[PASS] Decriptacao validada! Plaintext recuperado com sucesso.");
    else                      $display("[FAIL] Erro Decriptacao! Obtido: %032h", st_reg);

    $display("========================================\n");
    $finish;
  end
endmodule
