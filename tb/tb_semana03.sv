`timescale 1ns/1ps
module tb_semana03;

  logic [127:0] st_in, st_mc, st_inv_mc, st_ark, st_inv_sub, st_inv_shr;
  logic [127:0] rkey;

  minisoc_aes_mix_columns     u_mc     (.state_i(st_in),  .state_o(st_mc));
  minisoc_aes_inv_mix_columns u_inv_mc (.state_i(st_mc),  .state_o(st_inv_mc));
  minisoc_aes_add_round_key   u_ark    (.state_i(st_in),  .rkey_i(rkey), .state_o(st_ark));
  minisoc_aes_inv_sub_bytes   u_inv_sb (.state_i(st_in),  .state_o(st_inv_sub));
  minisoc_aes_inv_shift_rows  u_inv_sr (.state_i(st_in),  .state_o(st_inv_shr));

  int errors = 0;
  int checks = 0;

  task automatic check128(input string name, input logic [127:0] got, input logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("[FAIL] %s: got=%032h exp=%032h", name, got, exp);
    end
  endtask

  initial begin
    #1;
    // 1) Teste MixColumns - FIPS-197 Apendice B (Rodada 1)
    // After ShiftRows: d4bf5d30e0b452aeb84111f11e2798e5
    // After MixColumns: 046681e5e0cb199a48f8d37a2806264c
    st_in = 128'hd4bf5d30e0b452aeb84111f11e2798e5; #1;
    check128("FIPS-197 R1 MixColumns", st_mc, 128'h046681e5e0cb199a48f8d37a2806264c);

    // 2) Prova de Inversao: InvMixColumns(MixColumns(X)) == X
    check128("MixColumns -> InvMixColumns", st_inv_mc, 128'hd4bf5d30e0b452aeb84111f11e2798e5);

    // 3) Teste AddRoundKey - FIPS-197 Apendice B (Start of Round 1)
    st_in = 128'h3243f6a8885a308d313198a2e0370734;
    rkey  = 128'h2b7e151628aed2a6abf7158809cf4f3c; #1;
    check128("FIPS-197 R1 AddRoundKey", st_ark, 128'h193de3bea0f4e22b9ac68d2ae9f84808);

    // 4) Teste 2000 estados aleatorios para provar a relacao de inversao
    for (int k = 0; k < 2000; k++) begin
      logic [127:0] rnd;
      rnd = {$urandom, $urandom, $urandom, $urandom};
      st_in = rnd; #1;
      check128("Random InvMixColumns(MixColumns)", st_inv_mc, rnd);
    end
    $display("[INFO] 2000 verificacoes de inversao concluidas.");

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
