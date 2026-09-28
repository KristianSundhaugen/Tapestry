# What the librarian wrote after 001-url-shortener

Merged via PR #5 `docs(knowledge): learnings from 001-url-shortener`.

## `.tapestry/knowledge/architecture.md`

```markdown
# Architecture

- Single Fastify process. `src/index.ts` reads env and starts; `src/server.ts` exports `buildServer(deps)` so tests build the app without listening.
- `src/links/` holds the feature: `store.ts` (interface + SQLite), `routes.ts` (HTTP), `validate.ts` (input rules), `memory-store.ts` (test double).
- Data: SQLite file at `DB_PATH`, WAL mode, table `links(id, url UNIQUE, created_at)`.
- Tests: Vitest, `app.inject`, temp DB file per test. `npm test` runs in under 3 s.
```

## `.tapestry/knowledge/decisions.md`

```markdown
- 2026-09-28 (001): Dependencies are injected through `buildServer({ store, baseUrl })`; no module-level singletons. Reason: parallel tasks and tests need to swap the store.
- 2026-09-28 (001): No ORM. One prepared statement per query in the store class.
```

## `.tapestry/knowledge/conventions.md`

```markdown
- Routes live in `register<Feature>Routes(app, deps)` functions; `server.ts` only composes them.
- Validation returns `{ ok: true, value } | { ok: false, message }`; handlers map `ok: false` to 400 with a stable `error` code.
- Error bodies are `{ error: <snake_case_code>, message?: string }`. Never echo more than 100 chars of input.
```

## `.tapestry/knowledge/gotchas.md`

```markdown
- 2026-09-28 (001, review 03-r1): `URL.protocol` includes the colon (`"https:"`). Compare with the colon.
- 2026-09-28 (001, review 04-r1): await `app.close()` before `process.exit()`; SQLite WAL loses the last write otherwise.
- 2026-09-28 (001): `better-sqlite3` must be pinned to a version with Node 22 prebuilds or `npm ci` compiles on the VM (slow, needs python).
```

## `.claude/rules/project/http-handlers.md`

```markdown
---
paths:
  - "src/**/routes.ts"
  - "src/**/validate.ts"
---
# HTTP handlers

- Use the normalised `parsed.href` from `new URL()` for anything that ends up in a header (`Location`), never the raw input (001, review 03-r1 F2).
- Every route has a JSON schema for body/params and a `validate.ts` function for semantic rules; tests must go through the real validator, not a fixture that bypasses it.
- Strip trailing slashes from `baseUrl` before composing URLs.
```

## `CLAUDE.md` project notes block

```markdown
## Project notes

Internal URL shortener: Fastify + TypeScript + SQLite (`better-sqlite3`), Vitest. Node 22.
Commands: `npm ci` · `npm test` · `npm run lint` · `npm run typecheck` · `npm run build` · `npm run dev`.
Entry `src/index.ts`; app factory `buildServer(deps)` in `src/server.ts`; features under `src/<feature>/`.
No auth (VPN only), no analytics, no UI — by decision, see `.tapestry/knowledge/decisions.md`.
```
