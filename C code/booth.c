#include "booth.h"
#include <stdio.h>

// Booth's multiplication algorithm for signed 16-bit integers.
// Reduces the number of additions/subtractions in binary multiplication
// by encoding sequences of 1s as fewer operations.
uint32_t booth_multiply(uint16_t multiplicand, uint16_t multiplier) {
    int32_t result = 0;
    int prev = 0;

    // Iterate over each bit of the multiplier
    for (int i = 0; i <= 16; i++) {
        int curr = (multiplier >> i) & 1;

        // If the current bit is different from the previous bit,
        // perform an addition or subtraction of A shifted by i
        if (curr != prev) {
            if (curr == 1)
                result += (int32_t)multiplicand << i; // simulate addition of shifted multiplicand
            else
                result -= (int32_t)multiplicand << i; // simulate subtraction
        }
        
        prev = curr;
    }

    return -result;
}

