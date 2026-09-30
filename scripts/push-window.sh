#!/usr/bin/env bash
# Is GitHub activity (push, PR, comment, merge) allowed right now?
#   exit 0  allowed
#   exit 1  held; the reason is printed on stdout
#
# Reads git.pushWindow from .tapestry/config.local.json (personal, gitignored),
# layered over .tapestry/config.json. Both are read from the MAIN checkout, so
# agents in worktrees (which have no config.local.json) get the same answer.
#
# Bypass once:   TAPESTRY_PUSH_NOW=1 git push
# Test a time:   TAPESTRY_CLOCK="3 10:30" scripts/push-window.sh   (ISO weekday, HH:MM)
set -uo pipefail

[ "${TAPESTRY_PUSH_NOW:-}" = "1" ] && exit 0

PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done

# Main checkout = parent of the shared .git directory; fall back to this script's repo.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
common="$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then
  main="$(dirname "$common")"
else
  main="$here"
fi
local_cfg="$main/.tapestry/config.local.json"
shared_cfg="$main/.tapestry/config.json"

[ -f "$local_cfg" ] || [ -f "$shared_cfg" ] || exit 0

if [ -z "$PY" ]; then
  if [ -f "$local_cfg" ]; then
    echo "a push window may be configured but no working Python was found to read it, so holding to be safe (override once: TAPESTRY_PUSH_NOW=1)."
    exit 1
  fi
  exit 0
fi

clock="${TAPESTRY_CLOCK:-$(date '+%u %H:%M')}"

"$PY" - "$local_cfg" "$shared_cfg" "$clock" <<'PY'
import json, sys
local_cfg, shared_cfg, clock = sys.argv[1:4]

def window(path):
    try:
        with open(path, encoding="utf-8") as f:
            return (json.load(f).get("git") or {}).get("pushWindow") or {}
    except FileNotFoundError:
        return {}
    except Exception as e:
        print(f"cannot read {path} ({e}); holding to be safe (override once: TAPESTRY_PUSH_NOW=1).")
        sys.exit(1)

w = {}
w.update(window(shared_cfg))
w.update(window(local_cfg))          # personal settings win
if not w.get("enabled"):
    sys.exit(0)

names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
days = w.get("days") or names[:5]
hold_from, hold_until = w.get("holdFrom", "08:00"), w.get("holdUntil", "16:00")

def minutes(s):
    h, m = s.strip().split(":")
    return int(h) * 60 + int(m)

dow, hm = clock.split()
if names[int(dow) - 1] not in days:
    sys.exit(0)
now, a, b = minutes(hm), minutes(hold_from), minutes(hold_until)
held = (a <= now < b) if a <= b else (now >= a or now < b)
if held:
    print(f"GitHub activity is held {hold_from}-{hold_until} on {'/'.join(days)} "
          f"(git.pushWindow in .tapestry/config.local.json). Keep committing locally; push after {hold_until}.")
    sys.exit(1)
sys.exit(0)
PY
