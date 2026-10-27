/*
 * mandel.h - nucleo de calculo do fractal de Mandelbrot (reaproveitado do T1).
 *
 * Uma "unidade de trabalho" (tarefa) e UMA LINHA da imagem: para cada pixel da
 * linha iteramos z = z^2 + c ate escapar (|z| > 2) ou atingir max_iter.
 * O resultado de uma linha e um vetor de `width` inteiros (iteracoes por pixel).
 *
 * Linhas sao independentes entre si -> encaixam no saco de trabalho do modelo
 * mestre/escravo. O custo varia muito por linha (linhas que cortam o conjunto
 * sao caras), o que torna o balanceamento dinamico relevante.
 */
#ifndef MANDEL_H
#define MANDEL_H

#include <stdint.h>

/* Regiao fixa do plano complexo (a mesma em todas as execucoes). */
#define X_MIN (-2.0)
#define X_MAX ( 1.0)
#define Y_MIN (-1.5)
#define Y_MAX ( 1.5)

/* Calcula a linha `row` de uma imagem width x height e grava em out[0..width-1]. */
static inline void mandel_row(int row, int width, int height, int max_iter, int *out)
{
    const double dx = (X_MAX - X_MIN) / width;
    const double dy = (Y_MAX - Y_MIN) / height;
    const double ci = Y_MIN + row * dy;
    for (int col = 0; col < width; col++) {
        const double cr = X_MIN + col * dx;
        double zr = 0.0, zi = 0.0, zr2 = 0.0, zi2 = 0.0;
        int it = 0;
        while (it < max_iter && zr2 + zi2 <= 4.0) {
            zi  = 2.0 * zr * zi + ci;
            zr  = zr2 - zi2 + cr;
            zr2 = zr * zr;
            zi2 = zi * zi;
            it++;
        }
        out[col] = it;
    }
}

/* Grandeza verificavel: soma de todas as iteracoes, ponderada pela posicao
 * da linha para que uma linha fora de lugar altere o resultado (req. 3). */
static inline uint64_t mandel_checksum(const int *img, int width, int height)
{
    uint64_t sum = 0, weighted = 0;
    for (int r = 0; r < height; r++) {
        uint64_t rs = 0;
        for (int c = 0; c < width; c++) rs += (uint64_t)img[(long)r * width + c];
        sum += rs;
        weighted += rs * (uint64_t)(r + 1);
    }
    return sum ^ (weighted << 1);
}

static inline uint64_t mandel_total_iters(const int *img, long n)
{
    uint64_t s = 0;
    for (long i = 0; i < n; i++) s += (uint64_t)img[i];
    return s;
}

#endif
