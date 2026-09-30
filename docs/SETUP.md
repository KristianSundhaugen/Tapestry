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
bin/tapestry window                                                  # allowed / HELD
```

On Windows from cmd: `copy .tapestry\config.local.example.json .tapestry\config.local.json` and `bin\tapestry window`.

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

## Windows (Windows Terminal + PowerShell)

Everything you type happens in a PowerShell tab in Windows Terminal. Every script you run by hand has a `.ps1` twin:

| Task | PowerShell | bash (macOS/Linux) |
|------|------------|--------------------|
| set up | `.\scripts\setup.ps1` | `scripts/setup.sh` |
| add to another repo | `.\scripts\setup.ps1 -Into C:\path\to\repo` | `scripts/setup.sh --into /path` |
| check environment | `.\scripts\tapestry-doctor.ps1` | `scripts/tapestry-doctor.sh` |
| status | `.\scripts\tapestry-status.ps1 [id]` | `scripts/tapestry-status.sh [id]` |
| push window now? | `.\scripts\push-window.ps1` | `scripts/push-window.sh` |
| launcher (any of the above, plus Claude stages) | `.\bin\tapestry doctor`, `.\bin\tapestry run <id>` | `bin/tapestry doctor`, `bin/tapestry run <id>` |
| extract a zip | `tar -xf file.zip` | `unzip file.zip` |

From `cmd.exe`, or if PowerShell refuses to run scripts, `bin\tapestry.cmd <command>` runs the same PowerShell launcher with the execution policy bypassed for that one process.

**Install once** (PowerShell, then open a new tab so PATH updates):

```powershell
winget install Git.Git                 # git itself; also provides the bash Claude Code runs hooks with
winget install Python.Python.3.12      # hooks and scripts need a real Python
winget install GitHub.cli ; gh auth login
winget install Anthropic.ClaudeCode    # or: irm https://claude.ai/install.ps1 | iex
winget install Gitleaks.Gitleaks       # optional, reviewer scanner
pip install semgrep                    # optional, reviewer scanner
```

**Things specific to Windows:**

- **You never open Git Bash.** Claude Code uses Git for Windows' bash in the background to run the hooks and the `scripts/*.sh` files, and git uses it to run `.githooks/pre-push`, whichever terminal you push from. It just has to be installed.
- **Claude's PowerShell tool is guarded too.** The guard hook's matcher is `Bash|PowerShell`, and it recognises `& git push`, `git.exe push` and `& 'C:\...\git.exe' push`.
- **Execution policy.** If PowerShell says running scripts is disabled, allow local scripts for your user once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. If a file came from a downloaded zip and is still refused, `Get-ChildItem -Recurse | Unblock-File` in the repo.
- **Python Store stub.** If the doctor says `python` is the Microsoft Store stub, turn it off: *Settings → Apps → Advanced app settings → App execution aliases*, switch off `python.exe` and `python3.exe`.
- **Line endings.** `.gitattributes` keeps `*.sh` and the git hooks LF (bash needs that) and `*.ps1` CRLF. If you cloned before it existed, commit or stash your work, then fix once with `git rm --cached -r . ; git reset --hard`.
- **Push window.** `Copy-Item .tapestry\config.local.example.json .tapestry\config.local.json`. Override once: `$env:TAPESTRY_PUSH_NOW='1'; git push; Remove-Item Env:TAPESTRY_PUSH_NOW`.
- **A Windows Terminal profile** that opens Claude Code in your project (Settings → Open JSON file → add to `profiles.list`; use `powershell.exe` instead of `pwsh.exe` if you don't have PowerShell 7):

  ```jsonc
  {
      "name": "Tapestry",
      "commandline": "pwsh.exe -NoLogo -NoExit -Command claude",
      "startingDirectory": "C:\\path\\to\\your\\project",
      "tabColor": "#7A9E7E"
  }
  ```
- **OneDrive.** Avoid keeping the repository in a OneDrive, Dropbox or iCloud folder: worktrees under `.claude\worktrees\` create and delete many files during a run, and sync clients are known to corrupt `.git` while syncing. Prefer `C:\Users\<you>\Projects`, or exclude the folder from sync.

## Maintaining Tapestry's own skills

The `/tapestry-*` commands are ordinary Claude Code skills under `.claude/skills/`. To change one with some rigour, install Anthropic's `skill-creator` (`/plugin marketplace add anthropics/skills`, then `/plugin install skill-creator@anthropic-agent-skills`) and ask it to review or evaluate the skill; it can run before/after comparisons so a prompt change is measured, not guessed. It is a maintainer's tool, not something a Tapestry user needs.

## Troubleshooting

- **"you are on the base branch" when committing** — the guard hook stopped a commit on `main`. Create a branch. If you are the orchestrator committing the ledger, include `.tapestry` in the command (`git commit -m "chore(tapestry): …"`).
- **Reviewer cannot check out the PR branch** — the implementer's worktree still has it checked out. `git worktree list`, then `git worktree remove <path>` or `git -C <path> switch --detach`, then `git worktree prune`. The implementer procedure ends with `git switch --detach` precisely to avoid this; check its report if it happens often.
- **Wave validation fails with "both touch"** — two tasks in one wave overlap on a path. Move one to a later wave or narrow `touches`.
- **Agents ask for permission constantly** — add the commands to `settings.local.json` (see §4).
- **Hooks do nothing** — they must be executable: `chmod +x .claude/hooks/*.sh`. `scripts/tapestry-doctor.sh` checks this.
- **`isolation: worktree` unknown** — your Claude Code is older than the frontmatter it reads. Update Claude Code; as a fallback, remove the `isolation` line and run `/tapestry-run` with `maxParallelImplementers: 1`.
