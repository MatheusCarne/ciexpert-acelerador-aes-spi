# ==============================================================================
# Makefile - Projeto Acelerador AES (Trilha RTL - Ambiente Synopsys)
# ==============================================================================

# Altera o caractere de indentacao das regras de TAB para '>'
.RECIPEPREFIX = >

RTL_DIR   := rtl
TB_DIR    := tb
SIM_DIR   := sim_build
REPORTS   := docs/reports

RTL_SRCS  := $(wildcard $(RTL_DIR)/*.sv) $(wildcard $(RTL_DIR)/*.v)
TB_SRCS   := $(wildcard $(TB_DIR)/*.sv) $(wildcard $(TB_DIR)/*.v)

VCS       := vcs
VERDI     := verdi
SPYGLASS  := spyglass

VCS_FLAGS := -sverilog -kdb -debug_access+all -full64 \
             +incdir+$(RTL_DIR) \
             -l $(SIM_DIR)/compile.log

.PHONY: all help check_env lint sim wave clean

all: check_env sim

check_env:
> @mkdir -p $(RTL_DIR) $(TB_DIR) $(SIM_DIR) $(REPORTS)

sim: check_env
> @echo "==> Compilando com Synopsys VCS..."
> $(VCS) $(VCS_FLAGS) $(RTL_SRCS) $(TB_SRCS) -o $(SIM_DIR)/simv
> @echo "==> Executando Simulação..."
> $(SIM_DIR)/simv -l $(SIM_DIR)/simulation.log

clean:
> @echo "==> Limpando artefatos de compilação..."
> rm -rf $(SIM_DIR) csrc simv.daidir ucli.key vc_hdrs.h verdiLog novas* *.fsdb *.log
> @echo "Limpeza concluída."
