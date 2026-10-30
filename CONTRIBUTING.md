# Guia de Contribuição e Interação RTL <-> DV

Bem-vindo ao repositório do **IP Acelerador AES-128 (MiniSoC AES)**. Este documento estabelece as diretrizes de cooperação e integração entre o desenvolvimento RTL e a equipe de Design Verification (DV).



## 📌 Regras de Acesso e Entregas (Handshake via Tags)

1. **Acesso Exclusivo por Tags Congeladas:** A verificação funcional deve ser executada exclusivamente sobre as **Git Tags oficiais** do projeto. Não execute simulações de regressão sobre commits intermediários da branch `main`.
2. **Duplicidade de Tags para Mapeamento:** Para manter o histórico semanal organizado e atender à especificação de DV, os commits de entrega contêm **duas tags equivalentes**:
   - **Tag Interna/Semanal:** `w07-top-integration-v1.0`, `w10-all-modes-v1.1`, `w12-low-power-v2.0`
   - **Tag Oficial DV (Checkout de Verificação):** `rtl-v1.0`, `rtl-v1.1`, `rtl-v2.0`
   > *Nota:* Você pode usar o comando `git checkout rtl-v1.0` diretamente.
3. **Ambiente Reprodutível:** O ambiente de simulação utiliza **Synopsys VCS** e **Verdi**. Para compilar e rodar a simulação a partir da raiz, utilize:
   ```bash
   make sim


## 🐛 Fluxo de Reporte e Resolução de Bugs

Ao identificar divergências funcionais, violações de timing, violações de protocolo SPI ou erros de checagem:

1. **Abertura de Issue:** Acesse a aba **Issues** $\rightarrow$ **New Issue** e selecione o template **🐛 Bug Report (RTL / DV)**.
2. **Evidências:** Inclua a Tag testada, o comando de execução, os logs do VCS e a referência do sinal no Verdi/FSDB.
3. **Classificação pelo RTL Designer:**
   - **Defeito no RTL:** O erro é corrigido na branch local e uma nova tag de patch é gerada.
   - **Defeito no Ambiente DV:** O cenário é comunicado na Issue para ajuste no Testbench.
   - **Ambiguidade na Spec:** O ponto é documentado e levado ao instrutor/orientador.

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

## 🏷️ Padrão de Commit para Rastreabilidade

Ao submeter correções ou interagir no repositório, faça referência à Issue correspondente na mensagem do commit:

```bash
git commit -m "fix(aes_dp): corrige ordem dos bytes no ShiftRows"

