#!/bin/bash
#SBATCH --job-name=t2-strong
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=06:00:00
#SBATCH --output=results/strong_%j.out
# Escalabilidade forte: entrada fixa, P = 2..64, REPS repeticoes cada.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source scripts/config.sh
echo "NODES $SLURM_JOB_NODELIST"
for P in $PROCS; do
  if (( P == 2 )); then STEP_NODES=2; else STEP_NODES=4; fi
  if (( P <= 32 )); then TASKS_PER_CORE=1; else TASKS_PER_CORE=2; fi
  for r in $(seq "$REPS"); do
    $MPIRUN -N "$STEP_NODES" -n "$P" --ntasks-per-core="$TASKS_PER_CORE" \
      ./bin/mandel_mpi "$WIDTH" "$HEIGHT" "$MAX_ITER" "$GRAIN" | grep '^MPI'
  done
done
