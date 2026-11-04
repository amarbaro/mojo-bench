#!/usr/bin/env bash
# tests/perf.mojo vs tools/bench_oracle.py, same work, 3 runs each: each prints its own timed work in ms;
# peak RSS of the whole process from getrusage.
set -euo pipefail
cd "$(dirname "$0")/.."
timeout 120 systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 .venv/bin/mojo build -I src tests/perf.mojo -o .work/bench 2>.work/build.err || { echo "FAIL build: tests/perf.mojo"; cat .work/build.err; exit 1; }
run() {
  systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 python3 -I -c 'import resource, subprocess, sys
out = subprocess.run(sys.argv[2:], capture_output=True, text=True, check=True).stdout.strip()
print("%-7s %s, peak RSS %d MB" % (sys.argv[1], out, resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss // 1024))' "$@" \
    || { echo "FAIL run: $1"; exit 1; }
}
for i in 1 2 3; do run mojo .work/bench; run python python3 -I tools/bench_oracle.py; done
