---
feature: 001-url-shortener
title: URL shortener service
status: approved
created: 2026-09-28
approved_by: kristian
base_branch: main
---

# Plan: URL shortener service

## Approach

Bootstrap a minimal TypeScript/Fastify project with Vitest first, so every later task has a proof command. Then build the storage layer and the HTTP layer in parallel against a shared `LinkStore` interface defined below. A final task wires them together, adds startup/shutdown, and the persistence test. Four tasks, three waves; the middle wave runs two implementers in parallel on disjoint files.

## Architecture touchpoints

```
src/
  server.ts        Fastify instance factory (task 01 creates it, task 04 wires deps)
  index.ts         entrypoint: env, store, listen, shutdown (task 04)
  links/
    store.ts       LinkStore interface + SQLite implementation (task 02)
    routes.ts      POST /links, GET /:id (task 03)
    ids.ts         base62 id generator (task 02)
    validate.ts    URL validation (task 03)
test/
  *.test.ts
```

## Waves

| Wave | Task | Title | Touches | Depends on | Est. size |
|------|------|-------|---------|------------|-----------|
| 1 | 01 | Bootstrap project: TS, Fastify, Vitest, lint, scripts | `package.json`, `tsconfig.json`, `vitest.config.ts`, `eslint.config.js`, `src/server.ts`, `test/smoke.test.ts` | – | S |
| 2 | 02 | SQLite link store with idempotent insert and id generation | `src/links/store.ts`, `src/links/ids.ts`, `test/store.test.ts`, `package.json` (deps only) | 01 | M |
| 2 | 03 | HTTP routes with validation, using an in-memory LinkStore | `src/links/routes.ts`, `src/links/validate.ts`, `src/links/memory-store.ts`, `test/routes.test.ts` | 01 | M |
| 3 | 04 | Wire SQLite store into the server, env config, shutdown, persistence test | `src/server.ts`, `src/index.ts`, `src/links/memory-store.ts`, `test/persistence.test.ts`, `README.md` | 02, 03 | S |

## Shared interfaces

Both wave-2 tasks code against this; task 02 implements it, task 03 consumes it via an in-memory implementation for tests.

```ts
// src/links/store.ts (task 02 owns the file; task 03 must not edit it)
export interface Link { id: string; url: string; createdAt: string }

export interface LinkStore {
  /** Returns the existing link for `url` or creates one. `created` is false when it already existed. */
  getOrCreate(url: string): { link: Link; created: boolean };
  getById(id: string): Link | undefined;
  close(): void;
}

// src/links/memory-store.ts (task 03 owns; test-only implementation of LinkStore)
```

HTTP contract (task 03):

```
POST /links      body { url: string }
  201 { id, shortUrl }   created
  200 { id, shortUrl }   already existed
  400 { error: "invalid_url", message }
GET  /:id
  302 Location: <url>
  404 { error: "not_found" }
```

`shortUrl` = `${BASE_URL}/${id}`; task 03 receives `baseUrl` through `registerLinkRoutes(app, { store, baseUrl })`; task 04 changes `buildServer()` to `buildServer({ store, baseUrl })` and reads `BASE_URL` from env.

## Verification strategy

After wave 3 merges: `npm run lint && npm run typecheck && npm test` green in CI (AC6); manual smoke with curl for AC1–AC4; `persistence.test.ts` covers AC5.

## Rollout and rollback

New service, no migration. Rollback = stop the process. DB file is created on first start.

## Learnings to capture

- Whether `better-sqlite3` builds cleanly on the VM's Node version.
- The `buildServer(deps)` factory pattern, if it works well, becomes a convention.
