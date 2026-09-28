# Walkthrough: from a raw idea to merged code

A narrated run of Tapestry on a small feature. The artifacts it produced are in [`examples/url-shortener/`](../examples/url-shortener/); this page shows what you type, what you see, and what happens in between. Timestamps are from the example ledger.

## 0. Setup (once)

```
$ git clone https://github.com/KristianSundhaugen/Tapestry.git shortener && cd shortener
$ scripts/setup.sh
Tapestry doctor
required:
  OK       git 2.47.1
  OK       python3 3.12.3
  OK       claude 2.1.3xx
  OK       gh authenticated
...
$ claude
> /tapestry-setup
```

The setup skill sees an empty repo, asks for a name and description, confirms the base branch `main`, leaves the commands empty ("wave 1 will bootstrap them"), and writes `.tapestry/config.json`.

## 1. Idea → feature folder

```
> /tapestry-new internal URL shortener API
created .tapestry/features/001-internal-url-shortener-api/ (interview.md, spec.md, progress.md, tasks/, reviews/)
next: /tapestry-interview 001-internal-url-shortener-api
```

(The example uses the shorter id `001-url-shortener`.)

## 2. Interview (stage 1) — 09:02 → 09:31

```
> /tapestry-interview 001-url-shortener
```

Claude reads the raw idea and asks in rounds of at most three questions. Some of what it asked, and what changed because of the answers:

- *"Walk me through the moment someone uses this."* → engineers pasting dashboard links in chat; curl and scripts first, a bookmarklet later. This fixed the interface: JSON API, no UI.
- *"Custom aliases, analytics, auth, expiry — which of these are in?"* with all four proposed as out of scope → none in. This became the *Out of scope* list nobody had to argue about later.
- *"p95 under 50 ms and 50 req/s — accept or correct?"* → accepted. Numbers the reviewer can check.
- *"Same long URL posted twice?"* → same short id back. This produced a unique index and an idempotency test.
- *"What would make you reject the finished result?"* → "if I can't read it in an afternoon." That killed the ORM.

Two questions stayed open (base URL, id length) and became assumptions A1 and A2 in the spec. Claude showed the one-page `spec.md` and asked for approval; Kristian approved. Ledger: `interviewer  spec-approved  6 ACs, 2 assumptions`.

## 3. Plan (stage 2) — 09:40 → 09:44

```
> /tapestry-plan 001-url-shortener
```

The main session dispatches the **planner** agent. It reads the spec, the interview, the (still empty) knowledge, and the (empty) repo, and writes `plan.md` plus four task briefs:

| Wave | Task | Touches |
|------|------|---------|
| 1 | 01 bootstrap | `package.json`, `tsconfig.json`, `src/server.ts`, `test/smoke.test.ts`, … |
| 2 | 02 sqlite store | `src/links/store.ts`, `src/links/ids.ts`, `test/store.test.ts`, `package.json` |
| 2 | 03 http routes | `src/links/routes.ts`, `validate.ts`, `memory-store.ts`, `test/routes.test.ts` |
| 3 | 04 wire + persist | `src/server.ts`, `src/index.ts`, `memory-store.ts`, `test/persistence.test.ts`, `README.md` |

Note the design move that makes wave 2 parallel: the `LinkStore` interface is written out in *Shared interfaces*, task 02 owns `store.ts`, and task 03 codes against a local in-memory copy so it never has to touch task 02's file. `scripts/tapestry-validate.sh` confirms no overlaps. Kristian approves the waves table. Ledger: `human  plan-approved  4 tasks, 3 waves`.

## 4. Run (stages 3 and 4) — 09:45 → 11:31

```
> /tapestry-run 001-url-shortener
```

The orchestrator reads the ledger, fetches, prunes worktrees, and starts wave 1.

**Wave 1.** One **implementer** is dispatched with task 01. In its own worktree it creates branch `tapestry/001-url-shortener/01-bootstrap`, scaffolds the project, writes the smoke test, runs `npm test`, `npm run lint`, `npm run typecheck`, updates `config.json`'s commands (the brief explicitly allowed it), rebases, pushes, and runs `gh pr create` with the PR body template filled — including the actual test output. It reports back in twelve lines. The orchestrator records the PR in the ledger and dispatches the **reviewer** on PR #1: checks green, one nit (a missing `engines` field), verdict `approve`, report committed on the branch, summary posted as a PR comment. `gh pr checks --watch` (CI runs the same commands plus gitleaks and semgrep), `gh pr merge --squash --delete-branch`. Ledger updated; wave 1 done at 10:08.

**Wave 2.** Two implementers start at 10:09 in two worktrees, both branched from the freshly merged `main`. They never see each other. Task 02 opens PR #2 at 10:27, task 03 opens PR #3 at 10:31; each implementer's return message is written into the ledger by the orchestrator. Two reviewers run in parallel.

The reviewer on PR #3 is the interesting one — read [`reviews/03-r1.md`](../examples/url-shortener/reviews/03-r1.md). It re-ran the proof commands, then in the correctness pass found that `URL.protocol` was compared without the trailing colon, which the tests had not caught because the happy-path test bypassed the validator. It fixed the bug, fixed the test so it goes through the real validator, found a header-injection surface in the security pass and fixed that too, pushed two `fix(review)` commits, wrote the report, posted the summary on the PR, and left one question (trailing slash in `BASE_URL`) as an unapplied patch for the task that owns env handling. Verdict `fixed`. The orchestrator re-checked CI, merged #2 then #3.

**Wave 3.** Task 04 wires it together. Its first review came back `changes_requested`: the `SIGTERM` handler called `process.exit` without awaiting `app.close()`, which loses the last SQLite write. The reviewer did not auto-fix it because the fix changes shutdown semantics; it wrote the patch in the report. The orchestrator resumed the same implementer with the report path; it applied the patch and pushed; reviewer round 2: `approve`. Merged at 11:31. Ledger: `orchestrator  feature-merged  4 PRs, 5 review rounds`.

What you saw during those ninety minutes: the task list widget moving, four PRs appearing on GitHub with filled bodies and review comments, and one message from the orchestrator per wave. What you did: nothing, unless something had landed in *Blocked / needs human*.

## 5. Learn (stage 5) — 11:40

```
> /tapestry-learn 001-url-shortener
```

The **librarian** reads the ledger, the five review reports, the four PR bodies and the agents' memory files, and opens PR #5 `docs(knowledge): learnings from 001-url-shortener`. Its diff is in [`knowledge-after.md`](../examples/url-shortener/knowledge-after.md): an architecture summary, two decisions, three conventions, three gotchas (two of them straight from review findings), one path-scoped rule for HTTP handlers, and a *Project notes* block in `CLAUDE.md` — ten entries in all. Kristian reads the diff, removes one over-general convention, merges.

From now on, the planner reads `architecture.md` before slicing, any agent editing `src/**/routes.ts` gets the handler rule injected, and the reviewer's memory says "check `URL.protocol` comparisons first".

## 6. The next feature

```
> /tapestry-new add link expiry
```

The interview is shorter, because `knowledge/decisions.md` already says there is no auth and no analytics and the stack is fixed. The plan is smaller, because `architecture.md` says where routes and stores live. The reviewer knows the shutdown gotcha. That is the learning loop working.

## If something goes wrong

- The session dies mid-run: `/tapestry-run 001-url-shortener` again. It reconciles the ledger with `gh`, skips merged tasks, resumes `in_review` ones at review, restarts `in_progress` ones.
- An agent writes to *Blocked / needs human*: `/tapestry-status 001-url-shortener` shows it; fix the spec or the brief, clear the section, run again.
- You disagree with a review fix: revert the `fix(review)` commit on the branch and add a line to `REVIEW.md` so it does not recur.
