#include "montgomery.h"

uint16_t montgomery_reduce(uint32_t T, uint16_t q, uint16_t qinv, uint32_t R) {
    // Step 1: compute m = (T mod R) * qinv mod R
    uint16_t m = ((T % R) * qinv) % R;
    
    // Step 2: compute t = (T + m * q) / R
    // This removes one factor of R from the representation
    uint32_t t = (T + (uint32_t)m * q) / R; //t is a multiple of R
    
    // Step 3: final reduction (conditional subtraction)
    if (t >= q) t -= q;
    
    return (uint16_t)t;
}

// Convert input a to Montgomery form: a * R mod q
uint16_t to_montgomery(uint16_t a, uint32_t R, uint16_t q) {
    return ((uint32_t)a * R) % q;
}

// Convert Montgomery result back to standard form: a * R^(-1) mod q
uint16_t from_montgomery(uint16_t a, uint32_t Rinv, uint16_t q) {
    return ((uint32_t)a * Rinv) % q;
}
