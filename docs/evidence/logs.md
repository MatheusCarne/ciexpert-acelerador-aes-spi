### Log de Sucesso da Simulação (Synopsys VCS) | semana 1:
```text
==================================================
[TEST] Entrada  (Data) : 0x0123456789abcdef0123456789abcdef
[TEST] Chave    (Key)  : 0xfedcba9876543210fedcba9876543210
[TEST] Resultado (XOR) : 0xffffffffffffffffffffffffffffffff
[SUCCESS] Operacao XOR de 128 bits Validada!
==================================================

$finish called from file "tb/tb_dummy_top.sv", line 67.
$finish at simulation time                60000
           V C S   S i m u l a t i o n   R e p o r t
Time: 60000 ps
CPU Time:      0.380 seconds;       Data structure size:   0.0Mb
Sat Oct 10 16:07:04 2026
```
### Log de simulação SubBytes e ShiftRows | semana 2:

```
Chronologic VCS simulator copyright 1991-2025
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Oct 29 21:01 2026
[INFO] S-box: 256 entradas verificadas
[INFO] Vetores FIPS-197 Apendice B (rodadas 1 e 10) verificados
[INFO] 2000 estados aleatorios verificados
----------------------------------------
Checks: 6268  Erros: 0
TEST PASSED
$finish called from file "tb/tb_semana02.sv", line 148.
$finish at simulation time              2265000
Time: 2265000 ps
CPU Time:      0.410 seconds;       Data structure size:   0.0Mb
== RESULTADO: PASS ==
```
### Log de simulação transformações Mixcolumns e AddRoundKey | semana 3:
```text
Chronologic VCS simulator copyright 1991-2025
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov  4 14:18 2026
[INFO] 2000 verificacoes de inversao concluidas.
----------------------------------------
Checks: 2003  Erros: 0
TEST PASSED
$finish called from file "tb/tb_semana03.sv", line 53.
$finish at simulation time              2003000
Time: 2003000 ps
CPU Time:      0.440 seconds;       Data structure size:   0.0Mb
```
### Log de Simulação da Expansão de Chave | semana 4:
```text
==> Executando Simulação...
./simv
Info: [VCS_SAVE_RESTORE_INFO] ASLR (Address Space Layout Randomization) is detected on the machine. To enable $save functionality, ASLR will be switched off and simv re-executed.
Please use '-no_save' simv switch to avoid re-execution or '-suppress=ASLR_DETECTED_INFO' to suppress this message.
Chronologic VCS simulator copyright 1991-2025
Contains Synopsys proprietary information.
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov 11 15:43 2026
[PASS] Round 0 Key: 2b7e151628aed2a6abf7158809cf4f3c
[PASS] Round 1 Key: a0fafe1788542cb123a339392a6c7605
[PASS] Round 2 Key: f2c295f27a96b9435935807a7359f67f
[PASS] Round 3 Key: 3d80477d4716fe3e1e237e446d7a883b
[PASS] Round 4 Key: ef44a541a8525b7fb671253bdb0bad00
[PASS] Round 5 Key: d4d1c6f87c839d87caf2b8bc11f915bc
[PASS] Round 6 Key: 6d88a37a110b3efddbf98641ca0093fd
[PASS] Round 7 Key: 4e54f70e5f5fc9f384a64fb24ea6dc4f
[PASS] Round 8 Key: ead27321b58dbad2312bf5607f8d292f
[PASS] Round 9 Key: ac7766f319fadc2128d12941575c006e
[PASS] Round 10 Key: d014f9a8c9ee2589e13f0cc8b6630ca6
----------------------------------------
Checks: 11  Erros: 0
KEY EXPANSION TEST PASSED
$finish called from file "tb/tb_semana04.sv", line 50.
$finish at simulation time                 10000
           V C S   S i m u l a t i o n   R e p o r t
Time: 10000 ps
CPU Time:      0.390 seconds;       Data structure size:   0.0Mb
Wed Nov 11 15:43:26 2026
```
### Log de Simulação do Datapath Completo | semana 4:
```text
==> Executando Simulação...
./simv
Info: [VCS_SAVE_RESTORE_INFO] ASLR (Address Space Layout Randomization) is detected on the machine. To enable $save functionality, ASLR will be switched off and simv re-executed.
Please use '-no_save' simv switch to avoid re-execution or '-suppress=ASLR_DETECTED_INFO' to suppress this message.
Chronologic VCS simulator copyright 1991-2025
Contains Synopsys proprietary information.
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov 11 16:00 2026
========================================
 INICIANDO TESTE CIFRAGEM (ENCRYPTION)
========================================
[PASS] Cifragem validada! Resultado igual ao FIPS-197.

========================================
 INICIANDO TESTE DECRIPTACAO (DECRYPTION)
========================================
[PASS] Decriptacao validada! Plaintext recuperado com sucesso.
========================================

$finish called from file "tb/tb_semana04_dp.sv", line 99.
$finish at simulation time                 115000
           V C S   S i m u l a t i o n   R e p o r t
Time: 115000 ps
CPU Time:      0.380 seconds;       Data structure size:   0.0Mb
Wed Nov 11 16:00:43 2026
```
