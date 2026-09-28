---
name: tapestry-new
description: Create a new Tapestry feature folder from a raw idea. Usage /tapestry-new <one-line idea>. Allocates the next feature id, copies templates, records the raw idea, and tells you to run /tapestry-interview.
argument-hint: "<raw idea in one line>"
allowed-tools: Read, Write, Bash(scripts/*), Bash(ls *), Bash(date *), Bash(git add .tapestry*), Bash(git commit *), Bash(git push)
disable-model-invocation: true
---

Create a feature folder for the idea: **$ARGUMENTS**

If `$ARGUMENTS` is empty, ask for the idea in one sentence and stop.

Steps:

1. Run `scripts/tapestry-new.sh "$ARGUMENTS"`. It allocates the next id (`NNN-slug`), creates `.tapestry/features/<id>/` with `tasks/` and `reviews/`, copies `interview.md`, `spec.md` and `progress.md` from `.tapestry/templates/` with placeholders filled, and prints the id.
2. Confirm to the user what was created, in two lines, and tell them the next step is `/tapestry-interview <id>`.
3. Commit the new folder on the base branch: `git add .tapestry && git commit -m "chore(tapestry): new feature <id>" && git push` (skip the push if it is rejected; say so).
4. If the idea can be described as a diff in one sentence and is probably under `pipeline.skipPipelineBelowLines` lines, say so and offer the quick path instead: branch, change, PR, `/tapestry-review`.

Do not start the interview here; it is a separate command so the user can run it in a fresh session if they prefer.
