# Review instructions

Read by Claude Code Review (the managed GitHub app, if enabled) and by the Tapestry `reviewer` agent. Keep it short; it is loaded into every review.

## What "blocking" means here

Reserve blocking for findings that would break behaviour, leak data, or make rollback unsafe: wrong logic, unhandled error paths that lose data, injection or auth bypass, secrets in the diff, migrations that are not backward compatible, and changes outside the task's declared `touches` scope that alter behaviour elsewhere. Style, naming and refactoring suggestions are nits at most.

## Evidence bar

Every finding cites `file:line` in the diff or the surrounding code. Behaviour claims come from reading the code path or running it, not from inferring from names. If you are not sure, say "unverified" and do not block on it.

## Nits

At most five nits per review. If you found more, say "plus N similar" in the summary.

## Do not report

- Anything CI already enforces: formatting, lint, type errors (mention only if CI is not configured in `.tapestry/config.json`)
- Generated files, lockfiles, vendored dependencies
- Test code that intentionally breaks production rules
- Pre-existing issues outside the diff, unless the diff makes them worse (report those under "pre-existing", never as blocking)

## Always check

- The PR body's acceptance-criteria table has real command output, not "should pass"
- New behaviour has a test; changed behaviour has a changed test
- No new dependency without a one-line justification in the PR body
- Files changed ⊆ task `touches` + new tests, or the extras are justified
- Secrets: nothing that looks like a token, key or password, including in tests and fixtures

## Re-review convergence

After round 1, report only blocking findings and regressions introduced by the fixes. Do not add new nits.

## Summary shape

First line: `N blocking, M important, K nits — <verdict>`. Lead with "No blocking issues" when true.
