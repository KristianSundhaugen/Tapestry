---
name: tapestry-setup
description: One-time onboarding of a project into Tapestry. Detects the stack and commands, asks the human to confirm, writes .tapestry/config.json, seeds .tapestry/knowledge/architecture.md and the CLAUDE.md project notes, and checks that gh, git and optional scanners are available. Usage /tapestry-setup. Safe to re-run.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(scripts/*), Bash(ls *), Bash(cat *), Bash(which *), Bash(gh auth status*), Bash(git remote *), Bash(git branch *), Bash(git ls-files *)
disable-model-invocation: true
---

Onboard this project into Tapestry.

## 1. Detect

- Run `scripts/tapestry-doctor.sh` and keep its output (tools present, gh auth, base branch, remote).
- Detect the stack from the repo: `package.json` (scripts, test runner), `pyproject.toml` / `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile`, `Makefile`, CI files under `.github/workflows/`. Derive candidate commands for `install`, `test`, `lint`, `typecheck`, `format`, `build`, `e2e`.
- If the repo is empty apart from Tapestry itself, note that: the first feature's wave 1 will have to bootstrap the project, and commands can stay empty for now.

## 2. Confirm with the human

With `AskUserQuestion`, at most three questions per round:

- Project name and one-paragraph description (offer a draft from the README if there is one).
- Stack list and the detected commands: show them and ask to confirm or correct. A wrong `test` command breaks every proof later, so be explicit.
- Base branch (detected), parallelism (`maxParallelImplementers`, default 3), and whether the human wants to approve specs and plans (default yes) and merge PRs by hand (default no).
- Scanners: which of `semgrep`, `gitleaks`, `trivy` they want the reviewer to run (only those installed are used; others are reported as "not installed").

## 3. Write

- Write `.tapestry/config.json` with the confirmed values. Keep keys in the schema order; validate against `.tapestry/config.schema.json` (run `scripts/tapestry-validate.sh --config`).
- If the human changed any `models.*` value, also set the matching `model:` line in `.claude/agents/<role>.md`; Claude Code reads the frontmatter, the config value is the documented record.
- Write a first `.tapestry/knowledge/architecture.md`: top-level directories and what they hold, entry points, how tests run. Facts only, under 40 lines.
- Replace the *Project notes* block at the end of `CLAUDE.md` with a summary under 20 lines: name, purpose, stack, the exact commands, and any rule the human stated during setup.
- If `review.ciReviewWorkflow` is true, make sure `.github/workflows/tapestry-review.yml` exists (it ships with the framework) and tell the human it needs the `ANTHROPIC_API_KEY` repository secret (or `/install-github-app` to create it).

## 4. Report

Print what was written, the doctor's warnings (missing `gh` auth, missing scanners), and the next step: `/tapestry-new <your idea>`.
