---
feature: 001-url-shortener
task: 03
title: HTTP routes with validation against an in-memory LinkStore
wave: 2
depends_on: ["01"]
touches: [src/links/routes.ts, src/links/validate.ts, src/links/memory-store.ts, test/routes.test.ts]
status: merged
branch: tapestry/001-url-shortener/03-http-routes
pr: 3
assignee: implementer
---

# Task 03: HTTP routes with validation against an in-memory LinkStore

## Goal

`registerLinkRoutes(app, { store, baseUrl })` serves `POST /links` and `GET /:id` per the HTTP contract, validated, tested against an in-memory store.

## Context

- Spec: AC1–AC4. Non-http(s) schemes and URLs over 2,048 chars are 400. Duplicate URL → 200 with the same id.
- Shared interface, consumed only (task 02 owns `src/links/store.ts` and is being written in parallel; **do not create or edit that file**). Until it merges, declare the same interface locally in `memory-store.ts` with a `// TODO(04): import from ./store` comment; task 04 will switch the import.

```ts
export interface Link { id: string; url: string; createdAt: string }
export interface LinkStore {
  getOrCreate(url: string): { link: Link; created: boolean };
  getById(id: string): Link | undefined;
  close(): void;
}
```

- HTTP contract:

```
POST /links  { url }  → 201 { id, shortUrl } | 200 { id, shortUrl } | 400 { error: "invalid_url", message }
GET  /:id             → 302 Location | 404 { error: "not_found" }
```

- `shortUrl = \`${baseUrl}/${id}\``. `GET /health` already exists in `src/server.ts`; do not edit that file — export a plugin-style function and let task 04 register it.

## Steps

1. `src/links/validate.ts`: `export function validateUrl(input: unknown): { ok: true; url: string } | { ok: false; message: string }` — must be a string, ≤ 2,048 chars, parse with `new URL()`, protocol `http:` or `https:`. Normalise nothing else.
2. `src/links/memory-store.ts`: `MemoryLinkStore implements LinkStore` backed by two `Map`s; ids `m` + counter are fine for tests.
3. `src/links/routes.ts`: `export function registerLinkRoutes(app: FastifyInstance, deps: { store: LinkStore; baseUrl: string }): void`. `POST /links` with a JSON schema for the body (`{ url: string }`), calling `validateUrl` for the semantic checks; `GET /:id` with a param schema `^[0-9A-Za-z]{1,16}$`.
4. Errors as JSON bodies exactly per contract. Never echo the raw input back in `message` beyond 100 chars.
5. Tests with `app.inject`.

## Acceptance criteria

| # | Criterion | Proof |
|---|-----------|-------|
| T1 | Valid POST → 201 with id and `shortUrl` prefixed by baseUrl | `npm test -- routes` |
| T2 | Second POST same url → 200, same id | `npm test -- routes` |
| T3 | `javascript:alert(1)`, `ftp://x`, 3,000-char url, non-string → 400 `invalid_url` | `npm test -- routes` |
| T4 | GET known id → 302 with Location; unknown → 404 `not_found` | `npm test -- routes` |

## Tests to write

`test/routes.test.ts` covering T1–T4 with `MemoryLinkStore`.

## Do not

- Touch `src/server.ts`, `src/links/store.ts`, or add `src/index.ts`. Read env vars (task 04 injects `baseUrl`).

## Done when

- [x] All acceptance criteria proven, with output pasted in the PR body
- [x] `commands.test`, `commands.lint`, `commands.typecheck` pass
- [x] Only files listed in `touches` changed
- [x] PR opened against the base branch with the PR template filled
- [x] Report returned to the orchestrator
