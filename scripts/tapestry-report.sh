#!/usr/bin/env bash
# Build a test-run report for one Tapestry feature: what each stage produced, what each
# agent did (from the trace log), what landed on GitHub, and a PASS/FAIL checklist.
#
#   scripts/tapestry-report.sh <feature-id>
#
# Writes .tapestry/test-runs/<feature-id>-<YYYYmmdd-HHMM>.md and prints its path.
# Attach that file in the Claude chat where you want the run assessed.
# Works without gh or a trace log; the affected checks show SKIP.
set -uo pipefail

PY=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) py_order="py python3 python" ;; *) py_order="python3 python py" ;; esac
for c in $py_order; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -z "$PY" ] && { echo "a working Python 3 is required (run scripts/tapestry-doctor.sh)" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fid="${1:-}"
if [ -z "$fid" ]; then echo "usage: $0 <feature-id>" >&2; exit 1; fi
if [ ! -d "$here/.tapestry/features/$fid" ]; then echo "no such feature: $fid" >&2; exit 1; fi

mkdir -p "$here/.tapestry/test-runs"
stamp="$(date +%Y%m%d-%H%M)"
out="$here/.tapestry/test-runs/$fid-$stamp.md"
tmp="$(mktemp -d 2>/dev/null || echo "$here/.tapestry/test-runs/.tmp-$stamp")"
mkdir -p "$tmp"

# --- Collect raw evidence with the tools themselves --------------------------------
"$here/scripts/tapestry-doctor.sh" > "$tmp/doctor.txt" 2>&1 || true
"$here/scripts/tapestry-validate.sh" "$fid" > "$tmp/validate.txt" 2>&1; echo $? > "$tmp/validate.rc"
git -C "$here" log --format='%h %ad %an %s' --date=format:'%Y-%m-%d %H:%M' -40 > "$tmp/gitlog.txt" 2>&1 || true
git -C "$here" worktree list > "$tmp/worktrees.txt" 2>&1 || true
git -C "$here" branch -a --list '*tapestry/*' > "$tmp/branches.txt" 2>&1 || true
git -C "$here" config --get core.hooksPath > "$tmp/hookspath.txt" 2>/dev/null || true
"$here/scripts/push-window.sh" > "$tmp/window.txt" 2>&1; echo $? > "$tmp/window.rc"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  ( cd "$here" && gh pr list --state all --limit 50 --search "$fid" \
      --json number,title,state,headRefName,baseRefName,mergedAt,createdAt,url,body,comments,statusCheckRollup ) \
    > "$tmp/prs.json" 2>"$tmp/prs.err" || echo "[]" > "$tmp/prs.json"
else
  echo "gh not available or not authenticated" > "$tmp/prs.err"
fi
command -v claude >/dev/null 2>&1 && claude mcp list > "$tmp/mcp.txt" 2>&1 || true

"$PY" - "$here" "$fid" "$tmp" "$out" <<'PY'
import glob, json, os, re, sys, datetime, collections
root, fid, tmp, out = sys.argv[1:5]
fdir = os.path.join(root, ".tapestry", "features", fid)

def read(p, default=""):
    try:
        with open(p, encoding="utf-8") as f:
            return f.read()
    except Exception:
        return default

def fm(path):
    m = re.match(r"^---\n(.*?)\n---\n", read(path).replace("\r\n", "\n"), re.S)
    d = {}
    if m:
        for line in m.group(1).splitlines():
            if ":" in line and not line.startswith(" "):
                k, v = line.split(":", 1)
                v = re.sub(r"\s+#.*$", "", v.strip())          # "pr: #12" keeps #12; "wave: 1  # note" drops the note
                d[k.strip()] = v.strip().strip("'\"")
    return d

cfg = {}
try:
    cfg = json.loads(read(os.path.join(root, ".tapestry", "config.json")) or "{}")
except Exception:
    pass
test_cmd = (cfg.get("commands") or {}).get("test", "")
scanners = (cfg.get("review") or {}).get("scanners", [])
prefix = (cfg.get("git") or {}).get("branchPrefix", "tapestry")
RUNNERS = ("pytest", "vitest", "jest", "npm test", "npm run test", "pnpm test", "yarn test", "go test", "cargo test", "dotnet test", "mvn test", "gradle test")
def is_test_cmd(c):
    return bool(c) and ((test_cmd and test_cmd in c) or any(r in c for r in RUNNERS))

# Trace
trace = []
for line in read(os.path.join(root, ".tapestry", "logs", "trace.jsonl")).splitlines():
    try:
        trace.append(json.loads(line))
    except Exception:
        pass
has_trace = bool(trace)
tool_events = [e for e in trace if e.get("event") == "PreToolUse"]
def by_agent(name):
    return [e for e in tool_events if e.get("agent") == name]
def cmds(name):
    return [e.get("command", "") for e in by_agent(name) if e.get("tool") in ("Bash", "PowerShell")]

prs = []
try:
    prs = json.loads(read(os.path.join(tmp, "prs.json")) or "[]")
except Exception:
    prs = []
has_gh = os.path.exists(os.path.join(tmp, "prs.json"))

tasks = sorted(glob.glob(os.path.join(fdir, "tasks", "*.md")))
reviews = sorted(glob.glob(os.path.join(fdir, "reviews", "*.md")))
ledger = read(os.path.join(fdir, "progress.md")).replace("\r\n", "\n")
blocked = re.search(r"## Blocked / needs human\n(.*?)(\n## |\Z)", ledger, re.S)
blocked_lines = [l for l in (blocked.group(1).splitlines() if blocked else []) if l.strip() and not l.strip().startswith("<!--")]

checks = []
def check(stage, name, ok, evidence, skip=False):
    checks.append((stage, name, "SKIP" if skip else ("PASS" if ok else "FAIL"), evidence))

# --- Stage 0: environment
doctor = read(os.path.join(tmp, "doctor.txt"))
check("0 setup", "doctor has no MISSING items", "MISSING" not in doctor,
      "; ".join(l.strip() for l in doctor.splitlines() if "MISSING" in l) or "all required tools present")
check("0 setup", "git pre-push hook active", read(os.path.join(tmp, "hookspath.txt")).strip() == ".githooks",
      "core.hooksPath=" + (read(os.path.join(tmp, "hookspath.txt")).strip() or "(unset)"))
mcp = read(os.path.join(tmp, "mcp.txt")).strip()
check("0 setup", "MCP servers as configured (Tapestry default: none)", True, mcp.splitlines()[0][:160] if mcp else "claude mcp list: no output")

# --- Stage 1: interview
iv = fm(os.path.join(fdir, "interview.md")); sp = fm(os.path.join(fdir, "spec.md"))
ivtext = read(os.path.join(fdir, "interview.md"))
log_part = ivtext.split("## 11. Interview log", 1)[1] if "## 11. Interview log" in ivtext else ""
log_lines = [l for l in log_part.splitlines() if l.strip() and not l.startswith("Short record of the questions")]
check("1 interview", "interview.md filled in (interview log has entries)", "{{" not in ivtext and len(log_lines) >= 2,
      f"{len(log_lines)} line(s) in the interview log, {len(ivtext)} chars total")
check("1 interview", "spec.md approved", sp.get("status") == "approved", f"status={sp.get('status')!r} approved_by={sp.get('approved_by')!r}")
aq = [e for e in trace if e.get("tool") == "AskUserQuestion" and e.get("event") == "PreToolUse"]
check("1 interview", "interview asked questions with AskUserQuestion", len(aq) > 0, f"{len(aq)} question round(s)", skip=not has_trace)

# --- Stage 2: plan
pl = fm(os.path.join(fdir, "plan.md"))
check("2 plan", "plan.md approved", pl.get("status") == "approved", f"status={pl.get('status')!r}")
check("2 plan", "wave validation passes", read(os.path.join(tmp, "validate.rc")).strip() == "0", read(os.path.join(tmp, "validate.txt")).strip()[:300])
planner_runs = [e for e in trace if e.get("event") == "SubagentStart" and e.get("agent") == "planner"] or \
               [e for e in tool_events if e.get("tool") in ("Agent", "Task") and e.get("subagent_type") == "planner"]
check("2 plan", "planner agent was dispatched", len(planner_runs) > 0, f"{len(planner_runs)} dispatch(es)", skip=not has_trace)
check("2 plan", "planner ran the validator", any("tapestry-validate" in c for c in cmds("planner") + cmds("main")),
      "tapestry-validate.sh seen in planner/main commands", skip=not has_trace)
waves = collections.Counter(fm(t).get("wave") for t in tasks)
check("2 plan", "at least one wave runs tasks in parallel", any(n > 1 for n in waves.values()), f"tasks per wave: {dict(waves)}")

# --- Stage 3: implement
tfm = {os.path.basename(t): fm(t) for t in tasks}
check("3 implement", "every task has a PR", tasks != [] and all(v.get("pr") for v in tfm.values()),
      ", ".join(f"{k}: pr={v.get('pr') or '-'}" for k, v in tfm.items()))
impl_ids = {e.get("agent_id") for e in by_agent("implementer")}
impl_cwds = {e.get("cwd", "") for e in by_agent("implementer")}
in_wt = [c for c in impl_cwds if ".claude/worktrees" in c.replace("\\", "/")]
check("3 implement", "implementers worked in isolated worktrees", bool(impl_cwds) and len(in_wt) == len(impl_cwds),
      f"{len(impl_ids)} implementer run(s); {len(in_wt)}/{len(impl_cwds)} working dirs under .claude/worktrees", skip=not has_trace)
impl_tapestry_edits = [e.get("file_path") for e in by_agent("implementer") if e.get("tool") in ("Edit", "Write") and "/.tapestry/" in (e.get("file_path") or "").replace("\\", "/")]
check("3 implement", "implementers never edited .tapestry/ (ledger owned by orchestrator)", not impl_tapestry_edits,
      ", ".join(impl_tapestry_edits[:5]) or "none", skip=not has_trace)
ran_tests = [c for c in cmds("implementer") if is_test_cmd(c)]
check("3 implement", "implementers ran the tests", bool(ran_tests), f"{len(ran_tests)} test run(s) (config test command: `{test_cmd or 'not set'}`)",
      skip=not has_trace)
task_prs = [p for p in prs if (p.get("headRefName") or "").startswith(f"{prefix}/{fid}/")]
learn_prs = [p for p in prs if (p.get("headRefName") or "") == f"{prefix}/learn/{fid}" or "learnings from" in (p.get("title") or "").lower()]
if has_gh:
    bodies_ok = [p for p in task_prs if "Acceptance criteria" in (p.get("body") or "")]
    check("3 implement", "task PR bodies contain the acceptance-criteria proof table", task_prs != [] and len(bodies_ok) == len(task_prs), f"{len(bodies_ok)}/{len(task_prs)} task PRs")
else:
    check("3 implement", "PR bodies contain the acceptance-criteria proof table", False, read(os.path.join(tmp, "prs.err")).strip(), skip=True)

# --- Stage 4: review
tasks_reviewed = {os.path.basename(r).split("-r")[0] for r in reviews}
task_ids = {v.get("task") for v in tfm.values()}
check("4 review", "every task has a review report", bool(task_ids) and task_ids <= tasks_reviewed,
      f"reviews: {sorted(os.path.basename(r) for r in reviews)}")
verdicts = collections.Counter(fm(r).get("verdict") for r in reviews)
check("4 review", "review verdicts recorded", bool(reviews) and None not in verdicts and "pending" not in verdicts, f"{dict(verdicts)}")
rv_tests = [c for c in cmds("reviewer") if is_test_cmd(c)]
check("4 review", "reviewer re-ran the tests", bool(rv_tests), f"{len(rv_tests)} test run(s)", skip=not has_trace)
review_scanner_fields = " ".join(fm(r).get("scanners", "") for r in reviews)
for s in scanners:
    ran = [c for c in cmds("reviewer") if c.strip().startswith(s) or f" {s} " in f" {c} "]
    reported = s in review_scanner_fields     # e.g. "gitleaks: not installed" in the report frontmatter
    check("4 review", f"reviewer ran {s} or reported it missing", bool(ran) or reported,
          f"{len(ran)} run(s); review frontmatter: {review_scanner_fields[:120] or '(empty)'}", skip=not has_trace and not reviews)
second = [c for c in cmds("reviewer") if "/code-review" in c or "/security-review" in c]
check("4 review", "reviewer ran the built-in second opinion (/code-review, /security-review)", bool(second) or any("second opinion" in read(r) for r in reviews),
      f"{len(second)} run(s)", skip=not has_trace and not reviews)
fixes = [c for c in cmds("reviewer") if "fix(review)" in c]
check("4 review", "reviewer applied fixes itself when needed (informational)", True, f"{len(fixes)} fix(review) commit command(s)", skip=not has_trace)
main_src_edits, in_run = [], False
for e in trace:                       # only edits made while /tapestry-run was the active command count
    if e.get("event") == "UserPromptSubmit":
        in_run = (e.get("prompt") or "").startswith("/tapestry-run")
    elif e.get("event") == "Stop" and e.get("agent", "main") == "main":
        in_run = False
    elif in_run and e.get("event") == "PreToolUse" and e.get("agent") == "main" and e.get("tool") in ("Edit", "Write") \
            and not re.search(r"/\.tapestry/", (e.get("file_path") or "").replace("\\", "/")):
        main_src_edits.append(e.get("file_path"))
check("4 review", "orchestrator never edited files outside .tapestry/ during /tapestry-run", not main_src_edits, ", ".join(main_src_edits[:5]) or "none", skip=not has_trace)

# --- Stage 4b: merge
check("4b merge", "all tasks merged", tasks != [] and all(v.get("status") == "merged" for v in tfm.values()),
      ", ".join(f"{k}: {v.get('status')}" for k, v in tfm.items()))
if has_gh:
    merged = [p for p in task_prs if p.get("state") == "MERGED"]
    check("4b merge", "task PRs merged on GitHub", task_prs != [] and len(merged) == len(task_prs) >= len(tasks), f"{len(merged)} merged / {len(task_prs)} task PRs / {len(tasks)} tasks")
check("4b merge", "nothing left in Blocked / needs human", not blocked_lines, " | ".join(blocked_lines[:3]) or "empty")

# --- Stage 5: learn
stage = fm(os.path.join(fdir, "progress.md")).get("stage")
check("5 learn", "feature reached stage 'learned'", stage == "learned", f"stage={stage!r}")
# architecture.md is seeded by /tapestry-setup, so only the other files prove the librarian ran.
kn = {os.path.basename(p): read(p) for p in glob.glob(os.path.join(root, ".tapestry", "knowledge", "*.md"))
      if os.path.basename(p) not in ("README.md", "architecture.md")}
filled = [k for k, v in kn.items() if "_Empty." not in v]
rules = [os.path.basename(p) for p in glob.glob(os.path.join(root, ".claude", "rules", "project", "*.md")) if not p.endswith("README.md")]
lib_runs = [e for e in trace if e.get("agent") == "librarian"]
check("5 learn", "librarian wrote project knowledge", bool(filled or rules),
      f"filled: {filled}; learned rules: {rules}" + (f"; librarian events: {len(lib_runs)}" if has_trace else "") + " (merge the knowledge PR and git pull first)")
if has_gh:
    check("5 learn", "knowledge PR opened", bool(learn_prs), ", ".join(f"#{p['number']} {p['state']}" for p in learn_prs) or "none found")

# --- Guards
blocks = [e for e in trace if e.get("event") == "GuardBlock"]
check("guards", "guard blocks (informational: each should be intended)", True,
      f"{len(blocks)} block(s)" + ("" if not blocks else ": " + " | ".join(f"{b.get('reason','')[:60]} <- {b.get('command','')[:60]}" for b in blocks[:5])),
      skip=not has_trace)
held = [e for e in blocks if "push window" in (e.get("reason") or "")]
check("guards", "push-window holds (informational)", True, f"{len(held)} hold(s)", skip=not has_trace)
failures = [e for e in trace if e.get("event") == "PostToolUseFailure"]

# --- Agent activity summary
agents = collections.defaultdict(lambda: {"runs": set(), "tools": collections.Counter(), "first": None, "last": None})
for e in trace:
    a = agents[e.get("agent", "main")]
    if e.get("agent_id"):
        a["runs"].add(e["agent_id"])
    if e.get("event") == "PreToolUse":
        a["tools"][e.get("tool")] += 1
    ts = e.get("ts")
    if ts:
        a["first"] = a["first"] or ts
        a["last"] = ts
skills = [e.get("prompt", "").split()[0] for e in trace if e.get("event") == "UserPromptSubmit" and e.get("prompt", "").startswith("/")]
skills += [e.get("skill") for e in tool_events if e.get("tool") == "Skill" and e.get("skill")]

# --- Write report
p = sum(1 for c in checks if c[2] == "PASS"); f = sum(1 for c in checks if c[2] == "FAIL"); s = sum(1 for c in checks if c[2] == "SKIP")
L = []
L.append(f"# Tapestry test-run report: {fid}")
L.append("")
L.append(f"Generated {datetime.datetime.now().astimezone().isoformat(timespec='minutes')} · **{p} PASS, {f} FAIL, {s} SKIP** · trace events: {len(trace)} · PRs found: {len(prs) if has_gh else 'n/a'}")
L.append("")
L.append("## Checklist")
L.append("")
L.append("| Stage | Check | Result | Evidence |")
L.append("|---|---|---|---|")
for st, name, res, ev in checks:
    ev = str(ev).replace("|", "\\|").replace("\n", " ")
    L.append(f"| {st} | {name} | {res} | {ev[:220]} |")
L.append("")
L.append("## Agents")
L.append("")
L.append("| Agent | Runs | Tool calls | Most used tools | First → last event |")
L.append("|---|---|---|---|---|")
for name, a in sorted(agents.items()):
    top = ", ".join(f"{t} {n}" for t, n in a["tools"].most_common(5))
    L.append(f"| {name} | {len(a['runs']) or '-'} | {sum(a['tools'].values())} | {top} | {a['first'] or ''} → {a['last'] or ''} |")
L.append("")
L.append(f"Skills / slash commands used: {', '.join(dict.fromkeys(skills)) or 'none recorded'}")
L.append("")
if failures:
    L.append("## Tool failures")
    L.append("")
    for e in failures[:20]:
        L.append(f"- {e.get('ts','')} {e.get('agent','')} {e.get('tool','')}: {(e.get('error') or '')[:200]}")
    L.append("")
L.append("## Task board")
L.append("")
L.append("| Task | Wave | Status | Branch | PR |")
L.append("|---|---|---|---|---|")
for k, v in tfm.items():
    L.append(f"| {v.get('task')} | {v.get('wave')} | {v.get('status')} | {v.get('branch')} | {v.get('pr')} |")
L.append("")
if has_gh and prs:
    L.append("## Pull requests")
    L.append("")
    for pr in sorted(prs, key=lambda x: x.get("number", 0)):
        L.append(f"- #{pr.get('number')} {pr.get('state')} `{pr.get('headRefName')}` → `{pr.get('baseRefName')}`: {pr.get('title')} ({len(pr.get('comments') or [])} comments)")
    L.append("")
L.append("## Ledger")
L.append("")
L.append("```")
L.append(ledger.strip()[-6000:])
L.append("```")
L.append("")
for title, fn in (("Doctor", "doctor.txt"), ("Plan validation", "validate.txt"), ("Push window now", "window.txt"),
                  ("Git log (last 40)", "gitlog.txt"), ("Worktrees", "worktrees.txt"), ("Tapestry branches", "branches.txt"), ("MCP servers", "mcp.txt")):
    L.append(f"## {title}")
    L.append("")
    L.append("```")
    L.append(read(os.path.join(tmp, fn)).strip() or "(empty)")
    L.append("```")
    L.append("")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(L) + "\n")
print(f"{p} PASS, {f} FAIL, {s} SKIP")
PY
rm -rf "$tmp"
echo "report: ${out#$here/}"
