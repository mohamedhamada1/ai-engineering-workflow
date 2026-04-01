# AI Engineering Workflow

This document defines the standard AI-assisted engineering workflow used in the Supply Orchestration SDK repository.

The workflow ensures that AI-driven development remains:

- safe for SDK/platform code
- compatible with existing architecture
- strictly scoped
- reproducible
- stage-driven according to the roadmap

This workflow is optimized for platform SDK development and staged architecture execution.

---

# 1. Core Philosophy

The Supply Orchestration SDK uses AI to accelerate development, but all AI execution must follow strict discipline.

Key principles:

1. Architecture first
2. Ground against the real repository
3. Execute narrowly
4. Review diffs before fixing tests
5. Stabilize separately
6. Audit against invariants
7. Update project artifacts consistently

AI agents are assistants, not autonomous architects.

---

# 2. Tool Roles

## ChatGPT — Architect

Responsibilities:

- feature design
- architecture discussion
- risk analysis
- specification creation
- implementation plan creation
- workflow orchestration
- final architectural review

ChatGPT defines the work, but does not execute repository edits.

## Gemini — Red Team Reviewer

Responsibilities:

- challenge architectural assumptions
- detect hidden risks
- verify scope boundaries
- verify roadmap alignment
- confirm backward compatibility
- review spec and plan before implementation

Gemini acts as the architectural gatekeeper.

## Claude — Repository Executor

Responsibilities:

- preflight grounding
- feature implementation
- diff review
- stabilization
- PR compliance check

Claude must not modify architecture or expand scope.

Claude executes only approved spec + plan.

---

# 3. Canonical Workflow

Every feature follows this lifecycle:

1. Architecture discussion
2. Spec creation
3. Plan creation
4. Gemini review
5. Preflight grounding
6. Implementation
7. Diff review
8. Stabilization
9. PR check
10. Final architectural review
11. Merge and artifact update

---

# 4. Workflow Rules

## Cardinal Rules

1. Never skip Gemini review.
2. Never skip preflight grounding.
3. Never expand scope mid-implementation.
4. Never mix stabilization with new feature work.
5. Always update repository memory files after merge.

## Definition of Done

A feature is done when:

- format passes
- analyze/lint passes
- tests pass
- no changes exist outside approved scope
- architecture remains aligned with spec and plan
- roadmap and stage artifacts are updated

---

# 5. Mandatory Execution Flow

All stage work must follow this sequence:

1. Spec (with Verification Checklist)
2. Preflight Clarification Check
3. Plan
4. Implementation
5. Conformance Verification
6. Diff Review
7. Stabilization
8. PR Check
9. Final Architectural Review
10. Merge and Artifact Update

Implementation must not begin until the executor has emitted a Preflight Clarification Check.

Plans drive execution order, but specs define required behavior, clarification policy, and conformance targets.

---

# 6. Preflight Clarification Check

Before implementation, the executor (Claude) must emit a Preflight Clarification Check as the first output.

## Required Output

```
## Preflight Clarification Check

Status: READY | READY_WITH_ASSUMPTIONS | NEEDS_CLARIFICATION | BLOCKED

### Questions
(grouped, high-impact only — max 5)

### Assumptions
(explicit list of assumptions being made)

### Risk If Assumptions Are Wrong
(what breaks or degrades)
```

## When to Ask Questions

Questions are allowed only when ambiguity materially affects:

- correctness
- safety
- architecture
- shared contracts
- migrations
- tests or acceptance criteria

Questions must be grouped and high-impact only.
Default maximum: 5 questions per clarification round.

## When to Proceed Without Asking

The executor may proceed with `READY_WITH_ASSUMPTIONS` when:

- the spec's Preflight Clarification Intent allows assumption-driven continuation
- the risk of wrong assumptions is low (no shared contracts, no migrations, no public API changes)
- assumptions are explicitly stated in the check output

## When to Block

The executor must emit `BLOCKED` when:

- required artifacts are missing (spec, plan, review)
- spec contradicts plan
- ambiguity affects shared_contracts or public API surface
- no reasonable assumption can be made

---

# 7. Verification Checklist

Every spec must include a `## Verification Checklist` section with machine-friendly checkbox items.

## Purpose

The Verification Checklist is the minimum conformance target for:

- implementation (executor must satisfy all items)
- diff review (reviewer must check all items against code)
- post-review verification (conformance script checks for section presence)

## Required Categories

Each checklist must include items under:

- **Required Artifacts** — files, endpoints, components that must exist
- **Core Behavior** — functional requirements that must be implemented
- **Safety / Invariants** — constraints that must be preserved
- **Tests** — test coverage expectations

## Conformance Reporting

Reviews must explicitly report:

- satisfied items (checked)
- partially satisfied items (with explanation)
- missing items (with explanation)
- assumptions used by the executor during implementation
