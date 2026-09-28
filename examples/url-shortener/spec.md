---
feature: 001-url-shortener
title: URL shortener service
status: approved
created: 2026-09-28
approved_by: kristian
---

# Spec: URL shortener service

## What we are building

A single-process Fastify service in TypeScript that stores long URLs in SQLite and serves short redirects. `POST /links` creates or returns a short link; `GET /:id` redirects. Internal use only, no auth, no UI.

## Why

Long dashboard and log URLs make chat and docs unreadable. A tiny internal shortener removes the friction without adopting an external service.

## Acceptance criteria

| # | Criterion | Verified by |
|---|-----------|-------------|
| AC1 | `POST /links` with `{ "url": "<valid http(s) URL>" }` returns 201 and `{ "id": string, "shortUrl": string }` | `npm test` (`routes.test.ts`) |
| AC2 | Posting the same URL again returns 200 with the same `id` | `npm test` |
| AC3 | `GET /:id` for a known id returns 302 with `Location` = original URL | `npm test` (`routes.test.ts`) |
| AC4 | Unknown id → 404 `{ "error": "not_found" }`; invalid or non-http(s) URL, or URL over 2,048 chars → 400 `{ "error": "invalid_url", "message": string }` | `npm test` |
| AC5 | Links survive a process restart | `npm test` (`persistence.test.ts` reopens the DB file) |
| AC6 | `npm run lint`, `npm run typecheck`, `npm test` all pass in CI | `.github/workflows/tapestry-review.yml` |

## Out of scope

- Custom aliases, analytics, expiry, deletion, auth, web UI, rate limiting.

## Constraints and decisions

- **Decision**: Fastify + TypeScript + Vitest — *because* team standard.
- **Decision**: SQLite via `better-sqlite3`, no ORM — *because* one table; synchronous API keeps handlers simple.
- **Decision**: 7-character random base62 ids, retry on collision — *because* unguessable enough internally and short.
- **Decision**: duplicate URLs are idempotent (unique index on `url`) — *because* users paste the same link often.

## Assumptions

- A1: `BASE_URL` env var (default `http://localhost:3000`) is the prefix for `shortUrl`.
- A2: The SQLite file path comes from `DB_PATH` (default `./data/links.db`); directory is created on startup.

## Risks

- `better-sqlite3` needs a native build; mitigated by pinning the version and documenting Node 22.
- Random id collisions: negligible at this scale; retry loop bounded to 5 attempts, then 500.

## Non-functional requirements

- Redirect p95 under 50 ms; 50 req/s; JSON request logging without bodies; clean shutdown closes the DB.
