# Guia de Contribuição e Interação RTL <-> DV

Bem-vindo ao repositório do **IP Acelerador AES-128 (MiniSoC AES)**. Este documento estabelece as diretrizes de cooperação e integração entre o desenvolvimento RTL e a equipe de Design Verification (DV).

## 📌 Regras de Acesso e Entregas (Handshake via Tags)

1. **Acesso Exclusivo por Tags Congeladas:** A verificação funcional e a regressão devem ser executadas exclusivamente sobre as **Git Tags oficiais** do projeto. Não execute testes de aceitação sobre commits intermediários da branch `main`.
2. **Duplicidade de Tags para Mapeamento:** Para manter o histórico semanal e atender à especificação de DV, os commits de entrega contêm **duas tags equivalentes**:
   - **Tag Interna/Semanal:** `w07-top-integration-v1.0`, `w10-all-modes-v1.1`, `w12-low-power-v2.0`
   - **Tag Oficial DV (Checkout de Verificação):** `rtl-v1.0`, `rtl-v1.1`, `rtl-v2.0`
   > *Semanas e Git Tags no fim do arquivo*
3. **Ambiente Reprodutível (Synopsys VCS & Verdi):**
   - Compilação e simulação padrão: `make sim`
   - Abertura de formas de onda no Verdi: `make wave`
   - Limpeza de artefatos temporários: `make clean`

## 📥 Como o Verificador Parceiro Acessa o Código Congelado

O verificador parceiro pode obter a versão exata do IP de duas formas:

#### Opção A: Via Terminal Git (Recomendado para Simulação)
No repositório clonado localmente, atualize as tags e faça o *checkout* da versão pretendida:
```bash
# 1. Atualiza todas as tags do repositório remoto
git fetch --tags

# 2. Alterna para o estado estático da release de verificação
git checkout rtl-v1.0
```
*Nota:* Isso garante que a árvore de arquivos fique posicionada no commit exato da entrega, pronta para executar os scripts de simulação via `make sim` no ambiente Synopsys VCS sem alterar o código RTL.

#### Opção B: Via Interface Web do GitHub (Releases / Tags)
1. Acesse a aba **Releases** ou **Tags** na página principal do repositório.
2. Localize a release desejada (ex.: `W07: RTL v1.0 (First Handshake DV)`).
3. Faça o download do pacote estático em `.zip` ou `.tar.gz`, ou inspecione a árvore de arquivos diretamente na interface.

## 🐛 Fluxo de Reporte e Resolução de Bugs

Ao identificar divergências funcionais, violações de timing, violações de protocolo SPI ou erros de checagem:

1. **Abertura de Issue:** Acesse a aba **Issues** $\rightarrow$ **New Issue** e selecione o template **🐛 Bug Report (RTL / DV)**.
2. **Evidências Obrigatórias:**
   - Tag testada (ex: `rtl-v1.0`).
   - Semente randômica (*seed*) e comando exato para reprodução.
   - Arquivo de log da simulação e referência de forma de onda no Verdi (`.fsdb`).
3. **Classificação da Issue (feita pelo RTL Designer):**
   - **Defeito no RTL:** Erro corrigido na branch de desenvolvimento; nova tag de correção gerada (ex: `rtl-v1.0.1`).
   - **Defeito no Ambiente DV:** Ajuste de VIP ou Testbench alinhado diretamente na Issue.
   - **Ambiguidade na Espec:** Submetido ao instrutor/orientador para esclarecimento.

## 🛠️ Especificação de Topo e Modelos de Integração

Para garantir o reaproveitamento dos seus VIPs e do ambiente de teste, o top-level segue rigorosamente o **Block Guide – MiniSoC AES (v1.0.0)**:

- **Interfaces de Topo:** Sinais e temporizações idênticos para `CLK`, `RESET`, `SPI` e `MEMORY DATA`.
- **Módulos Auxiliares:** As versões de `minisoc_pll_mock` e `minisoc_memory` incluídas neste repositório servem para validação standalone e possuem as mesmas interfaces da trilha de DV. Elas podem ser substituídas pelas suas macros/VIPs durante os testes de integração.

---

## 🗺️ Roadmap de Funcionalidades por Tag

| Tag Oficial DV | Data de Entrega | Funcionalidades Incluídas | Limitações Conhecidas |
| :--- | :---: | :--- | :--- |
| **`rtl-v1.0`** | 04/12/2026 | Top-level integrado (`minisoc_top`), SPI Slave (Modo 0), registradores e **modos ECB, CBC e CTR**. | Modos PCBC, CFB e OFB desabilitados. |
| **`rtl-v1.1`** | 08/01/2027 | Suporte completo aos **6 modos** (ECB, CBC, CTR, PCBC, CFB, OFB) e correções da v1.0. | Funcionalidade completa sem Low Power. |
| **`rtl-v2.0`** | 22/01/2027 | Arquitetura Low Power (Power Gating / UPF / Clock Gating) para regressão funcional. | Foco em regressão (o teste de UPF é feito em RTL). |

## 📋 Acompanhamento de Tarefas via GitHub Projects

O desenvolvimento do **MiniSoC AES** utiliza o **GitHub Projects** (Quadro Kanban) para a gestão do backlog e acompanhamento do progresso das 13 semanas.

### 🔄 Colunas do Quadro (Board)
As tarefas e entregáveis estão organizados nas quatro colunas oficiais do quadro:

1. **Pendente:** Tarefas e entregáveis que ainda não foram iniciados (backlog do projeto).
2. **Em Progresso:** Módulos RTL, testbenches ou documentos em desenvolvimento ativo.
3. **Em Review:** Entregas congeladas em tag oficial (ex.: `rtl-v1.0`) que estão sob análise e simulação de regressão do **verificador parceiro**.
4. **Feito:** Tarefas e entregáveis com critérios de aceite atendidos e verificados.

> 🤝 **Autonomia do Verificador Parceiro:** Assim que o verificador concluir a suíte de testes de simulação e regressão sobre uma tag de entrega (ex.: `rtl-v1.0`, `rtl-v1.1`), ele mesmo deve mover a respectiva Issue/Card da coluna **Em Review** diretamente para **Feito**, ou voltar para **Em Progresso** relatando o bug.

---

### 🎯 Vinculação por Milestones (Marcos do Projeto)

Todas as **Issues** do quadro estão vinculadas aos quatro marcos principais do repositório:

- 📌 **M1: Architecture Freeze & Kick-off (Semanas 1 a 3):** Ambiente, microarquitetura v1.0 e transformações de rodada.
- 📌 **M2: RTL Freeze v1.0 / Handshake DV (Semanas 4 a 7):** Datapath, SPI, PLL, registradores e modos ECB, CBC e CTR.
- 📌 **M3: Baseline Synthesis & Formal Equivalence (Semanas 8 a 10):** Restrições SDC, síntese lógica, equivalência formal (Formality) e fechamento dos 6 modos (v1.1).
- 📌 **M4: Low Power RTL v2.0 & Final Release (Semanas 11 a 13):** Arquitetura UPF, Power Gating, Clock Gating e encerramento final.

---

### 🏷️ Labels para Classificação

- `feature`: Novas funcionalidades ou módulos RTL em desenvolvimento.
- `bug`: Defeitos funcionais, erros de protocolo SPI ou falhas de simulação.
- `rtl`: Alterações e códigos no diretório `rtl/`.
- `architecture` / `documentation`: Documentos de microarquitetura e relatórios semanais.
- `synthesis/eda`: Scripts Tcl, arquivos SDC, síntese (Design Compiler) e Formality.
- `low-power`: Implementações UPF, power gating e clock gating.

## 🏷️ Padrão de Commit para Rastreabilidade

Utilize commits semânticos vinculando as alterações à Issue correspondente:

`git commit -m "fix(spi): corrige atraso de amostragem no frame de leitura (closes #12)"`

---
<details>
<summary>🏷️ <b>Mapeamento Completo de Git Tags por Semana e Handshake DV</b> (Clique para expandir)</summary>

<br/>

> 💡 **Nota de Integração:** Nas Semanas **7**, **10** e **12**, **terá duas tags no mesmo commit**: a tag semanal do repositório RTL e a tag padrão esperada pelo verificador parceiro (`rtl-v1.0`, `rtl-v1.1`, `rtl-v2.0`).

| Semana | Foco / Descrição do Entregável | Tag Semanal (RTL) | Tag Oficial DV (Handshake) | Release / Milestone GitHub |
| :---: | :--- | :--- | :--- | :--- |
| **W01** | Kick-off, estudo e ambiente de simulação | `w01-environment-v1.0` | — | — |
| **W02** | SubBytes, ShiftRows e S-box + testbench | `w02-subbytes-shiftrows-v1.0` | — | — |
| **W03** | Microarquitetura, MixColumns e transformações inversas | `w03-architecture-v1.0` | — | `W01-W03: Environment & Architecture Freeze` |
| **W04** | Expansão de chave e datapath AES-128 | `w04-keyexp-datapath-v1.0` | — | — |
| **W05** | SPI front-end, registradores e PLL mock | `w05-spi-pll-v1.0` | — | — |
| **W06** | AES engine (ECB, CBC, CTR) e memória compartilhada | `w06-aes-engine-mem-v1.0` | — | — |
| **W07** | **Top-level integrado e RTL v1.0** | `w07-rtl-v1.0` |  **`rtl-v1.0`** | `W04-W07: RTL v1.0 (First Handshake DV)` |
| **W08** | Síntese inicial e baseline SDC | `w08-synthesis-baseline-v1.0` | — | — |
| **W09** | Verificação formal de equivalência (Formality) | `w09-formal-v1.0` | — | — |
| **W10** | **Fechamento funcional (6 modos) e RTL v1.1** | `w10-rtl-v1.1` |  **`rtl-v1.1`** | `W08-W10: RTL v1.1 (Functional Freeze)` |
| **W11** | Arquitetura de energia e UPF | `w11-upf-power-arch-v1.0` | — | — |
| **W12** | **Power Gating, Clock Gating e RTL v2.0** | `w12-rtl-v2.0` |  **`rtl-v2.0`** | — |
| **W13** | Síntese Low Power e apresentação final | `w13-final-release-v2.0` | — | `W11-W13: RTL v2.0 (Final Low Power IP Release)` |

