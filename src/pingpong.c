/*
 * pingpong.c - mede (a) tempo medio de processar UMA tarefa (bloco de `grain`
 * linhas) e (b) tempo de ida e volta de uma mensagem do mesmo tamanho do
 * resultado, entre o rank 0 e o rank 1. Usado para justificar a granularidade.
 *
 * Uso: mpirun -np 2 ./pingpong <width> <height> <max_iter> <grain> [reps]
 * Para medir intra-no, rode os 2 ranks no mesmo no; para inter-no, um por no.
 */
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include "mandel.h"

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank, nprocs;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);
    if (argc < 5 || nprocs != 2) {
        if (rank == 0) fprintf(stderr, "uso: mpirun -np 2 %s <width> <height> <max_iter> <grain> [reps]\n", argv[0]);
        MPI_Finalize();
        return 1;
    }
    const int width = atoi(argv[1]), height = atoi(argv[2]);
    const int max_iter = atoi(argv[3]), grain = atoi(argv[4]);
    const int reps = argc > 5 ? atoi(argv[5]) : 1000;
    const int n = 2 + grain * width; /* mesmo tamanho da mensagem TAG_RESULT */
    int *buf = calloc((size_t)n, sizeof(int));

    /* (b) ida e volta */
    MPI_Barrier(MPI_COMM_WORLD);
    for (int w = 0; w < 10; w++) { /* aquecimento */
        if (rank == 0) { MPI_Send(buf, n, MPI_INT, 1, 0, MPI_COMM_WORLD); MPI_Recv(buf, n, MPI_INT, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE); }
        else           { MPI_Recv(buf, n, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE); MPI_Send(buf, n, MPI_INT, 0, 0, MPI_COMM_WORLD); }
    }
    double t0 = MPI_Wtime();
    for (int r = 0; r < reps; r++) {
        if (rank == 0) { MPI_Send(buf, n, MPI_INT, 1, 0, MPI_COMM_WORLD); MPI_Recv(buf, n, MPI_INT, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE); }
        else           { MPI_Recv(buf, n, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE); MPI_Send(buf, n, MPI_INT, 0, 0, MPI_COMM_WORLD); }
    }
    double rtt = (MPI_Wtime() - t0) / reps;

    /* (a) tempo de uma tarefa: media sobre todos os blocos da imagem
     * (o custo por linha varia muito no Mandelbrot). */
    if (rank == 0) {
        int *row = malloc((size_t)grain * width * sizeof(int));
        double c0 = MPI_Wtime(), tmin = 1e30, tmax = 0;
        int blocks = 0;
        for (int s = 0; s < height; s += grain) {
            int cnt = height - s < grain ? height - s : grain;
            double b0 = MPI_Wtime();
            for (int i = 0; i < cnt; i++) mandel_row(s + i, width, height, max_iter, row + (long)i * width);
            double bt = MPI_Wtime() - b0;
            if (bt < tmin) tmin = bt;
            if (bt > tmax) tmax = bt;
            blocks++;
        }
        double task = (MPI_Wtime() - c0) / blocks;
        printf("PINGPONG grain=%d bytes=%zu rtt=%.9f task_avg=%.9f task_min=%.9f task_max=%.9f ratio=%.2f\n",
               grain, (size_t)n * sizeof(int), rtt, task, tmin, tmax, task / rtt);
        free(row);
    }
    free(buf);
    MPI_Finalize();
    return 0;
}
