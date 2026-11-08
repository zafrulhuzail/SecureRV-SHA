#include "sha256.h"

static volatile uint32_t *const host = (volatile uint32_t *)0x20000000u;
static const uint32_t lengths[] = {0, 3, 55, 56, 63, 64, 65, 256, 1024, 4096};
static const uint8_t published[] =
    "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";

int main(void)
{
    uint8_t input[4096];
    uint32_t digest[8];
    for (uint32_t i = 0; i < sizeof(input); ++i)
        input[i] = (uint8_t)((i * 73u + (i >> 3) + 19u) ^ (i >> 5));

    for (unsigned test = 0; test < sizeof(lengths) / sizeof(lengths[0]); ++test) {
        const uint8_t *message = input;
        uint32_t len = lengths[test];
        if (len == 3) message = (const uint8_t *)"abc";
        if (len == 56) message = published;
        host[1] = len;
        sha256(message, len, digest);
        host[2] = 1;
        for (unsigned i = 0; i < 8; ++i) host[8+i] = digest[i];
        host[3] = 1;
    }
    return 0;
}
