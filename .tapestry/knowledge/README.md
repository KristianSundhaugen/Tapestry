# Project knowledge

This directory is Tapestry's long-term memory for **this** project. It is committed to git, so it travels with the repo and is shared by every developer and every agent.

| File | What goes here | Who writes it |
|------|----------------|---------------|
| `architecture.md` | How the code is organised, the main modules, how data flows | librarian, humans |
| `decisions.md` | Durable decisions with dates and reasons (lightweight ADR log) | librarian, interviewer, humans |
| `conventions.md` | Naming, patterns, testing habits that agents must follow | librarian |
| `gotchas.md` | Things that bit an agent or a reviewer, and the fix | librarian, reviewer |
| `glossary.md` | Project-specific terms | interviewer, librarian |

Rules:

- Entries are short. One paragraph, dated, with the feature id that produced them.
- Prune. When an entry stops being true, delete it (or move it to a "superseded" section) in the same PR that makes it untrue.
- Anything an implementer must follow **while editing specific paths** is better as a path-scoped rule in `.claude/rules/project/`. The librarian decides.
- These files are loaded on demand by the planner and reviewer; `CLAUDE.md` stays short.
