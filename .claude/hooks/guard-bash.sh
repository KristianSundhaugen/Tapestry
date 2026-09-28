#!/usr/bin/env bash
# Tapestry PreToolUse hook for Bash.
# Blocks (exit 2) the small set of git operations that would break the pipeline's
# invariants regardless of what an agent decides. Everything else passes through
# to the normal permission flow (exit 0, no output).
#
# The command is split on shell separators (&&, ||, ;, |) and each segment is
# checked on its own, so `git rebase origin/main && git push --force-with-lease`
# is judged by the push segment only.
#
# Reads the hook JSON on stdin; needs python3 (present wherever Claude Code runs).
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
config="$project_dir/.tapestry/config.json"

base_branch="main"
protected="main master develop"
if [ -f "$config" ]; then
  base_branch="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("baseBranch","main"))' "$config" 2>/dev/null || echo main)"
  protected="$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["git"].get("protectedBranches",["main","master","develop"])))' "$config" 2>/dev/null || echo "main master develop")"
fi

block() {
  printf 'Tapestry guard: %s\n' "$1" >&2
  exit 2
}

# 4 (checked on the whole command). Obvious secret material.
if printf '%s' "$cmd" | grep -Eq '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'; then
  block "the command contains something that looks like a real credential."
fi

cwd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null || true)"

# Split into segments on &&, ||, ;, |  (newlines too).
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue

  case "$seg" in
    git\ push*|git\ *push*)
      # 1. Plain --force / -f is never allowed.
      if printf ' %s' "$seg" | grep -Eq ' (--force|-f)([ =]|$)'; then
        block "plain --force push is not allowed; use --force-with-lease on your own task branch only."
      fi
      # 2. Force-with-lease must not name a protected branch.
      if printf '%s' "$seg" | grep -q -- '--force-with-lease'; then
        for b in $protected; do
          if printf ' %s' "$seg" | grep -Eq "[ :=](origin/)?$b( |$)"; then
            block "force-pushing protected branch '$b' is not allowed."
          fi
        done
      fi
      # 3. Explicit push to a protected branch (refspec or branch name after the remote).
      for b in $protected; do
        if printf '%s' "$seg" | grep -Eq "git +push +(-[^ ]+ +)*[^ -][^ ]* +([^ ]+:)?$b( |$)"; then
          block "pushing directly to protected branch '$b' is not allowed; open a PR."
        fi
      done
      ;;
    git\ commit*)
      # 5. Committing while the checkout is on the base branch. Ledger commits
      #    (message mentions tapestry, files under .tapestry/) are the only exception.
      current="$(git -C "${cwd:-$project_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
      if [ "$current" = "$base_branch" ] && ! printf '%s' "$cmd" | grep -q 'tapestry'; then
        block "you are on the base branch '$base_branch'; create a task branch first (see .claude/rules/git-workflow.md)."
      fi
      ;;
  esac
done < <(printf '%s' "$cmd" | python3 -c 'import re,sys; print("\n".join(re.split(r"&&|\|\||;|\||\n", sys.stdin.read())))')

exit 0
