#ifndef MONTGOMERY_H
#define MONTGOMERY_H

#include <stdint.h>

uint16_t montgomery_reduce(uint32_t T, uint16_t q, uint16_t qinv, uint16_t R);
uint16_t to_montgomery(uint16_t a, uint16_t R, uint16_t q);
uint16_t from_montgomery(uint16_t a, uint16_t Rinv, uint16_t q);

#endif
