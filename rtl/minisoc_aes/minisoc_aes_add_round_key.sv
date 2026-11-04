// ============================================================================
// minisoc_aes_add_round_key.sv
// AddRoundKey (FIPS-197 5.1.4): XOR bitwise entre estado e subchave.
// ============================================================================
module minisoc_aes_add_round_key (
  input  logic [127:0] state_i,
  input  logic [127:0] rkey_i,
  output logic [127:0] state_o
);
  assign state_o = state_i ^ rkey_i;
endmodule
