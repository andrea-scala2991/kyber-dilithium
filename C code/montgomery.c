#include "montgomery.h"

uint16_t montgomery_reduce(uint32_t T, uint16_t q, uint16_t qinv, uint16_t R) {
    uint16_t m = ((T % R) * qinv) % R;
    uint32_t t = (T + (uint32_t)m * q) / R;
    if (t >= q) t -= q;
    return (uint16_t)t;
}

uint16_t to_montgomery(uint16_t a, uint16_t R, uint16_t q) {
    return ((uint32_t)a * R) % q;
}

uint16_t from_montgomery(uint16_t a, uint16_t Rinv, uint16_t q) {
    return ((uint32_t)a * Rinv) % q;
}
