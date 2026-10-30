# Acelerador AES com Interface SPI e Baixo Consumo

[![Language: SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![PDK: Synopsys SAED 32nm](https://img.shields.io/badge/PDK-Synopsys_SAED32nm-orange.svg)](#2-ambiente-de-desenvolvimento)
[![EDA: Synopsys Toolchain](https://img.shields.io/badge/EDA-Synopsys_VCS_%7C_DC_%7C_Formality-red.svg)](#2-ambiente-de-desenvolvimento)
[![Automation: GNU Make](https://img.shields.io/badge/Build-GNU_Make-green.svg)](#3-comandos-de-geração-e-automação)

IP digital de um acelerador de criptografia AES-128 com interface de controle SPI, barramento de dados para memória e suporte a técnicas de baixo consumo (*Low Power / UPF*). Desenvolvido no âmbito do projeto **Hands-on — RTL Design Track** (MiniSoC AES, v1.0.0).

---

## 🏗 Arquitetura do Sistema

O sistema de topo (`minisoc_top`) integra os quatro subsistemas funcionais especificados no *Block Guide*:

- **Módulo de Control & Reset**: Trata o reset assíncrono global (`rst_n`) e gerencia a sequência de inicialização determinística dos domínios do sistema.
- **PLL Mock (`minisoc_pll_mock`)**: Modelo RTL de integração do PLL que recebe referência de 2 GHz e gera o clock do sistema (`sys_clk`) com divisores `/1`, `/2`, `/4` e `/8` após o travamento (`locked`).
- **Front-End SPI (`minisoc_spi`)**: Interface SPI Slave (Modo 0, até 25 MHz) com sincronização CDC por *toggle* e banco de registradores para chave, IV, contador, modo de operação e status.
- **Núcleo AES (`minisoc_aes_top` e `minisoc_aes_dp`)**: Engine criptográfico AES-128 com microarquitetura iterativa por rodada, expansão de chave e suporte aos modos ECB, CBC, PCBC, CFB, OFB e CTR sobre 1 a 256 blocos.
- **Memória Compartilhada (`minisoc_memory`)**: Memória $1024 \times 32$ bits com multiplexação de posse (*ownership*) por exclusão mútua entre a interface externa `MEMORY DATA` e o engine AES.

---

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
