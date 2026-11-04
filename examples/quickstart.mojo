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
