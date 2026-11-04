# Same work as tools/bench_oracle.py: 20 x stats() of a 200-sample vector with 1000 bootstrap replicates.
from std.time import perf_counter_ns
from std.benchmark import keep
from bench import stats


def main():
    var x = List[Float64]()
    for i in range(200):
        x.append(Float64(i * 7919 % 1000) / 8)
    var t = perf_counter_ns()
    for _ in range(20):
        keep(stats(x, 1, 1000).median)
    print("stats 20x(n=200, B=1000)", (perf_counter_ns() - t) // 1_000_000, "ms")
