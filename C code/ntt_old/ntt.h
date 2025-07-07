#ifndef NTT_H
#define NTT_H

#include <stdint.h>

#define N 16           // input polynomial length
#define Q 17          // Modulus
#define ZETA 9        // Primitive 8th root of unity mod Q
#define OMEGA ((ZETA * ZETA) % Q) // omega = zeta^2 mod Q

// Modular arithmetic
uint16_t mod_add(uint16_t a, uint16_t b);
uint16_t mod_sub(uint16_t a, uint16_t b);
uint16_t mod_mul(uint16_t a, uint16_t b);
uint16_t mod_pow(uint16_t base, uint16_t exp);

// Fast standard NTT (Cooley-Tukey)
void ntt_standard(uint16_t a[N], uint16_t omega);

// Negacyclic NTT (Kyber-compatible)
void ntt_negacyclic(uint16_t a[N]);

void intt_standard(uint16_t a[N], uint16_t omega_inv);

// Inverse Negacyclic NTT (Gentleman-Sande)
void intt_negacyclic(uint16_t a[N]);

#endif
