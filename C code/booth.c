#include "booth.h"

int32_t booth_multiply(int16_t multiplicand, int16_t multiplier) {
    int32_t A = multiplicand;
    int32_t result = 0;
    int16_t m = multiplier;
    int prev_bit = 0;

    for (int i = 0; i < 16; i++) {
        int bit = (m >> i) & 1;
        if (bit != prev_bit) {
            if (bit == 1)
                result += A << i;
            else
                result -= A << i;
        }
        prev_bit = bit;
    }

    return result;
}
