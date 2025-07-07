#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "ntt.h"

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <length> <coeff0> <coeff1> ... <coeffN-1>\n", argv[0]);
        return 1;
    }

    int n = atoi(argv[1]);
    if (n <= 0 || (n & (n - 1)) != 0) {
        fprintf(stderr, "Length must be a power of 2.\n");
        return 1;
    }

    if (argc != n + 2) {
        fprintf(stderr, "Expected %d coefficients, got %d.\n", n, argc - 2);
        return 1;
    }

    uint16_t *a = malloc(sizeof(uint16_t) * n);
    if (!a) {
        perror("malloc error");
        return 1;
    }

    for (int i = 0; i < n; i++) {
        a[i] = (uint16_t)atoi(argv[i + 2]) % Q;
    }

    printf("Input vector:\n");
    for (int i = 0; i < n; i++) printf("%d ", a[i]);
    printf("\n\n");

    ntt_negacyclic(a, n);
    printf("Negacyclic NTT output:\n");
    for (int i = 0; i < n; i++) printf("%d ", a[i]);
    printf("\n\n");

    intt_negacyclic(a, n);
    printf("Negacyclic INTT output:\n");
    for (int i = 0; i < n; i++) printf("%d ", a[i]);
    printf("\n");

    free(a);
    return 0;
}
