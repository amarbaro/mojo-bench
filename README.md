# mojo-bench

<!-- install -->
Install: `pixi add mojo-bench` once published. For now: `git clone https://github.com/amarbaro/mojo-bench`, then `mojo run -I mojo-bench/src app.mojo`.

```mojo
from std.benchmark import keep
from bench import bench2, compare, table


def main():
    var n = 1000
    var s = UInt64(1)
    var t = UInt64(1)
    def slow() {mut s, imm n}:
        for _ in range(2 * n):
            s = s * 6364136223846793005 + 1442695040888963407
        keep(s)
    def fast() {mut t, imm n}:
        for _ in range(n):
            t = t * 6364136223846793005 + 1442695040888963407
        keep(t)
    var r = bench2("slow", slow, "fast", fast)  # samples interleaved, so drift hits both alike
    var c = compare(r[0].samples, r[1].samples)  # speedup of fast over slow, with a 95% CI
    print(table(r))
    print(c.speedup, "x [", c.lo, ",", c.hi, "]", c.verdict)
    print(r[1].json())
```

| Run | Mojo | Python oracle |
|---|---|---|
| 1 | 15 ms | 1721 ms |
Baselines and method: [docs/perf.md](docs/perf.md)
<!-- /install -->

Benchmark harness for Mojo that reports statistics, not one number: warmup, auto iteration count,
median, MAD, min, p95, seeded 95% bootstrap CI, outlier count, and `compare()` that says
"no difference" when the CIs overlap. 211 lines, no dependency beyond the stdlib. Every statistic is
checked bit for bit against a Python reference (`tools/oracle.py`) on 3117 seeded cases.

```mojo
from std.benchmark import keep
from bench import bench2, compare, table


def main():
    var n = 1000
    var s = UInt64(1)
    var t = UInt64(1)
    def slow() {mut s, imm n}:
        for _ in range(2 * n):
            s = s * 6364136223846793005 + 1442695040888963407
        keep(s)
    def fast() {mut t, imm n}:
        for _ in range(n):
            t = t * 6364136223846793005 + 1442695040888963407
        keep(t)
    var r = bench2("slow", slow, "fast", fast)  # samples interleaved, so drift hits both alike
    var c = compare(r[0].samples, r[1].samples)  # speedup of fast over slow, with a 95% CI
    print(table(r))
    print(c.speedup, "x [", c.lo, ",", c.hi, "]", c.verdict)
    print(r[1].json())
```

## Install

Requires Mojo 1.2 on Linux.

| Way | Command |
|---|---|
| Source path | `mojo run -I path/to/mojo-bench/src app.mojo` |
| Precompiled | `mojo precompile src/bench -o bench.mojoc` |
| Vendor | copy `src/bench/` into your project |

## What you get

- `bench(name, f, samples=30, warmup_ms=50, sample_ms=10, boots=1000, seed=1)`: ns per call of `f`.
- `bench2(na, f, nb, g, ...)`: two functions, samples interleaved so drift hits both alike.
- `compare(a, b)`: speedup of `b` over `a` with a bootstrap CI and a verdict.
- `stats(x)`, `table(results)`, `Result.json()`.

Docs: [api](docs/api.md), [design](docs/design.md), [perf](docs/perf.md).

## Performance

`scripts/bench.sh`: `stats()` of 200 samples with 1000 bootstrap replicates, 20 times:
Mojo 14 to 15 ms, Python oracle 1662 to 1721 ms (about 115x), peak RSS 11 MB against 12 MB.
A function 2x slower reads 2.00x with a CI of about 1.99 to 2.01 (varies by run); two copies of one function read "no difference".

## Checks

`scripts/check.sh` (10 to 25 s): builds `tests/cases.mojo`, diffs its output with `tools/oracle.py`
over 3117 cases, proves a deliberately wrong oracle (`--broken`) fails the same diff, runs
`tests/behavior.mojo`, and compiles and runs both examples, which must equal the code blocks in this
README and in `docs/api.md`. Every command runs under `systemd-run` with `MemoryMax=4G`.
`scripts/ci.sh` is the GitHub entry point.
