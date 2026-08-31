#!/usr/bin/env bash
# Render docs/diagrams/*.d2 to .svg + .png.
# Usage: ./render.sh          — only .d2 files newer than their .svg
#        ./render.sh -a       — force render all
#        ./render.sh foo.d2   — render specific file(s)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v d2 >/dev/null || { echo "d2 not found — install: https://d2lang.com/tour/install" >&2; exit 1; }

force=0
files=()
for arg in "$@"; do
  case "$arg" in
    -a|--all) force=1 ;;
    *) files+=("$arg") ;;
  esac
done

if [ "${#files[@]}" -eq 0 ]; then
  for f in *.d2; do files+=("$f"); done
fi

for f in "${files[@]}"; do
  [ -f "$f" ] || { echo "skip: $f not found" >&2; continue; }
  base="${f%.d2}"
  if [ "$force" -eq 0 ] && [ -f "$base.svg" ] && [ -f "$base.png" ] && [ "$base.svg" -nt "$f" ] && [ "$base.png" -nt "$f" ]; then
    echo "up to date: $f"
    continue
  fi
  d2 --layout elk "$f" "$base.svg"
  d2 --layout elk "$f" "$base.png"
  echo "rendered: $base.svg + $base.png"
done
