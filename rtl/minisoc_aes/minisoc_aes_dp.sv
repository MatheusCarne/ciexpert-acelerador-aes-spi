// ============================================================================
// minisoc_aes_dp.sv
// Datapath combinacional do AES-128 (Cipher e Inverse Cipher)
// ============================================================================
module minisoc_aes_dp (
  input  logic [127:0] state_i,      // Dado de entrada (Memoria ou Registrador)
  input  logic [127:0] rkey_i,       // Subchave da rodada atual
  input  logic         enc_dec_i,    // 1: Cifragem (Cipher), 0: Decriptacao (InvCipher)
  input  logic         bypass_mc_i,  // 1: Ignora (Inv)MixColumns na 10a Rodada
  input  logic         load_cycle_i, // 1: Ciclo 0 (Apenas AddRoundKey inicial)
  output logic [127:0] state_o       // Proximo estado
);

  // --------------------------------------------------------------------------
  // 1. Caminho de Cifragem (Encryption Path) - Rodadas 1 a 10
  // --------------------------------------------------------------------------
  logic [127:0] enc_sb_out, enc_sr_out, enc_mc_out, enc_mc_mux, enc_ark_out;

  minisoc_aes_sub_bytes   u_enc_sb (.state_i(state_i),    .state_o(enc_sb_out));
  minisoc_aes_shift_rows  u_enc_sr (.state_i(enc_sb_out), .state_o(enc_sr_out));
  minisoc_aes_mix_columns u_enc_mc (.state_i(enc_sr_out), .state_o(enc_mc_out));

  // Multiplexador: Bypass MixColumns na 10a Rodada
  assign enc_mc_mux = bypass_mc_i ? enc_sr_out : enc_mc_out;
  
  // AddRoundKey final da iteracao de Cifragem
  minisoc_aes_add_round_key u_enc_ark (
    .state_i(enc_mc_mux),
    .rkey_i (rkey_i),
    .state_o(enc_ark_out)
  );

  // --------------------------------------------------------------------------
  // 2. Caminho de Decriptacao (Decryption Path) - Rodadas 1 a 10
  // --------------------------------------------------------------------------
  logic [127:0] dec_sr_out, dec_sb_out, dec_ark_out, dec_mc_out, dec_mc_mux;

  minisoc_aes_inv_shift_rows  u_dec_sr (.state_i(state_i),    .state_o(dec_sr_out));
  minisoc_aes_inv_sub_bytes   u_dec_sb (.state_i(dec_sr_out), .state_o(dec_sb_out));
  
  // AddRoundKey intermediario da iteracao de Decriptacao
  minisoc_aes_add_round_key u_dec_ark (
    .state_i(dec_sb_out),
    .rkey_i (rkey_i),
    .state_o(dec_ark_out)
  );

  minisoc_aes_inv_mix_columns u_dec_mc (.state_i(dec_ark_out), .state_o(dec_mc_out));

  // Multiplexador: Bypass InvMixColumns na 10a Rodada
  assign dec_mc_mux = bypass_mc_i ? dec_ark_out : dec_mc_out;

  // --------------------------------------------------------------------------
  // 3. Logica de Steering (Multiplexadores de Saida)
  // --------------------------------------------------------------------------
  logic [127:0] loop_out;
  logic [127:0] init_ark_out;

  // MUX 1: Seleciona o caminho do loop (Cifragem vs Decriptacao)
  assign loop_out = enc_dec_i ? enc_ark_out : dec_mc_mux;

  // Ciclo de Carregamento (Ciclo 0 - Executa apenas o AddRoundKey inicial)
  minisoc_aes_add_round_key u_init_ark (
    .state_i(state_i),
    .rkey_i (rkey_i),
    .state_o(init_ark_out)
  );

  // MUX 2: Seleciona entre Loop Principal vs Ciclo de Carregamento (Ciclo 0)
  assign state_o = load_cycle_i ? init_ark_out : loop_out;

endmodule
