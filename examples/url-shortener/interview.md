---
feature: 001-url-shortener
title: URL shortener service
status: interviewed
created: 2026-09-28
---

# Interview: URL shortener service

> Raw idea, verbatim, as the user first stated it:
>
> I want a small URL shortener API for our internal tools. Post a long URL, get a short one back, hitting the short one redirects. Nothing fancy.

## 1. Goal

Internal engineers can turn long dashboard/log URLs into short links they can paste in chat and docs. Success is visible when links in the team channel stop wrapping over three lines.

## 2. Users and usage

About 40 engineers, a few dozen links a day, redirects maybe a few hundred a day. Used from curl/scripts and, later, a browser bookmarklet. No public traffic.

## 3. Scope

### In scope

- `POST /links` with a long URL → JSON with the short id and full short URL
- `GET /:id` → 302 redirect to the long URL
- Persistence that survives a restart
- Basic input validation and sensible errors

### Explicitly out of scope

- Custom aliases ("vanity" slugs)
- Click analytics
- Authentication (it sits behind the VPN)
- Link expiry or deletion
- A web UI

## 4. Constraints

- **Technical**: must run as a single Node process on the existing internal VM; no new managed services. SQLite file on local disk is acceptable.
- **Operational**: one engineer maintains it part-time; must be understandable in an afternoon.
- **Compliance / policy**: internal only; no PII stored beyond the URLs themselves.

## 5. Tech stack preferences

- Wants: TypeScript, Node 22, Fastify (team standard), Vitest.
- Avoids: ORMs ("too much for one table"), Docker for local dev.
- No preference: ID scheme, SQLite driver.

## 6. Non-functional requirements

- Redirect p95 under 50 ms on the VM (in-process SQLite makes this easy).
- Handle 50 req/s without tuning.
- Restart-safe; no data loss on clean shutdown.
- Logs: one line per request, JSON, no bodies.

## 7. Success criteria

1. `curl -X POST /links -d '{"url":"https://…"}'` returns 201 with `{ "id", "shortUrl" }`.
2. `curl -i /<id>` returns 302 with `Location` set to the original URL.
3. Unknown id returns 404 JSON; invalid URL returns 400 JSON with a message.
4. Restarting the process keeps existing links.
5. `npm test` passes and covers the three endpoints' happy and error paths.

## 8. Edge cases and failure modes

- Same long URL posted twice → return the existing id (idempotent). *Matters now.*
- Non-http(s) schemes (`javascript:`, `file:`) → 400. *Matters now.*
- Very long URLs (over 2,048 chars) → 400. *Matters now.*
- Concurrent posts of the same URL → both succeed with the same id. *Matters now; cheap with a unique index.*
- Disk full / DB locked → 500 with a generic message, logged. *Deferred: just don't crash.*

## 9. Existing context

Empty repository. Team conventions live in `.tapestry/knowledge/conventions.md` (none yet).

## 10. Open questions

| # | Question | Working assumption |
|---|----------|-------------------|
| 1 | Base URL for `shortUrl` in responses? | Read from `BASE_URL` env var, default `http://localhost:3000`. |
| 2 | ID length? | 7 chars base62, random; collision → retry. |

## 11. Interview log

- Who uses it, how? → ~40 engineers, chat/docs, curl and later a bookmarklet.
- Custom aliases? → No. Analytics? → No. Auth? → No, behind VPN.
- Stack? → TS/Node 22/Fastify/Vitest; no ORM; SQLite fine.
- Latency/scale numbers? → Accepted proposed p95 50 ms, 50 req/s.
- Duplicate URL behaviour? → Same id back.
- Reject non-http schemes? → Yes.
- What would make you reject it? → "If I can't read the whole thing in an afternoon."
