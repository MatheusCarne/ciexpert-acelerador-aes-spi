# Relatório Semanal — Semana 01
**Projeto:** Acelerador AES com Interface SPI e Baixo Consumo (Trilha RTL)  
**Aluno:** Matheus Cunha  
**Tag do Entregável:** `w01-environment-v1.0`

---

## 1. Visão Geral e Atividades Executadas

Nesta primeira semana, o foco esteve focado no kick-off do projeto, no estudo dos fundamentos teóricos essenciais, na estruturação do repositório Git e na automação do ambiente de execução/compilação.

### Atividades Realizadas:
1. **Estruturação do Repositório:** Criação da árvore estipulada de diretórios (`rtl/`, `tb/`, `models/`, `docs/`, `syn/`, `formal/`, `upf/`, `scripts/`) e configuração do arquivo de filtros `.gitignore`.
2. **Automação de Ambiente (One-Command Flow):** Construção de um `Makefile` configurado especificamente para o stack de ferramentas Synopsys (**VCS**, **Verdi** e **SpyGlass**) disponíveis no servidor.
3. **Validação do Fluxo Mínimo:** Implementação de um esqueleto RTL (`rtl/dummy_top.sv`) e de um testbench inicial (`tb/tb_dummy_top.sv`) para verificar a compilação e a simulação via **Synopsys VCS**.
4. **Estudo Teórico:** Leitura e análise dos conceitos do algoritmo AES (FIPS-197), do protocolo SPI, de travessia de domínio de clock (CDC) e da arquitetura do sistema de topo (`AES TOP-LEVEL SYSTEM`).
5. **Gestão do Projeto:** Criação do backlog completo de 15 semanas e mapeamento das *Issues* no GitHub Projects.

---

## 2. Resumo dos Estudos Teóricos (Fase de Especificação)

### A. Algoritmo AES-128 (FIPS-197)
O Advanced Encryption Standard (AES) é um algoritmo de criptografia simétrica por blocos que opera em matrizes de estado (*State*) de $4 \times 4$ bytes (128 bits). O AES-128 processa os dados através de 10 rodadas de transformação:
- **SubBytes:** Substituição não-linear de bytes via tabela de S-Box.
- **ShiftRows:** Transposição circular das linhas da matriz de estado.
- **MixColumns:** Multiplicação matricial no Campo de Galois $GF(2^8)$ sobre cada coluna.
- **AddRoundKey:** Operação XOR entre o *State* e a *Round Key*.
- **Expansão de Chave (*Key Expansion*):** Geração on-the-fly das chaves de rodada a partir da chave original de 128 bits.
- **Decisão Arquitetural:** Para atender ao requisito de **baixo consumo e menor área**, foi definida uma microarquitetura **iterativa** (uma única rodada física reutilizada sequencialmente via FSM em 10 ciclos).

### B. Protocolo SPI (Serial Peripheral Interface)
Protocolo de comunicação serial síncrono full-duplex. No contexto deste IP:
- Opera no domínio do clock externo **SCLK**.
- Utiliza um registrador de deslocamento (*Shift Register*) e contadores de bit/byte para recepção de comandos, chave, dados e registradores de controle/status no banco interno.

### C. Travessia de Domínio de Clock (CDC)
O sistema opera com dois domínios assíncronos principais: **SCLK** (SPI) e **sys_clk** (gerado pelo PLL). 
- **Estratégia:** Para evitar o fenômeno da metastabilidade, serão empregados sincronizadores de 2 estágios (*Double-Flop Synchronizer*) para sinais de controle/reset e sincronizadores apropriados para barramentos de dados entre domínios.

---

## 3. Resultados Obtidos e Validação

A automação do ambiente foi testada diretamente no terminal do servidor via comando `make`. 

### Log de Sucesso da Simulação (Synopsys VCS):
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
