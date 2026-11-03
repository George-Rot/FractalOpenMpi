# T2 – Mestre/escravo com MPI: fractal de Mandelbrot

Reaplicação do fractal do T1 no modelo mestre/escravo. **Tarefa = 1 linha da imagem**;
a granularidade (`grain`) define quantas linhas vão por mensagem.

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `src/mandel.h` | cálculo de uma linha + checksum (compartilhado) |
| `src/mandel_seq.c` | versão sequencial (T1) |
| `src/mandel_mpi.c` | mestre/escravo: tags `REQUEST/RESULT/WORK/STOP`; estatísticas via `MPI_Gather` |
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

## Rodar tudo
```bash
./run_all.sh no1,no2  # compila e submete seq, forte, fraca, grain e analise
```

## Comandos
```bash
make                                  # bin/mandel_seq, bin/mandel_mpi, bin/pingpong
./bin/mandel_seq 2500 6000 2000       # entrada de referencia
srun -n 4 ./bin/mandel_mpi 2500 6000 2000 4

# no Atlântica (alocacao exclusiva de 2 nós; P=64 usa --overcommit)
mkdir -p results                      # necessário antes de sbatch abrir results/*.out
sbatch -w no1 scripts/seq.sbatch      # T1 (ajuste MAX_ITER p/ 30–60 s)
sbatch -w no1,no2 scripts/strong.sbatch
sbatch -w no1,no2 scripts/weak.sbatch
sbatch -w no1,no2 scripts/grain.sbatch
sbatch -w no1,no2 scripts/mpi_all.sbatch  # forte+fraca+grain+analise num job so
python3 scripts/analyze.py            # results/tables.md, speedup.png, efficiency.png
```
Parâmetros podem ser sobrescritos por ambiente, ex.: `MAX_ITER=4000 sbatch -w no1,no2 scripts/strong.sbatch`.

## Metodologia
- Região medida: `MPI_Wtime()` no mestre, após `MPI_Barrier`, do início da distribuição até o último resultado; alocação/estatísticas fora. No sequencial, só o laço de linhas.
- Equivalência: toda execução imprime `checksum` e `total_iters`; o checksum pondera a posição da linha, então detecta linhas fora de ordem.
- Fraca: `height = HEIGHT × P` com largura e região fixas → custo médio por tarefa constante; `total_iters` comprova o crescimento ~P.
- Distribuição: `srun --distribution=cyclic` nos mesmos dois nós, com P/2 ranks por nó. P<=16 usa no máximo um rank por núcleo físico; P=32 usa os dois threads por núcleo. P=64 usa `--overcommit` e 32 ranks por nó, compartilhando as 16 CPUs lógicas de cada nó. Os tempos de P=64 medem contenção por CPU e devem ser identificados como sobrealocados.
- Os nós observados têm 8 núcleos físicos e 16 threads cada. A configuração com dois nós respeita a regra de alocação do enunciado, mas P=64 excede os 32 threads de hardware disponíveis. Os logs e o PDF existentes descrevem execuções anteriores.
