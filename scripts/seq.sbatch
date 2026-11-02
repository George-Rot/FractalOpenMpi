#!/bin/bash
#SBATCH --job-name=t2-seq
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=02:00:00
#SBATCH --output=results/seq_%j.out
# Versao sequencial (T1): 10 repeticoes da entrada de referencia em 1 no.
# Tambem roda cada entrada da escalabilidade fraca (height*P) uma vez para
# conferir os checksums; pode demorar ate ~62*T1 para P=2..32.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source scripts/config.sh
hostname; lscpu
for r in $(seq "$REPS"); do ./bin/mandel_seq "$WIDTH" "$HEIGHT" "$MAX_ITER"; done
if [ "${WEAK_CHECK:-1}" = 1 ]; then
  for P in $PROCS; do ./bin/mandel_seq "$WIDTH" $((HEIGHT * P)) "$MAX_ITER"; done
fi
