// ============================================================================
// minisoc_aes_sub_bytes.sv (Golden Model)
// SubBytes (FIPS-197 5.1.1): Aplica a S-box a cada byte do estado.
// ============================================================================
module minisoc_aes_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : g_sbox
      minisoc_aes_sbox u_sbox (
        .data_i (state_i[127-8*i -: 8]),
        .data_o (state_o[127-8*i -: 8])
      );
    end
  endgenerate
endmodule
