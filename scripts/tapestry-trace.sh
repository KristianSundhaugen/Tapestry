#!/usr/bin/env bash
# Switch Tapestry's test-run tracing on or off.
#   scripts/tapestry-trace.sh on       register the trace hook in .claude/settings.local.json (personal, gitignored)
#   scripts/tapestry-trace.sh off      remove it again
#   scripts/tapestry-trace.sh status   show whether it is on and how many events are logged
#   scripts/tapestry-trace.sh clear    empty .tapestry/logs/trace.jsonl (start a fresh test run)
# Restart `claude` after on/off: Claude Code reads hook settings when a session starts.
set -uo pipefail

PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -z "$PY" ] && { echo "a working Python 3 is required (run scripts/tapestry-doctor.sh)" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_settings="$here/.claude/settings.local.json"
logdir="$here/.tapestry/logs"
marker="$logdir/.trace-on"
log="$logdir/trace.jsonl"

case "${1:-status}" in
  on)
    mkdir -p "$logdir"
    "$PY" - "$local_settings" <<'PY'
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8-sig") as f:   # tolerate a BOM written by PowerShell
            data = json.load(f) or {}
    except Exception as e:
        sys.exit(f"cannot read {path}: {e}\nFix or delete that file, then run this again.")
hook = {"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/trace.sh", "timeout": 10}
events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
          "SubagentStart", "SubagentStop", "Stop"]
hooks = data.setdefault("hooks", {})
for ev in events:
    groups = hooks.setdefault(ev, [])
    if not any(h.get("command", "").endswith("/trace.sh") for g in groups for h in g.get("hooks", [])):
        groups.append({"matcher": "", "hooks": [dict(hook)]})
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    [ $? -eq 0 ] || { echo "tracing NOT enabled" >&2; exit 1; }
    : > "$marker"
    echo "tracing ON: events go to .tapestry/logs/trace.jsonl"
    echo "restart claude now (hooks are read at session start)"
    ;;
  off)
    rm -f "$marker"
    if [ -f "$local_settings" ]; then
      "$PY" - "$local_settings" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8-sig") as f:
    data = json.load(f)
hooks = data.get("hooks", {})
for ev in list(hooks):
    kept = []
    for g in hooks[ev]:
        g["hooks"] = [h for h in g.get("hooks", []) if not h.get("command", "").endswith("/trace.sh")]
        if g["hooks"]:
            kept.append(g)
    if kept:
        hooks[ev] = kept
    else:
        del hooks[ev]
if not hooks:
    data.pop("hooks", None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    fi
    echo "tracing OFF (the existing log is kept; restart claude)"
    ;;
  status)
    if [ -f "$marker" ]; then state="ON"; else state="OFF"; fi
    n=0; [ -f "$log" ] && n="$(wc -l < "$log" | tr -d ' ')"
    echo "tracing $state; $n event(s) in .tapestry/logs/trace.jsonl"
    ;;
  clear)
    mkdir -p "$logdir" && : > "$log" && rm -f "$log.lock"
    echo "trace log cleared"
    ;;
  *)
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
