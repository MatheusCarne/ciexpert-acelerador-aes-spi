# Relatório Semana 2 — Blocos combinacionais AES: S-box, SubBytes, ShiftRows

**Aluno:** Matheus · **Entrega:** 30/10/2026 · **Projeto:** MiniSoC AES (RTL track)

## 1. O que foi entregue

| Arquivo | Função |
|---|---|
| `rtl/minisoc_aes/minisoc_aes_sbox.sv` | S-box 8→8, combinacional, 256 entradas (gerado por `tools/gen_sbox.py`) |
| `rtl/minisoc_aes/minisoc_aes_sub_bytes.sv` | 16 instâncias da S-box sobre o estado de 128 bits |
| `rtl/minisoc_aes/minisoc_aes_shift_rows.sv` | ShiftRows, apenas reroteamento (zero lógica) |
| `tb/tb_semana02.sv` | Testbench self-checking (PASS/FAIL + timeout) |
| `scripts/run_all.sh` | Comando único: regenera S-box, compila e simula |
| `tools/gen_sbox.py` | Calcula a S-box por GF(2^8): inverso + transformação afim |

Execução: `./scripts/run_all.sh` (usa VCS).

## 2. Decisões de projeto

- **Convenção de bytes (Block Guide):** byte 0 em `[127:120]` … byte 15 em `[7:0]`. O byte `n` corresponde à linha `r = n mod 4`, coluna `c = n div 4` (estado column-major do FIPS-197).
- **S-box como tabela gerada:** a tabela vem de um script que implementa o inverso em GF(2^8) (polinômio x⁸+x⁴+x³+x+1) e a afim, com asserts em `S[00]=63`, `S[53]=ED`, `S[01]=7C`, `S[FF]=16` e verificação de bijetividade. Evita erro de digitação em 256 valores.
- **ShiftRows:** `s'[r][c] = s[r][(c+r) mod 4]`, escrito com `generate` e `localparam`; sem lógica, só fios.
- **Sem estado:** os três módulos são puramente combinacionais; registradores entram na Semana 4 (datapath/FSM).

## 3. Verificação

O testbench compara contra um modelo de referência **independente** (inverso por força bruta + afim, e ShiftRows por matriz 4×4):

1. S-box: as 256 entradas.
2. Vetores FIPS-197 Apêndice B, rodadas 1 e 10 (SubBytes e SubBytes→ShiftRows).
3. 2000 estados aleatórios (SubBytes, ShiftRows e cadeia).
4. Cantos: `0x00…00`, `0xFF…FF` e padrão de índices `000102…0f` (prova o mapeamento exato de ShiftRows).

| Vetor | Entrada | Esperado |
|---|---|---|
| R1 início | `193de3bea0f4e22b9ac68d2ae9f84808` | — |
| R1 SubBytes | | `d42711aee0bf98f1b8b45de51e415230` |
| R1 ShiftRows | | `d4bf5d30e0b452aeb84111f11e2798e5` |
| R10 início | `eb40f21e592e38848ba113e71bc342d2` | — |
| R10 SubBytes | | `e9098972cb31075f3d327d94af2e2cb5` |
| R10 ShiftRows | | `e9317db5cb322c723d2e895faf090794` |

Os vetores da rodada 10 foram obtidos de um AES-128 completo em Python, que reproduz o ciphertext do Apêndice B (`3925841d02dc09fbdc118597196a0b32`).

**Resultado (iverilog 12, ambiente de desenvolvimento):** 6268 checks, 0 erros, `TEST PASSED`.

**Teste de mutação:** trocar o sentido do ShiftRows gerou 4004 erros; alterar uma única entrada da S-box (`53→EC`) foi detectada. O testbench realmente pega falhas.

**Resultado no VCS (X-2025.06-SP2, servidor):** 6268 checks, 0 erros, `TEST PASSED`.

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

## 4. Dúvidas / pontos a confirmar com o professor

1. Confirmar que a convenção byte 0 em `[127:120]` vale também para a ordem dos registradores KEY0–3 (Word 0 = `[127:96]`) na saída do key expansion.
2. A S-box será mantida como tabela (case) ou o professor prefere a versão por GF(2^8) calculada, visando área na síntese da Semana 8?
3. InvSubBytes / InvShiftRows são necessários já no v1.0 (decifragem em ECB/CBC) ou só quando os modos forem implementados?

## 5. Próximos passos (Semana 3, 06/11)

Documento de microarquitetura, MixColumns, AddRoundKey e transformações inversas.
