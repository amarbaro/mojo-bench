"""Benchmark harness: warmup, auto iteration count, median/MAD/min/p95, seeded bootstrap CI, compare."""
from std.time import perf_counter_ns
from std.builtin.sort import sort


struct Rng:  # splitmix64: the same stream tools/oracle.py draws from
    var s: UInt64

    def __init__(out self, seed: Int):
        self.s = UInt64(seed)

    def below(mut self, n: Int) -> Int:
        self.s += 0x9E3779B97F4A7C15
        var z = (self.s ^ (self.s >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        return Int((z ^ (z >> 31)) % UInt64(n))


def _med(s: Span[Float64, _]) -> Float64:  # s sorted
    var n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def _pct(s: Span[Float64, _], p: Int) -> Float64:  # s sorted, nearest rank (no multiply-add, so no FMA drift from Python)
    return s[(len(s) * p + 99) // 100 - 1]


def _resample(s: Span[Float64, _], mut c: List[Int], mut g: Rng) -> Float64:
    """Median of n draws from sorted s: count the draws per rank, walk to the middle. No sort, no copy."""
    var n = len(s)
    for i in range(n):
        c[i] = 0
    for _ in range(n):
        c[g.below(n)] += 1
    var a = 0.0
    var b = 0.0
    var acc = 0
    for i in range(n):
        var prev = acc
        acc += c[i]
        if prev <= (n - 1) // 2 and (n - 1) // 2 < acc:
            a = s[i]
        if prev <= n // 2 and n // 2 < acc:
            b = s[i]
            break
    return (a + b) / 2


def _ci(mut m: List[Float64]) -> Tuple[Float64, Float64]:  # central 95% of the sorted replicates
    sort(m)
    var k = len(m) * 25 // 1000
    return (m[k], m[len(m) - 1 - k])


@fieldwise_init
struct Stats(Copyable, Writable):
    var n: Int
    var min: Float64
    var median: Float64
    var mad: Float64
    var p95: Float64
    var lo: Float64  # bootstrap 95% CI of the median
    var hi: Float64
    var outliers: Int  # beyond Tukey's 1.5 IQR fences


def stats(x: Span[Float64, _], seed: Int = 1, boots: Int = 1000) -> Stats:
    var s = List[Float64](x)
    sort(s)
    var med = _med(s)
    var d = List[Float64](length=len(x), fill=0.0)
    for i in range(len(x)):
        d[i] = abs(s[i] - med)
    sort(d)
    var mad = _med(d)
    var cnt = List[Int](length=len(x), fill=0)
    var q1 = _pct(s, 25)
    var q3 = _pct(s, 75)
    var w = (q3 - q1) + (q3 - q1) / 2  # 1.5 IQR
    var out = 0
    for v in s:
        out += Int(v < q1 - w or v > q3 + w)
    var g = Rng(seed)
    var m = List[Float64](length=boots, fill=0.0)
    for b in range(boots):
        m[b] = _resample(s, cnt, g)
    var c = _ci(m)
    var p95 = _pct(s, 95)
    return Stats(len(x), s[0], med, mad, p95, c[0], c[1], out)


@fieldwise_init
struct Cmp(Copyable, Writable):
    var speedup: Float64  # median(a) / median(b): above 1, b is faster
    var lo: Float64  # bootstrap 95% CI of the ratio
    var hi: Float64
    var verdict: String  # "no difference" when the two median CIs overlap


def compare(a: Span[mut=False, Float64, _], b: Span[mut=False, Float64, _], seed: Int = 1, boots: Int = 1000) -> Cmp:
    var sa = stats(a, seed, boots)
    var sb = stats(b, seed, boots)
    var xa = List[Float64](a)
    var xb = List[Float64](b)
    sort(xa)
    sort(xb)
    var ca = List[Int](length=len(a), fill=0)
    var cb = List[Int](length=len(b), fill=0)
    var g = Rng(seed)
    var m = List[Float64](length=boots, fill=0.0)
    for i in range(boots):
        var x = _resample(xa, ca, g)
        m[i] = x / _resample(xb, cb, g)
    var c = _ci(m)
    var v = String("no difference")
    if sa.hi < sb.lo:
        v = "a faster"
    elif sb.hi < sa.lo:
        v = "b faster"
    return Cmp(sa.median / sb.median, c[0], c[1], v^)


@fieldwise_init
struct Result(Copyable):
    var name: String
    var iters: Int  # calls per sample
    var samples: List[Float64]  # ns per call
    var s: Stats

    def json(self) -> String:
        var q = String(self.name).replace("\\", "\\\\").replace('"', '\\"')
        return String(
            '{"name":"', q, '","iters":', self.iters, ',"n":', self.s.n, ',"min":', self.s.min,
            ',"median":', self.s.median, ',"mad":', self.s.mad, ',"p95":', self.s.p95,
            ',"ci_lo":', self.s.lo, ',"ci_hi":', self.s.hi, ',"outliers":', self.s.outliers, "}",
        )


def _t[F: def() -> None](f: F, n: Int) -> Int:
    var t = Int(perf_counter_ns())
    for _ in range(n):
        f()
    return Int(perf_counter_ns()) - t


def _prep[F: def() -> None](f: F, warmup_ms: Int, sample_ms: Int) -> Int:  # warm up, return calls per sample
    var t0 = Int(perf_counter_ns())
    while Int(perf_counter_ns()) - t0 < warmup_ms * 1_000_000:
        f()
    var iters = 1
    var goal = sample_ms * 1_000_000
    while True:
        var t = _t(f, iters)
        if t >= goal:
            return iters
        iters = max(iters + 1, Int(Float64(iters) * Float64(goal) * 1.1 / Float64(max(t, 1))))


def bench[F: def() -> None](name: String, f: F, samples: Int = 30, warmup_ms: Int = 50, sample_ms: Int = 10, boots: Int = 1000, seed: Int = 1) -> Result:
    """ns per call of f over `samples` batches of about sample_ms each. Wrap results in std.benchmark.keep."""
    var iters = _prep(f, warmup_ms, sample_ms)
    var x = List[Float64](length=samples, fill=0.0)
    for i in range(samples):
        x[i] = Float64(_t(f, iters)) / Float64(iters)
    var s = stats(x, seed, boots)
    return Result(name, iters, x^, s^)


def bench2[F: def() -> None, G: def() -> None](na: String, f: F, nb: String, g: G, samples: Int = 30, warmup_ms: Int = 50, sample_ms: Int = 10, boots: Int = 1000, seed: Int = 1) -> List[Result]:
    """bench of two functions with their samples interleaved (ABBA), so clock or load drift hits both alike: use it before compare()."""
    var ia = _prep(f, warmup_ms, sample_ms)
    var ib = _prep(g, warmup_ms, sample_ms)
    var xa = List[Float64](length=samples, fill=0.0)
    var xb = List[Float64](length=samples, fill=0.0)
    for i in range(samples):
        if i % 2:
            xb[i] = Float64(_t(g, ib)) / Float64(ib)
            xa[i] = Float64(_t(f, ia)) / Float64(ia)
        else:
            xa[i] = Float64(_t(f, ia)) / Float64(ia)
            xb[i] = Float64(_t(g, ib)) / Float64(ib)
    var sa = stats(xa, seed, boots)
    var sb = stats(xb, seed, boots)
    return [Result(na, ia, xa^, sa^), Result(nb, ib, xb^, sb^)]


def _u(x: Float64) -> String:  # 3 significant-ish digits with a unit
    var d = 1.0
    var u = "ns"
    if x >= 1e6:
        d = 1e6
        u = "ms"
    elif x >= 1e3:
        d = 1e3
        u = "us"
    var c = Int(x / d * 100 + 0.5)
    return String(c // 100, ".", "0" if c % 100 < 10 else "", c % 100, u)


def _p(s: String, w: Int) -> String:  # right-align in w columns, left-align when w < 0
    var k = max(abs(w) - s.byte_length(), 0)
    return s + " " * k if w < 0 else " " * k + s


def table(rs: List[Result]) -> String:
    var o = String("name              median        MAD         min         p95   95% CI of median        out\n")
    for r in rs:
        o += String(_p(r.name, -16), _p(_u(r.s.median), 11), _p(_u(r.s.mad), 11), _p(_u(r.s.min), 11), _p(_u(r.s.p95), 11),
            "   [", _u(r.s.lo), ", ", _u(r.s.hi), "]  ", r.s.outliers, "/", r.s.n, "\n")
    return o^
