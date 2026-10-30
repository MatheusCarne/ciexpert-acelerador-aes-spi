// ============================================================================
// minisoc_aes_inv_mix_columns.sv
// InvMixColumns (FIPS-197 5.3.3): Multiplicacao inversa por {0e, 0b, 0d, 09}
// ============================================================================
module minisoc_aes_inv_mix_columns (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  function automatic logic [7:0] xtime(input logic [7:0] b);
    return b[7] ? ((b << 1) ^ 8'h1B) : (b << 1);
  endfunction

  function automatic logic [7:0] mul_9(input logic [7:0] b);
    logic [7:0] b2, b4, b8;
    b2 = xtime(b);  b4 = xtime(b2); b8 = xtime(b4);
    return b8 ^ b;
  endfunction

  function automatic logic [7:0] mul_b(input logic [7:0] b);
    logic [7:0] b2, b4, b8;
    b2 = xtime(b);  b4 = xtime(b2); b8 = xtime(b4);
    return b8 ^ b2 ^ b;
  endfunction

  function automatic logic [7:0] mul_d(input logic [7:0] b);
    logic [7:0] b2, b4, b8;
    b2 = xtime(b);  b4 = xtime(b2); b8 = xtime(b4);
    return b8 ^ b4 ^ b;
  endfunction

  function automatic logic [7:0] mul_e(input logic [7:0] b);
    logic [7:0] b2, b4, b8;
    b2 = xtime(b);  b4 = xtime(b2); b8 = xtime(b4);
    return b8 ^ b4 ^ b2;
  endfunction

  genvar c;
  generate
    for (c = 0; c < 4; c++) begin : g_cols
      logic [7:0] b0, b1, b2, b3;

      assign b0 = state_i[127 - 8*(4*c + 0) -: 8];
      assign b1 = state_i[127 - 8*(4*c + 1) -: 8];
      assign b2 = state_i[127 - 8*(4*c + 2) -: 8];
      assign b3 = state_i[127 - 8*(4*c + 3) -: 8];

      assign state_o[127 - 8*(4*c + 0) -: 8] = mul_e(b0) ^ mul_b(b1) ^ mul_d(b2) ^ mul_9(b3);
      assign state_o[127 - 8*(4*c + 1) -: 8] = mul_9(b0) ^ mul_e(b1) ^ mul_b(b2) ^ mul_d(b3);
      assign state_o[127 - 8*(4*c + 2) -: 8] = mul_d(b0) ^ mul_9(b1) ^ mul_e(b2) ^ mul_b(b3);
      assign state_o[127 - 8*(4*c + 3) -: 8] = mul_b(b0) ^ mul_d(b1) ^ mul_9(b2) ^ mul_e(b3);
    end
  endgenerate

endmodule
