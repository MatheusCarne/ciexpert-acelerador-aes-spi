// ============================================================================
// minisoc_aes_key_exp.sv
// Top-level da expansao de chave. Gera K0..K10 simultaneamente.
// ============================================================================
module minisoc_aes_key_exp (
  input  logic [127:0] key_i,
  output logic [127:0] round_keys_o [0:10] // Array desempacotado para a FSM indexar
);

  // Tabela Rcon (Round Constant) para AES-128 em GF(2^8)
  function automatic logic [7:0] get_rcon(input int rnd);
    case (rnd)
      1:  return 8'h01;
      2:  return 8'h02;
      3:  return 8'h04;
      4:  return 8'h08;
      5:  return 8'h10;
      6:  return 8'h20;
      7:  return 8'h40;
      8:  return 8'h80;
      9:  return 8'h1B;
      10: return 8'h36;
      default: return 8'h00;
    endcase
  endfunction

  // K0 é a chave original fornecida via SPI
  assign round_keys_o[0] = key_i;

  // Unroll combinacional para as subchaves K1 a K10
  genvar i;
  generate
    for (i = 1; i <= 10; i++) begin : g_key_exp
      minisoc_aes_key_exp_round u_kexp_rnd (
        .key_i  (round_keys_o[i-1]),
        .rcon_i (get_rcon(i)),
        .key_o  (round_keys_o[i])
      );
    end
  endgenerate

endmodule
