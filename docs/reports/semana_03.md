# Relatório Semana 3 — Microarquitetura e Transformações de Rodada

**Aluno:** Matheus · **Entrega:** 06/11/2026 · **Projeto:** MiniSoC AES (RTL track)

## 1. O que foi entregue

| Arquivo | Função |
|---|---|
| `docs/architecture/microarquitetura_v1.0.md` | Documento de arquitetura com FSM, CDC, reset e datapath. |
| `rtl/minisoc_aes/minisoc_aes_mix_columns.sv` | MixColumns direto em GF(2^8) (multiplicação por {02, 03, 01, 01}). |
| `rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv` | InvMixColumns em GF(2^8) (multiplicação por {0e, 0b, 0d, 09}). |
| `rtl/minisoc_aes/minisoc_aes_add_round_key.sv` | XOR bitwise entre o estado e a subchave da rodada. |
| `rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv` | Aplicação paralela da InvS-Box no estado de 128 bits. |
| `rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv` | Reordenamento inverso de linhas (apenas reroteamento). |
| `tools/gen_sbox.py` | Atualizado para gerar automaticamente `minisoc_aes_inv_sbox.sv`. |
| `tb/tb_semana03.sv` | Testbench autoverificável para as funções diretas e inversas. |

## 2. Decisões de Microarquitetura

Conforme detalhado no `microarquitetura_v1.0.md`, as principais decisões de implementação para o IP foram consolidadas:
- **Datapath Iterativo:** O motor operará com 1 rodada por ciclo de clock, instanciando 16 S-Boxes em paralelo para processar um bloco completo de 128 bits em ~10 ciclos.
- **Clock Domain Crossing (CDC):** O SPI (domínio `spi_sclk`) comunicará com o banco de registradores (domínio `clk` always-on) usando sincronizadores por *toggle*. O comando `START` será cruzado para o domínio `sys_clk` através de um sincronizador de borda de 2 estágios.
- **Expansão de Chave:** Para otimizar a latência de decriptação nos modos ECB e CBC, as 11 *round keys* serão pré-computadas e retidas em registradores.

## 3. Verificação

O `tb_semana03.sv` executa verificações determinísticas e aleatórias para comprovar a simetria das transformações.

1. **FIPS-197 Apêndice B (Rodada 1):** Validação exata das saídas do `MixColumns` e `AddRoundKey`.
2. **Prova de Inversão Algorítmica:** Garantia de que `InvMixColumns(MixColumns(X)) == X` para 2000 matrizes de estado geradas aleatoriamente.

**Resultado no Synopsys VCS (X-2025.06-SP2):** 2003 checks, 0 erros, `TEST PASSED`.

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
