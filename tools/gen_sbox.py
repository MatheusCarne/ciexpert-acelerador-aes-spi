#!/usr/bin/env python3
#O script tools/gen_sbox.py tem uma única responsabilidade: gerar o mapeamento estático byte a byte para as tabelas 
#minisoc_aes_sbox.sv e minisoc_aes_inv_sbox.sv baseando-se na matemática de $GF(2^8)$.
"""Gera minisoc_aes_sbox.sv e minisoc_aes_inv_sbox.sv a partir da matemática de GF(2^8)."""
import os, sys

def xtime(b):
    return ((b << 1) ^ 0x11B) & 0xFF if b & 0x80 else (b << 1)

def gmul(a, b):
    r = 0
    while b:
        if b & 1: r ^= a
        a = xtime(a); b >>= 1
    return r

def inv(a):
    if a == 0: return 0
    for x in range(1, 256):
        if gmul(a, x) == 1: return x

def rotl(x, n):
    return ((x << n) | (x >> (8 - n))) & 0xFF

def sbox(a):
    b = inv(a)
    return b ^ rotl(b, 1) ^ rotl(b, 2) ^ rotl(b, 3) ^ rotl(b, 4) ^ 0x63

# Calcula S-box e S-box Inversa
S = [sbox(i) for i in range(256)]
InvS = [0] * 256
for i in range(256):
    InvS[S[i]] = i

out_dir = sys.argv[1] if len(sys.argv) > 1 else "rtl/minisoc_aes"

# 1. Escreve minisoc_aes_sbox.sv
with open(os.path.join(out_dir, "minisoc_aes_sbox.sv"), "w") as f:
    f.write("""// ============================================================================
// minisoc_aes_sbox.sv -- S-box direta do AES (FIPS-197)
// ============================================================================
module minisoc_aes_sbox (
  input  logic [7:0] data_i,
  output logic [7:0] data_o
);
  always_comb begin
    case (data_i)
""")
    for i, v in enumerate(S):
        f.write(f"      8'h{i:02x}: data_o = 8'h{v:02x};\n")
    f.write("""      default: data_o = 8'h00;
    endcase
  end
endmodule
""")

# 2. Escreve minisoc_aes_inv_sbox.sv
with open(os.path.join(out_dir, "minisoc_aes_inv_sbox.sv"), "w") as f:
    f.write("""// ============================================================================
// minisoc_aes_inv_sbox.sv -- S-box inversa do AES (FIPS-197)
// ============================================================================
module minisoc_aes_inv_sbox (
  input  logic [7:0] data_i,
  output logic [7:0] data_o
);
  always_comb begin
    case (data_i)
""")
    for i, v in enumerate(InvS):
        f.write(f"      8'h{i:02x}: data_o = 8'h{v:02x};\n")
    f.write("""      default: data_o = 8'h00;
    endcase
  end
endmodule
""")

print("S-Box e InvS-Box geradas com sucesso.")
