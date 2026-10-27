# config.sh - parametros comuns a todos os experimentos (fonte unica).
# Entrada de referencia: calibrar WIDTH/HEIGHT/MAX_ITER para T1 entre 30 e 60 s
# no Atlantica (rode scripts/seq.sbatch e ajuste MAX_ITER se preciso).
WIDTH=${WIDTH:-2000}
HEIGHT=${HEIGHT:-2000}       # = numero de tarefas (linhas) da entrada de referencia
MAX_ITER=${MAX_ITER:-20000}
GRAIN=${GRAIN:-4}            # linhas por mensagem (justificar com pingpong/grain)
REPS=${REPS:-10}
PROCS=${PROCS:-"2 4 8 16 32 64"}
GRAINS=${GRAINS:-"1 4 16 64 256"}

# Distribuicao: --map-by node espalha os ranks em round-robin entre os 2 nos
# (rank 0 = mestre no no 1, rank 1 no no 2, ...). Com P=64 cada no recebe 32
# ranks -> usa as threads de HT. Troque se o cluster exigir srun.
MPIRUN=${MPIRUN:-"mpirun --map-by node --bind-to core:overload-allowed"}

mkdir -p results
