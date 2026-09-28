---
feature: 001-url-shortener
task: 01
title: Bootstrap project with TypeScript, Fastify, Vitest and lint
wave: 1
depends_on: []
touches: [package.json, tsconfig.json, vitest.config.ts, eslint.config.js, src/server.ts, test/smoke.test.ts]
status: merged
branch: tapestry/001-url-shortener/01-bootstrap
pr: 1
assignee: implementer
---

# Task 01: Bootstrap project with TypeScript, Fastify, Vitest and lint

## Goal

A runnable, testable, lintable TypeScript project exists so every later task has proof commands.

## Context

- Spec decisions: TypeScript, Node 22, Fastify, Vitest, no ORM, no Docker.
- The repo is empty apart from Tapestry files. Do not touch `.tapestry/` or `.claude/` except the ledger.
- After this task, `.tapestry/config.json` `commands` must be: `install: npm ci`, `test: npm test`, `lint: npm run lint`, `typecheck: npm run typecheck`, `format: npx prettier --write`, `build: npm run build`. Update the config file as part of this task (it is the one exception to `touches`, stated here explicitly).

## Steps

1. `npm init -y`; set `"type": "module"`, `"engines": { "node": ">=22" }`.
2. Add dependencies: `fastify`; dev: `typescript`, `vitest`, `@types/node`, `eslint`, `@eslint/js`, `typescript-eslint`, `prettier`, `tsx`.
3. `tsconfig.json`: `strict`, `module: NodeNext`, `outDir: dist`, `rootDir: src`, include `src`.
4. `src/server.ts`: `export function buildServer(): FastifyInstance` returning an instance with `GET /health` → `{ ok: true }`. No listen call here.
5. `test/smoke.test.ts`: build the server, `inject` `GET /health`, expect 200 and `{ ok: true }`.
6. `eslint.config.js` flat config with `@eslint/js` recommended + `typescript-eslint` recommended; `vitest.config.ts` with `include: ['test/**/*.test.ts']`.
7. Scripts: `test: vitest run`, `lint: eslint src test`, `typecheck: tsc --noEmit`, `build: tsc`, `dev: tsx src/index.ts` (index comes in task 04; the script may exist now).
8. Update `.tapestry/config.json` commands as listed in Context.

## Acceptance criteria

| # | Criterion | Proof |
|---|-----------|-------|
| T1 | `npm test` runs the smoke test and passes | `npm test` |
| T2 | `npm run lint` and `npm run typecheck` pass | both commands |
| T3 | `npm run build` produces `dist/server.js` | `npm run build && ls dist` |

## Tests to write

`test/smoke.test.ts` as in step 5.

## Do not

- Add routes beyond `/health`, a database, or `src/index.ts` (task 04).
- Add Docker, husky, or CI files (CI ships with Tapestry).

## Done when

- [x] All acceptance criteria proven, with output pasted in the PR body
- [x] `commands.test`, `commands.lint`, `commands.typecheck` pass
- [x] Only files listed in `touches` changed, plus `.tapestry/config.json` as stated
- [x] PR opened against the base branch with the PR template filled
- [x] Report returned to the orchestrator
