// ============================================================================
// minisoc_aes_mix_columns.sv
// MixColumns (FIPS-197 5.1.3): Multiplicacao de colunas em GF(2^8).
// ============================================================================
module minisoc_aes_mix_columns (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);
  function automatic logic [7:0] xtime(input logic [7:0] b);
    return b[7] ? ((b << 1) ^ 8'h1B) : (b << 1);
  endfunction

  function automatic logic [7:0] mul2(input logic [7:0] b);
    return xtime(b);
  endfunction

  function automatic logic [7:0] mul3(input logic [7:0] b);
    return xtime(b) ^ b;
  endfunction

  genvar c;
  generate
    for (c = 0; c < 4; c++) begin : g_cols
      logic [7:0] b0, b1, b2, b3;

      assign b0 = state_i[127 - 8*(4*c + 0) -: 8];
      assign b1 = state_i[127 - 8*(4*c + 1) -: 8];
      assign b2 = state_i[127 - 8*(4*c + 2) -: 8];
      assign b3 = state_i[127 - 8*(4*c + 3) -: 8];

      assign state_o[127 - 8*(4*c + 0) -: 8] = mul2(b0) ^ mul3(b1) ^      b2  ^      b3 ;
      assign state_o[127 - 8*(4*c + 1) -: 8] =      b0  ^ mul2(b1) ^ mul3(b2) ^      b3 ;
      assign state_o[127 - 8*(4*c + 2) -: 8] =      b0  ^      b1  ^ mul2(b2) ^ mul3(b3);
      assign state_o[127 - 8*(4*c + 3) -: 8] = mul3(b0) ^      b1  ^      b2  ^ mul2(b3);
    end
  endgenerate
endmodule
