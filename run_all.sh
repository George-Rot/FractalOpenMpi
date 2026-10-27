#!/bin/bash
# run_all.sh - compila e submete todos os experimentos em cadeia no Slurm.
#
# Uso: ./run_all.sh [no1,no2]
#   no1,no2  (opcional) fixa sempre os mesmos 2 nos (regra 4.1)
# Variaveis de config.sh podem ser sobrescritas, ex.: MAX_ITER=30000 ./run_all.sh
# Modulo MPI: defina MPI_MODULE (ex.: MPI_MODULE=openmpi ./run_all.sh).
set -e
cd "$(dirname "$0")"

[ -n "$MPI_MODULE" ] && module load "$MPI_MODULE"
make
mkdir -p results

NODES=${1:+-w $1}
SEQ_NODES=${1:+-w ${1%%,*}}   # sequencial roda no primeiro no

# LAD: no maximo 2 jobs enfileirados por usuario -> 2 jobs:
#   1) sequencial (1 no)   2) forte+fraca+grain+analise numa alocacao de 2 nos
J0=$(sbatch --parsable $SEQ_NODES scripts/seq.sbatch)
J1=$(sbatch --parsable $NODES --dependency=afterany:$J0 scripts/mpi_all.sbatch)

echo "Jobs: seq=$J0 mpi_all=$J1"
echo "Acompanhe com: squeue -u \$USER"
echo "Ao final: results/tables.md, results/speedup.png, results/efficiency.png"
