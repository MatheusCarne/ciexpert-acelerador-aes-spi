// ============================================================================
// tb_semana02.sv -- Testbench self-checking da Semana 2 (S-box, SubBytes, ShiftRows)
//  1) S-box: as 256 entradas contra referencia independente (inverso em GF(2^8) + afim)
//  2) Vetores FIPS-197 Apendice B: rodada 1 e rodada 10 (SubBytes e SubBytes+ShiftRows)
//  3) Aleatorio dirigido: 2000 estados contra modelo de referencia (matriz 4x4)
//  4) Casos de canto: 0x00..00, 0xFF..FF
// Termina com "TEST PASSED" / "TEST FAILED" e $finish; possui timeout.
// ============================================================================
`timescale 1ns/1ps
module tb_semana02;

  logic [7:0]   sb_in,  sb_out;
  logic [127:0] st_in,  st_sub, st_shift, st_both;

  minisoc_aes_sbox       u_sbox (.data_i(sb_in), .data_o(sb_out));
  minisoc_aes_sub_bytes  u_sub  (.state_i(st_in), .state_o(st_sub));
  minisoc_aes_shift_rows u_shr  (.state_i(st_in), .state_o(st_shift));
  // cadeia SubBytes -> ShiftRows (ordem da rodada AES)
  minisoc_aes_shift_rows u_shr2 (.state_i(st_sub), .state_o(st_both));

  int errors = 0;
  int checks = 0;

  // ---------------- referencia independente ----------------
  function automatic logic [7:0] xtime(input logic [7:0] b);
    return b[7] ? ((b << 1) ^ 8'h1B) : (b << 1);
  endfunction

  function automatic logic [7:0] gmul(input logic [7:0] a_in, input logic [7:0] b_in);
    logic [7:0] a, b, r;
    a = a_in; b = b_in; r = 8'h00;
    for (int i = 0; i < 8; i++) begin
      if (b[0]) r ^= a;
      a = xtime(a);
      b = b >> 1;
    end
    return r;
  endfunction

  function automatic logic [7:0] ref_sbox(input logic [7:0] a);
    logic [7:0] inv, s;
    logic [7:0] C63;
    C63 = 8'h63;
    inv = 8'h00;
    if (a != 8'h00)
      for (int x = 1; x < 256; x++)
        if (gmul(a, x[7:0]) == 8'h01) inv = x[7:0];
    for (int i = 0; i < 8; i++)
      s[i] = inv[i] ^ inv[(i+4)%8] ^ inv[(i+5)%8] ^ inv[(i+6)%8] ^ inv[(i+7)%8] ^ C63[i];
    return s;
  endfunction

  // tabela de referencia calculada uma unica vez (evita recalcular o inverso)
  logic [7:0] ref_tab [256];
  initial for (int i = 0; i < 256; i++) ref_tab[i] = ref_sbox(i[7:0]);

  // estado 4x4: byte n = [127-8n -: 8], linha n%4, coluna n/4
  function automatic logic [127:0] ref_sub_bytes(input logic [127:0] s);
    logic [127:0] o;
    for (int n = 0; n < 16; n++) o[127-8*n -: 8] = ref_tab[s[127-8*n -: 8]];
    return o;
  endfunction

  function automatic logic [127:0] ref_shift_rows(input logic [127:0] s);
    logic [7:0] m [4][4];
    logic [7:0] t [4][4];
    logic [127:0] o;
    for (int n = 0; n < 16; n++) m[n%4][n/4] = s[127-8*n -: 8];
    for (int r = 0; r < 4; r++)
      for (int c = 0; c < 4; c++) t[r][c] = m[r][(c+r)%4];
    for (int n = 0; n < 16; n++) o[127-8*n -: 8] = t[n%4][n/4];
    return o;
  endfunction

  task automatic check128(input string name, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("[FAIL] %s: got=%032h exp=%032h", name, got, exp);
    end
  endtask

  task automatic apply_state(input logic [127:0] s);
    st_in = s; #1;
  endtask

  // ---------------- estimulos ----------------
  logic [127:0] r1_start, r1_sub, r1_shift, r10_start, r10_sub, r10_shift;

  initial begin
    #1;
    // 1) S-box exaustiva
    for (int i = 0; i < 256; i++) begin
      sb_in = i[7:0]; #1; checks++;
      if (sb_out !== ref_tab[i]) begin
        errors++; $display("[FAIL] sbox(%02h)=%02h exp=%02h", i[7:0], sb_out, ref_tab[i]);
      end
    end
    sb_in = 8'h00; #1; checks++; if (sb_out !== 8'h63) begin errors++; $display("[FAIL] sbox(00)!=63"); end
    sb_in = 8'h53; #1; checks++; if (sb_out !== 8'hED) begin errors++; $display("[FAIL] sbox(53)!=ED"); end
    $display("[INFO] S-box: 256 entradas verificadas");

    // 2) Vetores FIPS-197 Apendice B
    r1_start  = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
    r1_sub    = 128'hd42711aee0bf98f1b8b45de51e415230;
    r1_shift  = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
    r10_start = 128'heb40f21e592e38848ba113e71bc342d2;
    r10_sub   = 128'he9098972cb31075f3d327d94af2e2cb5;
    r10_shift = 128'he9317db5cb322c723d2e895faf090794;

    apply_state(r1_start);
    check128("R1 SubBytes",           st_sub,   r1_sub);
    check128("R1 SubBytes+ShiftRows", st_both,  r1_shift);
    apply_state(r10_start);
    check128("R10 SubBytes",           st_sub,  r10_sub);
    check128("R10 SubBytes+ShiftRows", st_both, r10_shift);
    // ShiftRows isolado sobre a saida da SubBytes
    apply_state(r1_sub);
    check128("R1 ShiftRows isolado",  st_shift, r1_shift);
    $display("[INFO] Vetores FIPS-197 Apendice B (rodadas 1 e 10) verificados");

    // 4) cantos
    apply_state(128'h0);
    check128("zeros SubBytes", st_sub, {16{8'h63}});
    check128("zeros ShiftRows", st_shift, 128'h0);
    apply_state({16{8'hFF}});
    check128("ones ShiftRows", st_shift, {16{8'hFF}});
    check128("ones SubBytes",  st_sub, ref_sub_bytes({16{8'hFF}}));
    // padrao com byte unico: confirma o mapeamento exato de ShiftRows
    apply_state(128'h000102030405060708090a0b0c0d0e0f);
    check128("ShiftRows indices", st_shift, 128'h00050a0f04090e03080d02070c01060b);

    // 3) aleatorio
    for (int k = 0; k < 2000; k++) begin
      logic [127:0] v;
      v = {$urandom, $urandom, $urandom, $urandom};
      apply_state(v);
      check128("rand SubBytes",  st_sub,   ref_sub_bytes(v));
      check128("rand ShiftRows", st_shift, ref_shift_rows(v));
      check128("rand chain",     st_both,  ref_shift_rows(ref_sub_bytes(v)));
    end
    $display("[INFO] 2000 estados aleatorios verificados");

    $display("----------------------------------------");
    $display("Checks: %0d  Erros: %0d", checks, errors);
    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED");
    $finish;
  end

  initial begin
    #5_000_000;
    $display("TEST FAILED (timeout)");
    $finish;
  end
endmodule
