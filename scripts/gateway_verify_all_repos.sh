#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${1:-$(cd "$SCRIPT_ROOT/.." && pwd)}"

printf "repo\tgithub\tonedrive\tgworkspace\n"
for r in "$WORK_ROOT"/*; do
  [ -d "$r/.git" ] || continue
  n="$(basename "$r")"
  if [[ ! -x "$r/scripts/gateway_io.sh" ]]; then
    echo -e "$n\tmissing\tmissing\tmissing"
    continue
  fi
  out="$(cd "$r" && ./scripts/gateway_io.sh verify 2>&1 || true)"
  g="$(printf '%s\n' "$out" | rg -o 'github:(ok|fail)' -m1 | cut -d: -f2)"
  o="$(printf '%s\n' "$out" | rg -o 'onedrive:(ok|warn|fail)' -m1 | cut -d: -f2)"
  w="$(printf '%s\n' "$out" | rg -o 'gworkspace:(ok|warn|fail)' -m1 | cut -d: -f2)"
  echo -e "$n\t${g:-unknown}\t${o:-unknown}\t${w:-unknown}"
done
