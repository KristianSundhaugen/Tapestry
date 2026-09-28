---
feature: 001-url-shortener
task: 02
title: SQLite link store with idempotent insert and id generation
wave: 2
depends_on: ["01"]
touches: [src/links/store.ts, src/links/ids.ts, test/store.test.ts, package.json]
status: merged
branch: tapestry/001-url-shortener/02-sqlite-store
pr: 2
assignee: implementer
---

# Task 02: SQLite link store with idempotent insert and id generation

## Goal

`SqliteLinkStore` implements `LinkStore` on a SQLite file with a unique index on `url`, and `generateId()` yields 7-char base62 ids.

## Context

- Spec decisions: `better-sqlite3`, no ORM; 7-char random base62 ids with bounded collision retry; duplicate URLs idempotent.
- Shared interface (you own this file; write it exactly as below at the top of `src/links/store.ts`):

```ts
export interface Link { id: string; url: string; createdAt: string }
export interface LinkStore {
  getOrCreate(url: string): { link: Link; created: boolean };
  getById(id: string): Link | undefined;
  close(): void;
}
```

- Task 03 runs in parallel and consumes this interface through its own in-memory implementation; it does not import your SQLite class. Do not create `memory-store.ts` or touch `routes.ts`.
- `package.json` is in `touches` only to add the `better-sqlite3` and `@types/better-sqlite3` dependencies; change nothing else in it.

## Steps

1. `src/links/ids.ts`: `export function generateId(length = 7): string` using `crypto.randomBytes` mapped onto `[0-9A-Za-z]`. No modulo bias worries at this scale, but reject bias-prone shortcuts like `Math.random`.
2. `src/links/store.ts`: interfaces above; `export class SqliteLinkStore implements LinkStore` with constructor `(dbPath: string)`. On construct: open with `better-sqlite3`, `PRAGMA journal_mode = WAL`, create table `links(id TEXT PRIMARY KEY, url TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL)` if not exists. Prepare statements once.
3. `getOrCreate(url)`: inside a transaction, `SELECT` by url → return `{ created: false }` if found; else loop up to 5 times: `generateId()`, `INSERT`, on `SQLITE_CONSTRAINT_PRIMARYKEY` retry; on `SQLITE_CONSTRAINT_UNIQUE` (url raced in) re-select and return `{ created: false }`. After 5 id collisions throw `Error("id_collision")`.
4. `getById(id)`, `close()`.
5. Tests in `test/store.test.ts` using a temp file per test (`fs.mkdtempSync`).

## Acceptance criteria

| # | Criterion | Proof |
|---|-----------|-------|
| T1 | `getOrCreate` returns `created: true` first time, `false` with the same id the second time | `npm test -- store` |
| T2 | `getById` returns the link or `undefined` | `npm test -- store` |
| T3 | Ids are 7 chars from `[0-9A-Za-z]`; 10,000 generated ids contain no duplicates | `npm test -- store` |
| T4 | Reopening the same file returns previously stored links | `npm test -- store` |

## Tests to write

`test/store.test.ts`: the four cases above plus "close() then use throws".

## Do not

- Implement HTTP anything. Edit `src/server.ts`. Add an ORM or a migration tool.

## Done when

- [x] All acceptance criteria proven, with output pasted in the PR body
- [x] `commands.test`, `commands.lint`, `commands.typecheck` pass
- [x] Only files listed in `touches` changed
- [x] PR opened against the base branch with the PR template filled
- [x] Report returned to the orchestrator
