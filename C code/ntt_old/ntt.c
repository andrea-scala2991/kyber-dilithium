#include <stdint.h>
#include <stdio.h>
#include "ntt.h"

// -------------------- Modular Arithmetic --------------------

// Modular addition: (a + b) mod Q
uint16_t mod_add(uint16_t a, uint16_t b) {
    uint16_t r = a + b;
    return (r >= Q) ? r - Q : r;
}

// Modular subtraction: (a - b) mod Q, avoiding negative values
uint16_t mod_sub(uint16_t a, uint16_t b) {
    return (a >= b) ? (a - b) : (Q + a - b);
}

// Modular multiplication: (a * b) mod Q
uint16_t mod_mul(uint16_t a, uint16_t b) {
    return (a * b) % Q;
}

// Modular exponentiation: computes base^exp mod Q
uint16_t mod_pow(uint16_t base, uint16_t exp) {
    uint16_t res = 1;
    while (exp) {
        if (exp & 1)
            res = mod_mul(res, base); // Multiply result if current bit is 1
        base = mod_mul(base, base);   // Square the base
        exp >>= 1;                    // Shift exponent right by 1 bit
    }
    return res;
}

// -------------------- Standard Cooley–Tukey NTT --------------------
// Performs an in-place, decimation-in-time NTT (normal order input, bit-reversed output) with root ω
void ntt_standard(uint16_t a[N], uint16_t omega) {
    // For each stage of the NTT (len = 2, 4, ..., N)
    for (int len = 2; len <= N; len <<= 1) {
        int half = len >> 1; // Half the size of the current transform block
        uint16_t root = mod_pow(omega, N / len); // Twiddle factor root for this stage

        // Process each block of length 'len'
        for (int start = 0; start < N; start += len) {
            uint16_t w = 1; // Twiddle factor multiplier (starts at ω^0)
            for (int j = 0; j < half; ++j) {
                // Butterfly operation
                uint16_t u = a[start + j];                    // Top element
                uint16_t v = mod_mul(a[start + j + half], w); // Bottom × twiddle

                a[start + j] = mod_add(u, v);    // Top = u + v
                a[start + j + half] = mod_sub(u, v); // Bottom = u - v

                w = mod_mul(w, root); // Advance twiddle factor
            }
        }
    }
}

// -------------------- Negacyclic NTT (Kyber-compatible) --------------------
void ntt_negacyclic(uint16_t a[N]) {
    uint16_t zeta_pow;

    // Step 1: Twist input — multiply each coefficient by ζ^i
    printf("Twisting input by zeta^i:\n");
    for (int i = 0; i < N; ++i) {
        uint16_t zeta_pow = mod_pow(ZETA, i);
        a[i] = mod_mul(a[i], zeta_pow); // a[i] ← a[i] * ζ^i mod q
        
        printf("a[%d] = %d\n", i, a[i]);
    }

     

    // Step 2: Apply standard NTT using ω = ζ^2
    ntt_standard(a, OMEGA);

    // Step 3: Twist output — multiply each result by ζ^i again
    printf("untwisting:\n");
    for (int i = 0; i < N; ++i) {
        uint16_t zeta_pow = mod_pow(ZETA, i);
        a[i] = mod_mul(a[i], zeta_pow); // A[i] ← A[i] * ζ^i mod q
        printf("a[%d] = %d\n", i, a[i]);
    }

    // Step 4 (optional): Reorder output from bit-reversed to natural order
    //bit_reverse(a);
}

// Inverse standard NTT (Gentleman-Sande)
void intt_standard(uint16_t a[N], uint16_t omega_inv) {
    for (int len = N; len > 1; len >>= 1) {
        int half = len >> 1;
        uint16_t root = mod_pow(omega_inv, N / len);

        for (int start = 0; start < N; start += len) {
            uint16_t w = 1;
            for (int j = 0; j < half; j++) {
                uint16_t u = a[start + j];
                uint16_t v = a[start + j + half];

                a[start + j] = mod_add(u, v);
                uint16_t diff = mod_sub(u, v);
                a[start + j + half] = mod_mul(w, diff);

                w = mod_mul(w, root);
            }
        }
    }

    // Final scaling by n^{-1} mod q
    uint16_t n_inv = mod_pow(N, Q - 2); // Inverse of N mod Q (Fermat)
    for (int i = 0; i < N; i++) {
        a[i] = mod_mul(a[i], n_inv);
    }
}

// Inverse negacyclic NTT using Gentleman–Sande and ζ^{-i} untwist
void intt_negacyclic(uint16_t a[N]) {
    uint16_t zeta_inv = mod_pow(ZETA, Q - 2); // ζ⁻¹

    printf("Twisting input by zeta^-i:\n");
    for (int i = 0; i < N; ++i) {
        uint16_t zp = mod_pow(zeta_inv, i); // ζ^{-i}
        a[i] = mod_mul(a[i], zp);
        printf("a[%d] = %d\n", i, a[i]);
    }

    // Perform inverse NTT
    uint16_t omega_inv = mod_pow(OMEGA, Q - 2); // ω⁻¹
    intt_standard(a, omega_inv);

    printf("After inverse NTT (pre-output twist):\n");
    for (int i = 0; i < N; ++i) {
        printf("a[%d] = %d\n", i, a[i]);
    }

    // Twist output by ζ⁻ⁱ
    printf("untwisting:\n");
    for (int i = 0; i < N; ++i) {
        uint16_t zp = mod_pow(zeta_inv, i); // ζ^{-i}
        a[i] = mod_mul(a[i], zp);
        printf("a[%d] = %d\n", i, a[i]);
    }
}
