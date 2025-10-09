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

uint16_t mod_div2(uint16_t a){
    if ((a % 2) == 0)
        return a / 2;
    else
        return (1664 + ((a + 1) / 2));
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

void ntt_standard(uint16_t *a, int n, uint16_t omega) {
    int log_n = 0;
    for (int temp = n; temp > 1; temp >>= 1) log_n++;

    // Precompute twiddle factors (powers of omega)
    uint16_t zetas[n / 2];
    for (int i = 0; i < n / 2; i++) {
        int rev = bit_reverse(i, log_n - 1);
        zetas[i] = mod_pow(omega, rev);
    }

    // DIT NTT
    int stage = 0;
    for (int len = n / 2; len >= 1; len >>= 1) {
        int step = n / (2 * len);
        //stage++;
        //printf("stage %d:\n", stage);
        for (int start = 0; start < n; start += 2 * len) {
            for (int j = 0; j < len; j++) {
                int pos = start + j;
                uint16_t w = zetas[j * step]; //bit-reversed already

                //printf("butterfly (%d,%d), twiddle[%d] =%u\n", pos, pos + len, j*step, w);
                
                uint16_t u = a[pos];
                uint16_t v = mod_mul(a[pos + len], w);
                //printf("u[%u] = %u, v[%u] = %u\n", pos, a[pos], pos + len, a[pos + len] );
                a[pos] = mod_add(u, v);
                a[pos + len] = mod_sub(u, v);
                //printf("U = %u, V = %u\n", a[pos], a[pos + len]);
            }
        }
    }
    /*for (int i = 0; i < n/2;i++)
        printf("twiddle[%d]:%d\n", i, zetas[i]);*/
}

void intt_standard(uint16_t *a, int n, uint16_t omega) {
    int log_n = 0;
    for (int temp = n; temp > 1; temp >>= 1) log_n++;

    // Precompute twiddle factors in bit-reversed order
    uint16_t zetas[n / 2];
    for (int i = 0; i < n / 2; i++) {
        int rev = bit_reverse(i, log_n - 1);
        zetas[i] = mod_pow(omega, rev);
    }

    // Gentleman-Sande INTT
    int stage = 0;
    for (int len = 1; len < n; len <<= 1) {
        stage++;
        printf("stage %d:\n", stage);
        int step = n / (2 * len);
        for (int start = 0; start < n; start += 2 * len) {
            for (int j = 0; j < len; j++) {
                int pos = start + j;
                printf("butterfly (%d,%d), twiddle[%d] =%u\n", pos, pos + len, j*step, zetas[j * step]);
                uint16_t u = a[pos];
                uint16_t v = a[pos + len];
                printf("u[%u] = %u, v[%u] = %u\n", pos, a[pos], pos + len, a[pos + len] );
                a[pos] = mod_add(u, v);

                uint16_t t = mod_sub(u, v);
                a[pos + len] = mod_mul(t, zetas[j * step]);
                a[pos] = mod_div2(a[pos]);
                a[pos + len] = mod_div2(a[pos + len]);
                printf("U = %u, V = %u\n", a[pos], a[pos + len]);
            }
        }
        for (int i = 0; i < n/2;i++)
        printf("twiddle[%d]:%d\n", i, zetas[i]);
    }

    /*// Multiply by n⁻¹ mod q (Fermat's little theorem: n⁻¹ ≡ n^(q−2) mod q)
    uint16_t n_inv = mod_pow(n, Q - 2);
    for (int i = 0; i < n; i++) {
        a[i] = mod_mul(a[i], n_inv);
    }*/
}

void ntt_negacyclic(uint16_t *a, int n) {
    uint16_t zeta = find_primitive_2nth_root(n);
    uint16_t omega = mod_pow(zeta, 2);


    ntt_standard(a, n, 910);

    //printf("zeta = %d\n", zeta);
}

void intt_negacyclic(uint16_t *a, int n) {
    uint16_t zeta = find_primitive_2nth_root(n);
    uint16_t omega_inv = mod_pow(mod_pow(zeta, 2), Q - 2);
    uint16_t zeta_inv = mod_pow(zeta, Q - 2);

    intt_standard(a, n, 3040);

}

// Reverse the bits of index 'x' with 'log_n' bits
int bit_reverse(int x, int log_n) {
    int result = 0;
    for (int i = 0; i < log_n; i++) {
        result <<= 1;
        result |= (x & 1);
        x >>= 1;
    }
    return result;
}
