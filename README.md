# T2 – Mestre/escravo com MPI: fractal de Mandelbrot

Reaplicação do fractal do T1 no modelo mestre/escravo. **Tarefa = 1 linha da imagem**;
a granularidade (`grain`) define quantas linhas vão por mensagem.

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `src/mandel.h` | cálculo de uma linha + checksum (compartilhado) |
| `src/mandel_seq.c` | versão sequencial (T1) |
| `src/mandel_mpi.c` | mestre/escravo: tags `REQUEST/RESULT/WORK/STOP/STATS` |
| `src/pingpong.c` | tempo de tarefa × ida‑e‑volta de mensagem do mesmo tamanho |
| `scripts/*.sbatch` | jobs Slurm (seq, forte, fraca, granularidade) |
| `scripts/config.sh` | parâmetros únicos (entrada, P, grains, reps, mpirun) |
| `scripts/analyze.py` | tabelas (mediana/mín/máx), speed-up e eficiência |

## Requisitos da seção 2 (onde estão)
1. Iniciativa do escravo: `TAG_REQUEST` inicial; cada `TAG_RESULT` é novo pedido.
2. `MPI_Recv(..., MPI_ANY_SOURCE, MPI_ANY_TAG, ...)` no mestre.
3. Resultado leva `start` e é copiado em `img + start*width`.
4. Saco vazio → `TAG_STOP` (mensagem vazia).
5. Último bloco é `min(grain, restante)`; P ≥ 2 qualquer.
6. `grain` é o 4º argumento.

## Comandos
```bash
make                                  # bin/mandel_seq, bin/mandel_mpi, bin/pingpong
./bin/mandel_seq 2000 2000 20000      # teste local
mpirun -np 4 ./bin/mandel_mpi 2000 2000 20000 4

# no Atlântica (sempre os mesmos 2 nós: acrescente -w no1,no2)
sbatch scripts/seq.sbatch             # T1 (ajuste MAX_ITER p/ 30–60 s)
sbatch scripts/strong.sbatch
sbatch scripts/weak.sbatch
sbatch scripts/grain.sbatch
python3 scripts/analyze.py            # results/tables.md, speedup.png, efficiency.png
```
Parâmetros podem ser sobrescritos por ambiente, ex.: `MAX_ITER=30000 sbatch scripts/strong.sbatch`.

## Metodologia
- Região medida: `MPI_Wtime()` no mestre, após `MPI_Barrier`, do início da distribuição até o último resultado; alocação/estatísticas fora. No sequencial, só o laço de linhas.
- Equivalência: toda execução imprime `checksum` e `total_iters`; o checksum pondera a posição da linha, então detecta linhas fora de ordem.
- Fraca: `height = HEIGHT × P` com largura e região fixas → custo médio por tarefa constante; `total_iters` comprova o crescimento ~P.
- Distribuição: `mpirun --map-by node` (round-robin entre os 2 nós).
