# Mesmas flags de otimizacao para sequencial e paralela (regra 4.2).
CC      ?= gcc
MPICC   ?= mpicc
CFLAGS  = -O3 -march=native -std=c11 -Wall -Wextra
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
