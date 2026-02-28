#!/usr/bin/env bash
# Compare one "actual" screenshot against one or more design references.
# Generates per-reference diff PNG + metrics JSON + markdown summary.
#
# Usage:
#   ./scripts/screenshot_design_check.sh \
#     --actual screenshots/ui_with_results.png \
#     --reference /path/to/reference1.png \
#     --reference /path/to/reference2.png \
#     [--out-dir screenshots/design-check]

set -euo pipefail

ACTUAL=""
OUT_DIR="screenshots/design-check"
REFERENCES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actual)
      ACTUAL="${2:-}"
      shift 2
      ;;
    --reference)
      REFERENCES+=("${2:-}")
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./scripts/screenshot_design_check.sh \
    --actual <actual.png> \
    --reference <reference.png> [--reference <reference2.png> ...] \
    [--out-dir screenshots/design-check]
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ACTUAL" ]]; then
  echo "Missing --actual" >&2
  exit 2
fi

if [[ ! -f "$ACTUAL" ]]; then
  echo "Actual screenshot not found: $ACTUAL" >&2
  exit 1
fi

if [[ "${#REFERENCES[@]}" -eq 0 ]]; then
  echo "At least one --reference is required" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
REPORT="$OUT_DIR/report.md"
MODULE_CACHE_DIR="${TMPDIR:-/tmp}/swift-module-cache"
mkdir -p "$MODULE_CACHE_DIR"

actual_abs="$(cd "$(dirname "$ACTUAL")" && pwd)/$(basename "$ACTUAL")"

echo "# Screenshot Design Check" > "$REPORT"
echo "" >> "$REPORT"
echo "- Actual: \`$ACTUAL\`" >> "$REPORT"
echo "- Generated: \`$(date '+%Y-%m-%d %H:%M:%S')\`" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Reference | Similarity | MAE | RMSE | Changed Pixels | Diff |" >> "$REPORT"
echo "|---|---:|---:|---:|---:|---|" >> "$REPORT"

for ref in "${REFERENCES[@]}"; do
  if [[ ! -f "$ref" ]]; then
    echo "Reference not found, skipping: $ref" >&2
    continue
  fi

  ref_abs="$(cd "$(dirname "$ref")" && pwd)/$(basename "$ref")"
  if [[ "$actual_abs" == "$ref_abs" ]]; then
    echo "Reference equals actual; skipping self-compare: $ref" >&2
    continue
  fi

  base="$(basename "$ref")"
  stem="${base%.*}"
  diff_png="$OUT_DIR/${stem}.diff.png"
  metrics_json="$OUT_DIR/${stem}.metrics.json"

  SWIFT_MODULECACHE_PATH="$MODULE_CACHE_DIR" CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
    swift -module-cache-path "$MODULE_CACHE_DIR" scripts/visual_diff.swift \
    --actual "$ACTUAL" \
    --reference "$ref" \
    --output-diff "$diff_png" \
    --output-json "$metrics_json" >/tmp/visual_diff.out

  similarity="$(awk -F': ' '/Similarity/ {print $2}' /tmp/visual_diff.out | awk '{print $1}')"
  mae="$(awk -F': ' '/"mae"/ {gsub(/,/, "", $2); print $2}' "$metrics_json")"
  rmse="$(awk -F': ' '/"rmse"/ {gsub(/,/, "", $2); print $2}' "$metrics_json")"
  changed_raw="$(awk -F': ' '/"changedPixelsRatio"/ {gsub(/,/, "", $2); print $2}' "$metrics_json")"
  changed="$(awk -v r="$changed_raw" 'BEGIN { printf "%.2f%%", r * 100.0 }')"

  echo "| \`$ref\` | $similarity | $mae | $rmse | $changed | \`$diff_png\` |" >> "$REPORT"
done

if [[ ! -s "$REPORT" || "$(wc -l < "$REPORT")" -le 7 ]]; then
  echo "No valid comparisons were produced. Check --reference paths." >&2
  exit 1
fi

echo "Report: $REPORT"
