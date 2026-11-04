# Design

- **No dependency.** Everything is stdlib: `perf_counter_ns`, `sort`, `List`. 211 lines in `src/bench/bench.mojo`.
- **Bootstrap without copies.** A resample of the median needs only how often each rank is drawn. `_resample`
  counts draws per rank in one reused `List[Int]`, then walks to the middle: no resampled array, no sort,
  O(n) per replicate. This is the 115x over the Python oracle, which builds and sorts a list per replicate.
- **Memory model.** `stats` allocates one sorted copy, one deviation vector, one count vector, one replicate
  vector, once per call. The timing loop allocates nothing. Peak RSS of the bench is 11 MB, the process baseline.
- **Reproducible.** splitmix64 seeded by `seed`; index draw is `z % n`; percentiles use nearest rank with
  integer arithmetic (no multiply-add, so no FMA drift). The Python oracle uses the same stream, so results
  match bit for bit and the gate is a `cmp`.
- **Auto iteration count.** `_prep` warms up for `warmup_ms`, then grows calls per sample until one batch takes
  `sample_ms`. Timer cost is amortized; a sample is ns per call.
- **Verdict.** Two medians differ only when their bootstrap CIs do not overlap. Otherwise "no difference".
- **bench2.** Samples alternate A then B, B then A, so thermal or load drift hits both alike. Compare timings from
  one `bench2` call, not from two separate runs.
- **Gate.** The oracle is Python, in `tools/`, never imported by the library. A `--broken` oracle (index draw from
  the wrong range) must fail the same diff, else the gate cannot be trusted.
