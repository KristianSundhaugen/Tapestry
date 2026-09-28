#!/usr/bin/env bash
# Tapestry SessionStart hook.
# Prints a compact status of the pipeline so every session (including subagents that
# load CLAUDE.md) starts knowing which features exist, their stage, and whether anything
# is blocked. Output becomes context for Claude.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
features="$project_dir/.tapestry/features"
config="$project_dir/.tapestry/config.json"

[ -d "$features" ] || exit 0

if [ -f "$config" ]; then
  name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("name",""))' "$config" 2>/dev/null || true)"
  if [ -z "$name" ]; then
    echo "Tapestry: project not configured yet. Run /tapestry-setup first."
  fi
fi

count=0
out=""
for dir in "$features"/*/; do
  [ -d "$dir" ] || continue
  id="$(basename "$dir")"
  ledger="$dir/progress.md"
  [ -f "$ledger" ] || continue
  stage="$(grep -m1 '^stage:' "$ledger" | sed 's/^stage:[[:space:]]*//; s/[[:space:]]*#.*$//')"
  [ "$stage" = "learned" ] && continue
  blocked=""
  # Non-empty "Blocked / needs human" section = any non-heading, non-blank line before the next heading.
  if awk '/^## Blocked/{f=1;next} /^## /{f=0} f && NF && $0 !~ /^<!--/ {found=1} END{exit !found}' "$ledger"; then
    blocked=" — BLOCKED, see progress.md"
  fi
  tasks="$(ls "$dir/tasks" 2>/dev/null | grep -c '\.md$' || true)"
  merged="$(grep -l '^status: merged' "$dir"/tasks/*.md 2>/dev/null | wc -l | tr -d ' ')"
  out="$out  $id  stage=$stage  tasks=${merged:-0}/${tasks:-0} merged$blocked\n"
  count=$((count+1))
done

if [ "$count" -gt 0 ]; then
  printf 'Tapestry active features (%d):\n' "$count"
  printf '%b' "$out"
  printf 'Ledger: .tapestry/features/<id>/progress.md. Commands: /tapestry-status, /tapestry-run <id>.\n'
fi
exit 0
