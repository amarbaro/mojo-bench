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
