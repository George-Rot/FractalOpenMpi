# Mesmas flags de otimizacao para sequencial e paralela (regra 4.2).
CC      ?= gcc
MPICC   ?= mpicc
# Sem -march=native: o no de login tem CPU mais nova que os nos de computo
# (Xeon E5520, Nehalem) e gerava "Illegal instruction".
CFLAGS  = -O3 -std=c11 -Wall -Wextra
LDLIBS  = -lm

BIN = bin

all: $(BIN)/mandel_seq $(BIN)/mandel_mpi $(BIN)/pingpong

$(BIN):
	mkdir -p $(BIN)

$(BIN)/mandel_seq: src/mandel_seq.c src/mandel.h | $(BIN)
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

$(BIN)/mandel_mpi: src/mandel_mpi.c src/mandel.h | $(BIN)
	$(MPICC) $(CFLAGS) -o $@ $< $(LDLIBS)

$(BIN)/pingpong: src/pingpong.c src/mandel.h | $(BIN)
	$(MPICC) $(CFLAGS) -o $@ $< $(LDLIBS)

seq: $(BIN)/mandel_seq

clean:
	rm -rf $(BIN)

.PHONY: all seq clean
