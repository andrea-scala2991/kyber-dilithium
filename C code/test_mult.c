#include <stdio.h>
#include <stdint.h>

#include "barrett.h"
#include "booth.h"
#include "montgomery.h"
#include "kyber_params.h"
#include <stdlib.h>

int main(int argc, char *argv[]) {
    uint16_t a = strtoul(argv[1], NULL, 10);
    uint16_t b = strtoul(argv[2], NULL, 10);
    uint32_t res = a*b;
    uint32_t res_mod = res % Q;
    printf("%d * %d = %u\n", a, b, res);
    printf("%u mod %d = %d\n", res, Q, res_mod);

    // Booth multiplication
    uint32_t booth_result = booth_multiply(a, b);
    printf("Booth multiply: %d * %d = %u\n", a, b, booth_result);

    // Barrett reduction
    uint32_t mul = (uint32_t)a * b;
    uint16_t barrett_result = barrett_reduce(mul, Q);
    printf("Barrett reduction: (%d * %d) mod %d = %d\n", a, b, Q, barrett_result);

    // Montgomery multiplication
    uint16_t a_mont = to_montgomery(a, _R, Q);
    uint16_t b_mont = to_montgomery(b, _R, Q);
    uint32_t T = (uint32_t)a_mont * b_mont;
    uint16_t mont_result_mont = montgomery_reduce(T, Q, QINV, _R);
    uint16_t mont_result = from_montgomery(mont_result_mont, RINV, Q);
    printf("Montgomery multiplication: (%d * %d) mod %d = %d\n", a, b, Q, mont_result);

    return 0;
}
