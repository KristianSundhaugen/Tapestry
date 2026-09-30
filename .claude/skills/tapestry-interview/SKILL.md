---
name: tapestry-interview
description: Stage 1 of Tapestry. Run a structured interview that extracts goals, constraints, stack preferences, non-functional requirements, success criteria and edge cases from a raw idea, then write interview.md and a one-page spec.md for human approval. Usage /tapestry-interview <feature-id>. Runs in the main session because it needs the human.
argument-hint: "<feature-id>"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(scripts/*), Bash(git log *), Bash(git ls-files *), Bash(date *), Bash(git add .tapestry*), Bash(git commit *), Bash(git push)
disable-model-invocation: true
---

You are running the Tapestry **interview** for feature `$ARGUMENTS`. Your job is to remove ambiguity *before* anything is planned. The output is two files the planner can trust: `interview.md` (everything learned) and `spec.md` (one page, the contract).

## Setup

1. Read `.tapestry/features/$ARGUMENTS/interview.md`. The raw idea is in the quote at the top. If the file is missing, tell the user to run `/tapestry-new` first and stop.
2. Read `.tapestry/config.json` and `.tapestry/knowledge/*.md` so you do not ask what the project already knows (stack, conventions, decisions).
3. Skim the codebase (`git ls-files | head -200`, key entry points) so questions can reference real modules.

## How to interview

Ask with `AskUserQuestion`, in rounds of at most three questions. Offer concrete options with a recommended default where you can; free text where you cannot. Adapt to the answers; do not march through a checklist the user has already answered implicitly. Stop a topic when further questions would not change the plan.

Cover, in roughly this order, the sections of `interview.md`:

1. **Goal and users** — what changes for whom. Push for a scenario: "Walk me through the moment someone uses this."
2. **Scope** — get an explicit *out of scope* list. Suggest likely creep items and ask the user to confirm they are out.
3. **Constraints** — technical (must fit existing X), operational (deadline, hosting, budget), compliance.
4. **Stack preferences** — what to use, what to avoid, what they do not care about. Record indifference explicitly.
5. **Non-functional requirements** — offer numbers ("p95 under 300 ms?", "10 users or 10,000?") so the user can accept or correct rather than invent.
6. **Success criteria** — each must be checkable by someone who did not build it. Rewrite vague ones with the user until they are.
7. **Edge cases** — propose the ones you see (empty, huge, malformed, concurrent, offline, unauthorized, repeated) and ask which matter now.
8. **Existing context** — related code, docs, decisions.

Techniques that work: reflect back a proposed decision and ask for a yes/no; ask "what would make you reject the finished result?"; ask for the smallest version that would still be worth shipping.

Techniques to avoid: asking more than three things at once; asking what the codebase can answer; asking for implementation details the planner should decide.

## The grill: resolve every open branch

The structured pass fills in what the template asks for. This pass hunts for what it did not ask. Run it after the eight topics, before writing anything. Skip it only when the user says the feature is small, and say that you are skipping it.

Rules:

1. **One question at a time**, each with your recommended answer and the reason for it, so the user can accept with one word or correct you. Use `AskUserQuestion` with the recommendation as the first option.
2. **Look up before you ask.** If the codebase, `config.json`, or the knowledge files can answer it, read them and state the answer instead of asking.
3. **Hunt decision branches, not template gaps.** Each question is about a fork where two reasonable implementations would differ: who calls this and from where; what happens on the second call, the empty call, the concurrent call; what the caller sees on each failure; what is persisted and for how long; what must stay backward compatible; what is deliberately left ugly for now; what would make the user reject the result even though every acceptance criterion passes.
4. **Stop when a full pass produces no new branch**, or after twelve questions, whichever comes first. If branches remain at twelve, list them as assumptions with your recommended default and move on; do not keep going.
5. Every grill answer becomes a line in the *Constraints and decisions* or *Assumptions* section of the spec, with the reason. Nothing from the grill lives only in the transcript.

Do not generate code or designs during the grill, and do not re-ask anything the structured pass settled.

## Writing the outputs

1. Fill every section of `interview.md`. Unanswered questions go to *Open questions* with a working assumption. Keep the *Interview log* short: question → answer, one line each; grill questions are marked `[grill]`. Set `stage: interviewed` in `progress.md` and append `interviewer  interviewed  N questions (M grill), K open`.
2. Write `spec.md` from `.tapestry/templates/spec.md`: one page. Acceptance criteria are numbered `AC1…` with a *Verified by* column. Decisions carry their reason. Assumptions come from the open questions.
3. If the interview surfaced a durable decision or a new term, add it to `.tapestry/knowledge/decisions.md` / `glossary.md` (dated, tagged with the feature id).
4. Show the user the spec (it is short) and ask them to approve it, change it, or answer the open questions. When approved, set `status: approved` and `approved_by:` in `spec.md`, set `stage: specced` in `progress.md`, and append `interviewer  spec-approved` to the event log. If `pipeline.humanApprovesSpec` is false, approve it yourself and say so.
5. Commit the artifacts on the base branch: `git add .tapestry && git commit -m "chore(tapestry): spec $ARGUMENTS" && git push`. If the push is rejected by branch protection, tell the user, or that it is held by their push window; the commit stays local until the next push after the window.
6. Tell the user the next step: `/tapestry-plan $ARGUMENTS`.

Do not write any code, and do not start planning. If the idea turns out to be tiny, say so and offer the quick path.
