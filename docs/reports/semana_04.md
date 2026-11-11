# Relatório de Progresso — Semana 4: Expansão de Chave e Datapath Completo

**Autor:** Matheus Cunha

**Data:** 11/11/2026

**Projeto:** MiniSoC AES IP Core

## 1. Resumo Executivo

Durante a Semana 4, o foco foi a integração do ecossistema criptográfico do MiniSoC AES-128. Desenvolvemos o módulo de Expansão de Chave (`minisoc_aes_key_exp.sv`), o Datapath completo combinacional (`minisoc_aes_dp.sv`), e validamos todo o sistema utilizando os vetores oficiais do NIST (FIPS-197). A simulação integrada passou com **0 erros** para os fluxos de Cifragem e Decriptação.

## 2. Implementação da Expansão de Chave (`minisoc_aes_key_exp`)

O algoritmo AES-128 exige a derivação de 11 subchaves (Round Keys, $K_0$ a $K_{10}$) a partir da chave original de 128 bits fornecida via SPI.

* **Abordagem de Hardware:** Utilizou-se um arranjo combinacional (*unroll*) em cascata com 10 instâncias do bloco `minisoc_aes_key_exp_round`.

* **Componentes:** Cada estágio aplica a rotação (`RotWord`), a substituição não-linear (`SubWord` com 4 instâncias paralelas da S-Box) e o XOR com a constante de rodada estática `Rcon` mapeada para $GF(2^8)$.

* **Verificação (`tb_semana04.sv`):** Comparado com o Apêndice A da FIPS-197, o gerador de chaves obteve **11 de 11 checks corretos**, gerando todas as 10 subchaves instantaneamente na fase de setup.

### Log de Simulação da Expansão de Chave:
```text
==> Executando Simulação...
./simv
Info: [VCS_SAVE_RESTORE_INFO] ASLR (Address Space Layout Randomization) is detected on the machine. To enable $save functionality, ASLR will be switched off and simv re-executed.
Please use '-no_save' simv switch to avoid re-execution or '-suppress=ASLR_DETECTED_INFO' to suppress this message.
Chronologic VCS simulator copyright 1991-2025
Contains Synopsys proprietary information.
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov 11 15:43 2026
[PASS] Round 0 Key: 2b7e151628aed2a6abf7158809cf4f3c
[PASS] Round 1 Key: a0fafe1788542cb123a339392a6c7605
[PASS] Round 2 Key: f2c295f27a96b9435935807a7359f67f
[PASS] Round 3 Key: 3d80477d4716fe3e1e237e446d7a883b
[PASS] Round 4 Key: ef44a541a8525b7fb671253bdb0bad00
[PASS] Round 5 Key: d4d1c6f87c839d87caf2b8bc11f915bc
[PASS] Round 6 Key: 6d88a37a110b3efddbf98641ca0093fd
[PASS] Round 7 Key: 4e54f70e5f5fc9f384a64fb24ea6dc4f
[PASS] Round 8 Key: ead27321b58dbad2312bf5607f8d292f
[PASS] Round 9 Key: ac7766f319fadc2128d12941575c006e
[PASS] Round 10 Key: d014f9a8c9ee2589e13f0cc8b6630ca6
----------------------------------------
Checks: 11  Erros: 0
KEY EXPANSION TEST PASSED
$finish called from file "tb/tb_semana04.sv", line 50.
$finish at simulation time                 10000
           V C S   S i m u l a t i o n   R e p o r t
Time: 10000 ps
CPU Time:      0.390 seconds;       Data structure size:   0.0Mb
Wed Nov 11 15:43:26 2026
```

## 3. Integração do Datapath Completo (`minisoc_aes_dp`)

O datapath unifica as transformações diretas e inversas desenvolvidas nas semanas anteriores, incorporando a lógica de controle de rota (*steering logic*) e multiplexadores discutida no documento de microarquitetura.

### 3.1 Decisões Arquiteturais Implementadas:

1. **Ciclo de Carregamento (Ciclo 0):** O `AddRoundKey` inicial ($K_0$ para cifragem, $K_{10}$ para decriptação) é executado combinacionalmente na entrada do registrador de estado, evitando a inserção de MUXes complexos de bypass no loop principal e preservando a frequência máxima ($F_{max}$) do chip.

2. **Loop Iterativo (Rodadas 1 a 9):** O fluxo executa as transformações puras da rodada por ciclo de clock.

3. **Bypass da 10ª Rodada:** Um sinal de controle gerenciado pela FSM ativa o *bypass* do módulo `MixColumns` (na cifragem) ou `InvMixColumns` (na decriptação) exatamente na última rodada, conforme estipulado pela norma FIPS-197.

## 4. Resultados de Verificação e Simulação do Datapath

O testbench de integração (`tb_semana04_dp.sv`) simulou o ciclo de vida completo de um bloco de dados sob o ecossistema do Synopsys VCS.

* **Teste de Cifragem (Cipher):**
  * *Plaintext (FIPS-197 Apêndice B):* `3243f6a8885a308d313198a2e0370734`
  * *Ciphertext Obtido:* `3925841d02dc09fbdc118597196a0b32`
  * *Status:* `[PASS] Cifragem validada! Resultado igual ao FIPS-197.`

* **Teste de Decriptação (Inverse Cipher):**
  * *Ciphertext de Entrada:* `3925841d02dc09fbdc118597196a0b32`
  * *Plaintext Recuperado:* `3243f6a8885a308d313198a2e0370734`
  * *Status:* `[PASS] Decriptacao validada! Plaintext recuperado com sucesso.`

### Log de Simulação do Datapath Completo:
```text
==> Executando Simulação...
./simv
Info: [VCS_SAVE_RESTORE_INFO] ASLR (Address Space Layout Randomization) is detected on the machine. To enable $save functionality, ASLR will be switched off and simv re-executed.
Please use '-no_save' simv switch to avoid re-execution or '-suppress=ASLR_DETECTED_INFO' to suppress this message.
Chronologic VCS simulator copyright 1991-2025
Contains Synopsys proprietary information.
Compiler version X-2025.06-SP2_Full64; Runtime version X-2025.06-SP2_Full64;  Nov 11 16:00 2026
========================================
 INICIANDO TESTE CIFRAGEM (ENCRYPTION)
========================================
[PASS] Cifragem validada! Resultado igual ao FIPS-197.

========================================
 INICIANDO TESTE DECRIPTACAO (DECRYPTION)
========================================
[PASS] Decriptacao validada! Plaintext recuperado com sucesso.
========================================

$finish called from file "tb/tb_semana04_dp.sv", line 99.
$finish at simulation time                 115000
           V C S   S i m u l a t i o n   R e p o r t
Time: 115000 ps
CPU Time:      0.380 seconds;       Data structure size:   0.0Mb
Wed Nov 11 16:00:43 2026
```

## 5. Conclusão e Próximos Passos

A conclusão bem-sucedida da Semana 4 sela o núcleo funcional do acelerador criptográfico. Para a **Semana 5**, o foco será o desenvolvimento da Máquina de Estados Finos (FSM) de topo (`minisoc_aes_top.sv`), interligando o motor AES validado aos registradores de controle e barramentos do sistema MiniSoC.
