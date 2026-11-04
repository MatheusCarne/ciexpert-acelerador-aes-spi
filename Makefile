# ============================================================================
# Makefile -- Fluxo de Simulação e Compilação Synopsys (VCS / Verdi / SpyGlass)
# ============================================================================

# Diretórios
RTL_DIRS := rtl/minisoc_aes rtl/minisoc_mem rtl/minisoc_pll rtl/minisoc_spi rtl
TB_DIR   := tb

# Busca todos os arquivos RTL (exclui dummy_top se os módulos reais existirem)
RTL_SRCS := $(wildcard rtl/minisoc_aes/*.sv) \
            $(wildcard rtl/minisoc_mem/*.sv) \
            $(wildcard rtl/minisoc_pll/*.sv) \
            $(wildcard rtl/minisoc_spi/*.sv) \
            $(wildcard rtl/*.sv)

# Testbench padrão (pode ser sobrescrito: make sim TB=tb/tb_semana03.sv)
TB ?= tb/tb_semana03.sv

# Flags de Compilação VCS
VCS_FLAGS := -sverilog -full64 -kdb -debug_access+all \
             +incdir+rtl/minisoc_aes \
             -timescale=1ns/1ps

# Target Padrão
.PHONY: all sim wave lint clean

all: sim

# Compilação e Simulação VCS
sim:
	@echo "==> Gerando S-Boxes..."
	python3 tools/gen_sbox.py rtl/minisoc_aes
	@echo "==> Compilando com Synopsys VCS..."
	vcs $(VCS_FLAGS) $(RTL_SRCS) $(TB) -o simv
	@echo "==> Executando Simulação..."
	./simv

# Visualização no Verdi
wave:
	verdi -ssf nova.fsdb &

# Análise Estática com SpyGlass
lint:
	spyglass -project spyglass.prj -batch &

# Limpeza de artefatos
clean:
	rm -rf simv* csrc verdiLog ucli.key DVEfiles *.fsdb *.vdb spyglass_reports
