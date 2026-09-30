# MCP servers, skills and tools: what Tapestry uses and why

Researched September 2026 against what the Claude Code community has actually reported using. The pattern is consistent: the tools that survived contact with real pipelines are CLIs and hooks; most MCP servers lost on token cost, auth friction or reliability. Sources at the bottom.

## The rule behind the choices

MCP tool definitions are loaded into every session's context. Measured costs: the GitHub MCP server's ~90 tools cost roughly 55k tokens of definitions; Playwright MCP about 13.7k; a many-server setup around 150k. Claude Code's tool search (deferred loading, on by default with current models) reduces the startup cost, but per-call outputs are still larger than the equivalent CLI, and agents confuse similar tools. Anthropic's own best-practices page says CLI tools are the most context-efficient way to reach external services and explicitly recommends `gh`. So Tapestry ships **zero MCP servers by default** and adds them only for capabilities a CLI cannot provide.

## Used by default

| Tool | Purpose in Tapestry | Why it fits | Known limitations |
|------|---------------------|-------------|-------------------|
| **`gh` CLI** (cli.github.com) | implementers `gh pr create`, reviewers `gh pr checkout/comment/review`, orchestrator `gh pr checks/merge`, librarian reads merged PRs | Anthropic's recommendation; Claude knows it; a call costs hundreds of tokens, not thousands; `/code-review --comment` and `/install-github-app` depend on it anyway | needs `gh auth login` per machine; in CI use `GITHUB_TOKEN` |
| **git worktrees** (built into Claude Code: `isolation: worktree`, `--worktree`) | one isolated checkout per implementer/reviewer | the only isolation model the community found that reliably prevents agents overwriting each other; Anthropic's `/batch` uses the same mechanism | a worktree that made changes persists until pruned; the implementer detaches its branch at the end so the reviewer can check it out |
| **Claude Code subagents** (`.claude/agents/`) with `memory: project` | planner, implementer, reviewer, librarian | fresh context per role is the single most repeated success factor; project memory gives cross-session learning committed to git | nested output is summarised; max depth 3 (Tapestry never nests) |
| **Claude Code skills** (`.claude/skills/`) | the `/tapestry-*` stage commands | `disable-model-invocation: true` keeps pipeline stages explicit; `allowed-tools` limits blast radius | the interview must run in the main session (needs `AskUserQuestion`) |
| **Claude Code hooks** | force-push guard, base-branch guard, format-on-edit, session status | deterministic; instructions in prompts are advisory, hooks are not | need `python3`; must be executable |
| **`.claude/rules/` with `paths:`** | learned, path-scoped project rules | keeps `CLAUDE.md` short (bloated `CLAUDE.md` files get ignored) while making rules precise | rules that load on demand only apply when matching files are read |
| **`/code-review`** (bundled Claude Code skill) | second opinion inside the reviewer agent (`claude -p "/code-review high <base>...HEAD"`); CI review comments via `claude-code-action`; humans can also run `/code-review --fix` locally | 400k+ installs of the plugin form; the only mainstream reviewer that produces patches (`--fix`) rather than comments only | `--fix` edits in a background subagent bypass `/rewind`, revert with git; the managed GitHub-app version is Team/Enterprise only and ~$15–25 per PR |
| **`/security-review`** (bundled Claude Code skill) | semantic security pass inside the reviewer agent, next to semgrep and gitleaks | official; catches injection, authz and data-handling issues that pattern scanners miss; free | not hardened against prompt injection, so only on code the team wrote or reviewed; findings are confirmed by the reviewer before they count |
| **`skill-creator`** (official `anthropics/skills` marketplace) | authoring and evaluating Tapestry's own `/tapestry-*` skills | Anthropic's own tool, includes eval runs so a prompt change can be measured instead of eyeballed | for maintainers of the framework, not needed to use it |
| **`anthropics/claude-code-action`** | the advisory review job in `.github/workflows/tapestry-review.yml` | official; runs your own prompt in CI; inline comments through its bundled inline-comment tool | needs `ANTHROPIC_API_KEY` or the OAuth token from `/install-github-app`; not hardened against prompt injection, so only on trusted PRs |
| **semgrep** (CLI) | reviewer's SAST pass; CI job | archived-MCP → CLI is the maintained path; `--config auto` needs no setup; `--baseline-commit` limits CI to the diff | `auto` config sends metrics unless `--metrics=off`; needs Python; slow first run |
| **gitleaks** (CLI + GitHub Action) | secret detection in the reviewer and CI | fast, zero-config, widely adopted; catches the failure the reviewer must never miss | regex-based; tune `.gitleaks.toml` for false positives in fixtures |
| **Claude Code auto memory** | machine-local notes, alongside Tapestry's committed knowledge | built in, on by default, no setup | not shared across machines or CI; Tapestry's `.tapestry/knowledge/` is the shared layer |

## Opt-in: add when a concrete gap appears

Copy the snippet into `.mcp.json` → `mcpServers`, or run the `claude mcp add` command.

| Tool | Purpose | Why you might want it | Limitations | Install |
|------|---------|------------------------|-------------|---------|
| **Anthropic code-intelligence plugins** (`typescript-lsp`, `pyright-lsp`, `gopls`, `rust-analyzer`, …) | diagnostics after edits, go-to-definition | official, no MCP overhead; catches type errors before the test run | not available in cloud sessions; one plugin per language | `/plugin install typescript-lsp@claude-plugins-official` |
| **Context7** (upstash) | current library docs for post-cutoff APIs | avoids hallucinated APIs for new framework versions | free tier now 1,000 req/month; large responses; indexing lags releases; give it to a research subagent, not the main loop | `claude mcp add --transport http context7 https://mcp.context7.com/mcp --header "CONTEXT7_API_KEY: $CONTEXT7_API_KEY"` |
| **Serena** (oraios) | LSP-backed symbol search and edit for large codebases | real `find_symbol` / `find_referencing_symbols`; helps planners on 20k+ LOC repos where LSP plugins do not cover the language | maintainers advise skipping under ~20k LOC; can fill context faster; opens a dashboard tab | `claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --project-from-cwd` |
| **Playwright CLI** (`@playwright/cli`) | end-to-end verification in `commands.e2e` | Microsoft ships the CLI because MCP snapshots were 4× the tokens; `--skills` installs a Claude skill | needs a browser; CLI still evolving | `npm i -g @playwright/cli@latest && playwright-cli install --skills` |
| **GitHub MCP server** (github/github-mcp-server) | only for toolsets `gh` lacks: `code_security`, `dependabot`, `secret_protection` alerts, or sandboxes without a shell | official; remote OAuth | ~90 tools; dynamic toolsets deprecated after discovery failures; PAT scope friction; users report switching back to `gh` | `claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer $GITHUB_PAT" --header "X-MCP-Toolsets: repos,pull_requests"` |
| **Snyk MCP / CLI** | SCA/SAST/IaC with a Snyk account | commercial-grade dependency intelligence | account required; per-directory trust; the `snyk test` CLI gives the same results without tool definitions | `npx -y snyk@latest mcp configure --tool=claude-cli` |
| **Trivy CLI** | container and IaC scanning | standard in CI for images | only relevant if you ship containers; the MCP variant has no pipeline adoption evidence | `brew install trivy`; add `"trivy"` to `review.scanners` |

## Evaluated and not used

| Tool | Why not |
|------|---------|
| **Official `memory` MCP (knowledge graph)** | single JSONL file, no project scoping, Claude ignores it unless told; superseded by auto memory and committed knowledge files |
| **mem0 MCP** | cloud, API key, lossy (configs dropped when memories were atomised in a head-to-head test); adds value only for cross-agent semantic search |
| **claude-mem** | very popular but the flaky one: reported worker crashes, 50 GB+ local stores, high CPU; not pipeline-grade |
| **basic-memory / Graphiti / Zep** | Markdown-in-git is what `.tapestry/knowledge/` already is; graph stores need extra infrastructure and LLM calls for no gain on code context |
| **Sequential Thinking MCP** | Anthropic recommends extended thinking instead; package unmaintained; "context waste" in user reports |
| **git MCP (`mcp-server-git`)** | wraps twelve git commands Bash already runs with better fidelity |
| **Semgrep MCP / Guardian plugin** | standalone MCP archived Oct 2025; the plugin requires a Semgrep account and has minimal adoption; CLI in hooks/CI is the pattern that works |
| **Agent Teams (experimental)** | shared task list with file-locked claiming; documented overwrites when two teammates edit one file, no resume, lead drifts into implementing; disabled in `-p` mode. Tapestry's waves + worktrees give the parallelism without those failure modes |
| **Whole-marketplace installs** (everything-claude-code, wshobson/agents, superpowers) | catalogs of 48–94 agents; install single plugins if you want one, never the set: every agent description is context |

## Community patterns Tapestry borrowed

- *Grill the idea until no decision branch is open, one question at a time with a recommended answer, looking up what the codebase already knows* (mattpocock's `grill-me`); it is the second half of `/tapestry-interview`.
- *Verification before completion: run the exact command, read the output to the end, paste it next to the claim* (obra/superpowers' most-praised skill); it is a hard section in both the implementer and the reviewer.
- *Surgical changes, simplest thing that meets the criteria, know the finish line before starting* (the Karpathy `CLAUDE.md`); folded into the implementer's working style.
- *Interview → SPEC.md in a fresh session* (Anthropic best practices); *brainstorm → plan → subagent-driven development with per-task briefs and a controller that never fixes code* (obra/superpowers); *plans and solutions as dated Markdown that the next plan reads* (Every's compound engineering); *PRD → epic → tasks with `parallel` markers and a ledger in files* (ccpm); *one story per iteration, learnings appended, iteration caps* (Ralph pattern).
- Failures avoided: monolithic plans re-read by every agent (superpowers #512), ceremony on small changes (spec-kit critiques: 9× slower on a small task), multiple agents sharing a branch (ccpm, BMAD, agent teams), deep orchestration layers that fail silently (claude-flow #789), unbounded loops (Ralph).

## Sources

- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- MCP in Claude Code, tool search: https://code.claude.com/docs/en/mcp
- Subagents, worktrees, hooks, memory, code review, GitHub Actions: https://code.claude.com/docs/en/sub-agents · /worktrees · /hooks · /memory · /code-review · /github-actions
- Anthropic, "Code execution with MCP" (tool-definition cost): https://www.anthropic.com/engineering/code-execution-with-mcp
- MCP vs CLI token measurements: https://mariozechner.at/posts/2025-11-02-what-if-you-dont-need-mcp/ · https://vensas.de/en/blog/mcp-vs-cli-cost-comparison
- GitHub MCP server issues (dynamic toolsets, users moving to `gh`): https://github.com/github/github-mcp-server/issues/275
- Anthropic claude-code-security-review: https://github.com/anthropics/claude-code-security-review
- Semgrep MCP archived: https://github.com/semgrep/mcp
- Playwright CLI vs MCP: https://github.com/microsoft/playwright-cli
- Memory comparisons: https://www.logicweave.ai/claude-code-memory-vs-mem0-tested/ · claude-mem issues #423, #903, #2096
- Serena: https://github.com/oraios/serena
- superpowers plan-size issue: https://github.com/obra/superpowers/issues/512
- spec-kit critiques: https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html · https://azanello.com/blog/github-spec-kit-review
- ccpm: https://github.com/automazeio/ccpm · compound engineering: https://github.com/EveryInc/compound-engineering-plugin
- Ralph loop failure modes: https://ralphloop.sh/blog/ralph-loop-failure-modes
- Agent teams: https://code.claude.com/docs/en/agent-teams
