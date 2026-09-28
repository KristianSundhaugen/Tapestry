---
feature: {{FEATURE_ID}}
title: {{TITLE}}
status: draft            # draft | approved
created: {{DATE}}
approved_by:
base_branch: {{BASE_BRANCH}}
---

# Plan: {{TITLE}}

The plan is an index. Per-task detail lives in `tasks/NN-slug.md` so implementers receive only their own brief, never the whole plan.

## Approach

Three to ten sentences on the technical approach and the main design choices. Reference the spec's decisions; do not restate them.

## Architecture touchpoints

Which modules, files, services or tables change and how they relate. A short diagram (Mermaid or ASCII) is welcome when the change spans more than three modules.

## Waves

Tasks are grouped into waves. All tasks in one wave are independent of each other and touch disjoint files, so they can run in parallel. A wave starts only when every PR from the previous wave is merged.

| Wave | Task | Title | Touches | Depends on | Est. size |
|------|------|-------|---------|------------|-----------|
| 1 | 01 | | `path/a`, `path/b` | – | S |
| 1 | 02 | | `path/c` | – | S |
| 2 | 03 | | `path/a`, `path/d` | 01 | M |

Size: S = under 100 changed lines, M = 100–300, L = over 300 (split L tasks).

## Shared interfaces

Anything two tasks both depend on (a type, a function signature, an API shape, a table). Define it here so parallel implementers agree without talking to each other.

```
// e.g. export interface ShortLink { id: string; url: string; createdAt: Date }
```

## Verification strategy

How the feature as a whole is proven after the last wave merges: which commands, which manual checks, which acceptance criteria each maps to.

## Rollout and rollback

Feature flags, migrations, ordering constraints, and how to undo.

## Learnings to capture

Things the librarian should look for once this feature is merged (new conventions, gotchas discovered during planning).
