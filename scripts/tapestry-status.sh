#!/usr/bin/env bash
# Print Tapestry pipeline status.
#   scripts/tapestry-status.sh            all features
#   scripts/tapestry-status.sh <id>       one feature: task board, last events, blocked section
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
features="$here/.tapestry/features"

field() { grep -m1 "^$2:" "$1" 2>/dev/null | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*#.*$//"; }

if [ -z "${1:-}" ]; then
  printf '%-40s %-12s %s\n' "feature" "stage" "tasks (merged/total)"
  found=0
  for dir in "$features"/*/; do
    [ -d "$dir" ] || continue
    found=1
    id="$(basename "$dir")"
    stage="$(field "$dir/progress.md" stage)"
    total="$(ls "$dir/tasks" 2>/dev/null | grep -c '\.md$' || true)"
    merged="$(grep -l '^status: merged' "$dir"/tasks/*.md 2>/dev/null | wc -l | tr -d ' ')"
    printf '%-40s %-12s %s/%s\n' "$id" "${stage:-?}" "${merged:-0}" "${total:-0}"
  done
  [ "$found" -eq 0 ] && echo "(no features yet — run /tapestry-new <idea>)"
  exit 0
fi

dir="$features/$1"
if [ ! -d "$dir" ]; then
  echo "no such feature: $1" >&2
  exit 1
fi

echo "== $1 =="
echo "stage: $(field "$dir/progress.md" stage)   wave: $(field "$dir/progress.md" current_wave)   spec: $(field "$dir/spec.md" status)   plan: $(field "$dir/plan.md" status)"
echo
printf '%-4s %-5s %-12s %-6s %-40s\n' "task" "wave" "status" "pr" "title"
for t in "$dir"/tasks/*.md; do
  [ -f "$t" ] || continue
  printf '%-4s %-5s %-12s %-6s %-40s\n' "$(field "$t" task)" "$(field "$t" wave)" "$(field "$t" status)" "$(field "$t" pr)" "$(field "$t" title | cut -c1-40)"
done
echo
echo "last events:"
awk '/^```/{f=!f;next} f' "$dir/progress.md" | tail -n 10 | sed 's/^/  /'
echo
echo "blocked / needs human:"
awk '/^## Blocked/{f=1;next} /^## /{f=0} f && $0 !~ /^<!--/' "$dir/progress.md" | sed '/^[[:space:]]*$/d' | sed 's/^/  /' | grep . || echo "  (none)"
