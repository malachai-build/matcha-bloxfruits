#!/usr/bin/env bash
# Static gate: luau-lsp analyze on every chunk, the concatenation, loader.lua
# and the generated loader failure-path harness; plus the static stability
# rules in tests/static_stability.py (when Python is available).
# Pass: zero SyntaxError in every file; the concatenation lists no unknown
# globals beyond the baseline names in dist/ug_baseline.txt; every rule passes.
set -e
cd "$(dirname "$0")"
LSP="${LUAU_LSP:-/c/Users/Oscar/.rokit/tool-storage/johnnymorganz/luau-lsp/1.66.1/luau-lsp.exe}"
mkdir -p dist
bash build.sh >/dev/null
fail=0
PY="$(command -v python || command -v python3 || true)"
if [ -n "$PY" ]; then "$PY" -I tests/make_loader_harness.py dist/loader_harness.luau >/dev/null; fi
for f in src/*.lua dist/test.full.lua loader.lua $( [ -f dist/loader_harness.luau ] && echo dist/loader_harness.luau ); do
  out="dist/an_$(basename "$f" .lua).txt"
  "$LSP" analyze --platform=standard "$f" > "$out" 2>&1 || true
  syn=$(grep -c SyntaxError "$out" || true)
  printf '%-24s syntax errors: %s\n' "$f" "$syn"
  [ "$syn" = "0" ] || fail=1
done
if [ -f dist/ug_baseline.txt ]; then
  grep -oE "Unknown global '[A-Za-z_0-9]+'" dist/an_test.full.txt | sed -E "s/Unknown global '//;s/'//" | sort -u > dist/ug_full.txt
  extra=$(comm -13 <(sort -u dist/ug_baseline.txt) dist/ug_full.txt)
  if [ -n "$extra" ]; then echo "concatenation has unknown globals beyond the baseline:"; echo "$extra"; fail=1; else echo "concatenation: no unknown globals beyond the baseline"; fi
fi
if [ -n "$PY" ]; then
  if "$PY" -I tests/static_stability.py . > dist/static_stability.txt 2>&1; then
    echo "static stability rules: $(grep -c '^PASS' dist/static_stability.txt) passed"
  else
    cat dist/static_stability.txt; fail=1
  fi
else
  echo "static stability rules: skipped (no python)"
fi
exit $fail
