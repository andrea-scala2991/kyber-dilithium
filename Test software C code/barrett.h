#ifndef BARRETT_H
#define BARRETT_H

#include <stdint.h>

uint16_t barrett_reduce(uint32_t a, uint16_t q);

#endif
