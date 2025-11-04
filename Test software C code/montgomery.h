#ifndef MONTGOMERY_H
#define MONTGOMERY_H

#include <stdint.h>
#include "kyber_params.h"

#define _R 65536
#define RINV 169
#define QINV 3327


uint16_t montgomery_reduce(uint32_t T, uint16_t q, uint16_t qinv, uint32_t R);
uint16_t to_montgomery(uint16_t a, uint32_t R, uint16_t q);
uint16_t from_montgomery(uint16_t a, uint32_t Rinv, uint16_t q);

#endif
