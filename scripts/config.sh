# config.sh - parametros comuns a todos os experimentos (fonte unica).
# Entrada de referencia candidata: 2500x6000x2000 levou 34.511247 s em
# uma execucao isolada; confirme T1 pela mediana do job sequencial.
WIDTH=${WIDTH:-2500}
HEIGHT=${HEIGHT:-6000}       # = numero de tarefas (linhas) da entrada de referencia
MAX_ITER=${MAX_ITER:-2000}
GRAIN=${GRAIN:-4}            # linhas por mensagem (justificar com pingpong/grain)
REPS=${REPS:-10}
# Limite do cluster: 16 tarefas MPI por no; em 2 nos, P<=32.
# A distribuicao ciclica coloca ate 16 ranks em cada no.
PROCS=${PROCS:-"2 4 8 16 32"}
GRAINS=${GRAINS:-"1 4 16 64 256"}

# Distribuicao: no LAD os programas MPI sao lancados com srun (manual do LAD).
# --distribution=cyclic espalha os ranks em round-robin entre os 2 nos
# (rank 0 = mestre no no 1, rank 1 no no 2, ...). Com P=32 cada no recebe
# 16 ranks.
MPIRUN=${MPIRUN:-"srun --distribution=cyclic"}

mkdir -p results
