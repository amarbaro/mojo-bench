---
name: mojo-bench
description: "Statistical micro-benchmarks for Mojo: bootstrap confidence intervals, MAD, outliers, interleaved A/B runs and a compare verdict that says 'no difference' when the intervals overlap. Use when timing a Mojo function needs more than one number."
metadata:
  short-description: "Micro-benchmarks for Mojo with bootstrap CIs and interleaved A/B compare"
---

# mojo-bench

One file, stdlib only, Mojo 1.2. Same seed gives the same numbers.

## When to use

Time a Mojo function with a median and a confidence interval, or decide whether A beats B.
Not for GPU kernels (no device sync) or calls that take seconds each.

## Install

`mojo run -I src app.mojo` from a clone, or copy `src/bench/`.

## The calls

```mojo
from std.benchmark import keep
from bench import bench, bench2, compare, stats, table

def main() raises:
    var n = 1000
    var a = UInt64(1)
    var b = UInt64(1)
    def fast() {mut a, imm n}:
        for _ in range(n):
            a = a * 6364136223846793005 + 1442695040888963407
        keep(a)
    def slow() {mut b, imm n}:
        for _ in range(2 * n):
            b = b * 6364136223846793005 + 1442695040888963407
        keep(b)
    var r = bench("fast", fast, samples=10, boots=200)   # Result: name, samples, stats
    print(table([r.copy()]))
    print(r.json())
    var p = bench2("fast", fast, "slow", slow, samples=10, boots=200)  # interleaved ABBA samples
    var c = compare(p[0].samples, p[1].samples)          # c.speedup (a/b), c.lo, c.hi, c.verdict
    print(c.verdict)
    var s = stats(p[0].samples, 1, 200)                  # any List[Float64]
    print(s.median, s.mad, s.p95, s.outliers)
```

## Gotchas

- Always `keep(result)` inside the timed function, or the optimizer may delete the work.
- Timed functions use the Mojo 1.2 capture form `def f() {mut s, imm n}:`.
- Two closures passed to `bench2` must not capture the same `mut` variable (aliasing error): one state variable each.
- A loop bound that is a compile-time constant can fold away: take it from a runtime value.
- Compare numbers from one `bench2` call, not two separate runs: drift between runs can exceed the effect.
- `compare` reports "no difference" when the two median intervals overlap; do not claim a speedup then.

## Gate

`scripts/check.sh` from the repo: oracle cases byte-identical to `tools/oracle.py`, a broken oracle must fail,
behaviour tests, README and `docs/api.md` code blocks compiled. `scripts/bench.sh` for the Python comparison.
