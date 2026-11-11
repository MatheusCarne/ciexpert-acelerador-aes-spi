// ============================================================================
// minisoc_aes_key_exp_round.sv
// Calcula a subchave K_{i} a partir da subchave K_{i-1} e do Rcon_{i}
// ============================================================================
module minisoc_aes_key_exp_round (
  input  logic [127:0] key_i,
  input  logic [7:0]   rcon_i,
  output logic [127:0] key_o
);
  logic [31:0] w0, w1, w2, w3;
  logic [31:0] w4, w5, w6, w7;
  logic [31:0] rot_w3, sub_w3;

  // Separa a chave anterior em 4 palavras de 32 bits
  assign w0 = key_i[127:96];
  assign w1 = key_i[95:64];
  assign w2 = key_i[63:32];
  assign w3 = key_i[31:0];

  // RotWord: Rotaciona w3 em 1 byte para a esquerda
  assign rot_w3 = {w3[23:0], w3[31:24]};

  // SubWord: Aplica a S-Box diretamente em cada byte
  minisoc_aes_sbox u_sb0 (.data_i(rot_w3[31:24]), .data_o(sub_w3[31:24]));
  minisoc_aes_sbox u_sb1 (.data_i(rot_w3[23:16]), .data_o(sub_w3[23:16]));
  minisoc_aes_sbox u_sb2 (.data_i(rot_w3[15:8]),  .data_o(sub_w3[15:8]));
  minisoc_aes_sbox u_sb3 (.data_i(rot_w3[7:0]),   .data_o(sub_w3[7:0]));

  // XOR principal do Key Expansion AES-128
  assign w4 = w0 ^ sub_w3 ^ {rcon_i, 24'h000000};
  assign w5 = w1 ^ w4;
  assign w6 = w2 ^ w5;
  assign w7 = w3 ^ w6;

  // Concatena as novas palavras para formar a chave da rodada
  assign key_o = {w4, w5, w6, w7};

endmodule
