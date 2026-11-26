#!/usr/bin/env python3
"""
Gera vetores de referencia da Semana 6 para o MiniSoC AES:
- Modos: ECB (000), CBC (001), CTR (101) em cifragem e decriptacao
- Tamanhos: 1, 2 e 256 blocos (128 bits por bloco; 256 blocos = 1024 palavras x 32b)
- Limitacao conhecida da v1.0: PCBC (010), CFB (011) e OFB (100) ficam para W10.
"""
from pathlib import Path
import random

# S-box FIPS-197
SBOX = [
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
]

INV_SBOX = [0] * 256
for idx, val in enumerate(SBOX):
    INV_SBOX[val] = idx

RCON = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]


def xtime(a: int) -> int:
    a &= 0xFF
    return ((a << 1) ^ 0x1B) & 0xFF if (a & 0x80) else ((a << 1) & 0xFF)


def gmul(a: int, b: int) -> int:
    res = 0
    aa = a & 0xFF
    bb = b & 0xFF
    for _ in range(8):
        if bb & 1:
            res ^= aa
        aa = xtime(aa)
        bb >>= 1
    return res & 0xFF


def sub_word(w: int) -> int:
    return (
        (SBOX[(w >> 24) & 0xFF] << 24)
        | (SBOX[(w >> 16) & 0xFF] << 16)
        | (SBOX[(w >> 8) & 0xFF] << 8)
        | SBOX[w & 0xFF]
    )


def rot_word(w: int) -> int:
    return ((w << 8) & 0xFFFFFFFF) | ((w >> 24) & 0xFF)


def key_expansion_128(key128: int) -> list[int]:
    w = [(key128 >> (128 - 32 * (i + 1))) & 0xFFFFFFFF for i in range(4)]
    for i in range(4, 44):
        temp = w[i - 1]
        if i % 4 == 0:
            temp = sub_word(rot_word(temp)) ^ (RCON[i // 4] << 24)
        w.append((w[i - 4] ^ temp) & 0xFFFFFFFF)

    rkeys = []
    for rnd in range(11):
        rk = (
            (w[4 * rnd] << 96)
            | (w[4 * rnd + 1] << 64)
            | (w[4 * rnd + 2] << 32)
            | w[4 * rnd + 3]
        )
        rkeys.append(rk)
    return rkeys


def add_round_key(state: list[int], rkey128: int) -> list[int]:
    rk_bytes = [(rkey128 >> (128 - 8 * (i + 1))) & 0xFF for i in range(16)]
    return [state[i] ^ rk_bytes[i] for i in range(16)]


def sub_bytes(state: list[int]) -> list[int]:
    return [SBOX[b] for b in state]


def inv_sub_bytes(state: list[int]) -> list[int]:
    return [INV_SBOX[b] for b in state]


def shift_rows(state: list[int]) -> list[int]:
    # Column-major: byte index idx = row + 4*col -> s'[row][col] = s[row][(col+row)%4]
    out = [0] * 16
    for c in range(4):
        for r in range(4):
            out[r + 4 * c] = state[r + 4 * ((c + r) % 4)]
    return out


def inv_shift_rows(state: list[int]) -> list[int]:
    out = [0] * 16
    for c in range(4):
        for r in range(4):
            out[r + 4 * c] = state[r + 4 * ((c - r + 4) % 4)]
    return out


def mix_columns(state: list[int]) -> list[int]:
    out = [0] * 16
    for c in range(4):
        b0, b1, b2, b3 = state[4 * c : 4 * c + 4]
        out[4 * c + 0] = xtime(b0) ^ (xtime(b1) ^ b1) ^ b2 ^ b3
        out[4 * c + 1] = b0 ^ xtime(b1) ^ (xtime(b2) ^ b2) ^ b3
        out[4 * c + 2] = b0 ^ b1 ^ xtime(b2) ^ (xtime(b3) ^ b3)
        out[4 * c + 3] = (xtime(b0) ^ b0) ^ b1 ^ b2 ^ xtime(b3)
    return out


def inv_mix_columns(state: list[int]) -> list[int]:
    out = [0] * 16
    for c in range(4):
        b0, b1, b2, b3 = state[4 * c : 4 * c + 4]
        out[4 * c + 0] = gmul(0x0E, b0) ^ gmul(0x0B, b1) ^ gmul(0x0D, b2) ^ gmul(0x09, b3)
        out[4 * c + 1] = gmul(0x09, b0) ^ gmul(0x0E, b1) ^ gmul(0x0B, b2) ^ gmul(0x0D, b3)
        out[4 * c + 2] = gmul(0x0D, b0) ^ gmul(0x09, b1) ^ gmul(0x0E, b2) ^ gmul(0x0B, b3)
        out[4 * c + 3] = gmul(0x0B, b0) ^ gmul(0x0D, b1) ^ gmul(0x09, b2) ^ gmul(0x0E, b3)
    return out


def int_to_bytes16(val: int) -> list[int]:
    return [(val >> (128 - 8 * (i + 1))) & 0xFF for i in range(16)]


def bytes16_to_int(b: list[int]) -> int:
    acc = 0
    for byte in b:
        acc = (acc << 8) | (byte & 0xFF)
    return acc


def aes_cipher_block(block128: int, rkeys: list[int]) -> int:
    st = add_round_key(int_to_bytes16(block128), rkeys[0])
    for rnd in range(1, 10):
        st = sub_bytes(st)
        st = shift_rows(st)
        st = mix_columns(st)
        st = add_round_key(st, rkeys[rnd])
    st = sub_bytes(st)
    st = shift_rows(st)
    st = add_round_key(st, rkeys[10])
    return bytes16_to_int(st)


def aes_inv_cipher_block(block128: int, rkeys: list[int]) -> int:
    st = add_round_key(int_to_bytes16(block128), rkeys[10])
    for rnd in range(1, 10):
        st = inv_shift_rows(st)
        st = inv_sub_bytes(st)
        st = add_round_key(st, rkeys[10 - rnd])
        st = inv_mix_columns(st)
    st = inv_shift_rows(st)
    st = inv_sub_bytes(st)
    st = add_round_key(st, rkeys[0])
    return bytes16_to_int(st)


def add_ctr_block(ctr_base128: int, k: int) -> int:
    hi64 = (ctr_base128 >> 64) & ((1 << 64) - 1)
    lo64 = ctr_base128 & ((1 << 64) - 1)
    lo_sum = lo64 + k
    carry = (lo_sum >> 64) & 1
    new_lo64 = lo_sum & ((1 << 64) - 1)
    new_hi64 = (hi64 + carry) & ((1 << 64) - 1)
    return (new_hi64 << 64) | new_lo64


def run_mode(mode: str, decrypt: bool, key128: int, iv128: int, ctr128: int, blocks: list[int]) -> list[int]:
    rkeys = key_expansion_128(key128)
    out = []
    if mode == "ECB":
        for blk in blocks:
            out.append(aes_inv_cipher_block(blk, rkeys) if decrypt else aes_cipher_block(blk, rkeys))
    elif mode == "CBC":
        chain = iv128
        for blk in blocks:
            if not decrypt:
                ct = aes_cipher_block(blk ^ chain, rkeys)
                out.append(ct)
                chain = ct
            else:
                pt = aes_inv_cipher_block(blk, rkeys) ^ chain
                out.append(pt)
                chain = blk
    elif mode == "CTR":
        for idx, blk in enumerate(blocks):
            ks = aes_cipher_block(add_ctr_block(ctr128, idx), rkeys)
            out.append(blk ^ ks)
    else:
        raise ValueError(f"Modo nao suportado na W6: {mode}")
    return out


def blocks_to_words32(blocks: list[int]) -> list[int]:
    words = []
    for blk in blocks:
        for w_idx in range(4):
            words.append((blk >> (96 - 32 * w_idx)) & 0xFFFFFFFF)
    return words


def write_hex_words(path: Path, words: list[int]) -> None:
    path.write_text("\n".join(f"{w:08x}" for w in words) + "\n")


def main() -> None:
    out_dir = Path("tb/vectors_w06")
    out_dir.mkdir(parents=True, exist_ok=True)

    key128 = 0x2B7E151628AED2A6ABF7158809CF4F3C
    iv128 = 0x000102030405060708090A0B0C0D0E0F
    ctr128 = 0xF0F1F2F3F4F5F6F70000000000000001

    # Vetor oficial FIPS-197 no bloco 0
    fips_pt0 = 0x3243F6A8885A308D313198A2E0370734
    fips_ct0 = aes_cipher_block(fips_pt0, key_expansion_128(key128))
    assert fips_ct0 == 0x3925841D02DC09FBDC118597196A0B32

    rng = random.Random(20261126)

    for nblk in (1, 2, 256):
        pts = [fips_pt0 if i == 0 else rng.getrandbits(128) for i in range(nblk)]
        write_hex_words(out_dir / f"pt_{nblk}.hex", blocks_to_words32(pts))

        for mode in ("ECB", "CBC", "CTR"):
            cts = run_mode(mode, False, key128, iv128, ctr128, pts)
            pts_rec = run_mode(mode, True, key128, iv128, ctr128, cts)
            assert pts_rec == pts, f"Falha roundtrip Python em {mode} ({nblk} blocos)"

            write_hex_words(out_dir / f"{mode.lower()}_enc_{nblk}.hex", blocks_to_words32(cts))
            write_hex_words(out_dir / f"{mode.lower()}_dec_{nblk}.hex", blocks_to_words32(pts_rec))

    print("Vetores de 1, 2 e 256 blocos gerados em tb/vectors_w06/ para ECB, CBC e CTR.")


if __name__ == "__main__":
    main()
