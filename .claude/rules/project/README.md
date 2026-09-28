# Project rules (learned)

Path-scoped rules the librarian writes after features are merged. Each file covers one topic and uses the `paths:` frontmatter so it only loads when Claude edits matching files:

```markdown
---
paths:
  - "src/api/**/*.ts"
---
# API handlers
- Every handler validates input with the shared `parseBody()` helper (see 001-short-links, review F2).
```

Humans may edit these freely. Keep each file under 40 lines; if it grows, split by path.
