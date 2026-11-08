#include "sha256.h"

#ifndef USE_ACCEL
static const uint32_t initial[8] = {
    0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au, 0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
};
static const uint32_t constants[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u, 0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u,
};

static uint32_t ror(uint32_t x, unsigned n)
{
    return (x >> n) | (x << (32 - n));
}

static void compress(uint32_t state[8], const uint32_t block[16])
{
    uint32_t w[64];
    for (unsigned i = 0; i < 16; ++i) w[i] = block[i];
    for (unsigned i = 16; i < 64; ++i) {
        uint32_t x = w[i-15], y = w[i-2];
        w[i] = w[i-16] + (ror(x,7) ^ ror(x,18) ^ (x >> 3)) +
               w[i-7] + (ror(y,17) ^ ror(y,19) ^ (y >> 10));
    }
    uint32_t a=state[0], b=state[1], c=state[2], d=state[3];
    uint32_t e=state[4], f=state[5], g=state[6], h=state[7];
    for (unsigned i = 0; i < 64; ++i) {
        uint32_t t1 = h + (ror(e,6) ^ ror(e,11) ^ ror(e,25)) +
                      ((e & f) ^ (~e & g)) + constants[i] + w[i];
        uint32_t t2 = (ror(a,2) ^ ror(a,13) ^ ror(a,22)) +
                      ((a & b) ^ (a & c) ^ (b & c));
        h=g; g=f; f=e; e=d+t1;
        d=c; c=b; b=a; a=t1+t2;
    }
    state[0]+=a; state[1]+=b; state[2]+=c; state[3]+=d;
    state[4]+=e; state[5]+=f; state[6]+=g; state[7]+=h;
}
#else
static volatile uint32_t *const sha = (volatile uint32_t *)0x10000000u;

static void compress(uint32_t state[8], const uint32_t block[16])
{
    (void)state;
    for (unsigned i = 0; i < 16; ++i) sha[8+i] = block[i];
    sha[0] = 2;
    while (sha[0] & 1u) {}
}
#endif

void sha256(const uint8_t *data, uint32_t len, uint32_t digest[8])
{
    const uint32_t high_bits = len >> 29;
    const uint32_t low_bits = len << 3;
#ifdef USE_ACCEL
    sha[0] = 1;
#else
    for (unsigned i = 0; i < 8; ++i) digest[i] = initial[i];
#endif
    while (len >= 64) {
        uint32_t block[16];
        for (unsigned i = 0; i < 16; ++i) {
            block[i] = ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
                       ((uint32_t)data[2] << 8) | data[3];
            data += 4;
        }
        compress(digest, block);
        len -= 64;
    }

    uint32_t tail[16];
    for (unsigned i = 0; i < 16; ++i) tail[i] = 0;
    for (unsigned i = 0; i < len; ++i)
        tail[i / 4] |= (uint32_t)data[i] << (24 - 8 * (i % 4));
    tail[len / 4] |= 0x80u << (24 - 8 * (len % 4));
    if (len >= 56) {
        compress(digest, tail);
        for (unsigned i = 0; i < 16; ++i) tail[i] = 0;
    }
    tail[14] = high_bits;
    tail[15] = low_bits;
    compress(digest, tail);
#ifdef USE_ACCEL
    for (unsigned i = 0; i < 8; ++i) digest[i] = sha[24+i];
#endif
}
