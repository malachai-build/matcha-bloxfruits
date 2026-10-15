#!/usr/bin/env bash
# Concatenate the chunks (in name order) into the single-file fallback build.
set -e
cd "$(dirname "$0")"
mkdir -p dist
cat src/*.lua > dist/test.full.lua
printf 'dist/test.full.lua: %s lines\n' "$(wc -l < dist/test.full.lua)"
