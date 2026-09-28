#!/usr/bin/env bash
# Tapestry setup.
#
# Two ways to use Tapestry:
#   A. This repo IS your project:      clone it, run scripts/setup.sh, start prompting.
#   B. Add Tapestry to an existing repo:  scripts/setup.sh --into /path/to/your/repo
#
# Both make the hooks executable and check the environment.
# Then run `claude` and type /tapestry-setup to fill in the project profile.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$src"
keep_examples=0

while [ $# -gt 0 ]; do
  case "$1" in
    --into) target="$(cd "$2" && pwd)"; shift 2 ;;
    --keep-examples) keep_examples=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ "$target" != "$src" ]; then
  echo "Installing Tapestry into $target"
  if [ ! -d "$target/.git" ]; then
    echo "error: $target is not a git repository (run 'git init' there first)" >&2
    exit 1
  fi
  # Directories are merged file by file without overwriting; single files are skipped if present.
  for item in .claude .tapestry .github scripts bin; do
    mkdir -p "$target/$item"
    (cd "$src/$item" && find . -type f) | while IFS= read -r f; do
      f="${f#./}"
      case "$f" in features/*) continue ;; esac      # never copy feature folders
      if [ -e "$target/$item/$f" ]; then
        echo "  skip $item/$f (exists)"
      else
        mkdir -p "$target/$item/$(dirname "$f")"
        cp -p "$src/$item/$f" "$target/$item/$f"
      fi
    done
    echo "  merged $item/"
  done
  if [ -e "$target/REVIEW.md" ]; then echo "  skip REVIEW.md (exists)"; else cp "$src/REVIEW.md" "$target/REVIEW.md"; echo "  copied REVIEW.md"; fi
  if [ -f "$target/CLAUDE.md" ] && grep -q '<!-- Tapestry -->' "$target/CLAUDE.md"; then
    echo "  skip CLAUDE.md (Tapestry section present)"
  elif [ -f "$target/CLAUDE.md" ]; then
    echo "  CLAUDE.md exists; appending Tapestry section"
    { echo; echo "<!-- Tapestry -->"; cat "$src/CLAUDE.md"; } >> "$target/CLAUDE.md"
  else
    cp "$src/CLAUDE.md" "$target/CLAUDE.md"; echo "  copied CLAUDE.md"
  fi
  grep -q '^.claude/worktrees' "$target/.gitignore" 2>/dev/null || {
    printf '\n# Tapestry\n.claude/worktrees/\n.claude/settings.local.json\n.claude/agent-memory-local/\nCLAUDE.local.md\n' >> "$target/.gitignore"
    echo "  updated .gitignore"
  }
fi

chmod +x "$target"/.claude/hooks/*.sh "$target"/scripts/*.sh "$target"/bin/* 2>/dev/null || true

if [ "$keep_examples" -eq 0 ] && [ "$target" = "$src" ] && [ -d "$target/examples" ]; then
  echo "note: examples/ contains the walkthrough artifacts; delete it once you no longer need it"
fi
mkdir -p "$target/.tapestry/features"

echo
"$target/scripts/tapestry-doctor.sh"
echo
echo "Next:"
echo "  cd $target"
echo "  claude                # start Claude Code"
echo "  /tapestry-setup       # fill in the project profile (stack, commands, base branch)"
echo "  /tapestry-new <idea>  # start your first feature"
