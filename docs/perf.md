# Performance

Rerun: `scripts/bench.sh` (builds `tests/perf.mojo`, runs it and `tools/bench_oracle.py` 3 times each,
both under a 4G memory cap). Work: `stats()` on 200 samples with 1000 bootstrap replicates, 20 times.

| Run | Mojo | Python oracle |
|---|---|---|
| 1 | 15 ms | 1721 ms |
| 2 | 14 ms | 1662 ms |
| 3 | 15 ms | 1691 ms |
| Peak RSS | 11 MB | 12 MB |

About 115x. Source: 211 lines (`wc -l src/bench/*.mojo`).

Accuracy (`tests/behavior.mojo`, in the gate): a function doing 2x the work reads 2.00x, CI about 1.99 to 2.01 (varies by run),
"b faster"; two copies of one function read 0.9996x, CI [0.998, 1.0005], "no difference".
