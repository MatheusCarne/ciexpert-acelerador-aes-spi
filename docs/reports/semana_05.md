# Relatório Técnico de Desenvolvimento - Semana 5

**Projeto:** Acelerador Criptográfico MiniSoC AES-128 (RTL/DV Track)  
**Marco:** Semana 5 — Interface SPI, PLL Mock, FSM de Topo e Banco de Registradores  
**Autor:** Matheus Carneiro da Cunha  
**Programa CI-Expert**  

## 1. Visão Geral da Semana 5

A **Semana 5** teve como foco principal a integração do núcleo criptográfico AES-128 (validado nas semanas anteriores) com a infraestrutura de controle do sistema SoC. Isso abrangeu o desenvolvimento da Máquina de Estados (FSM) de topo, o modelo comportamental de clock (PLL Mock), a interface de barramento serial SPI Mode 0 de 40 bits com sincronização de clock por *toggle* (CDC), e o gerenciamento do banco de registradores mapeados.

## 2. Componentes Desenvolvidos e Arquitetura RTL

### 2.1. FSM de Controle e Top-Level do AES (`minisoc_aes_top.sv`)
O topo do núcleo criptográfico unifica o datapath iterativo (`minisoc_aes_dp`) e a expansão de chaves combinacional (`minisoc_aes_key_exp`) sob o controle de uma FSM síncrona de 5 estados:
* `IDLE`: Aguarda o pulso de disparo (`start_i`).
* `LOAD_CYCLE`: Ciclo 0, executando o `AddRoundKey` inicial com a chave primária ($K_0$ para cifragem, $K_{10}$ para decriptação).
* `ROUND_LOOP`: Executa iterativamente as rodadas de 1 a 9, chaveando dinamicamente os índices conforme o modo (`enc_dec_i`).
* `FINAL_ROUND`: Executa a 10ª rodada aplicando o *bypass* do bloco `(Inv)MixColumns`.
* `DONE`: Sinaliza a conclusão do bloco processado por um ciclo de clock (`done_o`).

### 2.2. Modelo de Integração do PLL (`minisoc_pll_mock.sv`)
Implementou-se um modelo comportamental flexível para simular a geração de clock do sistema a partir de uma referência de $2\text{ GHz}$:
* **Entradas:** `clkin`, `rst_n`, `enable`, `pll_div_sel` (`2'b00` para $/1$, `2'b01` para $/2$, `2'b10` para $/4$, `2'b11` para $/8$).
* **Saídas:** `clkout` (clock em nível baixo quando desabilitado ou destravado) e `locked` (sinal assinalado após contagem do atraso de estabilização pseudoaleatório).

### 2.3. Front-End SPI e Banco de Registradores (`minisoc_spi.sv`)
* **Protocolo:** SPI Mode 0 (MOSI amostrado na borda de subida e MISO atualizado na borda de descida de `spi_sclk`), em padrão **MSB-first** com frames de **40 bits** estruturados em `RWb` (1 bit), `ADDR[5:0]` (6 bits), `RSV` (1 bit reservado) e `DATA[31:0]` (32 bits).
* **Transações:** Suporte a escrita em transação única e leitura em duas fases (onde a segunda fase envia o comando NOP `0x3F` para recolher o dado deslocado no registrador de transmissão).
* **CDC por Toggle:** Recepção serial operando no domínio de `spi_sclk` e barramento interno síncrono ao clock do sistema (`clk`), garantindo cruzamento seguro de domínios assíncronos.
* **Banco de Registradores (Seção 6):** Cobertura completa de `KEY0–3`, `IV0–3`, `COUNTER_HI/LO`, `NUM_BLOCKS`, `AES_CONTROL` (com pulso *write-one-pulse* para start), `AES_STATUS`, `VERSION`, `SYSTEM_CONTROL` e `SYSTEM_STATUS`.

## 3. Validação e Testbenches

Dois ambientes de simulação dirigidos foram implementados e executados com o **Synopsys VCS**:
1. **`tb/tb_semana05.sv`:** Validou a FSM de controle do AES utilizando os vetores oficiais do NIST FIPS-197 para cifragem e decriptação completas.
2. **`tb/tb_semana05_spi.sv`:** Validou com sucesso:
   * O travamento do PLL (PLL_LOCKED = 1) em todos os quatro divisores ($/1$, $/2$, $/4$, $/8$).
   * As operações de escrita e leitura SPI em todos os registradores R/W (`KEY0`, `KEY1`, `NUM_BLOCKS`, etc.).
   * A proteção rigorosa dos registradores *Read-Only* (`VERSION`), impedindo alterações indevidas via barramento.

## 4. Dificuldades Encontradas e Soluções Aplicadas

Durante o processo de integração e simulação no Synopsys VCS, alguns desafios técnicos foram identificados e resolvidos:

### 4.1. Desincronização de Subchaves na FSM de Topo
* **Problema:** Na primeira versão da FSM, o estado `FINAL_ROUND` disparava na contagem 9, fazendo com que a 10ª rodada utilizasse a subchave incorreta (`round_keys[9]` em vez de `round_keys[10]`).
* **Solução:** Ajustou-se a lógica de transição para incrementar o contador até a rodada 10 exata e corrigiu-se a indexação condicional no bloco combinacional de seleção de chaves (`round_keys[10 - round_cnt_q]` para o modo de decriptação).

### 4.2. Conflito de Múltiplos Drivers Procedurais (`Error-[ICPD]`)
* **Problema:** O compilador VCS reportou o erro `Error-[ICPD]` indicando que a variável `frame_toggle_spi` estava sendo escrita em múltiplos blocos `always_ff`.
* **Solução:** Unificou-se a lógica de contagem de bits e inversão do toggle no mesmo bloco sequencial sensível ao `spi_sclk`, eliminando o conflito estrutural.

### 4.3. Ordem de Declaração de Variáveis Locais em SystemVerilog (`Error-[SE]`)
* **Problema:** O compilador gerou erro de sintaxe ao encontrar a declaração da variável local `logic [31:0] rval;` após comandos executáveis dentro do bloco `initial`.
* **Solução:** Reposicionou-se a declaração da variável estritamente no topo do bloco procedural, conforme exigido pelo padrão rigoroso do SystemVerilog.

## 5. Conclusão e Critérios de Aceite

Todos os critérios de aceite da **Semana 5** foram atingidos com **100% de sucesso**:
* ✅ Registradores R/W escritos e lidos com exatidão via protocolo SPI.
* ✅ Registradores *Read-Only* mantidos inalterados após tentativas de escrita.
* ✅ PLL Mock travando perfeitamente nos quatro divisores ($/1$, $/2$, $/4$, $/8$).
* ✅ Compilação limpa no Synopsys VCS, sem erros ou avisos críticos.
