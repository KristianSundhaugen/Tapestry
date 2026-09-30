#!/usr/bin/env bash
# Validate Tapestry artifacts.
#   scripts/tapestry-validate.sh --config          validate .tapestry/config.json against the schema
#   scripts/tapestry-validate.sh <feature-id>      validate plan.md + tasks/*.md of a feature
# Exit 0 when valid, 1 with a list of problems otherwise.
set -uo pipefail

# Find a Python that actually runs. On Windows, "python3"/"python" may be the
# Microsoft Store stub, which exists on PATH but only prints an install hint.
PY=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json, sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -z "$PY" ] && { echo "python3 or python is required" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${1:-}" = "--config" ]; then
  "$PY" - "$here/.tapestry/config.json" "$here/.tapestry/config.schema.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1])); schema = json.load(open(sys.argv[2]))
errors = []
for key in schema["required"]:
    if key not in cfg: errors.append(f"missing top-level key: {key}")
for key in schema["properties"]["project"]["required"]:
    if not cfg.get("project", {}).get(key): errors.append(f"project.{key} is empty")
ms = cfg.get("pipeline", {}).get("mergeStrategy")
if ms not in ("squash", "merge", "rebase"): errors.append(f"pipeline.mergeStrategy invalid: {ms}")
for k in ("maxParallelImplementers", "maxReviewRounds"):
    v = cfg.get("pipeline", {}).get(k)
    if not isinstance(v, int) or v < 1: errors.append(f"pipeline.{k} must be a positive integer")
for s in cfg.get("review", {}).get("scanners", []):
    if s not in ("semgrep", "gitleaks", "trivy", "snyk"): errors.append(f"review.scanners: unknown scanner {s}")
try:
    import jsonschema  # optional, gives full validation when installed
    jsonschema.validate(cfg, schema)
except ImportError:
    pass
except Exception as e:
    errors.append(f"schema: {e.message if hasattr(e,'message') else e}")
if errors:
    print("config.json problems:"); [print("  -", e) for e in errors]; sys.exit(1)
print("config.json ok")
PY
  exit $?
fi

fid="${1:-}"
if [ -z "$fid" ]; then
  echo "usage: $0 --config | <feature-id>" >&2
  exit 1
fi
dir="$here/.tapestry/features/$fid"
if [ ! -d "$dir" ]; then
  echo "no such feature: $fid" >&2
  exit 1
fi

"$PY" - "$dir" <<'PY'
import glob, os, re, sys
d = sys.argv[1]
errors = []

def frontmatter(path):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        return None, text
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            v = v.split("#", 1)[0].strip()
            fm[k.strip()] = v
    return fm, m.group(2)

def as_list(v):
    v = (v or "").strip()
    if v.startswith("["):
        inner = v[1:-1].strip()
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    return [v] if v else []

plan = os.path.join(d, "plan.md")
if not os.path.exists(plan):
    errors.append("plan.md missing")
else:
    fm, body = frontmatter(plan)
    if fm is None: errors.append("plan.md has no frontmatter")
    for sec in ("## Approach", "## Waves", "## Shared interfaces", "## Verification strategy"):
        if sec not in body: errors.append(f"plan.md missing section '{sec}'")

tasks = sorted(glob.glob(os.path.join(d, "tasks", "*.md")))
if not tasks:
    errors.append("no task files in tasks/")

by_wave = {}
ids = set()
for t in tasks:
    name = os.path.basename(t)
    fm, body = frontmatter(t)
    if fm is None:
        errors.append(f"{name}: no frontmatter"); continue
    tid = fm.get("task", "")
    if not re.fullmatch(r"\d{2}", tid): errors.append(f"{name}: task id must be two digits, got '{tid}'")
    if tid in ids: errors.append(f"{name}: duplicate task id {tid}")
    ids.add(tid)
    try:
        wave = int(fm.get("wave", "0"))
    except ValueError:
        wave = 0
    if wave < 1: errors.append(f"{name}: wave must be >= 1")
    touches = as_list(fm.get("touches"))
    if not touches: errors.append(f"{name}: touches is empty")
    deps = as_list(fm.get("depends_on"))
    if fm.get("status", "") not in ("todo", "in_progress", "in_review", "approved", "merged", "blocked"):
        errors.append(f"{name}: invalid status '{fm.get('status')}'")
    for sec in ("## Goal", "## Steps", "## Acceptance criteria", "## Done when"):
        if sec not in body: errors.append(f"{name}: missing section '{sec}'")
    if "{{" in body: errors.append(f"{name}: unfilled template placeholder")
    by_wave.setdefault(wave, []).append((tid, name, touches, deps))

# Dependency and wave checks.
wave_of = {tid: w for w, items in by_wave.items() for (tid, _, _, _) in items}
for w, items in by_wave.items():
    for tid, name, touches, deps in items:
        for dep in deps:
            if dep not in wave_of: errors.append(f"{name}: depends_on unknown task {dep}")
            elif wave_of[dep] >= w: errors.append(f"{name}: depends on {dep} which is in wave {wave_of[dep]} (must be an earlier wave)")
    # Pairwise disjoint touches inside a wave (prefix overlap counts: src/a and src/a/b.ts collide).
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            a, b = items[i], items[j]
            for pa in a[2]:
                for pb in b[2]:
                    pa_, pb_ = pa.rstrip("/"), pb.rstrip("/")
                    if pa_ == pb_ or pa_.startswith(pb_ + "/") or pb_.startswith(pa_ + "/"):
                        errors.append(f"wave {w}: {a[1]} and {b[1]} both touch '{pa}' / '{pb}'")

if errors:
    print(f"{os.path.basename(d)}: {len(errors)} problem(s)")
    for e in errors: print("  -", e)
    sys.exit(1)
print(f"{os.path.basename(d)}: plan and {len(tasks)} task(s) valid, {len(by_wave)} wave(s)")
PY
