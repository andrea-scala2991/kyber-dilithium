#include <stdint.h>
#include <stdio.h>
#include "ntt.h"

int main() {
    uint16_t a[N]  = {1, 2, 3, 4}; // Example input polynomial
    uint16_t a8[N] = {1, 2, 3, 4, 5, 6, 7, 8};
    uint16_t a16[N] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 , 13, 14, 15, 16};
    uint16_t b[N]  = {5, 6, 7, 8};
    uint16_t c[N]  = {10, 12, 15, 16};
   
    uint16_t input[N] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 , 13, 14, 15, 16};

    printf("input vector:\n");
    for (int i = 0; i < N; i++) {
        printf("%d ", input[i]);
    }
    printf("\n\n");

    ntt_negacyclic(input); // Perform Kyber-style negacyclic NTT

    // Print result
    printf("Negacyclic NTT output(bit reversed order):\n");
    for (int i = 0; i < N; i++) {
        printf("%d ", input[i]);
    }
    printf("\n\n");

    intt_negacyclic(input); // Perform Kyber-style negacyclic INTT

    // Print result
    printf("Negacyclic INTT output(normal order):\n");
    for (int i = 0; i < N; i++) {
        printf("%d ", input[i]);
    }
    printf("\n\n");

    return 0;
}
