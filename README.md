# Tapestry

A reusable multi-agent development pipeline for [Claude Code](https://code.claude.com). Clone it, run one setup step, and turn a raw idea into reviewed, merged pull requests:

```
raw idea ──▶ interview ──▶ spec ──▶ plan ──▶ parallel implementers ──▶ reviewer ──▶ merge ──▶ learn
             (stage 1)             (stage 2)   one PR per task (3)    applies fixes (4)       (5)
```

Every stage leaves a Markdown artifact in the repo, so the pipeline is resumable, reviewable, and gets smarter about your project with each feature.

## Why it looks the way it does

Tapestry is built from what the Claude Code community has found to work, and from what has failed (see [`docs/TOOLING.md`](docs/TOOLING.md) for the evidence):

- **Interview before plan.** Most bad plans come from unasked questions. Stage 1 is a structured interview run by Claude with you, not a form.
- **Small briefs, not big plans.** Each implementer gets one self-contained task file, never the whole plan. Big plans re-read by every agent are the most common token sink.
- **One task = one worktree = one branch = one PR.** Two agents never share a branch. Tasks that can run in parallel are grouped into *waves* whose files do not overlap; the planner is validated on that.
- **The reviewer fixes things.** A fresh-context reviewer runs your tests and scanners, reads the diff three ways (correctness, security, practice), commits the safe fixes itself, and writes a report with `file:line` evidence. Bounded: after `maxReviewRounds` a human decides.
- **The orchestrator never codes.** The main session keeps the ledger and dispatches agents. Anthropic's own guidance and every framework post-mortem say the same thing: the lead that starts implementing is the lead that loses track.
- **Learn loop.** After merge, a librarian agent writes what was learned into `.tapestry/knowledge/` and path-scoped `.claude/rules/`, and prunes what became false. Humans approve that PR.
- **Almost no MCP servers.** `gh`, `git` and local scanners cost a few hundred tokens per call; MCP tool definitions cost tens of thousands per session. `.mcp.json` is empty by default; opt-ins are documented.
- **Ceremony scales with the change.** A one-sentence diff skips the pipeline: branch, change, PR, `/tapestry-review`.

## Quick start

```bash
git clone https://github.com/KristianSundhaugen/Tapestry.git my-project && cd my-project
bin/tapestry install      # checks git, gh, claude, python; sets up git hooks
claude                    # start Claude Code
```

Then, inside Claude Code:

```
/tapestry-setup                         # one-time: stack, commands, base branch → .tapestry/config.json
/tapestry-new internal URL shortener    # creates .tapestry/features/001-internal-url-shortener/
/tapestry-interview 001-internal-url-shortener
/tapestry-plan 001-internal-url-shortener
/tapestry-run 001-internal-url-shortener
/tapestry-learn 001-internal-url-shortener
```

On Windows, in Windows Terminal (PowerShell):

```powershell
git clone https://github.com/KristianSundhaugen/Tapestry.git my-project; cd my-project
.\bin\tapestry install      # PowerShell setup: git hooks, environment check
claude
```

No Git Bash window needed; see [Windows](docs/SETUP.md#windows-windows-terminal--powershell).

First time? Do the [test run](docs/TEST-RUN.md): a small weather API that exercises every stage and ends with a pass/fail report.

Adding Tapestry to an existing repository: `scripts/setup.sh --into /path/to/repo` or `.\scripts\setup.ps1 -Into C:\path\to\repo`. Full instructions in [`docs/SETUP.md`](docs/SETUP.md).

## What is in the box

| Path | What |
|------|------|
| `CLAUDE.md`, `REVIEW.md` | Short project instructions and review calibration, loaded every session / every review |
| `.claude/agents/` | `planner`, `implementer`, `reviewer`, `librarian` — roles, tools, isolation, memory |
| `.claude/skills/` | The `/tapestry-*` commands that drive each stage |
| `.claude/rules/` | Always-on pipeline and git rules; `project/` holds rules the librarian learns |
| `.claude/hooks/` | Guard against force-pushes and base-branch commits; format on edit; status at session start |
| `.claude/settings.json` | Permissions and hook wiring |
| `.tapestry/config.json` | Your project profile: stack, commands, limits |
| `.tapestry/templates/` | The shapes of interview, spec, plan, task, progress, review, PR body |
| `.tapestry/knowledge/` | Long-term project memory, committed |
| `.tapestry/features/<id>/` | One folder per feature with all its artifacts |
| `.github/workflows/tapestry-review.yml` | CI: your checks + gitleaks + semgrep, then Claude review comments on every PR |
| `scripts/`, `bin/tapestry` | Setup, doctor, validation, status, and a CLI wrapper |
| `docs/` | [Setup](docs/SETUP.md) · [Architecture](docs/ARCHITECTURE.md) · [Agents](docs/AGENTS.md) · [Tooling](docs/TOOLING.md) · [Walkthrough](docs/WALKTHROUGH.md) · [Test run](docs/TEST-RUN.md) |
| `examples/url-shortener/` | Every artifact from one complete run |

## Requirements

Claude Code (recent; the agent frontmatter uses `isolation: worktree` and `memory: project`), `git` (on Windows: Git for Windows, whose bundled bash Claude Code uses to run hooks; you never open it yourself), Python 3 (hooks and scripts), and the [GitHub CLI](https://cli.github.com) authenticated with `gh auth login`. Optional: `semgrep`, `gitleaks` for the reviewer's scanners.

## License

MIT — see [LICENSE](LICENSE).
