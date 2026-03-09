# Feature Spec: [Feature Name]

**Stage:** [Stage ID — e.g., Stage 4.2]
**Status:** Draft / Approved
**Author:** ChatGPT (Architect)
**Reviewer:** Gemini (Gatekeeper)
**Date:** [Date]

---

## Problem Statement

[One to three sentences describing the user-facing or engineering problem this feature solves.]

---

## Acceptance Criteria

Each criterion must be independently testable.

- [ ] [Criterion 1 — specific, testable, measurable]
- [ ] [Criterion 2]
- [ ] [Criterion 3]
- [ ] [Add as many as needed]

---

## In Scope

[Explicit list of what this feature includes. Be specific.]

- [Item 1]
- [Item 2]
- [Item 3]

---

## Out of Scope

[Explicit list of what is NOT included in this feature. Being explicit prevents scope creep.]

- [Item 1 — deferred to Stage X.Y]
- [Item 2 — out of scope entirely]
- [Item 3]

---

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `path/to/new_file.dart` | [Brief description of what this file does] |
| `path/to/another_file.dart` | [Brief description] |

---

## Files to Modify

| File Path | Change Description |
|-----------|-------------------|
| `path/to/existing_file.dart` | [What changes and why] |
| `path/to/another_file.dart` | [What changes and why] |

---

## Protected Files

These files must NOT be touched by this feature.

- `path/to/protected_file.dart` — [Reason: e.g., touches persistence schema]
- `path/to/another_protected.dart` — [Reason]

---

## Core Invariants

These constraints must be preserved throughout this feature's implementation.

- [Invariant 1 — e.g., "Session schema must not change"]
- [Invariant 2 — e.g., "Public API surface must not change"]
- [Invariant 3 — e.g., "No new external dependencies"]

---

## Architecture Notes

[Brief description of the design approach. Include any important architectural decisions made during the architecture discussion phase.]

---

## Data Model Changes

[Describe any new or modified data models. If none, write "None."]

---

## Public API Changes

[Describe any changes to the public API. If none, write "None. Public API is unchanged."]

---

## Dependencies

[List any new external dependencies required. If none, write "None."]

---

## Open Questions

[List any unresolved questions or risks that should be addressed before or during implementation.]

1. [Question 1]
2. [Question 2]

---

## Reviewer Notes

[Gemini fills this section during review.]

- [Note 1]
- [Note 2]

**Decision:** Approved / Rejected
**Reason:** [If rejected, state what must change.]
