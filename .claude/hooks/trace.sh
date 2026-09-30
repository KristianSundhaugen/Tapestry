#!/usr/bin/env bash
# Tapestry trace hook (opt-in, for test runs).
# Appends one JSON line per Claude Code event to .tapestry/logs/trace.jsonl in the
# main checkout: which agent did what, with which tool, from which directory.
# scripts/tapestry-report.sh turns it into a pass/fail report.
#
# Not registered in the shared .claude/settings.json. `bin/tapestry trace on` adds it
# to your personal .claude/settings.local.json; `bin/tapestry trace off` removes it.
# Never blocks anything; always exits 0.
set -uo pipefail

PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -z "$PY" ] && exit 0

input="$(cat)"

# Main checkout, even when the event comes from an agent working in a worktree.
main="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$main" ]; then
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then main="$(dirname "$common")"; else main="$(pwd)"; fi
fi
logdir="$main/.tapestry/logs"
mkdir -p "$logdir" 2>/dev/null || exit 0

printf '%s' "$input" | "$PY" -c '
import datetime, json, sys
out = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

def cut(s, n=300):
    s = "" if s is None else str(s)
    return s if len(s) <= n else s[:n] + "..."

ti = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
rec = {
    "ts": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "event": d.get("hook_event_name"),
    "session": (d.get("session_id") or "")[:8],
    "agent": d.get("agent_type") or "main",
    "agent_id": d.get("agent_id"),
    "cwd": d.get("cwd"),
    "tool": d.get("tool_name"),
}
for k in ("command", "file_path", "skill", "subagent_type", "description", "pattern", "url"):
    if k in ti:
        rec[k] = cut(ti[k])
if "prompt" in ti:
    rec["prompt"] = cut(ti["prompt"], 200)
if d.get("prompt"):
    rec["prompt"] = cut(d["prompt"], 200)
tr = d.get("tool_response")
if isinstance(tr, dict):
    for k in ("exit_code", "exitCode", "interrupted", "is_error", "isError"):
        if k in tr:
            rec[k] = tr[k]
for k in ("error", "source", "reason", "stop_hook_active"):
    if d.get(k) not in (None, ""):
        rec[k] = cut(d[k], 300) if isinstance(d[k], str) else d[k]
rec = {k: v for k, v in rec.items() if v not in (None, "")}
line = (json.dumps(rec, ensure_ascii=False) + "\n").encode("utf-8")
# Several agents log at once: take a lock so lines never interleave (Windows has no atomic append).
import os
lock = open(out + ".lock", "a+b")
try:
    try:
        import msvcrt
        lock.seek(0); msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1); unlock = lambda: (lock.seek(0), msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1))
    except ImportError:
        import fcntl
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX); unlock = lambda: fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    fd = os.open(out, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    try:
        os.write(fd, line)
    finally:
        os.close(fd)
        unlock()
finally:
    lock.close()
' "$logdir/trace.jsonl" 2>/dev/null
exit 0
