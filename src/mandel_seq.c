/*
 * mandel_seq.c - versao sequencial (referencia T1), sem MPI.
 *
 * Uso: ./mandel_seq <width> <height> <max_iter>
 * Regiao medida: apenas o laco de calculo das linhas (mesmos limites da
 * versao MPI: alocacao da imagem fica fora).
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <time.h>
#include "mandel.h"

static double now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "uso: %s <width> <height> <max_iter>\n", argv[0]);
        return 1;
    }
    const int width = atoi(argv[1]), height = atoi(argv[2]), max_iter = atoi(argv[3]);
    int *img = malloc((size_t)width * height * sizeof(int));
    if (!img) { perror("malloc"); return 1; }

    double t0 = now();
    for (int r = 0; r < height; r++)
        mandel_row(r, width, height, max_iter, img + (long)r * width);
    double t1 = now();

    printf("SEQ width=%d height=%d max_iter=%d tasks=%d total_iters=%" PRIu64
           " checksum=%" PRIu64 " time=%.6f\n",
           width, height, max_iter, height,
           mandel_total_iters(img, (long)width * height),
           mandel_checksum(img, width, height), t1 - t0);
    free(img);
    return 0;
}
