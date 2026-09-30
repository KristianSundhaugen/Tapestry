#!/usr/bin/env bash
# Check the environment Tapestry needs. Never fails hard; prints OK / WARN / MISSING per item.
set -uo pipefail

# Windows (Git Bash) often has only "python"; Linux/macOS have python3.
PY="$(command -v python3 || command -v python || true)"
[ -z "$PY" ] && { echo "python3 or python is required" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok()   { printf '  OK       %s\n' "$1"; }
warn() { printf '  WARN     %s\n' "$1"; }
miss() { printf '  MISSING  %s\n' "$1"; }

echo "Tapestry doctor"
echo "required:"
command -v git >/dev/null 2>&1 && ok "git $(git --version | awk '{print $3}')" || miss "git"
command -v python3 >/dev/null 2>&1 && ok "python3 $(python3 --version 2>&1 | awk '{print $2}')" || miss "python3 (hooks and scripts need it)"
if command -v claude >/dev/null 2>&1; then ok "claude $(claude --version 2>/dev/null | head -n1)"; else miss "claude (Claude Code CLI): https://code.claude.com/docs/en/setup"; fi
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh installed but not authenticated: run 'gh auth login'"; fi
else
  miss "gh (GitHub CLI): https://cli.github.com — implementers and reviewers open and merge PRs with it"
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
if [ -f "$here/.tapestry/config.json" ]; then
  name="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"].get("name",""))' "$here/.tapestry/config.json" 2>/dev/null || true)"
  [ -n "$name" ] && ok "project '$name'" || warn ".tapestry/config.json not filled in: run /tapestry-setup"
  test_cmd="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"].get("test",""))' "$here/.tapestry/config.json" 2>/dev/null || true)"
  [ -n "$test_cmd" ] && ok "test command: $test_cmd" || warn "no test command configured; agents cannot prove work until there is one"
else
  miss ".tapestry/config.json"
fi

echo "optional (reviewer scanners):"
command -v semgrep  >/dev/null 2>&1 && ok "semgrep"  || warn "semgrep not installed  (pip install semgrep | brew install semgrep)"
command -v gitleaks >/dev/null 2>&1 && ok "gitleaks" || warn "gitleaks not installed (brew install gitleaks | https://github.com/gitleaks/gitleaks/releases)"
command -v trivy    >/dev/null 2>&1 && ok "trivy"    || warn "trivy not installed    (only needed for container/IaC projects)"

echo "hooks:"
for h in guard-bash.sh post-edit-format.sh session-start.sh; do
  if [ -x "$here/.claude/hooks/$h" ]; then ok "$h executable"; else warn "$h not executable: chmod +x .claude/hooks/$h"; fi
done
exit 0
