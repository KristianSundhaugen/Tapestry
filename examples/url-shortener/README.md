# Example: URL shortener

The artifacts a complete Tapestry run produces, for a small TypeScript/Fastify service. Read them in this order and compare with `docs/WALKTHROUGH.md`, which narrates the run:

1. `interview.md` — stage 1 output: the raw idea, what the interviewer asked, what was decided, what stayed open.
2. `spec.md` — the one-page contract the human approved.
3. `plan.md` — the approach, the waves table (note tasks 02 and 03 in the same wave with disjoint `touches`), and the shared interface both parallel implementers coded against.
4. `tasks/*.md` — one self-contained brief per implementer.
5. `reviews/03-r1.md` — a reviewer report where the reviewer found a real bug, fixed it, pushed, and deferred one question to the next task.
6. `progress.md` — the ledger after the whole feature merged and the librarian ran.
7. `knowledge-after.md` — what the librarian wrote into `.tapestry/knowledge/` and `.claude/rules/project/` afterwards.

To try the pipeline on this idea yourself: run `/tapestry-new "internal URL shortener API"` in an empty repo that has Tapestry installed, then `/tapestry-interview 001-internal-url-shortener-api`. Your interview will differ; that is the point.
