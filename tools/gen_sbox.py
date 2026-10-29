#!/usr/bin/env python3
"""Gera rtl/minisoc_aes/minisoc_aes_sbox.sv a partir da matematica de GF(2^8) (FIPS-197 5.1.1)."""
import sys
def xtime(b): return ((b<<1)^0x11B) & 0xFF if b & 0x80 else (b<<1)
def gmul(a,b):
    r=0
    while b:
        if b&1: r^=a
        a=xtime(a); b>>=1
    return r
def inv(a):
    if a==0: return 0
    for x in range(1,256):
        if gmul(a,x)==1: return x
def rotl(x,n): return ((x<<n)|(x>>(8-n)))&0xFF
def sbox(a):
    b=inv(a)
    return b^rotl(b,1)^rotl(b,2)^rotl(b,3)^rotl(b,4)^0x63
S=[sbox(i) for i in range(256)]
assert S[0x00]==0x63 and S[0x53]==0xED and S[0xFF]==0x16 and S[0x01]==0x7C
assert len(set(S))==256
out=sys.argv[1]
with open(out,"w") as f:
    f.write("""// ============================================================================
// minisoc_aes_sbox.sv
// S-box do AES (FIPS-197, Fig. 7): inverso multiplicativo em GF(2^8)
// (x^8+x^4+x^3+x+1) seguido da transformacao afim. Combinacional, 8 -> 8.
// ARQUIVO GERADO por tools/gen_sbox.py -- nao editar a tabela manualmente.
// ============================================================================
module minisoc_aes_sbox (
  input  logic [7:0] data_i,
  output logic [7:0] data_o
);
  always_comb begin
    case (data_i)
""")
    for i,v in enumerate(S):
        f.write(f"      8'h{i:02x}: data_o = 8'h{v:02x};\n")
    f.write("""      default: data_o = 8'h00;
    endcase
  end
endmodule
""")
print("ok")
