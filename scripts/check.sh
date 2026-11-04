#!/usr/bin/env bash
# The gate. tests/cases.mojo (built to .work/cases) must print, for every case of the seeded cases file
# (tools/fixtures_oracle.py: edge vectors + 2500 random stats + 600 random compare cases), the same IEEE bits as
# tools/oracle.py. Then behaviour (tests/behavior.mojo) and the example. Negative control: the same diff against the
# oracle's --broken mode must fail, or the gate cannot be trusted. IMPL="python3 -I tools/oracle.py --broken" fails it.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
cap() { timeout 90 systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 "$@"; }  # exit 137 = over the 4G cap = a bug
M="cap .venv/bin/mojo"
IMPL=${IMPL:-.work/cases}
if [[ $IMPL == .work/cases ]]; then
  $M build -I src tests/cases.mojo -o .work/cases 2>.work/build.err || { echo "FAIL build: tests/cases.mojo"; cat .work/build.err; exit 1; }
fi
cap python3 -I tools/fixtures_oracle.py .work/cases.txt || { echo "FAIL setup: fixtures"; exit 1; }
n=$(grep -c '' .work/cases.txt)
key=$(cat .work/cases.txt tools/oracle.py | sha256sum | cut -c1-16)  # the oracle's answers are cached per (cases, oracle) hash
[[ -f .work/want-$key.txt ]] || cap python3 -I tools/oracle.py .work/cases.txt > .work/want-$key.txt || { echo "FAIL oracle: tools/oracle.py"; exit 1; }
cap $IMPL .work/cases.txt > .work/got.txt || { echo "FAIL impl: $IMPL crashed"; exit 1; }
cmp -s .work/got.txt .work/want-$key.txt || { echo "FAIL oracle: line $(cmp .work/got.txt .work/want-$key.txt | grep -o 'line [0-9]*' | cut -d' ' -f2) differs"; exit 1; }
echo "oracle: $n cases ($(grep -c '^S' .work/cases.txt) stats, $(grep -c '^C' .work/cases.txt) compare) byte-identical to tools/oracle.py"
if [[ $IMPL == .work/cases ]]; then
  cap python3 -I tools/oracle.py --broken .work/cases.txt 2>/dev/null | cmp -s - .work/want-$key.txt && { echo "FAIL negative control: broken oracle passed the diff"; exit 1; }
  echo "negative control: tools/oracle.py --broken differs from the reference, as it must"
  $M run -I src tests/behavior.mojo || { echo "FAIL behavior: tests/behavior.mojo"; exit 1; }
  for e in "quickstart README.md" "api docs/api.md"; do  # each doc code block is a compiled example, byte for byte
    set -- $e
    python3 -I -c 'import re, sys; b = re.findall(r"```mojo\n(.*?)\n```", open(sys.argv[2]).read(), re.S); sys.exit(open(sys.argv[1]).read().rstrip() not in b)' examples/$1.mojo $2 || { echo "FAIL doc: $2 block differs from examples/$1.mojo"; exit 1; }
    $M run -I src examples/$1.mojo > /dev/null || { echo "FAIL example: examples/$1.mojo"; exit 1; }
  done
fi
echo "PASS all"
