# API

`from bench import ...`. Times are ns per call. None of these raise.

```mojo
from std.benchmark import keep
from bench import bench, stats, compare, table


def main() raises:
    var x: List[Float64] = [10.0, 11.0, 12.0, 13.0, 100.0]
    var s = stats(x, 1, 200)  # seed 1, 200 bootstrap replicates
    print(s.median, s.mad, s.outliers)
    var n = 1000
    var acc = UInt64(1)
    def work() {mut acc, imm n}:
        for _ in range(n):
            acc = acc * 6364136223846793005 + 1442695040888963407
        keep(acc)
    var r = bench("lcg", work, samples=10, boots=200)
    print(table([r.copy()]))
    print(r.json())
    print(compare(x, x).verdict)
```

## Functions

| Signature | What |
|---|---|
| `bench[F: def() -> None](name, f, samples=30, warmup_ms=50, sample_ms=10, boots=1000, seed=1) -> Result` | Warm up `f`, pick calls per sample to fill `sample_ms`, time `samples` batches. |
| `bench2[F, G](na, f, nb, g, samples=30, warmup_ms=50, sample_ms=10, boots=1000, seed=1) -> List[Result]` | Two functions, samples interleaved (ABBA). `f` and `g` must not capture the same `mut` variable. |
| `stats(x: Span[Float64], seed=1, boots=1000) -> Stats` | Statistics of any sample vector. |
| `compare(a, b, seed=1, boots=1000) -> Cmp` | Speedup `median(a)/median(b)`, bootstrap CI of the ratio, verdict. |
| `table(rs: List[Result]) -> String` | Aligned table, one row per result. |

## Types

| Type | Fields |
|---|---|
| `Stats` | `n, min, median, mad, p95, lo, hi, outliers`. `lo`, `hi`: 95% CI of the median. `outliers`: beyond Tukey's 1.5 IQR fences. |
| `Cmp` | `speedup` (above 1: `b` faster), `lo`, `hi`, `verdict`: `"a faster"`, `"b faster"` or `"no difference"` (median CIs overlap). |
| `Result` | `name, iters` (calls per sample), `samples`, `s: Stats`; `json() -> String`. |

## Notes

- Wrap the result of the timed work in `std.benchmark.keep`, or the optimizer may delete it.
- Same `seed` and `boots` give the same numbers; the PRNG is splitmix64.
- `stats` and `compare` need a non-empty vector.
