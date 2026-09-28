---
feature: {{FEATURE_ID}}
title: {{TITLE}}
stage: new                # new | interviewed | specced | planned | running | merged | learned
current_wave: 0
updated: {{DATE}}
---

# Progress: {{TITLE}}

This is the ledger. The orchestrator reads it at the start of every `/tapestry-run` and is its only writer during a run (agents report; it records). It is the only thing that has to survive context compaction, session restarts and machine changes.

## Task board

| Task | Wave | Status | Branch | PR | Review rounds | Notes |
|------|------|--------|--------|----|---------------|-------|

## Event log

Append-only. One line per event, newest last. Format: `YYYY-MM-DD HH:MM  actor  event  detail`.

```
{{DATE}}  human  created  feature created from raw idea
```

## Blocked / needs human

<!-- Anything an agent could not resolve. The orchestrator stops and shows this section when it is non-empty. Leave this comment; write entries below it. -->

## Decisions made during execution

<!-- Decisions taken by agents that were not in the spec or plan. The librarian promotes durable ones into project knowledge. -->
