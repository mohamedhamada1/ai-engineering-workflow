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

## Preflight Clarification Intent

- Executor should ask questions if ambiguity affects correctness, safety, architecture, or protected boundaries.
- Maximum grouped questions: 5
- If unanswered, executor may proceed only with explicit assumptions when risk is acceptable (no shared_contracts, no migrations, no public API changes).

---

## Verification Checklist

> **Quality rule:** Every checklist item must be machine-verifiable. Each item must be one of:
> - file/artifact existence (greppable filename)
> - endpoint/route/contract existence (METHOD /path)
> - invariant/safety behavior (greppable keyword or pattern)
> - test evidence (test class or test method name)
>
> Vague items like "implementation is correct" or "logic is robust" are not valid checklist items.

### Mandatory (blocks stage completion if missing)

#### Required Artifacts
- [ ] [File/endpoint/component 1 — e.g., `VendorCockpitView.kt` exists]
- [ ] [File/endpoint/component 2 — e.g., `GET /admin/vendors/{id}/readiness` endpoint exists]

#### Core Behavior
- [ ] [Functional requirement 1 — e.g., `ReadinessScoreCalculator` computes score from capability + availability]
- [ ] [Functional requirement 2 — e.g., vendor list returns `operationalStatus` field]

#### Safety / Invariants
- [ ] [Constraint 1 — e.g., `shared_contracts` not modified]
- [ ] [Constraint 2 — e.g., no new external dependencies added]

#### Tests
- [ ] [Test expectation 1 — e.g., `VendorReadinessTest.kt` exists with at least 2 test cases]
- [ ] [Test expectation 2 — e.g., empty-state rendering test exists]

### Optional / Quality (does not block, but should be addressed)

- [ ] [Nice-to-have 1 — e.g., empty-state illustration renders correctly]
- [ ] [Nice-to-have 2 — e.g., loading skeleton present on vendor detail]

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
