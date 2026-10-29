// ============================================================================
// minisoc_aes_sub_bytes.sv
// SubBytes: aplica a S-box a cada um dos 16 bytes do estado (128 bits).
// Convencao do projeto: byte 0 em [127:120] ... byte 15 em [7:0].
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
