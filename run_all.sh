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

J0=$(sbatch --parsable $SEQ_NODES scripts/seq.sbatch)
J1=$(sbatch --parsable $NODES --dependency=afterany:$J0 scripts/strong.sbatch)
J2=$(sbatch --parsable $NODES --dependency=afterany:$J1 scripts/weak.sbatch)
J3=$(sbatch --parsable $NODES --dependency=afterany:$J2 scripts/grain.sbatch)
# Analise final roda sozinha ao fim (job leve, 1 no, nao exclusivo).
J4=$(sbatch --parsable --dependency=afterany:$J3 --nodes=1 --ntasks=1 --time=00:10:00 \
     --job-name=t2-analyze --output=results/analyze_%j.out \
     --wrap="python3 scripts/analyze.py results")

echo "Jobs: seq=$J0 strong=$J1 weak=$J2 grain=$J3 analyze=$J4"
echo "Acompanhe com: squeue -u \$USER"
echo "Ao final: results/tables.md, results/speedup.png, results/efficiency.png"
