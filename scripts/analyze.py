#!/usr/bin/env python3
"""analyze.py - le results/*.out, gera tabelas (mediana/min/max) e graficos.

Uso: python3 scripts/analyze.py [results [seq_job_id mpi_job_id]]
Saidas: results/tables.md, results/speedup.png, results/efficiency.png
"""
import glob, os, re, sys
from collections import defaultdict
from statistics import median

d = sys.argv[1] if len(sys.argv) > 1 else "results"
seq_job_id = sys.argv[2] if len(sys.argv) > 2 else ""
mpi_job_id = sys.argv[3] if len(sys.argv) > 3 else ""
KV = re.compile(r"(\w+)=([\w.\-]+)")

def result_files(prefix):
    job_id = seq_job_id if prefix == "seq" else mpi_job_id
    pattern = f"{prefix}_{job_id}.out" if job_id else f"{prefix}_*.out"
    return sorted(glob.glob(os.path.join(d, pattern)))

def parse(prefix, tag):
    rows = []
    for f in result_files(prefix):
        for line in open(f):
            if line.startswith(tag):
                rows.append(dict(KV.findall(line)))
    return rows

def stats(v): return median(v), min(v), max(v)

out = []
seq = parse("seq", "SEQ")
ref_w = int(os.environ.get("WIDTH", 2000))
ref_h = int(os.environ.get("HEIGHT", 4000))
ref_iter = int(os.environ.get("MAX_ITER", 2000))
seq_ref = [r for r in seq if (int(r["width"]), int(r["height"]), int(r["max_iter"]))
           == (ref_w, ref_h, ref_iter)]
if not seq_ref:
    sys.exit("sem resultado sequencial da entrada de referencia em %s" % d)
T1, T1min, T1max = stats([float(r["time"]) for r in seq_ref])
seq_ck = {(int(r["width"]), int(r["height"]), int(r["max_iter"])): r["checksum"]
          for r in seq}
out += ["## Sequencial", f"T1 mediana={T1:.3f}s min={T1min:.3f} max={T1max:.3f} "
        f"checksum={seq_ref[0]['checksum']} total_iters={seq_ref[0]['total_iters']}", ""]

def scaling(prefix, title, weak):
    rows = parse(prefix, "MPI")
    by = defaultdict(list)
    for r in rows: by[int(r["P"])].append(r)
    res = {}
    out.extend([f"## {title}", "| P | tarefas | total_iters | Tp mediana | min | max | S | E | checksum ok |",
                "|---|---|---|---|---|---|---|---|---|"])
    for P in sorted(by):
        t = [float(r["time"]) for r in by[P]]
        med, mn, mx = stats(t)
        h = int(by[P][0]["height"])
        ck = {r["checksum"] for r in by[P]}
        key = (int(by[P][0]["width"]), h, int(by[P][0]["max_iter"]))
        ok = ("sem referencia" if key not in seq_ck else
              ("sim" if ck == {seq_ck[key]} else "NAO"))
        S = T1 / med
        E = S if weak else S / P  # fraca: E = T1/Tp
        res[P] = (S, E)
        out.append(f"| {P} | {h} | {by[P][0]['total_iters']} | {med:.3f} | {mn:.3f} | {mx:.3f} | "
                   f"{S:.2f} | {E:.3f} | {ok} |")
    out.append("")
    return res

strong = scaling("strong", "Escalabilidade forte", False)
weak = scaling("weak", "Escalabilidade fraca (E = T1/Tp)", True)

# Granularidade
pp = parse("grain", "PINGPONG")
if pp:
    out += ["## Tarefa vs ida e volta (pares: intra-no, inter-no)",
            "| grain | bytes | rtt (us) | tarefa media (us) | razao |", "|---|---|---|---|---|"]
    for r in pp:
        out.append(f"| {r['grain']} | {r['bytes']} | {float(r['rtt'])*1e6:.1f} | "
                   f"{float(r['task_avg'])*1e6:.1f} | {r['ratio']} |")
    out.append("")
g = defaultdict(list); slaves = defaultdict(lambda: defaultdict(list))
for f in result_files("grain"):
    cur = None
    for line in open(f):
        kv = dict(KV.findall(line))
        if line.startswith("MPI"):
            cur = int(kv["grain"]); g[cur].append(float(kv["time"]))
        elif line.startswith("SLAVE") and cur is not None:
            slaves[cur][int(kv["rank"])].append((float(kv["rows"]), float(kv["busy"])))
if g:
    out += ["## Granularidade (P=32)", "| grain | T mediana | min | max | S |", "|---|---|---|---|---|"]
    for G in sorted(g):
        med, mn, mx = stats(g[G])
        out.append(f"| {G} | {med:.3f} | {mn:.3f} | {mx:.3f} | {T1/med:.2f} |")
    out.append("")
    for G in sorted(slaves):
        out += [f"### Carga por escravo, grain={G} (mediana das repeticoes)",
                "| rank | linhas | ocupado (s) |", "|---|---|---|"]
        for rk in sorted(slaves[G]):
            v = slaves[G][rk]
            out.append(f"| {rk} | {median(x[0] for x in v):.0f} | {median(x[1] for x in v):.3f} |")
        out.append("")

open(os.path.join(d, "tables.md"), "w").write("\n".join(out))
print("\n".join(out))

try:
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
except ImportError:
    sys.exit("matplotlib ausente: graficos nao gerados")
if strong:
    P = sorted(strong)
    plt.figure(); plt.plot(P, [strong[p][0] for p in P], "o-", label="medido")
    plt.plot(P, P, "k--", label="ideal (S=P)"); plt.xscale("log", base=2); plt.yscale("log", base=2)
    plt.xlabel("processos (P)"); plt.ylabel("speed-up"); plt.legend(); plt.grid(alpha=.3)
    plt.title("Escalabilidade forte"); plt.savefig(os.path.join(d, "speedup.png"), dpi=150)
    plt.figure()
    plt.plot(P, [strong[p][1] for p in P], "o-", label="forte (S/P)")
    if weak:
        W = sorted(weak); plt.plot(W, [weak[p][1] for p in W], "s-", label="fraca (T1/Tp)")
    plt.xscale("log", base=2); plt.ylim(0, 1.1); plt.xlabel("processos (P)"); plt.ylabel("eficiencia")
    plt.legend(); plt.grid(alpha=.3); plt.title("Eficiencia")
    plt.savefig(os.path.join(d, "efficiency.png"), dpi=150)
