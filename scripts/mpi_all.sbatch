#!/bin/bash
#SBATCH --job-name=t2-mpi-all
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=04:00:00
#SBATCH --output=results/mpi_all_%j.out
# Roda forte, fraca e granularidade numa unica alocacao (mesmos 2 nos) e no fim
# a analise. Existe porque o LAD limita a 2 jobs enfileirados por usuario e a
# o tempo total do job precisa caber nas 4 h solicitadas abaixo.
# Os .sbatch sao executados como scripts bash (as linhas #SBATCH viram comentario).
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
mkdir -p results
echo "Distribuicao P=64 (ranks por no):"
srun -N 2 -n 64 --ntasks-per-node=32 --overcommit --cpu-bind=none hostname | sort | uniq -c
bash scripts/strong.sbatch > "results/strong_${SLURM_JOB_ID}.out" 2>&1
bash scripts/weak.sbatch   > "results/weak_${SLURM_JOB_ID}.out"   2>&1
bash scripts/grain.sbatch  > "results/grain_${SLURM_JOB_ID}.out"  2>&1
python3 scripts/analyze.py results "${T2_SEQ_JOB_ID:-}" "$SLURM_JOB_ID"
