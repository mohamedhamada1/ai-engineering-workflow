# Known Issues

Replace this file with your project's risk and issue tracker.

---

## How to Use This File

`KNOWN_ISSUES.md` tracks:

- **Active Risks** — potential problems that could affect current or future work
- **Deferred Items** — things intentionally out of scope, with a reason
- **Closed Items** — resolved issues

Update this file when:
- A new blocker is discovered during implementation
- A reviewer identifies a risk
- An item is deferred
- An item is resolved

---

## Active Risks

_No active risks. Add risks as they are discovered._

---

## Deferred / Out of Scope

_No deferred items yet. Add items as they are scoped out of features._

---

## Closed

_No resolved items yet._

---

## Risk Entry Format

```markdown
### [RISK-ID] — [Short Description]
[Description of the risk and why it matters.]
Mitigation: [What is being done to reduce the risk.]
Status: Open / Deferred / Closed
```

## Example

```markdown
### RL-001 — Planned file vs actual repo mismatch
Implementation plans may reference files that do not exist in the repo.
Mitigation: Mandatory preflight grounding before any code edits.
Status: Open
```
