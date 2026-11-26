# Relatório Técnico — Semana 6: Integração do Núcleo AES-128 no `minisoc_top`, Arbitragem de Memória, Correção do Caminho de Leitura SPI e Validação FIPS-197

- **Projeto:** Acelerador Criptográfico AES-128 via SPI (`ciexpert-acelerador-aes-spi`)
- **Módulo Integrado:** `minisoc_top` (`rtl/minisoc_top/minisoc_top.sv`), `minisoc_memory` (`rtl/minisoc_memory/minisoc_memory.sv`), `minisoc_spi` (`rtl/minisoc_spi/minisoc_spi.sv`) e submódulos AES-128 (`rtl/minisoc_aes/*.sv`)
- **Testbench de Integração:** `tb/tb_semana06_top.sv`
- **Simulador:** Synopsys VCS (`X-2025.06-SP2_Full64`, timescale `1ns/1ps`)
- **Branch / Tag de Entrega:** `semana06-minisoc-top` -> `main` | Tag `w06-aes-engine-mem-v1.0`

---

## 1. Resumo Executivo

Na **Semana 6**, o foco foi integrar completamente o núcleo criptográfico **AES-128** (`minisoc_aes_top` e submódulos) e a memória compartilhada (`minisoc_memory`) ao topo do sistema (`minisoc_top`), operando em conjunto com o `minisoc_pll_mock` (com `sys_clk` de `250 MHz` após lock/divisão) e a interface `minisoc_spi`.

Durante a integração e simulação no Synopsys VCS, o controlador de blocos e o núcleo AES-128 executaram corretamente o ciclo completo de leitura de entrada (`0..3`), processamento do bloco e escrita da saída (`512..515`), ativando `done_sticky = 1` (`BLOCKS_DONE = 1`). No entanto, o *polling* via SPI de `AES_STATUS` (`0x0C`) inicialmente retornava `0x00000000` (e, em estágio intermediário, `0x00000040` por deslocamento de bits), além de uma divergência inicial no dado cifrado causada pela polaridade do bit de seleção de operação (`enc_dec_i`) e pela ordem das palavras de 128 bits.

Após a correção da captura/deslocamento de `tx_shift_reg` no `minisoc_spi.sv`, do alinhamento do bit de controle de operação (`enc_dec_i` em `0x0B`) e da resolução de conflitos de *merge* com `origin/main`, a simulação em `tb/tb_semana06_top.sv` validou com sucesso:
- **Cifragem FIPS-197:** Saída `3925841d 02dc09fb dc118597 196a0b32` com `AES_STATUS = 0x00000202` (`[PASS]`).
- **Decriptação FIPS-197 (`InvCipher`):** Retorno ao bloco original `3243f6a8 885a308d 313198a2 e0370734` (`[PASS]`).

---

## 2. Tudo o que Foi Realizado na Semana 6

### 2.1. Integração e Controle de Execução no `minisoc_top`
- **Conexão do núcleo AES-128 (`u_aes_top`):** Integração de `minisoc_aes_top` ao domínio de clock do sistema (`sys_clk`), recebendo `start_i` (`core_start_pulse`), `enc_dec_i`, `key_i` (`aes_key_128`), `data_i` (`core_data_in`) e retornando `data_o` (`core_data_out`), `busy_o` (`core_busy`) e `done_o` (`core_done`).
- **Máquina de estados do controlador de blocos (`blk_state_t`):** Acompanhamento e validação da transição pelos estados de carregamento de palavras, disparo do núcleo (`core_start_pulse`), espera de conclusão (`core_busy` -> `core_done`), escrita dos resultados na memória de saída (`OUT_BASE_ADDR`, palavras `512..515`), atualização de `blocks_done_q` e retorno ao estado ocioso (`ST_IDLE`) com `ctrl_done_sticky = 1` e `ctrl_busy = 0`.
- **Registradores e sinais de controle via SPI:**
  - Escrita da chave AES-128 nos registradores `0x00..0x03`.
  - Configuração de `NUM_BLOCKS = 1` no registrador `0x0A`.
  - Disparo e controle de operação no registrador `0x0B` (`START` no bit `0` e seleção `enc_dec_i` no bit `1`).
  - Leitura de status em `AES_STATUS` (`0x0C`), observando `0x00000202` (`DONE = 1` no bit `1` e `BLOCKS_DONE = 1` no byte `[15:8]`).
  - Arbitragem de seleção de memória via registrador `0x0E` (`MEM_SEL_AES = 0` para acesso externo/SPI e `MEM_SEL_AES = 1` para acesso do motor AES).

### 2.2. Arbitragem e Acesso à Memória (`minisoc_memory.sv`)
- **Seleção determinística por `mem_sel_aes`:** A memória síncrona de 32 bits (`DEPTH = 1024`) alterna entre a porta externa (`ext_en`, `ext_we`, `ext_addr`, `ext_wdata`, `ext_rdata`) quando `mem_sel_aes == 0` e a porta do AES (`aes_en`, `aes_we`, `aes_addr`, `aes_wdata`, `aes_rdata`) quando `mem_sel_aes == 1`.
- **Fluxo de dados:**
  1. Com `mem_sel_aes = 0`, escrita do bloco de entrada nas posições `0..3`.
  2. Com `mem_sel_aes = 1` (`0x0E = 0x0F`), leitura pelo controlador AES e gravação do resultado cifrado/decriptado nas posições `512..515`.
  3. Retorno de `mem_sel_aes = 0` (`0x0E = 0x0E`), leitura externa de `ext_mem_rdata` nos endereços `512..515`.

### 2.3. Validação FIPS-197 (Cifragem e Decriptação) em `tb/tb_semana06_top.sv`
- **Sequência de simulação validada:**
  - `[STEP 1]` Habilitação do PLL (`0x0E = 0x0000_000E`) e espera de `pll_locked_o == 1` (`[PASS]` em `2125000 ps`).
  - `[STEP 2]` Escrita da chave AES-128 (`0x00..0x03`).
  - `[STEP 3]` Configuração de `NUM_BLOCKS = 1` (`0x0A`).
  - `[STEP 4]` Escrita do bloco de entrada na memória (`0..3`).
  - `[STEP 5]` Seleção de memória para o AES (`0x0E = 0x0000_000F`).
  - `[STEP 6]` Disparo de `START` com `enc_dec_i = 1` (`0x0B = 0x0000_0003` para cifragem `Cipher`), *polling* em `0x0C` até `rdata[1] == 1` (`0x00000202`), leitura de `512..515` e verificação de `3925841d 02dc09fb dc118597 196a0b32` (`[PASS]`).
  - `[STEP 7]` Teste de decriptação (`InvCipher` com bit `1 = 0` e `START = 1`, escrevendo `32'h0000_0001` em `0x0B`) carregando o *ciphertext* FIPS-197 em `0..3`, aguardando `DONE` em `0x0C`, lendo `512..515` e verificando `3243f6a8 885a308d 313198a2 e0370734` (`[PASS]`).
- **Controle de verbosidade:** O `$monitor` detalhado da FSM interna foi condicionado à *plusarg* `+MON` (`$test$plusargs("MON")`), mantendo a saída padrão limpa e objetiva.

---

## 3. Modificações em Arquivos de Outras Semanas / Módulos Existentes

Para viabilizar a integração e a leitura confiável via SPI no `minisoc_top`, foram realizadas modificações pontuais em arquivos pertencentes a outras partes/semanas do projeto:

| Arquivo | Escopo da Alteração | Motivo Técnico |
| :--- | :--- | :--- |
| `rtl/minisoc_spi/minisoc_spi.sv` | Refatoração da captura de `reg_rdata_i` no domínio `clk` (`tx_latch_q` quando `reg_rd_en_o` está ativo) e carregamento/deslocamento MSB-first de `tx_shift_reg` alinhado a `posedge spi_cs_n` / `negedge spi_sclk`, com driver único em `tx_shift_reg`. | Corrigir leituras SPI que retornavam `0x00000000` (falta de borda de `negedge spi_sclk` com `spi_cs_n == 1`), evitar erro `Error-[ICPD]` de múltiplos drivers em `always_ff` e eliminar deslocamento de bits (`0x02` aparecendo como `0x40`). |
| `rtl/minisoc_top/minisoc_top.sv` | Esclarecimento e padronização da ligação de `aes_decrypt` / `aes_enc_dec_sel` (`BIT_AES_CTRL_DECRYPT`) para `.enc_dec_i` do `minisoc_aes_top`, preservando `1` = cifragem (`Cipher`) e `0` = decriptação (`InvCipher`) durante a resolução de conflito com `origin/main`. | Evitar inversão indesejada da operação (`~aes_decrypt` da `origin/main` inverteria a polaridade já validada no `minisoc_aes_top`). |
| `.gitignore` | Inclusão de regras para artefatos de compilação e simulação do Synopsys VCS (`simv*`, `*.daidir/`, `csrc/`, `*.key`, `ucli.key`, `vc_hdrs.h`, `*.vcd`, `*.fsdb`, `*.log`). | Impedir o versionamento de binários gerados e diretórios temporários do VCS no repositório GitHub. |

---

## 4. Mudanças Relevantes na Arquitetura

1. **Desacoplamento de Domínio de Clock e Latch de Leitura SPI (`clk` vs. `spi_sclk` / `spi_cs_n`):**
   - A geração de `reg_rd_en_o` e a disponibilidade de `reg_rdata_i` ocorrem no domínio síncrono de `clk` (`sys_clk`), enquanto o deslocamento serial de saída (`MISO`) ocorre no domínio SPI.
   - A separação entre a captura síncrona (`tx_latch_q` em `posedge clk` quando `reg_rd_en_o` é assertado) e o carregamento/deslocamento em `tx_shift_reg` (com driver único e sem *race* entre bordas de `clk` e `spi_sclk`) tornou a leitura de registradores de status (`0x0C`) determinística no *testbench*.
2. **Confirmação da Polaridade de Operação (`enc_dec_i`) na Fronteira `minisoc_top` -> `minisoc_aes_top`:**
   - Ficou consolidado na arquitetura integrada que **`enc_dec_i = 1` seleciona cifragem (`Cipher`, chaves de rodada `0` a `10`)** e **`enc_dec_i = 0` seleciona decriptação (`InvCipher`, carga inicial com `round_keys[10]` e contagem regressiva `10 - round_cnt_q`)**.
   - Consequentemente, o comando de disparo via registrador `0x0B` utiliza `32'h0000_0003` (`START=1`, `enc_dec_i=1`) para cifrar e `32'h0000_0001` (`START=1`, `enc_dec_i=0`) para decriptar.
3. **Concatenação de Palavras de 32 Bits em Barramentos de 128 Bits:**
   - Validou-se a ordenação `{in_words[0], in_words[1], in_words[2], in_words[3]}` para `core_data_in`, `{key_q[0], key_q[1], key_q[2], key_q[3]}` para `aes_key_128` e `{out_words[0], out_words[1], out_words[2], out_words[3]} = core_data_out` para a escrita na região de saída da memória (`512..515`), reproduzindo exatamente os vetores do padrão FIPS-197.

---

## 5. Dificuldades Encontradas e Soluções Aplicadas

1. **`AES_STATUS` (`0x0C`) retornando `0x00000000` apesar de `done_sticky = 1` no monitor:**
   - **Causa:** O núcleo AES-128 completava a execução e setava `done_sticky = 1`, mas `tx_shift_reg` dependia de `negedge spi_sclk` com `spi_cs_n == 1`, condição que não ocorria quando `spi_cs_n` subia com `spi_sclk` em `0`, além de haver necessidade de aguardar a propagação CDC entre os dois frames do `spi_read`.
   - **Solução:** Captura de `{8'h00, reg_rdata_i}` em `tx_latch_q` no `posedge clk` com `reg_rd_en_o`, carregamento de `tx_shift_reg` ao desativar `spi_cs_n` e intervalo de `#100ns` entre o frame de leitura e o `NOP` no `spi_read` do *testbench*.
2. **Erro de compilação VCS `Error-[ICPD]` (múltiplos drivers em `tx_shift_reg`):**
   - **Causa:** Atribuir a `tx_shift_reg` em dois blocos `always_ff` distintos (`posedge clk` e `negedge spi_sclk`), o que é proibido pelo SystemVerilog.
   - **Solução:** Centralização da escrita de `tx_shift_reg` em um único bloco `always_ff`, usando um registrador auxiliar (`tx_latch_q`) no domínio `clk`.
3. **Deslocamento de bits na leitura SPI (`0x02` lido como `0x40`):**
   - **Causa:** Retenção extra de deslocamento no primeiro `negedge spi_sclk` após nova captura desalinhou os bits deslocados em `tx_shift_reg`.
   - **Solução:** Remoção da retenção extra e padronização do carregamento em `spi_cs_n == 1` com deslocamento contínuo `{tx_shift_reg[38:0], 1'b0}` em `negedge spi_sclk` quando `spi_cs_n == 0`.
4. **Saída divergente na primeira cifragem (`cb13389c 1d59c1d5 0d11f6b9 0c38ce7f`):**
   - **Causa:** Escrita de `32'h0000_0001` no registrador `0x0B` manteve o bit `1` (`enc_dec_i`) em `0`, executando `InvCipher` em vez de `Cipher`.
   - **Solução:** Uso de `32'h0000_0003` no `0x0B` para cifragem e adição de caso de teste dedicado para decriptação (`32'h0000_0001` no `0x0B`).
5. **Conflitos de *merge* com `origin/main` e truncamento acidental durante resolução automática:**
   - **Causa:** Divergências entre `semana06-minisoc-top` e `origin/main` em `rtl/minisoc_top/minisoc_top.sv` (polaridade de `enc_dec_i`) e `tb/tb_semana06_top.sv` (`+MON` e loop de *polling*), agravadas por uma expressão regular abrangente que removeu os passos `[STEP 1]` a `[STEP 6]` e causou leitura `x` no `AES_STATUS`.
   - **Solução:** Preservação da polaridade correta (`enc_dec_i = aes_ctrl_q[BIT_AES_CTRL_DECRYPT]`), restauração completa do fluxo de teste no `tb/tb_semana06_top.sv`, reexecução da simulação VCS com dupla validação FIPS-197 (`[PASS]` na cifragem e na decriptação), atualização do PR e alinhamento da tag `w06-aes-engine-mem-v1.0` na `main`.

---

## 6. Conclusão

A integração do núcleo **AES-128** com o `minisoc_top`, `minisoc_memory` e `minisoc_spi` foi concluída e verificada em simulação no Synopsys VCS. O sistema apresentou comunicação SPI confiável para configuração, disparo, *polling* de status e transferência de blocos de memória, validando tanto a cifragem quanto a decriptação do vetor FIPS-197 e deixando o repositório sincronizado na `main` com a tag `w06-aes-engine-mem-v1.0`.
