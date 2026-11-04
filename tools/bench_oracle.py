#!/usr/bin/env python3 -I
"""Same work as tests/perf.mojo: 20 x stats() of a 200-sample vector with 1000 bootstrap replicates."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

x = [float(i * 7919 % 1000) / 8 for i in range(200)]
t = time.perf_counter()
for _ in range(20):
    s = oracle.stats(x, 1, 1000)
print("stats 20x(n=200, B=1000)", round((time.perf_counter() - t) * 1000), "ms")
