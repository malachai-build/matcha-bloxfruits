#!/usr/bin/env bash
# Static gate: luau-lsp analyze on every chunk and on the concatenation.
# Pass: zero SyntaxError in every file; the concatenation lists no unknown
# globals beyond the baseline API names in dist/ug_baseline.txt.
set -e
cd "$(dirname "$0")"
LSP="${LUAU_LSP:-/c/Users/Oscar/.rokit/tool-storage/johnnymorganz/luau-lsp/1.66.1/luau-lsp.exe}"
mkdir -p dist
bash build.sh >/dev/null
fail=0
for f in src/*.lua dist/test.full.lua; do
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
exit $fail
