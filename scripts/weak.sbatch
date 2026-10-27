#!/bin/bash
#SBATCH --job-name=t2-weak
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=08:00:00
#SBATCH --output=results/weak_%j.out
# Escalabilidade fraca: tarefas = HEIGHT * P. A largura (custo de cada linha)
# e a regiao do plano sao fixas, entao o custo medio por tarefa se mantem e o
# trabalho total (total_iters impresso) cresce ~P vezes.
cd "$SLURM_SUBMIT_DIR"; source scripts/config.sh
echo "NODES $SLURM_JOB_NODELIST"
for P in $PROCS; do
  H=$((HEIGHT * P))
  for r in $(seq "$REPS"); do
    $MPIRUN -np "$P" ./bin/mandel_mpi "$WIDTH" "$H" "$MAX_ITER" "$GRAIN" | grep '^MPI'
  done
done
