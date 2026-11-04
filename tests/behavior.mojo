# compare() on vectors with a known answer, then on real timings: a 2x slower function reads ~2x with a CI clear of 1,
# two copies of one function read "no difference". Raises (non-zero exit) on any miss.
from std.sys import argv
from std.testing import assert_equal, assert_true
from std.benchmark import keep
from bench import bench2, compare


def main() raises:
    var a = List[Float64]()
    var h = List[Float64]()
    for i in range(30):
        a.append(100.0 + Float64(i * 7 % 11) / 4)
        h.append(a[i] * 0.5)
    var c = compare(a, h)
    assert_equal(c.speedup, 2.0)
    assert_equal(c.verdict, "b faster")
    assert_true(c.lo > 1.0)
    assert_equal(compare(a, a).verdict, "no difference")
    var n = 300 + len(argv()) - 1  # runtime value: the loops cannot be folded
    var s1 = UInt64(1)
    var s2 = UInt64(1)
    var s3 = UInt64(1)
    def one() {mut s1, imm n}:
        for _ in range(n):
            s1 = s1 * 6364136223846793005 + 1442695040888963407
        keep(s1)
    def two() {mut s2, imm n}:
        for _ in range(2 * n):
            s2 = s2 * 6364136223846793005 + 1442695040888963407
        keep(s2)
    def same() {mut s3, imm n}:
        for _ in range(n):
            s3 = s3 * 6364136223846793005 + 1442695040888963407
        keep(s3)
    var p = bench2("one", one, "two", two)
    var r = compare(p[1].samples, p[0].samples)
    print("2x slower:", r.speedup, "CI", r.lo, r.hi, r.verdict)
    assert_true(r.speedup > 1.7 and r.speedup < 2.3)
    assert_true(r.lo > 1.0 and r.verdict == "b faster")
    var e = bench2("one", one, "same", same)
    var q = compare(e[0].samples, e[1].samples)
    print("identical:", q.speedup, "CI", q.lo, q.hi, q.verdict)
    assert_equal(q.verdict, "no difference")
