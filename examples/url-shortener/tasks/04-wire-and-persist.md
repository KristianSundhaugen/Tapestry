---
feature: 001-url-shortener
task: 04
title: Wire SQLite store into the server, env config, shutdown, persistence test
wave: 3
depends_on: ["02", "03"]
touches: [src/server.ts, src/index.ts, src/links/memory-store.ts, test/persistence.test.ts, README.md]
status: merged
branch: tapestry/001-url-shortener/04-wire-and-persist
pr: 4
assignee: implementer
---

# Task 04: Wire SQLite store into the server, env config, shutdown, persistence test

## Goal

`npm run dev` starts a working shortener on `PORT` with a SQLite file at `DB_PATH`; links survive restart (AC5); README explains the three commands.

## Context

- Merged so far: task 02 (`SqliteLinkStore` in `src/links/store.ts`), task 03 (`registerLinkRoutes`, `MemoryLinkStore` with a local copy of the interface marked `TODO(04)`).
- Spec assumptions A1/A2: `BASE_URL` default `http://localhost:3000`; `DB_PATH` default `./data/links.db`, directory created on startup.
- Logging: Fastify's built-in pino logger, request lines only, no bodies.

## Steps

1. `src/links/memory-store.ts`: replace the local interface copy with `import type { Link, LinkStore } from "./store.js"`.
2. `src/server.ts`: `buildServer(deps: { store: LinkStore; baseUrl: string })`, register `registerLinkRoutes`, keep `/health`, `logger: true` with `disableRequestLogging: false`. Add `app.addHook("onClose", () => deps.store.close())`.
3. `src/index.ts`: read `PORT` (default 3000), `BASE_URL`, `DB_PATH`; `fs.mkdirSync(dirname(DB_PATH), { recursive: true })`; construct `SqliteLinkStore`; `buildServer`; `listen({ port, host: "0.0.0.0" })`; on `SIGINT`/`SIGTERM` → `app.close()` then exit.
4. `test/persistence.test.ts`: temp dir; build server with a `SqliteLinkStore` on `tmp/links.db`; POST a url; close app; build a *new* server on the same file; GET the id → 302.
5. `README.md`: what it is, `npm ci`, `npm run dev`, env vars, the two endpoints with curl examples.

## Acceptance criteria

| # | Criterion | Proof |
|---|-----------|-------|
| T1 | Links survive re-opening the DB file through the HTTP layer | `npm test -- persistence` |
| T2 | Whole suite green | `npm run lint && npm run typecheck && npm test` |
| T3 | Manual: start with `npm run dev`, POST then GET via curl, restart, GET again → 302 | paste curl output |

## Tests to write

`test/persistence.test.ts` as in step 4.

## Do not

- Change route behaviour or store internals. Add auth, analytics, or a UI.

## Done when

- [x] All acceptance criteria proven, with output pasted in the PR body
- [x] `commands.test`, `commands.lint`, `commands.typecheck` pass
- [x] Only files listed in `touches` changed
- [x] PR opened against the base branch with the PR template filled
- [x] Report returned to the orchestrator
