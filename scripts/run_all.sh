#!/usr/bin/env bash
# Comando unico da Semana 2:  ./scripts/run_all.sh
# Regenera o S-box, compila com VCS (fallback: iverilog) e roda o testbench.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p sim

python3 tools/gen_sbox.py rtl/minisoc_aes/minisoc_aes_sbox.sv

RTL="rtl/minisoc_aes/minisoc_aes_sbox.sv rtl/minisoc_aes/minisoc_aes_sub_bytes.sv rtl/minisoc_aes/minisoc_aes_shift_rows.sv"
TB="tb/tb_semana02.sv"

if command -v vcs >/dev/null 2>&1 || { [ -f /Tools/synopsys/snps.sh ] && source /Tools/synopsys/snps.sh && command -v vcs >/dev/null 2>&1; }; then
  echo ">> Simulando com VCS"
  vcs -full64 -sverilog -timescale=1ns/1ps $RTL $TB -o sim/simv -l sim/compile.log
  ./sim/simv -l sim/run.log
  LOG=sim/run.log
else
  echo ">> VCS indisponivel, usando iverilog"
  iverilog -g2012 -o sim/simv.vvp $RTL $TB
  vvp sim/simv.vvp | tee sim/run.log
  LOG=sim/run.log
fi

if grep -q "TEST PASSED" "$LOG"; then echo "== RESULTADO: PASS =="; else echo "== RESULTADO: FAIL =="; exit 1; fi
