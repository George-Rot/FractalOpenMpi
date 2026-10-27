/*
 * mandel_mpi.c - Mandelbrot no modelo mestre/escravo com MPI.
 *
 * Uso: mpirun -np P ./mandel_mpi <width> <height> <max_iter> <grain>
 *   grain = numero de linhas (unidades de trabalho) por mensagem (req. 6).
 *
 * Saco de trabalho: as linhas 0..height-1, guardadas implicitamente pelo
 * mestre como o indice `next_row` (proxima linha ainda nao distribuida).
 * Uma tarefa = bloco [start, start+count) com count <= grain.
 *
 * Protocolo (tags):
 *   TAG_REQUEST  escravo -> mestre  pedido inicial de trabalho, sem dados (req. 1)
 *   TAG_RESULT   escravo -> mestre  [start, count, iters...]: resultado de um bloco;
 *                                   tambem vale como pedido do proximo (req. 1)
 *   TAG_WORK     mestre  -> escravo [start, count]: bloco a processar
 *   TAG_STOP     mestre  -> escravo saco vazio, escravo deve terminar (req. 4)
 *   TAG_STATS    escravo -> mestre  [tarefas, linhas, tempo ocupado] apos STOP
 *                                   (fora da regiao medida; usado no balanceamento)
 */
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include "mandel.h"

enum { TAG_REQUEST = 1, TAG_RESULT = 2, TAG_WORK = 3, TAG_STOP = 4, TAG_STATS = 5 };

#define HDR 2 /* cabecalho das mensagens de resultado: start, count */

static void master(int nprocs, int width, int height, int max_iter, int grain)
{
    int *img = malloc((size_t)width * height * sizeof(int));
    /* buffer que cabe o maior resultado possivel: cabecalho + grain linhas */
    int *buf = malloc(((size_t)HDR + (size_t)grain * width) * sizeof(int));
    if (!img || !buf) { perror("malloc"); MPI_Abort(MPI_COMM_WORLD, 1); }

    const int nslaves = nprocs - 1;
    int next_row = 0;   /* topo do saco */
    int active = nslaves; /* escravos ainda nao encerrados */
    long msgs_recv = 0;

    MPI_Barrier(MPI_COMM_WORLD);
    double t0 = MPI_Wtime(); /* inicio da distribuicao */

    while (active > 0) {
        MPI_Status st;
        /* Ordem de chegada: atende quem ficar pronto primeiro (req. 2). */
        MPI_Recv(buf, HDR + grain * width, MPI_INT, MPI_ANY_SOURCE, MPI_ANY_TAG,
                 MPI_COMM_WORLD, &st);
        msgs_recv++;

        if (st.MPI_TAG == TAG_RESULT) {
            /* Req. 3: o bloco volta para sua posicao de origem na imagem. */
            int start = buf[0], count = buf[1];
            memcpy(img + (long)start * width, buf + HDR, (size_t)count * width * sizeof(int));
        }
        /* TAG_REQUEST ou TAG_RESULT: ambos sao pedidos de trabalho. */
        if (next_row < height) {
            int work[2];
            work[0] = next_row;
            /* Req. 5: ultimo bloco pode ser menor; nada exige divisibilidade. */
            work[1] = (height - next_row < grain) ? height - next_row : grain;
            next_row += work[1];
            MPI_Send(work, 2, MPI_INT, st.MPI_SOURCE, TAG_WORK, MPI_COMM_WORLD);
        } else {
            MPI_Send(NULL, 0, MPI_INT, st.MPI_SOURCE, TAG_STOP, MPI_COMM_WORLD);
            active--;
        }
    }
    double t1 = MPI_Wtime(); /* chegada do ultimo resultado */

    printf("MPI P=%d width=%d height=%d max_iter=%d grain=%d tasks=%d total_iters=%" PRIu64
           " checksum=%" PRIu64 " time=%.6f\n",
           nprocs, width, height, max_iter, grain, height,
           mandel_total_iters(img, (long)width * height),
           mandel_checksum(img, width, height), t1 - t0);

    /* Estatisticas por escravo (balanceamento), coletadas fora da regiao medida. */
    for (int s = 1; s <= nslaves; s++) {
        double stats[3];
        MPI_Recv(stats, 3, MPI_DOUBLE, s, TAG_STATS, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        printf("SLAVE rank=%d blocks=%.0f rows=%.0f busy=%.6f idle=%.6f\n",
               s, stats[0], stats[1], stats[2], (t1 - t0) - stats[2]);
    }
    free(buf);
    free(img);
}

static void slave(int width, int height, int max_iter, int grain)
{
    int *buf = malloc(((size_t)HDR + (size_t)grain * width) * sizeof(int));
    if (!buf) { perror("malloc"); MPI_Abort(MPI_COMM_WORLD, 1); }
    double busy = 0.0;
    long blocks = 0, rows = 0;

    MPI_Barrier(MPI_COMM_WORLD);
    /* Req. 1: a iniciativa e do escravo. */
    MPI_Send(NULL, 0, MPI_INT, 0, TAG_REQUEST, MPI_COMM_WORLD);

    for (;;) {
        int work[2];
        MPI_Status st;
        MPI_Recv(work, 2, MPI_INT, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &st);
        if (st.MPI_TAG == TAG_STOP) break;

        int start = work[0], count = work[1];
        double c0 = MPI_Wtime();
        for (int i = 0; i < count; i++)
            mandel_row(start + i, width, height, max_iter, buf + HDR + (long)i * width);
        busy += MPI_Wtime() - c0;
        blocks++;
        rows += count;

        buf[0] = start;
        buf[1] = count;
        /* Resultado = pedido do proximo bloco. */
        MPI_Send(buf, HDR + count * width, MPI_INT, 0, TAG_RESULT, MPI_COMM_WORLD);
    }

    double stats[3] = { (double)blocks, (double)rows, busy };
    MPI_Send(stats, 3, MPI_DOUBLE, 0, TAG_STATS, MPI_COMM_WORLD);
    free(buf);
}

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank, nprocs;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);

    if (argc < 5 || nprocs < 2) {
        if (rank == 0)
            fprintf(stderr, "uso: mpirun -np P(>=2) %s <width> <height> <max_iter> <grain>\n", argv[0]);
        MPI_Finalize();
        return 1;
    }
    const int width = atoi(argv[1]), height = atoi(argv[2]);
    const int max_iter = atoi(argv[3]), grain = atoi(argv[4]);
    if (grain < 1) {
        if (rank == 0) fprintf(stderr, "grain deve ser >= 1\n");
        MPI_Finalize();
        return 1;
    }

    if (rank == 0) master(nprocs, width, height, max_iter, grain);
    else           slave(width, height, max_iter, grain);

    MPI_Finalize();
    return 0;
}
