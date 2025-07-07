#include "barrett.h"

// Barrett reduction computes a % q using an approximation method.
// It's faster than division by q and avoids actual division at runtime.
uint16_t barrett_reduce(uint32_t a, uint16_t q) {
    uint32_t k = 16;  // choose k such that 2^k > q
    uint32_t mu = (1ULL << (2 * k)) / q;  // mu = floor(2^(2k) / q), precomputed reciprocal

    // Approximate division: t ≈ a / q
    uint32_t t = ((uint64_t)a * mu) >> (2 * k);

    // Compute a - t * q, which approximates a % q
    uint32_t r = a - t * q;

    // Final correction: if r ≥ q, subtract q once
    if (r >= q) r -= q;

    return (uint16_t)r;
}

