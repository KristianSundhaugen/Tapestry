# Setup and onboarding

For a developer who knows git and Claude Code but has not used Tapestry. About fifteen minutes.

## 1. Prerequisites

| Tool | Why | Check |
|------|-----|-------|
| Claude Code | runs everything | `claude --version` |
| git | branches, worktrees | `git --version` |
| GitHub CLI `gh` | implementers open PRs, reviewers comment, orchestrator merges | `gh auth status` |
| python3 | hooks and helper scripts parse JSON with it | `python3 --version` |
| semgrep, gitleaks (optional) | reviewer's deterministic security checks | `semgrep --version`, `gitleaks version` |

`scripts/tapestry-doctor.sh` checks all of these and tells you what is missing.

## 2. Get the framework

**Option A — start a new project from Tapestry**

```bash
git clone https://github.com/KristianSundhaugen/Tapestry.git my-project
cd my-project
git remote rename origin tapestry           # keep it around for updates
gh repo create my-org/my-project --private --source=. --push
scripts/setup.sh
```

**Option B — add Tapestry to an existing repository**

```bash
git clone https://github.com/KristianSundhaugen/Tapestry.git /tmp/tapestry
/tmp/tapestry/scripts/setup.sh --into /path/to/your/repo
```

This copies `.claude/`, `.tapestry/`, `.github/workflows/tapestry-review.yml`, `scripts/`, `bin/`, `REVIEW.md`, appends the Tapestry section to an existing `CLAUDE.md`, and adds the worktree and local-settings entries to `.gitignore`. Existing files are never overwritten; the script says what it skipped so you can merge by hand.

Commit the result on a branch and merge it like any other change.

## 3. Configure the project

Start Claude Code in the repo and run:

```
/tapestry-setup
```

It detects your stack and the commands for install, test, lint, typecheck, format and build, asks you to confirm them, and writes `.tapestry/config.json`. It also seeds `.tapestry/knowledge/architecture.md` and the *Project notes* block in `CLAUDE.md`.

The one setting that matters most is `commands.test`. Every implementer proves its work with it and every reviewer re-runs it. If your project has no tests yet, leave it empty; the planner will make "add a test runner and a smoke test" the first task of your first feature.

You can edit `.tapestry/config.json` by hand at any time; `scripts/tapestry-validate.sh --config` checks it. Key knobs:

| Key | Default | Meaning |
|-----|---------|---------|
| `project.baseBranch` | `main` | PR target; worktrees branch from it |
| `pipeline.maxParallelImplementers` | 3 | implementers running at once in a wave |
| `pipeline.maxReviewRounds` | 3 | review→fix cycles per PR before a human is asked |
| `pipeline.humanApprovesSpec` / `humanApprovesPlan` | true | gates after stages 1 and 2 |
| `pipeline.humanMergesPRs` | false | true = orchestrator stops at "approved" and you merge |
| `review.scanners` | semgrep, gitleaks | run by the reviewer when installed |
| `review.autoApplyFixes` | true | reviewer commits fixes; false = patches in the report only |
| `models.*` | inherit | per-role model alias, mirrored into each agent's `model:` frontmatter by `/tapestry-setup` (`haiku` is a reasonable choice for the librarian) |

## 4. Permissions

`.claude/settings.json` allows the git and `gh` operations the pipeline needs and denies force-pushes, hard resets and reading `.env*`. Your package manager and test runner are **not** pre-allowed because Tapestry does not know your stack; copy `.claude/settings.local.json.example` to `.claude/settings.local.json` and add them (`Bash(npm *)`, `Bash(pytest*)`, …), or accept the prompts the first time.

The `guard-bash.sh` hook enforces three invariants regardless of permissions: no force-push to protected branches, no direct push to protected branches, no commits while on the base branch (except ledger commits).

## 5. CI

`.github/workflows/tapestry-review.yml` runs on every pull request:

1. Your commands from `config.json` (install, lint, typecheck, test, build), then `gitleaks` and `semgrep`. These block merging if you enable branch protection.
2. A Claude review with inline comments via `anthropics/claude-code-action`, if the `ANTHROPIC_API_KEY` secret exists. Advisory only.

Add your toolchain step (`actions/setup-node`, `setup-python`, …) where the comment says. To get the API key into the repo: `gh secret set ANTHROPIC_API_KEY`, or run `/install-github-app` inside Claude Code and switch the workflow to `claude_code_oauth_token`.

Recommended branch protection on the base branch: require the `deterministic checks` job for PRs, require a linear history, and disallow force pushes. Do **not** require a pull request for every push, or add a bypass for the person running the pipeline: the stage commands commit ledger files (`.tapestry/…`) straight to the base branch. If your organisation forbids that, set `pipeline.humanMergesPRs: true` and push the ledger commits yourself after each run; the skills tell you when a push was rejected.

## 5b. Optional: a personal push window

To keep all GitHub activity (pushes, PRs, review comments, merges) out of certain hours, for example your working day, create a personal config that is never committed:

```bash
cp .tapestry/config.local.example.json .tapestry/config.local.json   # holds Mon–Fri 08:00–16:00 by default
scripts/push-window.sh && echo allowed || echo held
```

While the window is active: the `.githooks/pre-push` hook refuses your own `git push` (setup sets `core.hooksPath` for this); the guard hook refuses agents' `git push` and GitHub-writing `gh` commands; and `/tapestry-run` keeps implementers building and committing locally, then stops with a list of held branches. Run `/tapestry-run <id>` again after the window closes and it pushes, opens the PRs, reviews and merges. Override once with `TAPESTRY_PUSH_NOW=1 git push`.

The window controls when things reach GitHub, not the timestamps inside commits. Git records author and committer times when a commit is made, and GitHub shows them. If that matters to you, the times are the ones your machine had when you (or the agents) committed.

## 6. First feature

```
/tapestry-new <your idea in one line>
/tapestry-interview <id>     # answer questions; approve the one-page spec
/tapestry-plan <id>          # approve the waves table
/tapestry-run <id>           # watch PRs appear; the reviewer fixes and the orchestrator merges
/tapestry-learn <id>         # approve the knowledge PR
```

`/tapestry-status` at any time shows where things are. Everything lives in `.tapestry/features/<id>/`; if a session dies, run `/tapestry-run <id>` again and it resumes from `progress.md`.

## 7. Keeping Tapestry up to date

Tapestry's own files are under `.claude/`, `.tapestry/templates/`, `scripts/`, `bin/`, `docs/`. Your project's state is under `.tapestry/config.json`, `.tapestry/knowledge/`, `.tapestry/features/`, `.claude/rules/project/`, `.claude/agent-memory/`. To upgrade, pull the framework files from the `tapestry` remote and review the diff; the state directories are never touched by an upgrade.

## Windows notes

Tapestry works on Windows through Git Bash, which Claude Code needs anyway.

- Install [Git for Windows](https://git-scm.com/download/win) (provides Git Bash), a real Python 3 (`winget install Python.Python.3.12`, or python.org with *Add to PATH* ticked), and `gh` (`winget install GitHub.cli`, then `gh auth login`). Open a new terminal afterwards so PATH updates.
- If `scripts/tapestry-doctor.sh` says `python3` is the Microsoft Store stub, turn the stubs off: *Settings → Apps → Advanced app settings → App execution aliases*, switch off `python.exe` and `python3.exe`. The scripts also accept the `py` launcher that the python.org installer adds.
- Commands like `unzip`, `mv` and `~` are Git Bash, not `cmd.exe`. In `cmd`/PowerShell, `tar -xf file.zip` extracts a zip.
- Run `scripts/setup.sh` and `bin/tapestry` from Git Bash, not PowerShell. Hooks and scripts detect `python` when `python3` is absent.
- Line endings: `.gitattributes` pins the scripts to LF. If you cloned before that file existed, run `git rm --cached -r . && git reset --hard` once in Git Bash.
- Avoid putting the repository inside a OneDrive, Dropbox or iCloud folder. Git worktrees under `.claude/worktrees/` create and delete thousands of files during a run, and sync clients are known to corrupt `.git` while syncing them. If you must, exclude the folder from sync (OneDrive: *Settings → Sync and backup → Manage backup*, or right-click → *Free up space* is not enough; use *Choose folders* to deselect it) or set `worktree.baseRef` aside and run with `maxParallelImplementers: 1`.
- `chmod +x` has no effect on NTFS; Git Bash runs the scripts by their shebang, so nothing else is needed.

## Troubleshooting

- **"you are on the base branch" when committing** — the guard hook stopped a commit on `main`. Create a branch. If you are the orchestrator committing the ledger, include `.tapestry` in the command (`git commit -m "chore(tapestry): …"`).
- **Reviewer cannot check out the PR branch** — the implementer's worktree still has it checked out. `git worktree list`, then `git worktree remove <path>` or `git -C <path> switch --detach`, then `git worktree prune`. The implementer procedure ends with `git switch --detach` precisely to avoid this; check its report if it happens often.
- **Wave validation fails with "both touch"** — two tasks in one wave overlap on a path. Move one to a later wave or narrow `touches`.
- **Agents ask for permission constantly** — add the commands to `settings.local.json` (see §4).
- **Hooks do nothing** — they must be executable: `chmod +x .claude/hooks/*.sh`. `scripts/tapestry-doctor.sh` checks this.
- **`isolation: worktree` unknown** — your Claude Code is older than the frontmatter it reads. Update Claude Code; as a fallback, remove the `isolation` line and run `/tapestry-run` with `maxParallelImplementers: 1`.
