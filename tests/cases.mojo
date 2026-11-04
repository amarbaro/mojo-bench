# Reads the cases file (see tools/oracle.py), prints one line of IEEE bits per case. Gate diffs it with the oracle's.
from std.sys import argv
from std.memory import bitcast
from bench import stats, compare


def b(x: Float64) -> String:
    return hex(bitcast[DType.uint64, 1](x))


def main() raises:
    var o = String()
    for line in open(argv()[1], "r").read().split("\n"):
        var t = line.split(" ")
        if len(t) < 4:
            continue
        var seed = Int(t[1])
        var boots = Int(t[2])
        var n = Int(t[3])
        var x = List[Float64]()
        if t[0] == "S":
            for i in range(n):
                x.append(Float64(t[4 + i]))
            var s = stats(x, seed, boots)
            o += String("S ", n, " ", b(s.min), " ", b(s.median), " ", b(s.mad), " ", b(s.p95), " ", b(s.lo), " ", b(s.hi), " ", s.outliers, "\n")
        else:
            var nb = Int(t[4])
            var y = List[Float64]()
            for i in range(n):
                x.append(Float64(t[5 + i]))
            for i in range(nb):
                y.append(Float64(t[5 + n + i]))
            var c = compare(x, y, seed, boots)
            o += String("C ", b(c.speedup), " ", b(c.lo), " ", b(c.hi), " ", c.verdict, "\n")
    print(o, end="")
