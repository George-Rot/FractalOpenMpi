#!/bin/bash
#SBATCH --job-name=t2-grain
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --exclusive
#SBATCH --time=04:00:00
#SBATCH --output=results/grain_%j.out
# Granularidade e balanceamento com P=32:
#  (a) tempo de tarefa vs ida e volta (intra-no e inter-no)
#  (b) varias granularidades
#  (c) linhas SLAVE: blocos, linhas e tempo ocupado por escravo
cd "$SLURM_SUBMIT_DIR"; source scripts/config.sh
echo "NODES $SLURM_JOB_NODELIST"
for G in $GRAINS; do
  echo "# intra-no"; mpirun -np 2 --map-by core ./bin/pingpong "$WIDTH" "$HEIGHT" "$MAX_ITER" "$G"
  echo "# inter-no"; mpirun -np 2 --map-by node ./bin/pingpong "$WIDTH" "$HEIGHT" "$MAX_ITER" "$G"
done
for G in $GRAINS; do
  for r in $(seq "$REPS"); do
    $MPIRUN -np 32 ./bin/mandel_mpi "$WIDTH" "$HEIGHT" "$MAX_ITER" "$G"
  done
done
