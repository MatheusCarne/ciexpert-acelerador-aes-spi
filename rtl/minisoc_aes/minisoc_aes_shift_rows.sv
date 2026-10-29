// ============================================================================
// minisoc_aes_shift_rows.sv
// ShiftRows (FIPS-197 5.1.2): puro reroteamento, sem logica.
// Byte n (n = 0..15, byte 0 em [127:120]) -> linha r = n%4, coluna c = n/4.
// Linha r rotaciona r posicoes a esquerda: s'[r][c] = s[r][(c+r)%4].
// ============================================================================
module minisoc_aes_shift_rows (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);
  genvar r, c;
  generate
    for (c = 0; c < 4; c++) begin : g_col
      for (r = 0; r < 4; r++) begin : g_row
        localparam int DST = r + 4*c;
        localparam int SRC = r + 4*((c + r) % 4);
        assign state_o[127-8*DST -: 8] = state_i[127-8*SRC -: 8];
      end
    end
  endgenerate
endmodule
