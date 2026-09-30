# Test run: prove the pipeline end to end

A scripted first run on a small, real feature (a weather API) that exercises every stage, every agent, the hooks and the GitHub loop, records what happened, and ends with a report you can hand to someone else (or to Claude) to judge.

Budget about an hour of wall-clock time for stages 3 to 5 and a noticeable amount of Claude usage: four to six agents run, some in parallel.

## What is being tested

| Stage | You run | Agent(s) | Hooks and tools that must work | Report checks |
|---|---|---|---|---|
| 0 setup | `bin/tapestry install`, `/tapestry-setup` | – | doctor, pre-push hook, session-start hook | *0 setup* |
| 1 interview | `/tapestry-new`, `/tapestry-interview` | main session | AskUserQuestion, templates | *1 interview* |
| 2 plan | `/tapestry-plan` | planner | wave validator | *2 plan* |
| 3 implement | `/tapestry-run` | implementer × N, in worktrees | guard hook, format hook, git, `gh pr create` | *3 implement* |
| 4 review | (inside `/tapestry-run`) | reviewer × N | tests, semgrep, gitleaks, `gh pr comment`, fix commits | *4 review* |
| 4b merge | (inside `/tapestry-run`) | main session | CI checks, `gh pr merge`, ledger commits | *4b merge* |
| 5 learn | `/tapestry-learn` | librarian | knowledge files, path-scoped rules, docs PR | *5 learn* |
| guards | a deliberate bad command | – | guard hook blocks it | *guards* |

MCP servers: Tapestry ships with none, on purpose (see [TOOLING.md](TOOLING.md)). The report records `claude mcp list` so you can see that nothing unexpected is loaded.

## Before you start

- `gh auth status` says you are logged in (`gh auth login` if not).
- Pick the app's stack by what already works in a Git Bash tab, because agents run commands there and CI runs the same commands on Linux:
  - **Python**: `python --version` must print a version. If it prints the Microsoft Store message, or `bin/tapestry doctor` warns that only `py` works, turn off the App execution aliases for `python.exe`/`python3.exe` and add Python to PATH (Settings > Apps > Installed apps > Python > Modify > Add Python to environment variables), then open a new tab.
  - **TypeScript**: `node --version` and `npm --version` must work (`winget install OpenJS.NodeJS.LTS`, new tab).

## 0. Prepare a separate test repository

Keep test code out of the Tapestry repo, and keep it out of OneDrive (agent worktrees create and delete many files). In Git Bash:

```bash
mkdir -p ~/Projects/weather-test && cd ~/Projects/weather-test
git init -b main
~/OneDrive/Dokumenter/Projects/Tapestry/scripts/setup.sh --into .
git add -A && git commit -m "chore: add Tapestry"
gh repo create weather-test --private --source=. --push
bin/tapestry trace on        # record every agent and tool event for the report
```

About timing: stages 3 to 5 push branches, open PRs, comment and merge. If you want no GitHub activity during working hours, either run those stages after your push window closes, or copy `.tapestry/config.local.example.json` to `.tapestry/config.local.json` in this repo too, in which case the run pauses with "held" at the first push and resumes when you run `/tapestry-run` again after the window. Seeing that hold happen is itself a useful test.

Then start Claude Code in the folder (`claude`) and run `/tapestry-setup`. Suggested answers:

- Name `weather-test`; description "Tiny HTTP API that returns current weather for a city."
- Stack: Python 3.12 with FastAPI, httpx and pytest, or TypeScript with Fastify and Vitest (see *Before you start*).
- Commands: leave empty. The planner makes the first task a bootstrap task; its implementer reports the project's commands and the orchestrator writes them into `.tapestry/config.json`. Seeing that happen (`orchestrator  commands-set` in the ledger) is part of the test.
- `maxParallelImplementers`: 2. `maxReviewRounds`: 2. Approve specs and plans yourself: yes. Merge PRs yourself: no.

## 1. Idea and interview

```
/tapestry-new Weather API: GET /weather?city=Oslo returns current temperature and conditions from Open-Meteo, with input validation, a 10-minute cache and clear error responses
/tapestry-interview <id printed above>
```

Open-Meteo needs no API key, so no secrets are involved. Useful answers if asked: no auth, no database, in-memory cache, tests must not call the real API (mock HTTP), unknown city returns 404, invalid input returns 400, upstream failure returns 502.

Look for: questions in rounds of at most three, a one-page `spec.md` with numbered acceptance criteria, and an approval prompt.

## 2. Plan

```
/tapestry-plan <id>
```

Look for: 3 to 5 tasks; the first bootstraps the project and test runner; **at least one wave with two tasks side by side** (for example "Open-Meteo client with geocoding" beside "HTTP route and validation against a fake client"). If every wave has a single task, reply with "split the client and the route into parallel tasks in the same wave". Exercising parallel worktrees is half the point.

## 3. Run

```
/tapestry-run <id> --dry-run      # shows what would be dispatched; changes nothing
/tapestry-run <id>
```

While it runs, look for:

- Background agents appearing in Claude Code's task list: implementers first, then reviewers.
- Branches `tapestry/<id>/NN-…` and PRs appearing on GitHub, each with a filled acceptance-criteria table.
- A reviewer comment on each PR; any `fix(review): …` commits the reviewer pushed.
- CI running on each PR (the `tapestry-review` workflow).
- PRs merged one by one, in wave order.

In a second pane (Ctrl+Shift+Y) you can follow along with `bin/tapestry status <id>`.

If it stops with *Blocked / needs human*, that is also a result: note what it said, fix or answer it, and run `/tapestry-run <id>` again.

## 4. Learn

```
/tapestry-learn <id>
```

Look for a PR titled `docs(knowledge): learnings from <id>`. Read the diff, merge it yourself on GitHub, then bring your checkout up to date so the report sees the knowledge files:

```bash
git switch main && git pull --ff-only
```

## 5. Probe the guard (two minutes)

In the same Claude session, ask it to do two things it must not be able to do:

```
Run exactly: git push --force origin main
Then run exactly: git commit --allow-empty -m "probe: direct commit on main"
```

Both should be refused by the Tapestry guard (make sure your checkout is on `main` for the second one). The refusals show up in the report under *guards*.

## 6. Report

```bash
bin/tapestry report <id>
```

This writes `.tapestry/test-runs/<id>-<date>.md` with a PASS / FAIL / SKIP checklist per stage, what each agent did, the PRs, the ledger and the environment. Then:

1. Attach that file in the Claude chat where you want the run assessed (this project's chat is fine: the file is plain Markdown). Add `.tapestry/logs/trace.jsonl` too if something looks wrong; it has every event.
2. Add a few lines of your own: anything that felt slow, confusing, or not what you expected. The report can only see what happened, not what you intended.
3. `bin/tapestry trace off` and restart `claude` when you are done testing.

## Reading the report

- **FAIL** on a stage means the artifact or behaviour that stage promises is missing. The *Evidence* column says what was found instead.
- **SKIP** means the check needed something that was not available (`gh` not authenticated, tracing off, no test command yet).
- *Informational* rows always PASS; judge them yourself (for example, each guard block should be one you expected).
