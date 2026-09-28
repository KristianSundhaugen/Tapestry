---
feature: {{FEATURE_ID}}
title: {{TITLE}}
status: draft            # draft | approved
created: {{DATE}}
approved_by:             # human name/handle, set when approved
---

# Spec: {{TITLE}}

Keep this to one page. It is the contract between the human and the agents. If it needs more, the feature is too big: split it.

## What we are building

Two to five sentences. A reader with no context should understand the change.

## Why

The problem or opportunity, and why now.

## Acceptance criteria

Each criterion is a statement that is either true or false about the finished system, and names how it is checked.

| # | Criterion | Verified by |
|---|-----------|-------------|
| AC1 | | test / manual step / metric |
| AC2 | | |

## Out of scope

Bullet list. Anything not listed here and not in the acceptance criteria is out of scope by default.

## Constraints and decisions

Decisions already made (from the interview), with the reason. The planner must not reopen these.

- **Decision**: … — *because* …

## Assumptions

Open questions from the interview turned into working assumptions. If an assumption turns out wrong during implementation, the implementer stops and reports BLOCKED rather than guessing.

- A1:

## Risks

What could make this fail or take much longer, and the mitigation.

## Non-functional requirements

Only the ones that apply. Numbers where possible.
