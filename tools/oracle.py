#!/usr/bin/env python3 -I
"""Reference for src/bench: same splitmix64 stream, same index draw, statistics.median, no numpy.
Reads a cases file (S seed boots n x.. | C seed boots na nb a.. b..), prints one line of IEEE bits per case.
--broken draws bootstrap indices from the wrong range: the negative control for scripts/check.sh."""
import statistics, struct, sys

M = (1 << 64) - 1
BROKEN = "--broken" in sys.argv


class Rng:
    def __init__(self, seed): self.s = seed & M

    def below(self, n):
        self.s = (self.s + 0x9E3779B97F4A7C15) & M
        z = ((self.s ^ (self.s >> 30)) * 0xBF58476D1CE4E5B9) & M
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & M
        return (z ^ (z >> 31)) % (n - 1 if BROKEN and n > 1 else n)


def pct(s, p): return s[(len(s) * p + 99) // 100 - 1]  # nearest rank


def boot(x, g):  # x sorted: a resample is a draw of ranks
    return statistics.median([x[g.below(len(x))] for _ in x])


def ci(m):
    m.sort()
    k = len(m) * 25 // 1000
    return m[k], m[len(m) - 1 - k]


def stats(x, seed, boots):
    s = sorted(x)
    med = statistics.median(s)
    q1, q3 = pct(s, 25), pct(s, 75)
    w = (q3 - q1) + (q3 - q1) / 2  # 1.5 IQR
    g = Rng(seed)
    lo, hi = ci([boot(s, g) for _ in range(boots)])
    out = sum(v < q1 - w or v > q3 + w for v in s)
    return [s[0], med, statistics.median([abs(v - med) for v in s]), pct(s, 95), lo, hi], out


def compare(a, b, seed, boots):
    sa, sb = stats(a, seed, boots)[0], stats(b, seed, boots)[0]
    g = Rng(seed)
    a, b = sorted(a), sorted(b)
    m = []
    for _ in range(boots):
        x = boot(a, g)
        m.append(x / boot(b, g))
    lo, hi = ci(m)
    v = "a faster" if sa[5] < sb[4] else "b faster" if sb[5] < sa[4] else "no difference"
    return [sa[1] / sb[1], lo, hi], v


def bits(v): return "0x%x" % struct.unpack(">Q", struct.pack(">d", v))[0]


if __name__ == "__main__":
    for line in open([a for a in sys.argv[1:] if a[0] != "-"][0]):
        t = line.split()
        seed, boots, n = int(t[1]), int(t[2]), int(t[3])
        if t[0] == "S":
            f, out = stats([float(v) for v in t[4:4 + n]], seed, boots)
            print("S", n, *map(bits, f), out)
        else:
            nb = int(t[4])
            f, v = compare([float(x) for x in t[5:5 + n]], [float(x) for x in t[5 + n:5 + n + nb]], seed, boots)
            print("C", *map(bits, f), v)
