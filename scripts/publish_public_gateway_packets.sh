#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${1:-$(cd "$SCRIPT_ROOT/.." && pwd)}"
ONEDRIVE_ROOT="${GATEWAY_ONEDRIVE_ROOT:-}"
GWORK_ROOT="${GATEWAY_GWORKSPACE_ROOT:-}"
STAMP="$(date +%Y%m%d_%H%M%S)"
TAG="public_intel_${STAMP}"

if [[ -z "$ONEDRIVE_ROOT" || -z "$GWORK_ROOT" ]]; then
  echo "Usage: GATEWAY_ONEDRIVE_ROOT=... GATEWAY_GWORKSPACE_ROOT=... $0 [work_root]"
  exit 2
fi

for p in "$ONEDRIVE_ROOT" "$GWORK_ROOT"; do
  if [[ ! -d "$p" ]]; then
    echo "Missing gateway root: $p"
    exit 1
  fi
done

OD_BASE="$ONEDRIVE_ROOT/Exports/LAM_Public/$TAG"
GW_BASE="$GWORK_ROOT/Exports/LAM_Public/$TAG"
mkdir -p "$OD_BASE" "$GW_BASE"

REPORT="$SCRIPT_ROOT/PUBLIC_EXPORT_REPORT_${STAMP}.md"
TMP_TSV="/tmp/public_export_${STAMP}.tsv"
: > "$TMP_TSV"

# Public-level artifacts expected by user: analysis/research/plans/strategies/maps/logs.
PATTERNS=(
  "README.md"
  "ROADMAP.md"
  "DEV_LOGS.md"
  "*ANALYSIS*.md"
  "*RESEARCH*.md"
  "*PLAN*.md"
  "*STRATEGY*.md"
  "*ATLAS*.md"
  "*MATRIX*.md"
  "WORKFLOW_SNAPSHOT_STATE.md"
  "WORKFLOW_SNAPSHOT_CONTRACT.md"
  "SYSTEM_STATE.md"
  "SYSTEM_STATE_CONTRACT.md"
  "INTERACTION_PROTOCOL.md"
)

for r in "$WORK_ROOT"/*; do
  [[ -d "$r/.git" ]] || continue
  repo="$(basename "$r")"
  out_rel="${repo}"
  od_repo="$OD_BASE/$out_rel"
  gw_repo="$GW_BASE/$out_rel"
  mkdir -p "$od_repo" "$gw_repo"

  copied=0
  manifest="$od_repo/MANIFEST.txt"
  : > "$manifest"

  for pat in "${PATTERNS[@]}"; do
    while IFS= read -r -d '' f; do
      rel="${f#$r/}"
      mkdir -p "$od_repo/$(dirname "$rel")" "$gw_repo/$(dirname "$rel")"
      cp -f "$f" "$od_repo/$rel"
      cp -f "$f" "$gw_repo/$rel"
      echo "$rel" >> "$manifest"
      copied=$((copied+1))
    done < <(find "$r" -maxdepth 4 -type f -name "$pat" -print0)
  done

  sort -u "$manifest" -o "$manifest"
  cp -f "$manifest" "$gw_repo/MANIFEST.txt"

  printf "%s\t%d\t%s\t%s\n" "$repo" "$copied" "$od_repo" "$gw_repo" >> "$TMP_TSV"
done

{
  echo "# Public Export Report — $STAMP"
  echo
  echo "## Target External Systems"
  echo "- OneDrive root: $ONEDRIVE_ROOT"
  echo "- Google Workspace root: $GWORK_ROOT"
  echo
  echo "## Per-Repository Delivery"
  echo
  echo "| Repository | Files Exported | OneDrive Packet | Google Workspace Packet |"
  echo "|---|---:|---|---|"
  while IFS=$'\t' read -r repo cnt od gw; do
    echo "| $repo | $cnt | $od | $gw |"
  done < "$TMP_TSV"
  echo
  echo "## Verification"
  echo "- Every packet contains `MANIFEST.txt` with exported public-level documents."
  echo "- Files were copied to both external gateway roots in this run."
} > "$REPORT"

cat "$REPORT"
