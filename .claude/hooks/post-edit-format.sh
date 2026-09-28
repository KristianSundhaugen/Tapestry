#!/usr/bin/env bash
# Tapestry PostToolUse hook for Edit|Write.
# Runs the project's formatter (commands.format in .tapestry/config.json) on the file
# that was just written, if a formatter is configured and the file is inside the project.
# Never fails the tool call: formatting problems are reported, not enforced (the reviewer
# and CI catch them).
set -uo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
config="$project_dir/.tapestry/config.json"
[ -f "$config" ] || exit 0

fmt="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"].get("format",""))' "$config" 2>/dev/null || true)"
[ -z "$fmt" ] && exit 0

# Only format source files, never Tapestry artifacts or markdown.
case "$file" in
  *.md|*/.tapestry/*|*/.claude/*) exit 0 ;;
esac

# Run from the file's repo root so tool configs resolve (the file may live in a worktree).
root="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || echo "$project_dir")"
if ! (cd "$root" && eval "$fmt \"$file\"") >/dev/null 2>&1; then
  printf 'Tapestry: formatter "%s" failed on %s (not blocking).\n' "$fmt" "$file"
fi
exit 0
