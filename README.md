# Acelerador AES com Interface SPI e Baixo Consumo

[![Language: SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![PDK: Synopsys SAED 32nm](https://img.shields.io/badge/PDK-Synopsys_SAED32nm-orange.svg)](#2-ambiente-de-desenvolvimento)
[![EDA: Synopsys Toolchain](https://img.shields.io/badge/EDA-Synopsys_VCS_%7C_DC_%7C_Formality-red.svg)](#2-ambiente-de-desenvolvimento)
[![Automation: GNU Make](https://img.shields.io/badge/Build-GNU_Make-green.svg)](#3-comandos-de-geração-e-automação)

IP digital de um acelerador de criptografia AES-128 com interface de controle SPI, barramento de dados para memória e suporte a técnicas de baixo consumo (*Low Power / UPF*). Desenvolvido no âmbito do projeto **Hands-on — RTL Design Track** (MiniSoC AES, v1.0.0).

## 🏗 Arquitetura do Sistema

O sistema de topo (`minisoc_top`) integra os quatro subsistemas funcionais especificados no *Block Guide*:

- **Módulo de Control & Reset**: Trata o reset assíncrono global (`rst_n`) e gerencia a sequência de inicialização determinística dos domínios do sistema.
- **PLL Mock (`minisoc_pll_mock`)**: Modelo RTL de integração do PLL que recebe referência de 2 GHz e gera o clock do sistema (`sys_clk`) com divisores `/1`, `/2`, `/4` e `/8` após o travamento (`locked`).
- **Front-End SPI (`minisoc_spi`)**: Interface SPI Slave (Modo 0, até 25 MHz) com sincronização CDC por *toggle* e banco de registradores para chave, IV, contador, modo de operação e status.
- **Núcleo AES (`minisoc_aes_top` e `minisoc_aes_dp`)**: Engine criptográfico AES-128 com microarquitetura iterativa por rodada, expansão de chave e suporte aos modos ECB, CBC, PCBC, CFB, OFB e CTR sobre 1 a 256 blocos.
- **Memória Compartilhada (`minisoc_memory`)**: Memória $1024 \times 32$ bits com multiplexação de posse (*ownership*) por exclusão mútua entre a interface externa `MEMORY DATA` e o engine AES.

## 📂 Estrutura do Repositório

```text
.
├── README.md
├── CONTRIBUTING.md      # Guia completo de colaboração RTL <-> DV
├── Makefile             # Automação de compilação, simulação e lint
├── docs/
│   ├── spec/            # Block Guide do MiniSoC AES v1.0.0
│   ├── architecture/    # Microarquitetura v1.0 e Arquitetura de Energia
│   └── reports/         # Relatórios de entregas semanais (w01 a w13)
├── rtl/
│   ├── minisoc_aes/     # S-Box, SubBytes, ShiftRows, MixColumns, KeyExp, DP e Top
│   ├── minisoc_mem/     # Memória compartilhada 1024x32
│   ├── minisoc_pll/     # Modelo de integração do PLL
│   ├── minisoc_spi/     # Front-end SPI e banco de registradores
│   └── minisoc_top.sv   # Top-level de integração do sistema
├── tb/                  # Testbenches self-checking e vetores da FIPS-197
├── tools/               # Scripts auxiliares em Python (geradores e modelos de ref)
├── syn/                 # Arquivos SDC, scripts TCL e relatórios do Design Compiler
├── formal/              # Scripts e relatórios de equivalência formal (Formality)
└── upf/                 # Especificação de intenção de energia (UPF)
```

## 📋 Gestão do Projeto (GitHub Projects & Kanban)

O ciclo de desenvolvimento de 13 semanas é gerenciado no quadro **CI EXPERT** do GitHub Projects, aplicando a metodologia Kanban para rastreabilidade de código e integração contínua com a trilha de Design Verification (DV).

### 🔄 Colunas do Quadro Kanban:
1. **Pendente (Backlog):** Requisitos e entregáveis das semanas futuras ainda não iniciados.
2. **Em Progresso:** Atividades e módulos RTL sob desenvolvimento ativo na semana corrente.
3. **Em Review:** Releases congeladas por Git Tag oficial (`rtl-v1.0`, `rtl-v1.1`, `rtl-v2.0`) em análise e simulação de regressão pelo **verificador parceiro**.
4. **Feito:** Entregáveis auditados, com critérios de aceite atendidos e aprovados pelo instrutor.

> **Regra de Transição:** O verificador parceiro se colaborador do github possui autonomia para mover a Issue/Card da coluna **Em Review** diretamente para **Feito** assim que validar a suíte de simulação sobre a tag oficial.

### 📌 Milestones Principais:
- **M1: Architecture Freeze & Kick-off (Semanas 1 a 3):** Configuração de ambiente, especificação de microarquitetura e transformações de rodada AES.
- **M2: RTL Freeze v1.0 / Handshake DV (Semanas 4 a 7):** Datapath AES, SPI front-end, registradores, memória, PLL e primeiros modos (ECB, CBC, CTR).
- **M3: Baseline Synthesis & Formal Equivalence (Semanas 8 a 10):** Restrições SDC, síntese lógica inicial, equivalência formal no Synopsys Formality e suporte aos 6 modos (v1.1).
- **M4: Low Power RTL v2.0 & Final Release (Semanas 11 a 13):** Intenção de energia em UPF, Power Gating, Clock Gating, síntese Low Power e encerramento.

### 📑 Mapeamento Semanal de Issues (#1 a #14):
<details>
<summary>🏷️ <b>Clique para expandir o mapa semanal</b></summary>

<br/>
  
| Issue | Semana | Título da Atividade | Estado Atual | Milestone Vinculado |
| :---: | :---: | :--- | :---: | :--- |
| **#1** | **W01** | Kick-off, Estudo do Algoritmo/SPI e Ambiente Inicial | `Feito` | M1: Architecture Freeze |
| **#2** | **W02** | Desafio RTL: SubBytes, ShiftRows e S-box + Testbench | `Feito` | M1: Architecture Freeze |
| **#3** | **W03** | Microarquitetura v1.0, MixColumns, AddRoundKey e Inversas | `Em Progresso` | M1: Architecture Freeze |
| **#4** | **W04** | Expansão de Chave (Key Expansion) e Datapath AES-128 | `Pendente` | M2: RTL Freeze v1.0 |
| **#5** | **W05** | SPI Front-End, Banco de Registradores e PLL Mock | `Pendente` | M2: RTL Freeze v1.0 |
| **#6** | **W06** | AES Engine (FSM ECB/CBC/CTR) e Memória Compartilhada | `Pendente` | M2: RTL Freeze v1.0 |
| **#7** | **W07** | Integração do Top-Level (`minisoc_top`) e RTL v1.0 | `Pendente` | M2: RTL Freeze v1.0 |
| **#8** | **W08** | Síntese Lógica Inicial e Baseline de Timing/Área (SDC) | `Pendente` | M3: Baseline Synthesis & Formal |
| **#9** | **W09** | Verificação Formal de Equivalência (Synopsys Formality) | `Pendente` | M3: Baseline Synthesis & Formal |
| **#10** | **W10** | Fechamento Funcional (6 Modos AES) e Release RTL v1.1 | `Pendente` | M3: Baseline Synthesis & Formal |
| **#11** | **W11** | Arquitetura de Energia, Tabela de Estados e UPF | `Pendente` | M4: Low Power RTL v2.0 |
| **#12** | **W12** | Técnicas de Baixo Consumo (Power Gating / Clock Gating) | `Pendente` | M4: Low Power RTL v2.0 |
| **#14** | **W13** | Síntese Low Power, Comparação com Baseline e Encerramento | `Pendente` | M4: Low Power RTL v2.0 |

</details>

### 🏷️ Mapeamento de Git Tags, Releases e Handshake DV

Para garantir a estabilidade do ambiente de verificação, as entregas de código utilizam o mecanismo de **tags estáticas congeladas**.

<details>
<summary>🏷️ <b>Clique para expandir a tabela completa de Tags e Releases</b></summary>

<br/>

> 💡 **Mapeamento Duplo de Tags:** Nas semanas marcadas com (**W07**, **W10** e **W12**), o commit de entrega possui **duas tags equivalentes** (a tag interna do projeto e a tag oficial esperada pela equipe de DV).

| Semana | Data Entrega | Foco do Entregável | Tag Semanal (RTL) | Tag Oficial DV | Release / Milestone GitHub |
| :---: | :---: | :--- | :--- | :---: | :--- |
| **W01** | 23/10/2026 | Ambiente configurado, scripts e relatório inicial | `w01-environment-v1.0` | — | — |
| **W02** | 30/10/2026 | SubBytes, ShiftRows, S-box e testbench FIPS-197 | `w02-subbytes-shiftrows-v1.0` | — | — |
| **W03** | 06/11/2026 | Documento de microarquitetura e MixColumns/Inversas | `w03-architecture-v1.0` | — | `W01-W03: Environment & Architecture Freeze` |
| **W04** | 13/11/2026 | Key Expansion e Datapath AES-128 (`minisoc_aes_dp`) | `w04-keyexp-datapath-v1.0` | — | — |
| **W05** | 20/11/2026 | SPI Slave (Modo 0), registradores e PLL mock | `w05-spi-pll-v1.0` | — | — |
| **W06** | 27/11/2026 | AES Engine (`minisoc_aes_top`) e Memória 1024x32 | `w06-aes-engine-mem-v1.0` | — | — |
| **W07** | 04/12/2026 | **Top-level integrado (`minisoc_top`) — RTL v1.0** | `w07-rtl-v1.0` |  **`rtl-v1.0`** | `W07: RTL v1.0 (First Handshake DV)` |
| **W08** | 11/12/2026 | Restrições SDC, síntese lógica e relatório baseline | `w08-synthesis-baseline-v1.0` | — | — |
| **W09** | 18/12/2026 | Fluxo no Formality e verificação de equivalência | `w09-formal-v1.0` | — | — |
| **—** | **Recesso** | *21/12/2026 a 03/01/2027 — Sem entregas* | — | — | — |
| **W10** | 08/01/2027 | **Suporte aos 6 modos AES e correções — RTL v1.1** | `w10-rtl-v1.1` |  **`rtl-v1.1`** | `W10: RTL v1.1 (Functional Freeze)` |
| **W11** | 15/01/2027 | Arquitetura de energia, UPF e simulação power-aware | `w11-upf-power-arch-v1.0` | — | — |
| **W12** | 22/01/2027 | **Power gating, ICG clock gating — RTL v2.0** | `w12-rtl-v2.0` |  **`rtl-v2.0`** | — |
| **W13** | 29/01/2027 | **Síntese Low Power final, relatórios e apresentação** | `w13-final-release-v2.0` | — | `W13: RTL v2.0 (Final Low Power IP Release)` |

</details>

## 🚀 Como Executar (Ferramental Synopsys EDA)

O ambiente foi configurado para execução nativa com as ferramentas da **Synopsys** via terminal ou automação pelo `Makefile`.

### Requisitos de Ambiente:
- **Synopsys VCS**: Compilação e simulação de SystemVerilog.
- **Synopsys Verdi**: Visualização e debug de formas de onda (.fsdb).
- **Synopsys SpyGlass**: Análise estática de RTL (Linting).
- **Synopsys Design Compiler (DC)**: Síntese lógica e otimização.
- **Synopsys Formality**: Verificação formal de equivalência RTL $\times$ Netlist.

### Comandos do Makefile:

```bash
# Compilar e executar a simulação autoverificável com Synopsys VCS
make sim

# Executar análise estática de código (Lint) via Synopsys SpyGlass
make lint

# Abrir as formas de onda da simulação (.fsdb) na interface gráfica do Synopsys Verdi
make wave

# Limpar arquivos temporários de compilação, diretórios e logs (simv, csrc, verdiLog)
make clean
```


## 📦 Regras para os Entregáveis Semanais

Para garantir o atendimento aos critérios de aceite do projeto:
1. **Relatório Técnico:** Todas as entregas possuem um relatório detalhado gravado em `docs/reports/semana_XX.md` com metodologia, resultados, logs do VCS e dúvidas/ambiguidades do *Block Guide*.
2. **Reprodutibilidade:** Toda entrega pode ser validada em ambiente limpo executando um único comando (`make sim` ou `./scripts/run_all.sh`).
3. **Qualidade RTL:** Todo código deve ser aprovado em *linting* sem erros.
4. **Interação DV:** Defeitos reportados pelo verificador parceiro são acompanhados através da aba **Issues** e resolvidos em correções vinculadas a novas tags.

Para maiores detalhes sobre a interface de integração com a equipe de verificação e fluxo de bugs, consulte o arquivo **[CONTRIBUTING.md](CONTRIBUTING.md)**.
