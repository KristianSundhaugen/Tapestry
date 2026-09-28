#!/usr/bin/env bash
# Create a new Tapestry feature folder from a raw idea.
# Usage: scripts/tapestry-new.sh "raw idea in one line"
# Prints the new feature id on the last line.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
features="$here/.tapestry/features"
templates="$here/.tapestry/templates"

idea="${1:-}"
if [ -z "$idea" ]; then
  echo "usage: $0 \"raw idea in one line\"" >&2
  exit 1
fi

mkdir -p "$features"

# Next id: highest existing NNN + 1.
last="$(ls "$features" 2>/dev/null | grep -E '^[0-9]{3}-' | sort | tail -n1 | cut -c1-3 || true)"
if [ -z "$last" ]; then next=1; else next=$((10#$last + 1)); fi
num="$(printf '%03d' "$next")"

# Slug: lowercase, alnum and dashes, max 40 chars, from the first six words.
slug="$(printf '%s' "$idea" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -d- -f1-6 | cut -c1-40 | sed 's/-$//')"
[ -z "$slug" ] && slug="feature"
id="$num-$slug"
dir="$features/$id"

if [ -e "$dir" ]; then
  echo "error: $dir already exists" >&2
  exit 1
fi

mkdir -p "$dir/tasks" "$dir/reviews"
today="$(date +%Y-%m-%d)"
now="$(date '+%Y-%m-%d %H:%M')"
title="$(printf '%s' "$idea" | cut -c1-80)"
base_branch="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("baseBranch","main"))' "$here/.tapestry/config.json" 2>/dev/null || echo main)"

fill() {
  # $1 template, $2 destination
  python3 - "$1" "$2" "$id" "$title" "$today" "$now" "$idea" "$base_branch" <<'PY'
import sys
src, dst, fid, title, today, now, idea, base = sys.argv[1:9]
text = open(src, encoding="utf-8").read()
for k, v in {
    "{{FEATURE_ID}}": fid, "{{TITLE}}": title, "{{DATE}}": today,
    "{{RAW_IDEA}}": idea, "{{BASE_BRANCH}}": base,
}.items():
    text = text.replace(k, v)
open(dst, "w", encoding="utf-8").write(text)
PY
}

fill "$templates/interview.md" "$dir/interview.md"
fill "$templates/spec.md" "$dir/spec.md"
fill "$templates/progress.md" "$dir/progress.md"
# The progress template's first event uses {{DATE}}; make it a timestamp.
sed -i.bak "s/^$today  human  created/$now  human  created/" "$dir/progress.md" && rm -f "$dir/progress.md.bak"

echo "created .tapestry/features/$id/ (interview.md, spec.md, progress.md, tasks/, reviews/)"
echo "next: /tapestry-interview $id"
echo "$id"
