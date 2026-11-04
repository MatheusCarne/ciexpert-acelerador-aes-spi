// ============================================================================
// minisoc_aes_inv_sub_bytes.sv
// InvSubBytes: aplica a InvS-box a cada um dos 16 bytes do estado de 128 bits.
// ============================================================================
module minisoc_aes_inv_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : g_inv_sbox
      minisoc_aes_inv_sbox u_inv_sbox (
        .data_i (state_i[127-8*i -: 8]),
        .data_o (state_o[127-8*i -: 8])
      );
    end
  endgenerate
endmodule
