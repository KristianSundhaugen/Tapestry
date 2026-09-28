---
name: tapestry-learn
description: Stage 5 of Tapestry, the learn loop. After a feature is merged, dispatch the librarian to distil learnings from the ledger, reviews and merged PRs into .tapestry/knowledge/, path-scoped rules, and the CLAUDE.md project notes, then open a docs PR for humans to approve. Usage /tapestry-learn <feature-id>.
argument-hint: "<feature-id>"
allowed-tools: Read, Agent, Bash(gh pr *), Bash(git fetch *), Bash(git log *)
disable-model-invocation: true
---

Capture learnings from feature `$ARGUMENTS`.

1. Read `.tapestry/features/$ARGUMENTS/progress.md`. The stage should be `merged`. If it is not, warn the user that learnings from an unfinished feature are partial and ask whether to continue.
2. Dispatch the **librarian** subagent:

   > Run the learn loop for Tapestry feature `$ARGUMENTS`. Read the ledger, reviews, spec, plan, merged PRs and agent memories. Update `.tapestry/knowledge/*.md`, add or update path-scoped rules in `.claude/rules/project/`, refresh the *Project notes* block in `CLAUDE.md` (under 20 lines). Prune anything this feature made false. Set `stage: learned`, commit on `<git.branchPrefix>/learn/$ARGUMENTS` (from `origin/<baseBranch>`) and open a PR `docs(knowledge): learnings from $ARGUMENTS`. Report what was added, updated and pruned.

3. Show the user the librarian's report and the PR link. Recommend they read the diff: it is the moment to catch a wrong lesson before every future agent inherits it.
