#ifndef SECURERV_SHA256_H
#define SECURERV_SHA256_H
#include <stdint.h>
void sha256(const uint8_t *data, uint32_t len, uint32_t digest[8]);
#endif
