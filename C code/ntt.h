#ifndef NTT_H
#define NTT_H

#include <stdint.h>
#include "kyber_params.h"

uint16_t mod_add(uint16_t a, uint16_t b);
uint16_t mod_sub(uint16_t a, uint16_t b);
uint16_t mod_mul(uint16_t a, uint16_t b);
uint16_t mod_pow(uint16_t base, uint16_t exp);

uint16_t find_primitive_2nth_root(int n);
int bit_reverse(int x, int log_n);

void ntt_standard(uint16_t *a, int n, uint16_t omega);
void intt_standard(uint16_t *a, int n, uint16_t omega_inv);

void ntt_negacyclic(uint16_t *a, int n);
void intt_negacyclic(uint16_t *a, int n);

#endif