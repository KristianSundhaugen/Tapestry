#!/usr/bin/env bash
# Check the environment Tapestry needs. Never fails hard; prints OK / WARN / MISSING per item.
set -uo pipefail

# Find a Python that actually runs. On Windows, "python3"/"python" may be the
# Microsoft Store stub, which exists on PATH but only prints an install hint.
PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done


here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok()   { printf '  OK       %s\n' "$1"; }
warn() { printf '  WARN     %s\n' "$1"; }
miss() { printf '  MISSING  %s\n' "$1"; }

echo "Tapestry doctor"
echo "required:"
command -v git >/dev/null 2>&1 && ok "git $(git --version | awk '{print $3}')" || miss "git"
if [ -n "$PY" ]; then
  ok "python ($PY $("$PY" -c 'import platform; print(platform.python_version())'))"
else
  miss "a working Python 3 (hooks and scripts need it; without it the git guard hook only blocks force-pushes)"
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    echo "           'python'/'python3' on PATH is the Microsoft Store stub. Install Python from python.org"
    echo "           (tick 'Add to PATH'), or: winget install Python.Python.3.12 — then turn off the stubs in"
    echo "           Settings > Apps > Advanced app settings > App execution aliases."
  fi
fi
# Project commands in config.json run on Linux CI too, so they say `python`, not `py`.
if [ "$PY" = "py" ] && ! python -c 'import sys' >/dev/null 2>&1; then
  warn "'python' is not a working Python here (only the 'py' launcher is). Project commands like 'python -m pytest' will fail."
  echo "           Fix: Settings > Apps > Advanced app settings > App execution aliases: turn off python.exe/python3.exe,"
  echo "           and make sure Python's folder is on PATH (installer: Modify > Add Python to environment variables)."
fi
if command -v claude >/dev/null 2>&1; then ok "claude $(claude --version 2>/dev/null | head -n1)"; else miss "claude (Claude Code CLI): https://code.claude.com/docs/en/setup"; fi
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh installed but not authenticated: run 'gh auth login'"; fi
else
  miss "gh (GitHub CLI) — implementers and reviewers open and merge PRs with it. Windows: winget install GitHub.cli; macOS: brew install gh; then gh auth login"
fi

echo "repository:"
if git -C "$here" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "git repository"
  remote="$(git -C "$here" remote get-url origin 2>/dev/null || true)"
  [ -n "$remote" ] && ok "origin: $remote" || warn "no 'origin' remote; PRs need one"
  default="$(git -C "$here" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##' || true)"
  [ -n "$default" ] && ok "default branch: $default" || warn "default branch unknown (run: git remote set-head origin -a)"
else
  miss "not a git repository"
fi

echo "config:"
if [ -f "$here/.tapestry/config.json" ] && [ -n "$PY" ]; then
  name="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("name",""))' "$here/.tapestry/config.json" 2>/dev/null || true)"
  [ -n "$name" ] && ok "project '$name'" || warn ".tapestry/config.json not filled in: run /tapestry-setup"
  test_cmd="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"].get("test",""))' "$here/.tapestry/config.json" 2>/dev/null || true)"
  [ -n "$test_cmd" ] && ok "test command: $test_cmd" || warn "no test command configured; agents cannot prove work until there is one"
else
  miss ".tapestry/config.json"
fi

echo "optional (reviewer scanners):"
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) hint_semgrep="py -m pip install semgrep"; hint_gitleaks="winget install Gitleaks.Gitleaks"; hint_trivy="winget install AquaSecurity.Trivy" ;;
  Darwin*)              hint_semgrep="brew install semgrep";    hint_gitleaks="brew install gitleaks";           hint_trivy="brew install trivy" ;;
  *)                    hint_semgrep="pipx install semgrep";    hint_gitleaks="https://github.com/gitleaks/gitleaks/releases"; hint_trivy="https://trivy.dev" ;;
esac
command -v semgrep  >/dev/null 2>&1 && ok "semgrep"  || warn "semgrep not installed  ($hint_semgrep)"
command -v gitleaks >/dev/null 2>&1 && ok "gitleaks" || warn "gitleaks not installed ($hint_gitleaks)"
command -v trivy    >/dev/null 2>&1 && ok "trivy"    || warn "trivy not installed    (only for container/IaC projects: $hint_trivy)"

echo "test-run tracing:"
if [ -f "$here/.tapestry/logs/.trace-on" ]; then ok "ON ($(wc -l < "$here/.tapestry/logs/trace.jsonl" 2>/dev/null | tr -d ' ' || echo 0) events); turn off with: bin/tapestry trace off"; else ok "off (for a test run: bin/tapestry trace on)"; fi

echo "push window:"
hp="$(git -C "$here" config --get core.hooksPath || true)"
[ "$hp" = ".githooks" ] && ok "git pre-push hook active (core.hooksPath=.githooks)" || warn "git pre-push hook not active: git config core.hooksPath .githooks"
if [ -f "$here/.tapestry/config.local.json" ]; then
  if wmsg="$(bash "$here/scripts/push-window.sh")"; then ok "configured; GitHub activity allowed right now"; else ok "configured; HELD right now — $wmsg"; fi
else
  ok "not configured (optional: cp .tapestry/config.local.example.json .tapestry/config.local.json)"
fi

echo "hooks:"
for h in guard-bash.sh post-edit-format.sh session-start.sh; do
  if [ -x "$here/.claude/hooks/$h" ]; then ok "$h executable"; else warn "$h not executable: chmod +x .claude/hooks/$h"; fi
done
exit 0
