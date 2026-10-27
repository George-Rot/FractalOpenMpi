#!/bin/bash
#SBATCH --job-name=t2-strong
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=06:00:00
#SBATCH --output=results/strong_%j.out
# Escalabilidade forte: entrada fixa, P = 2..64, REPS repeticoes cada.
cd "$SLURM_SUBMIT_DIR"; source scripts/config.sh
echo "NODES $SLURM_JOB_NODELIST"
for P in $PROCS; do
  for r in $(seq "$REPS"); do
    $MPIRUN -np "$P" ./bin/mandel_mpi "$WIDTH" "$HEIGHT" "$MAX_ITER" "$GRAIN" | grep '^MPI'
  done
done
