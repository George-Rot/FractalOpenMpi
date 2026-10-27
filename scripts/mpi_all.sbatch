#!/bin/bash
#SBATCH --job-name=t2-mpi-all
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=08:00:00
#SBATCH --output=results/mpi_all_%j.out
# Roda forte, fraca e granularidade numa unica alocacao (mesmos 2 nos) e no fim
# a analise. Existe porque o LAD limita a 2 jobs enfileirados por usuario e a
# 8 h para jobs de 2 nos: o tempo somado dos tres precisa caber nesse limite.
# Os .sbatch sao executados como scripts bash (as linhas #SBATCH viram comentario).
cd "$SLURM_SUBMIT_DIR"; mkdir -p results
bash scripts/strong.sbatch > "results/strong_${SLURM_JOB_ID}.out" 2>&1
bash scripts/weak.sbatch   > "results/weak_${SLURM_JOB_ID}.out"   2>&1
bash scripts/grain.sbatch  > "results/grain_${SLURM_JOB_ID}.out"  2>&1
python3 scripts/analyze.py results
