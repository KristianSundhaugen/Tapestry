#!/usr/bin/env bash
# Tapestry PreToolUse hook for Bash and PowerShell (matcher "Bash|PowerShell").
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

# Find a Python that actually runs. On Windows, "python3"/"python" may be the
# Microsoft Store stub, which exists on PATH but only prints an install hint.
PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done

input="$(cat)"
if [ -z "$PY" ]; then
  # No working Python: degrade to a raw-text check so force-pushes are still blocked.
  if printf '%s' "$input" | grep -Eq 'git +push[^"]*( --force([ "]|$)| -f([ "]|$))'; then
    printf 'Tapestry guard: plain --force push is not allowed (and no working Python was found, so other checks are off: run scripts/tapestry-doctor.sh).\n' >&2
    exit 2
  fi
  exit 0
fi
cmd="$(printf '%s' "$input" | "$PY" -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
config="$project_dir/.tapestry/config.json"

base_branch="main"
protected="main master develop"
if [ -f "$config" ]; then
  base_branch="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("baseBranch","main"))' "$config" 2>/dev/null || echo main)"
  protected="$("$PY" -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["git"].get("protectedBranches",["main","master","develop"])))' "$config" 2>/dev/null || echo "main master develop")"
fi

cwd="$(printf '%s' "$input" | "$PY" -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null || true)"

block() {
  # When tracing is on (bin/tapestry trace on), record the block for the test-run report.
  if [ -f "$project_dir/.tapestry/logs/.trace-on" ]; then
    printf '%s' "$input" | "$PY" -c 'import datetime,json,os,sys
d=json.load(sys.stdin)
rec={"ts":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"event":"GuardBlock","agent":d.get("agent_type") or "main","agent_id":d.get("agent_id"),"reason":sys.argv[2],"command":sys.argv[3][:300],"cwd":d.get("cwd","")}
fd=os.open(sys.argv[1],os.O_WRONLY|os.O_APPEND|os.O_CREAT,0o644); os.write(fd,(json.dumps(rec)+"\n").encode("utf-8")); os.close(fd)' \
      "$project_dir/.tapestry/logs/trace.jsonl" "$1" "$cmd" 2>/dev/null || true
  fi
  printf 'Tapestry guard: %s\n' "$1" >&2
  exit 2
}

# 4 (checked on the whole command). Obvious secret material.
if printf '%s' "$cmd" | grep -Eq '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'; then
  block "the command contains something that looks like a real credential."
fi


# Personal push window: is GitHub activity held right now?
window_msg=""
if [ -f "$project_dir/scripts/push-window.sh" ]; then
  window_msg="$(bash "$project_dir/scripts/push-window.sh")" && window_msg=""
fi
hold() {
  block "push window: $window_msg This is not a failure: leave the work committed locally, do not retry or bypass it, and report 'HELD: push window' with your branch name."
}

# Split into segments on &&, ||, ;, |  (newlines too).
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue
  # PowerShell tool spellings: "& git push", "git.exe push", "& 'C:\...\git.exe' push", "$env:X='1'" prefixes.
  seg="$(printf '%s' "$seg" | "$PY" -c 'import re,sys; s=sys.stdin.read(); print(re.sub(r"""^&?\s*(["\x27]?)(?:[^"\x27]*[\\/])?(git|gh)(?:\.exe)?\1(?=\s|$)""", r"\2", s, count=1))')"

  # 0. GitHub-visible activity inside the push window.
  if [ -n "$window_msg" ]; then
    case "$seg" in
      git\ push*|git\ *\ push*) hold ;;
    esac
    if printf '%s' "$seg" | grep -Eq '^gh +(pr +(create|merge|comment|review|edit|close|reopen|ready)|issue +(create|comment|edit|close|reopen)|release +(create|edit|upload|delete)|repo +(create|edit|fork|sync)|workflow +run|run +rerun|secret +set|label +create)( |$)'; then
      hold
    fi
    if printf '%s' "$seg" | grep -Eq '^gh +api( |$)' && printf ' %s' "$seg" | grep -Eq ' (-X|--method)[ =]?(POST|PATCH|PUT|DELETE)| (-f|-F|--field|--raw-field|--input)[ =]'; then
      hold
    fi
    if printf '%s' "$seg" | grep -Eq 'TAPESTRY_PUSH_NOW=|--no-verify'; then
      hold
    fi
  fi

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
done < <(printf '%s' "$cmd" | "$PY" -c 'import re,sys; print("\n".join(re.split(r"&&|\|\||;|\||\n", sys.stdin.read())))')

exit 0
