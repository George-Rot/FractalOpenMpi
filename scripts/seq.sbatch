#!/bin/bash
#SBATCH --job-name=t2-seq
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=02:00:00
#SBATCH --output=results/seq_%j.out
# Versao sequencial (T1): 10 repeticoes da entrada de referencia em 1 no.
# Tambem roda as entradas da escalabilidade fraca (height*P) so para conferir
# os checksums (1 repeticao; desligue com WEAK_CHECK=0).
cd "$SLURM_SUBMIT_DIR"; source scripts/config.sh
hostname; lscpu
for r in $(seq "$REPS"); do ./bin/mandel_seq "$WIDTH" "$HEIGHT" "$MAX_ITER"; done
if [ "${WEAK_CHECK:-1}" = 1 ]; then
  for P in 2 4; do ./bin/mandel_seq "$WIDTH" $((HEIGHT * P)) "$MAX_ITER"; done
fi
