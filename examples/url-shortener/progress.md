---
feature: 001-url-shortener
title: URL shortener service
stage: learned
current_wave: 3
updated: 2026-09-28
---

# Progress: URL shortener service

## Task board

| Task | Wave | Status | Branch | PR | Review rounds | Notes |
|------|------|--------|--------|----|---------------|-------|
| 01 | 1 | merged | tapestry/001-url-shortener/01-bootstrap | #1 | 1 (approve) | |
| 02 | 2 | merged | tapestry/001-url-shortener/02-sqlite-store | #2 | 1 (fixed: close() guard) | |
| 03 | 2 | merged | tapestry/001-url-shortener/03-http-routes | #3 | 1 (fixed: F1 protocol, F2 href) | F4 deferred to 04 |
| 04 | 3 | merged | tapestry/001-url-shortener/04-wire-and-persist | #4 | 2 (r1 changes_requested: SIGTERM handler; r2 approve) | |

## Event log

```
2026-09-28 09:02  human         created           feature created from raw idea
2026-09-28 09:31  interviewer   spec-approved     6 ACs, 2 assumptions
2026-09-28 09:40  planner       plan-drafted      4 tasks in 3 waves, awaiting approval
2026-09-28 09:44  human         plan-approved     4 tasks, 3 waves
2026-09-28 09:45  orchestrator  run-started       wave 1
2026-09-28 09:46  orchestrator  dispatched        implementer task 01
2026-09-28 09:58  orchestrator  pr-opened         #1 task 01
2026-09-28 10:06  orchestrator  review-r1         #1 approve 0 blocking, 0 important, 1 nit
2026-09-28 10:08  orchestrator  merged            #1 task 01
2026-09-28 10:08  orchestrator  wave-started      wave 2 (02, 03 in parallel)
2026-09-28 10:09  orchestrator  dispatched        implementers task 02, task 03
2026-09-28 10:27  orchestrator  pr-opened         #2 task 02
2026-09-28 10:31  orchestrator  pr-opened         #3 task 03
2026-09-28 10:44  orchestrator  review-r1         #3 fixed 1 blocking, 1 important, 2 nits
2026-09-28 10:46  orchestrator  review-r1         #2 fixed 0 blocking, 1 important, 0 nits
2026-09-28 10:49  orchestrator  merged            #2 task 02
2026-09-28 10:50  orchestrator  merged            #3 task 03
2026-09-28 10:50  orchestrator  wave-started      wave 3
2026-09-28 10:51  orchestrator  dispatched        implementer task 04
2026-09-28 11:05  orchestrator  pr-opened         #4 task 04
2026-09-28 11:16  orchestrator  review-r1         #4 changes_requested 1 blocking (SIGTERM handler never awaited close)
2026-09-28 11:22  orchestrator  resumed           implementer task 04 for 04-r1 F1
2026-09-28 11:29  orchestrator  review-r2         #4 approve 0 blocking, 0 important, 0 nits
2026-09-28 11:31  orchestrator  merged            #4 task 04
2026-09-28 11:31  orchestrator  feature-merged    4 PRs, 5 review rounds
2026-09-28 11:40  librarian     learned           10 entries added, 0 pruned (PR #5)
```

## Blocked / needs human

## Decisions made during execution

- (03, review F4) `BASE_URL` trailing slash: task 04 strips it in `index.ts` before passing `baseUrl`. Documented in README.
- (02) `better-sqlite3` pinned to the version that has prebuilt binaries for Node 22; `npm ci` needs no toolchain on the VM.
- (04) Shutdown: `app.close()` is awaited before `process.exit(0)`; the first version raced and lost the last write (caught by review r1).
