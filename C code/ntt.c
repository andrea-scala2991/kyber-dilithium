#include "ntt.h"
#include <stdio.h>

uint16_t mod_add(uint16_t a, uint16_t b) {
    uint16_t r = a + b;
    return (r >= Q) ? r - Q : r;
}

uint16_t mod_sub(uint16_t a, uint16_t b) {
    return (a >= b) ? (a - b) : (Q + a - b);
}

uint16_t mod_mul(uint16_t a, uint16_t b) {
    return (a * b) % Q;
}

uint16_t mod_pow(uint16_t base, uint16_t exp) {
    uint16_t res = 1;
    while (exp) {
        if (exp & 1) res = mod_mul(res, base);
        base = mod_mul(base, base);
        exp >>= 1;
    }
    return res;
}

// Finds the smallest ζ such that ζ^(2n) ≡ 1 mod q and ζ^k ≠ 1 for all 0 < k < 2n
uint16_t find_primitive_2nth_root(int n) {
    int order = 2 * n;
    for (uint16_t z = 2; z < Q; z++) {
        if (mod_pow(z, order) != 1) continue;

        int is_primitive = 1;
        for (int d = 1; d < order; d++) {
            if (mod_pow(z, d) == 1) {
                is_primitive = 0;
                break;
            }
        }
        if (is_primitive) return z;
    }
    return 0; // not found
}

void bit_reverse(uint16_t *a, int n) {
    int j = 0;
    for (int i = 1; i < n; i++) {
        int bit = n >> 1;
        while (j & bit) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        if (i < j) {
            uint16_t tmp = a[i];
            a[i] = a[j];
            a[j] = tmp;
        }
    }
}

void ntt_standard(uint16_t *a, int n, uint16_t omega) {
    for (int len = 2; len <= n; len <<= 1) {
        int half = len >> 1;
        uint16_t root = mod_pow(omega, n / len);
        for (int start = 0; start < n; start += len) {
            uint16_t w = 1;
            for (int j = 0; j < half; ++j) {
                uint16_t u = a[start + j];
                uint16_t v = mod_mul(a[start + j + half], w);
                a[start + j] = mod_add(u, v);
                a[start + j + half] = mod_sub(u, v);
                w = mod_mul(w, root);
            }
        }
    }
}

void intt_standard(uint16_t *a, int n, uint16_t omega_inv) {
    for (int len = n; len > 1; len >>= 1) {
        int half = len >> 1;
        uint16_t root = mod_pow(omega_inv, n / len);
        for (int start = 0; start < n; start += len) {
            uint16_t w = 1;
            for (int j = 0; j < half; ++j) {
                uint16_t u = a[start + j];
                uint16_t v = a[start + j + half];
                a[start + j] = mod_add(u, v);
                a[start + j + half] = mod_mul(w, mod_sub(u, v));
                w = mod_mul(w, root);
            }
        }
    }

    uint16_t n_inv = mod_pow(n, Q - 2);  // Fermat inverse
    for (int i = 0; i < n; i++) {
        a[i] = mod_mul(a[i], n_inv);
    }
}

void ntt_negacyclic(uint16_t *a, int n) {
    uint16_t zeta = find_primitive_2nth_root(n);
    uint16_t omega = mod_pow(zeta, 2);

    for (int i = 0; i < n; ++i)
        a[i] = mod_mul(a[i], mod_pow(zeta, i));

    ntt_standard(a, n, omega);

    for (int i = 0; i < n; ++i)
        a[i] = mod_mul(a[i], mod_pow(zeta, i));

    printf("zeta = %d\n", zeta);
}

void intt_negacyclic(uint16_t *a, int n) {
    uint16_t zeta = find_primitive_2nth_root(n);
    uint16_t omega_inv = mod_pow(mod_pow(zeta, 2), Q - 2);
    uint16_t zeta_inv = mod_pow(zeta, Q - 2);

    for (int i = 0; i < n; ++i)
        a[i] = mod_mul(a[i], mod_pow(zeta_inv, i));

    intt_standard(a, n, omega_inv);

    for (int i = 0; i < n; ++i)
        a[i] = mod_mul(a[i], mod_pow(zeta_inv, i));
}
