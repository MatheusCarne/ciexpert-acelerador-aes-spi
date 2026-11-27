# Relatório Técnico — Semana 6: Integração Completa do MiniSoC AES-128 (`minisoc_top`, `minisoc_memory`, Modos ECB/CBC/CTR, Arbitragem e Validação Multi-Bloco)

* **Projeto:** Acelerador Criptográfico AES-128 via SPI (`ciexpert-acelerador-aes-spi`)
* **Especificação de Referência:** `DV_BlockGuide_MiniSoCAES_v1.0.0.pdf` (Seções 6, 7, 8, 9 e 11) e NIST FIPS-197
* **Módulos Principais:**
  * `rtl/minisoc_top/minisoc_top.sv`
  * `rtl/minisoc_memory/minisoc_memory.sv`
  * `rtl/minisoc_spi/minisoc_spi.sv`
  * `rtl/minisoc_aes/*.sv` (`minisoc_aes_top.sv`, `minisoc_aes_dp.sv`, `minisoc_aes_key_exp.sv`, etc.)
* **Verificação e Referência:**
  * `gen_vectors_w06.py` (modelo de referência em Python + geração de `.hex` em `tb/vectors_w06/`)
  * `tb/tb_semana06_top.sv` (validação FIPS-197 de cifragem e decriptação)
  * `tb/tb_semana06_blocks.sv` (validação de 1, 2 e 256 blocos nos modos ECB, CBC e CTR + testes de erro)
* **Simulador / Lint:** Synopsys VCS `X-2025.06-SP2_Full64` (`timescale 1ns/1ps`, `+lint=all`)
* **Branch / Commit / Tag Final:** `main` (`8b95c7e`) | Tag `w06-aes-engine-mem-v1.0`

## 1. Resumo Executivo

Na **Semana 6**, foi concluída e validada a integração completa do motor criptográfico **AES-128** e da memória compartilhada (`1024 × 32` bits) no `minisoc_top.sv`, seguindo a especificação do *Block Guide* (`v1.0.0`) e o padrão **FIPS-197**.

Além da integração inicial com o `minisoc_pll_mock` (`250 MHz` após divisão) e da correção do caminho de leitura serial no `minisoc_spi.sv`, o controlador de blocos e a memória foram refinados para atender integralmente aos requisitos da Semana 6:

1. **Memória compartilhada (`minisoc_memory.sv`):** Configuração `1024 × 32` bits single-port síncrona, **sem reset funcional** no array ou na saída registrada, com arbitragem mutuamente exclusiva controlada por `MEM_SEL_AES` (`0` = interface externa, `1` = AES Engine).
2. **Captura atômica no `START` e processamento *in-place* (`minisoc_top.sv`):** No pulso válido de `START`, o controlador captura `KEY`, `IV`, `COUNTER`, `MODE`, `DECRYPT` e `NUM_BLOCKS`. Para cada bloco ($k \in [0, \mathrm{NUM\_BLOCKS}-1]$), lê 4 palavras consecutivas a partir de $4k$, executa o modo configurado e escreve o resultado **in-place** nas mesmas 4 posições de memória.
3. **Suporte aos modos `ECB`, `CBC` e `CTR` (cifragem e decriptação):** Todos os 3 modos foram implementados e validados nos dois sentidos contra o modelo de referência em Python (`gen_vectors_w06.py`) para **1, 2 e 256 blocos** (ocupando até as 1024 palavras da memória).
4. **Detecção de configurações inválidas:** Valores de `NUM_BLOCKS` fora de `1..256` (`0` e `257`) ou códigos de `MODE` reservados/fora do escopo da Semana 6 (`3'b111` e `3'b010`) sinalizam `ERROR = 1` (`AES_STATUS[2]`), mantêm `DONE = 0` (`AES_STATUS[1]`) e encerram imediatamente sem alterar a memória.
5. **Limitação conhecida da v1.0:** Os modos encadeados **PCBC (`3'b010`)**, **CFB (`3'b011`)** e **OFB (`3'b100`)** permanecem planejados para a **Semana 10 (W10)** e são rejeitados com `ERROR = 1` na release atual.

## 2. Tudo o que Foi Realizado na Semana 6

### 2.1. Memória Compartilhada e Arbitragem (`rtl/minisoc_memory/minisoc_memory.sv`)

* **Organização física:** Memória síncrona de $1024 \times 32$ bits (`DEPTH = 1024`, `ADDR_W = 10`), comportando até $256$ blocos AES de $128$ bits ($4$ palavras consecutivas por bloco: `Word 0` = `[127:96]`, `Word 1` = `[95:64]`, `Word 2` = `[63:32]`, `Word 3` = `[31:0]`).
* **Sem reset funcional:** Conforme a Seção 7.3 do *Block Guide*, o array `mem` e o registrador de leitura `mem_q` operam exclusivamente em `@(posedge clk)` sem limpeza por `rst_n`.
* **Ownership por `MEM_SEL_AES`:** Quando `mem_sel_aes == 0`, a memória responde exclusivamente à porta externa (`ext_en`, `ext_we`, `ext_addr`, `ext_wdata`, `ext_rdata`); quando `mem_sel_aes == 1`, responde exclusivamente à porta do controlador AES (`aes_en`, `aes_we`, `aes_addr`, `aes_wdata`, `aes_rdata`).

### 2.2. Controlador Multi-Bloco e Modos Criptográficos (`rtl/minisoc_top/minisoc_top.sv`)

* **Snapshot no `START` válido:** Ao detectar `cmd_start_pulse`, o controlador registra `cap_key_q`, `cap_iv_q`, `cap_ctr_q`, `cap_mode_q`, `cap_enc_dec_q` e `cap_num_blocks_q`, garantindo imunidade a alterações nos registradores durante o processamento multi-bloco.
* **Validação de configuração antes do processamento:**
  * Verifica `(num_blocks_q >= 1) && (num_blocks_q <= 256)` e `mode_v` pertencente ao conjunto suportado na W6 (`MODE_ECB = 3'b000`, `MODE_CBC = 3'b001`, `MODE_CTR = 3'b101`).
  * Em caso inválido, transita de `ST_IDLE` diretamente para `ST_FINISH` com `ctrl_error <= 1'b1`, `ctrl_done_sticky <= 1'b0` e `ctrl_busy <= 1'b0`, sem ler nem escrever na memória.
* **Operação por modo (`ECB`, `CBC`, `CTR`):**
  * **ECB (`3'b000`):** Cifra (`enc_dec_i = 1`) ou decripta (`enc_dec_i = 0`) cada bloco independentemente.
  * **CBC (`3'b001`):**
    * *Cifragem:* Calcula $C_i = \text{Cipher}_K(P_i \oplus C_{i-1})$, com $C_{-1} = \text{IV}$, atualizando `cbc_chain_q <= core_data_out`.
    * *Decriptação:* Calcula $P_i = \text{InvCipher}_K(C_i) \oplus C_{i-1}$, atualizando `cbc_chain_q <= raw_block_q`.
  * **CTR (`3'b101`):**
    * Força o núcleo AES em modo cifragem (`core_enc_dec_sel = 1'b1`), gera o bloco contador de 128 bits a partir da base `{IV[127:64], 64'd0} ^ {64'd0, COUNTER_HI, COUNTER_LO}` incrementada por `current_block_idx` e aplica $\text{Out}_i = \text{In}_i \oplus \text{Cipher}_K(\text{CTR}_i)$ tanto na cifragem quanto na decriptação.
* **Escrita *in-place* e flags de status (`AES_STATUS`, `0x0C`):**
  * Lê 4 palavras em `current_block_idx * 4 + word_idx` (`ST_LOAD_REQ` / `ST_LOAD_WAIT`), executa o núcleo AES (`ST_START_CORE` / `ST_WAIT_CORE`) e escreve as 4 palavras resultantes nos mesmos endereços `current_block_idx * 4 + word_idx` (`ST_STORE_REQ`).
  * Atualiza `BUSY` (`bit 0`), `DONE` (`bit 1`, *sticky* até o próximo `START` válido), `ERROR` (`bit 2`) e `BLOCKS_DONE` (`bits [15:8]`, incrementado uma única vez por bloco concluído em `ST_NEXT_BLOCK`).

### 2.3. Modelo de Referência em Python e Suíte de Verificação

* **`gen_vectors_w06.py`:** Implementa em Python puro a expansão de chaves AES-128, `Cipher`, `InvCipher` e os modos `ECB`, `CBC` e `CTR` (com *self-check* de ida e volta e verificação do vetor oficial FIPS-197 no bloco 0), exportando arquivos `.hex` em `tb/vectors_w06/` para **1, 2 e 256 blocos**.
* **`tb/tb_semana06_top.sv`:** Valida no `minisoc_top` integrado o travamento do PLL, a cifragem FIPS-197 (`3925841d 02dc09fb dc118597 196a0b32`) e a decriptação FIPS-197 (`3243f6a8 885a308d 313198a2 e0370734`) com leitura *in-place* nos endereços `0..3`.
* **`tb/tb_semana06_blocks.sv`:** Executa:
  * 4 cenários de rejeição de configuração inválida (`NUM_BLOCKS=0`, `NUM_BLOCKS=257`, `MODE=111_RES` e `MODE=010_PCBC`), verificando `STATUS = 0x00000004` e preservação da memória.
  * 18 cenários multi-bloco cobrindo `ECB`, `CBC` e `CTR` (`ENC` e `DEC`) para `1`, `2` e `256` blocos, conferindo palavra por palavra contra os arquivos `.hex` gerados pelo Python.


## 3. Modificações em Arquivos de Outras Semanas / Módulos Existentes

| Arquivo | Modificações Realizadas | Justificativa Técnica |
| :--- | :--- | :--- |
| `rtl/minisoc_spi/minisoc_spi.sv` | Captura síncrona de `reg_rdata_i` no domínio `clk` (`tx_latch_q` quando `reg_rd_en_o` está ativo) e carregamento/deslocamento MSB-first em driver único de `tx_shift_reg`. | Corrigir leituras SPI que retornavam `0x00000000` ou deslocadas (`0x40` em vez de `0x02`) e eliminar erro `Error-[ICPD]` de múltiplos drivers no VCS. |
| `rtl/minisoc_memory/minisoc_memory.sv` | Remoção do reset funcional (`negedge rst_n`) no bloco sequencial da memória e atualização síncrona direta de `mem_q` durante `sel_we`. | Adequar a memória `1024 × 32` à Seção 7.3 do *Block Guide* ("a memória não possui reset funcional"). |
| `rtl/minisoc_top/minisoc_top.sv` | Adição do *snapshot* no `START`, validação de `NUM_BLOCKS` (`1..256`) e `MODE` (`000`, `001`, `101`), lógica de encadeamento `CBC` e contador `CTR`, escrita *in-place* (`k*4 + word_idx`) e correção do incremento único de `blocks_done_q`. | Atender integralmente às Seções 6, 7, 8 e 11 do *Block Guide* e aos requisitos da Semana 6. |
| `tb/tb_semana06_top.sv` | Atualização dos endereços de leitura da saída de `512..515` para `0..3` (acompanhando a escrita *in-place*) e controle do monitor via `+MON`. | Validar o comportamento *in-place* com os vetores FIPS-197 de cifragem e decriptação. |
| `.gitignore` | Inclusão dos artefatos de build/simulação do Synopsys VCS (`simv*`, `*.daidir/`, `csrc/`, `*.key`, `vc_hdrs.h`, `*.vcd`, `*.fsdb`, `*.log`). | Manter o repositório limpo de binários e temporários gerados em simulação. |


## 4. Mudanças Relevantes na Arquitetura

1. **Processamento *In-Place* sobre a Memória Compartilhada (`1024 × 32`):**
   * Anteriormente, os blocos de entrada eram lidos a partir da base `0` e gravados a partir de `OUT_BASE_ADDR = 512`, o que limitaria o espaço útil a 128 blocos sem sobreposição. Com a escrita *in-place* em `current_block_idx * 4 + word_idx`, o sistema suporta o limite nominal de **256 blocos** ($256 \times 4 = 1024$ palavras).
2. **Isolamento de Configuração por *Snapshot* no `START`:**
   * A captura dos parâmetros (`KEY`, `IV`, `COUNTER`, `MODE`, `DECRYPT`, `NUM_BLOCKS`) no pulso de `START` desacopla a execução em andamento dos registradores mapeados via SPI.
3. **Reuso do Datapath AES-128 para `ECB`, `CBC` e `CTR`:**
   * O núcleo `minisoc_aes_top` permaneceu inalterado e altamente modular, enquanto a camada de encadeamento (`CBC`) e geração de *keystream* por contador (`CTR`) foi integrada no sequenciador de blocos do `minisoc_top.sv`.
4. **Desacoplamento CDC no Caminho de Leitura SPI:**
   * A captura de `reg_rdata_i` no domínio `sys_clk` antes do deslocamento serial em `spi_sclk` eliminou condições de corrida entre os dois domínios de clock.

## 5. Dificuldades Encontradas e Soluções Aplicadas

1. **`AES_STATUS` (`0x0C`) lido como `0x00000000` / `0x00000040` via SPI:**
   * **Causa:** Condição de carregamento dependente de `negedge spi_sclk` com `spi_cs_n == 1` e desalinhamento de 1 bit no deslocamento inicial de `tx_shift_reg`.
   * **Solução:** Latch síncrono `tx_latch_q` no domínio `clk` durante `reg_rd_en_o` e carregamento alinhado de `tx_shift_reg` com driver único.
2. **Saída `xxxxxxxx` após migração para escrita *in-place*:**
   * **Causa:** O `minisoc_top.sv` passou a gravar os resultados em `0..3` (*in-place*) e a memória deixou de ser zerada no reset, enquanto `tb_semana06_top.sv` ainda lia `512..515`.
   * **Solução:** Atualização da leitura no `tb_semana06_top.sv` para os endereços `0..3`, restaurando o `[PASS]` imediato na cifragem e decriptação FIPS-197.
3. **Divergência inicial no modo `CTR` entre RTL e Python (`got=0x9672e58b` vs. `exp=0x9dec6a5a`):**
   * **Causa:** Diferença na composição inicial de `IV` e `COUNTER` (`IV0..IV1` em `tb_semana06_blocks.sv` estava com `00010203_04050607` enquanto o script Python usava `f0f1f2f3_f4f5f6f7` como base do contador).
   * **Solução:** Padronização da formação do bloco contador `{IV[127:64], 64'd0} ^ {64'd0, COUNTER_HI, COUNTER_LO}` com incremento de 128 bits por bloco e passagem explícita do `IV` correspondente por modo no testbench.
4. **Lint do VCS (`+lint=all`):**
   * **Causa:** A ferramenta reportou apenas avisos `Lint-[NS] Null statement` referentes a atrasos isolados (`#25ns;`, `#50ns;`, etc.) no testbench `tb_semana06_blocks.sv`, sem erros nem alertas de síntese nos módulos RTL.
5. **Sincronização de branch (`git pull --rebase`) e atualização da tag:**
   * **Causa:** Avanço paralelo da branch `origin/main` e existência prévia da tag local `w06-aes-engine-mem-v1.0`.
   * **Solução:** Rebase limpo (`d3d7628..8b95c7e`), envio para `origin/main` e atualização forçada da tag anotada `w06-aes-engine-mem-v1.0` (`3887f05`).

## 6. Logs de Execução e Validação

### 6.1. Validação FIPS-197 *In-Place* (`tb/tb_semana06_top.sv`)

```text
[STEP 1] Habilitando PLL @ 50000
[PASS] PLL travado na Semana 6 @ 2125000
[STEP 2] Escrevendo chave AES-128 @ 2125000
[STEP 3] Configurando NUM_BLOCKS = 1 @ 10425000
[STEP 4] Escrevendo bloco de entrada na memoria @ 12500000
[STEP 5] Selecionando memoria para AES (0x0E = 0x0F) @ 14875000
[STEP 6] Disparando START cifragem (0x0B = 0x03) @ 16950000
[INFO] AES_STATUS final: 0x00000202
[INFO] Saida AES: 3925841d 02dc09fb dc118597 196a0b32
[PASS] Cifragem FIPS-197 validada no minisoc_top!
[STEP 7] Carregando ciphertext FIPS-197 para decriptacao @ 25800000
[INFO] Saida Decriptacao AES: 3243f6a8 885a308d 313198a2 e0370734
[PASS] Decriptacao FIPS-197 validada no minisoc_top!
$finish called from file "tb/tb_semana06_top.sv", line 204.
$finish at simulation time             39100000
```

### 6.2. Geração dos Vetores de Referência em Python (`gen_vectors_w06.py`)

```text
$ python3 gen_vectors_w06.py
Vetores de 1, 2 e 256 blocos gerados em tb/vectors_w06/ para ECB, CBC e CTR.
```

### 6.3. Validação Multi-Bloco (`1, 2 e 256 blocos`) em `ECB`, `CBC` e `CTR` + Erros (`tb/tb_semana06_blocks.sv`)

```text
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov 26 17:47 2026
[INFO] PLL travado @ 2125000
[PASS] Configuracao invalida rejeitada (NUM_BLOCKS=0): STATUS=0x00000004
[PASS] Configuracao invalida rejeitada (NUM_BLOCKS=257): STATUS=0x00000004
[PASS] Configuracao invalida rejeitada (MODE=111_RES): STATUS=0x00000004
[PASS] Configuracao invalida rejeitada (MODE=010_PCBC): STATUS=0x00000004
[PASS] ECB (DEC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] ECB (ENC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] ECB (DEC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] ECB (ENC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] ECB (DEC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[PASS] ECB (ENC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[PASS] CBC (DEC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] CBC (ENC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] CBC (DEC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] CBC (ENC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] CBC (DEC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[PASS] CBC (ENC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[PASS] CTR (DEC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] CTR (ENC) | 1 bloco(s) | STATUS=0x00000102 | BLOCKS_DONE=1
[PASS] CTR (DEC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] CTR (ENC) | 2 bloco(s) | STATUS=0x00000202 | BLOCKS_DONE=2
[PASS] CTR (DEC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[PASS] CTR (ENC) | 256 bloco(s) | STATUS=0x00000002 | BLOCKS_DONE=0
[ALL PASS] Semana 6 concluida: ECB, CBC e CTR (ENC/DEC) para 1, 2 e 256 blocos + erros validados!
$finish called from file "tb/tb_semana06_blocks.sv", line 270.
$finish at simulation time           1868625000
           V C S   S i m u l a t i o n   R e p o r t
Time: 1868625000 ps
CPU Time:      1.710 seconds;       Data structure size:   0.1Mb
```

## 7. Checklist de Aceite da Semana 6

* [x] **`minisoc_memory` (Seção 7):** Memória $1024 \times 32$, single-port síncrona, sem reset funcional e com arbitragem por `MEM_SEL_AES`.
* [x] **`minisoc_aes_top` / `minisoc_top` (Seção 8):** Captura de `KEY`, `IV`, `COUNTER`, `MODE`, `DECRYPT` e `NUM_BLOCKS` no `START` válido; leitura de 4 palavras, processamento e escrita *in-place*; atualização de `BUSY`, `DONE` (*sticky* até novo `START`), `ERROR` e `BLOCKS_DONE`.
* [x] **Modos de operação:** `ECB`, `CBC` e `CTR` validados em cifragem e decriptação; `PCBC`, `CFB` e `OFB` documentados como limitação conhecida da v1.0 (para a W10).
* [x] **Configurações inválidas:** `NUM_BLOCKS` fora de `1..256` e `MODE` reservado/não suportado sinalizam `ERROR` e encerram sem processar.
* [x] **Verificação multi-bloco e lint:** Testbench automatizado de `1`, `2` e `256` blocos por modo comparado com modelo de referência em Python (`gen_vectors_w06.py`) e compilação VCS `+lint=all` sem erros no RTL.
