#include "barrett.h"

uint16_t barrett_reduce(uint32_t a, uint16_t q) {
    uint32_t k = 16;
    uint32_t mu = (1ULL << (2 * k)) / q;

    uint32_t t = ((uint64_t)a * mu) >> (2 * k);
    uint32_t r = a - t * q;

    if (r >= q) r -= q;
    return (uint16_t)r;
}
