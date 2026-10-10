# Acelerador AES com Interface SPI e Baixo Consumo

IP digital de um acelerador de criptografia AES-128 com interface de controle SPI, barramento de dados para memória e suporte a técnicas de baixo consumo (*Low Power / UPF*). Desenvolvido no âmbito do projeto *Hands-on — RTL Design Track*.

---

## 🏗 Arquitetura do Sistema

O sistema de topo (`AES TOP-LEVEL SYSTEM`) integra os seguintes subsistemas principais:

- **Módulo de RESET**: Trata o reset assíncrono global e distribui os resets sincronizados para os domínios de clock.
- **PLL (Mock)**: Gerador comportamental de clock do sistema com sinal `locked`.
- **Interface SPI (Slave)**: Recebe comandos, chave de criptografia, dados e bitfields de configuração/status operando no domínio `SCLK`.
- **Núcleo AES**: Datapath de criptografia AES-128 com microarquitetura iterativa por rodada, otimizado para redução de área e consumo.
- **Memory / Data System**: Subsistema responsável por intermediar a leitura e escrita de blocos de dados entre a memória e o acelerador AES.

---

## 🚀 Como Executar (Ambiente Synopsys)

Certifique-se de que os módulos e variáveis de ambiente das ferramentas Synopsys (**VCS**, **Verdi**, **SpyGlass**) estejam carregados no terminal.

### Compilação e Simulação Mínima
Para checar o ambiente e rodar o fluxo completo em um único comando:
```bash
make
