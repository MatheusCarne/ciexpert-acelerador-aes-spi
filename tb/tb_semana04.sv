`timescale 1ns/1ps

module tb_semana04;
  logic [127:0] key_in;
  logic [127:0] round_keys [0:10];

  minisoc_aes_key_exp u_key_exp (
    .key_i(key_in),
    .round_keys_o(round_keys)
  );

  int errors = 0;
  int checks = 0;

  logic [127:0] expected_keys [0:10];

  initial begin
    // FIPS-197 Appendix A - Expected Round Keys
    expected_keys[0]  = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    expected_keys[1]  = 128'ha0fafe1788542cb123a339392a6c7605;
    expected_keys[2]  = 128'hf2c295f27a96b9435935807a7359f67f;
    expected_keys[3]  = 128'h3d80477d4716fe3e1e237e446d7a883b;
    expected_keys[4]  = 128'hef44a541a8525b7fb671253bdb0bad00;
    expected_keys[5]  = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    expected_keys[6]  = 128'h6d88a37a110b3efddbf98641ca0093fd;
    expected_keys[7]  = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
    expected_keys[8]  = 128'head27321b58dbad2312bf5607f8d292f;
    expected_keys[9]  = 128'hac7766f319fadc2128d12941575c006e;
    expected_keys[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;

    // Chave de entrada original
    key_in = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    #10; // Aguarda estabilizacao do combinacional

    for (int i = 0; i <= 10; i++) begin
      checks++;
      if (round_keys[i] !== expected_keys[i]) begin
        errors++;
        $display("[FAIL] Round %0d Key: got=%032h exp=%032h", i, round_keys[i], expected_keys[i]);
      end else begin
        $display("[PASS] Round %0d Key: %032h", i, round_keys[i]);
      end
    end

    $display("----------------------------------------");
    $display("Checks: %0d  Erros: %0d", checks, errors);
    if (errors == 0) $display("KEY EXPANSION TEST PASSED");
    else             $display("KEY EXPANSION TEST FAILED");
    
    $finish;
  end
endmodule
