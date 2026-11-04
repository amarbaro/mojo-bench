#!/usr/bin/env python3 -I
"""Writes the cases file for scripts/check.sh: hand-made edge vectors + seeded random S and C cases
(values are multiples of 1/16, so decimal text parses to the same double everywhere)."""
import random, sys

r = random.Random(20261104)
out = []


def f(v): return repr(v)


def S(x, seed=1, boots=200): out.append(f"S {seed} {boots} {len(x)} " + " ".join(map(f, x)))


def C(a, b, seed=1, boots=200): out.append(f"C {seed} {boots} {len(a)} {len(b)} " + " ".join(map(f, a + b)))


for x in ([5.0], [1.0, 2.0], [3.0, 3.0, 3.0], [1.0, 2.0, 3.0, 4.0, 100.0], [0.0, 0.0, 0.0, 1.0], list(map(float, range(1, 31))),
          [10.5, 10.25, 10.0, 10.75, 500.0, 10.5, 10.125, 9.875, 10.5, 0.5]):
    S(x)
    S(x, 7, 1000)
base = [100.0 + (i * 7 % 11) / 4 for i in range(30)]
C(base, base)
C(base, [v * 0.5 for v in base])
C([v * 0.5 for v in base], base)
for i in range(2500):  # random stats cases: all-distinct, tied, heavy-tailed
    n = r.randint(1, 60)
    k = r.choice([1, 3, 10, 1000])
    x = [r.randint(1, 16 * k) / 16 * (r.choice([1, 1, 1, 50]) if i % 3 == 0 else 1) for _ in range(n)]
    S(x, r.randint(0, 2**63 - 1) if i % 2 else r.randint(0, 99), r.choice([50, 200, 200, 500]))
for i in range(600):
    na, nb = r.randint(1, 40), r.randint(1, 40)
    c = r.randint(5, 400)
    C([r.randint(c, 2 * c) / 16 for _ in range(na)], [r.randint(c, 2 * c) * r.choice([1, 1, 2, 3]) / 16 for _ in range(nb)],
      r.randint(0, 99), 200)
open(sys.argv[1], "w").write("\n".join(out) + "\n")
