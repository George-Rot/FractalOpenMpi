#!/bin/bash
# run_all.sh - compila e submete todos os experimentos em cadeia no Slurm.
#
# Uso: ./run_all.sh no1,no2
# Para retomar apos falha no segundo sbatch: T2_SEQ_JOB_ID=ID ./run_all.sh no1,no2
#   fixa os mesmos 2 nos para os experimentos MPI (P=64 usa --overcommit).
# Variaveis de config.sh podem ser sobrescritas, ex.: MAX_ITER=3000 ./run_all.sh no1,no2
# Modulo MPI: defina MPI_MODULE (ex.: MPI_MODULE=openmpi ./run_all.sh).
set -euo pipefail
cd "$(dirname "$0")"
if [[ $# -ne 1 ]]; then
  echo "uso: $0 no1,no2" >&2
  exit 2
fi
IFS=, read -r -a NODE_NAMES <<< "$1"
if (( ${#NODE_NAMES[@]} != 2 )); then
  echo "uso: $0 no1,no2 (dois nos distintos)" >&2
  exit 2
fi
declare -A SEEN_NODES=()
for NODE_NAME in "${NODE_NAMES[@]}"; do
  if [[ ! "$NODE_NAME" =~ ^[a-zA-Z0-9._-]+$ || -n "${SEEN_NODES[$NODE_NAME]+x}" ]]; then
    echo "informe dois nomes de nos distintos" >&2
    exit 2
  fi
  SEEN_NODES[$NODE_NAME]=1
done

if [ -n "${MPI_MODULE:-}" ]; then module load "$MPI_MODULE"; fi
make
mkdir -p results

NODES=$1
SEQ_NODE=${NODE_NAMES[0]}   # sequencial roda no primeiro no

# LAD: no maximo 2 jobs enfileirados por usuario -> 2 jobs:
#   1) sequencial (1 no)   2) forte+fraca+grain+analise numa alocacao de 2 nos
if [[ -n "${T2_SEQ_JOB_ID:-}" ]]; then
  J0=$T2_SEQ_JOB_ID
  if [[ ! "$J0" =~ ^[0-9]+$ ]]; then
    echo "T2_SEQ_JOB_ID deve ser um ID numerico do Slurm" >&2
    exit 2
  fi
else
  J0=$(sbatch --parsable -w "$SEQ_NODE" scripts/seq.sbatch)
  echo "Job sequencial submetido: $J0"
fi
if ! J1=$(sbatch --parsable -w "$NODES" --dependency="afterok:$J0" \
     --export="ALL,T2_SEQ_JOB_ID=$J0" scripts/mpi_all.sbatch); then
  echo "Falha ao submeter MPI. Para retomar sem repetir o sequencial:" >&2
  echo "T2_SEQ_JOB_ID=$J0 $0 $NODES" >&2
  exit 1
fi

echo "Jobs: seq=$J0 mpi_all=$J1"
echo "Acompanhe com: squeue -u \$USER"
echo "Ao final: results/tables.md, results/speedup.png, results/efficiency.png"
