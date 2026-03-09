# AI Engineering Workflow — Feature Lifecycle

This document defines the standard feature lifecycle used in the AI Engineering Workflow system.

Every feature — regardless of size — follows the same ordered stages. Skipping stages is not permitted.

---

## 1. Architecture Discussion

**Owner:** Engineer + ChatGPT
**Input:** Feature goal (one paragraph written by the engineer)
**Output:** Architectural decision

Before any spec is written, the engineer and ChatGPT discuss the feature at the architecture level:

- What problem does this feature solve?
- Where does it belong in the existing architecture?
- What modules, models, and abstractions are involved?
- Are there any invariants or constraints that limit the design?
- What is the minimal viable implementation?

**Rule:** Architecture discussions must happen before spec writing. Never skip directly to implementation.

---

## 2. Spec Creation

**Owner:** ChatGPT
**Input:** Architecture decision + AI Brain
**Output:** `spec.md` stored in `.ai/specs/`
**Template:** `.ai/templates/spec_template.md`

ChatGPT produces a detailed feature specification:

- Feature name and stage number
- Problem statement
- Acceptance criteria (testable)
- Scope — what is included
- Out of scope — what is explicitly excluded
- File list (files to create or modify)
- Protected files (must not be touched)
- Core invariants for this feature
- Open questions or risks

**Rule:** The spec defines the contract. Implementation must match the spec. Changes to scope require a spec revision and re-review.

---

## 3. Plan Creation

**Owner:** ChatGPT
**Input:** Approved spec + AI Brain
**Output:** `plan.md` stored in `.ai/plans/`
**Template:** `.ai/templates/plan_template.md`

ChatGPT produces a step-by-step implementation plan:

- Ordered list of implementation steps
- For each step: file path, what to add/change, why
- Test plan: what tests to write or update
- Verification commands (format, analyze, test)

**Rule:** The plan must be deterministic enough for Claude to execute without making architectural decisions.

---

## 4. Gemini Review

**Owner:** Gemini
**Input:** Spec + Plan + AI Brain
**Output:** GO or NO-GO with written rationale

Gemini reviews the spec and plan against:

- Architecture consistency
- Invariant protection
- Scope boundaries
- Roadmap alignment
- Backward compatibility
- Known issues

**Rule:** Implementation does not begin until Gemini issues a GO. A NO-GO returns the spec/plan to ChatGPT for revision.

---

## 5. Preflight Grounding

**Owner:** Claude
**Input:** Approved spec + plan + real repository
**Output:** GO or NO-GO with grounding report
**Command:** `.ai/commands/05_preflight_grounding.md`
**Template:** `.ai/templates/preflight_template.md`

Claude reads the actual repository to verify:

- All files in the approved scope exist at the expected paths
- File contents are consistent with the plan's assumptions
- No symbol renames or API mismatches
- Protected files are not in the scope list
- No pre-existing failures that would block the feature

**Rule:** Claude does not write a single line of code until preflight passes. A NO-GO stops execution completely.

---

## 6. Implementation

**Owner:** Claude
**Input:** Approved plan + preflight report
**Output:** Code changes
**Command:** `.ai/commands/02_implement_feature.md`

Claude executes the plan step by step:

- Edits only files in the approved scope
- Does not refactor unrelated code
- Does not add features not in the plan
- Does not change architecture
- Makes small, verifiable edits
- Runs `format` and `analyze` after each logical unit of work

**Rule:** If a required change would affect a file outside the approved scope, Claude stops and reports — it does not self-approve scope expansions.

---

## 7. Diff Review

**Owner:** Claude
**Input:** Git diff of implementation
**Output:** Safety assessment report
**Command:** `.ai/commands/06_diff_review.md`
**Template:** `.ai/templates/diff_review_template.md`

Claude reviews its own diff against:

- Approved file list (no unexpected files changed)
- Protected file list (no protected files touched)
- Invariant checklist (no invariants violated)
- API surface (no unplanned public API changes)
- Dependency list (no new dependencies introduced)

**Rule:** Any unexpected change in the diff is flagged before stabilization begins.

---

## 8. Stabilization

**Owner:** Claude
**Input:** Test failures + diff review report
**Output:** Fixed code
**Command:** `.ai/commands/03_stabilize_feature.md`
**Template:** `.ai/templates/stabilize_template.md`

Claude fixes compilation errors and test failures:

- Analyzes the root cause of each failure
- Fixes only what is broken
- Does not introduce new features during stabilization
- Runs the full verification suite after each fix

**Rule:** Stabilization is separate from implementation. Do not mix new feature work with bug fixes.

---

## 9. PR Check

**Owner:** Claude
**Input:** Full git diff
**Output:** PR scope audit
**Command:** `.ai/commands/04_pr_check.md`

Claude performs a final audit:

- Every changed file was in the approved scope
- No protected files were modified
- No unplanned API changes
- No unplanned dependency changes
- All tests pass
- Format and analyze are clean

**Output:** Pass or Fail. If Fail, Claude lists specific violations.

---

## 10. Final Architectural Review

**Owner:** ChatGPT
**Input:** PR diff + implementation notes
**Output:** Architectural approval or revision request

ChatGPT reviews:

- Does the implementation match the spec?
- Are there any architectural drift issues?
- Are there any risks that should be captured in `KNOWN_ISSUES.md`?
- Should the `AI_REPO_BRAIN.md` be updated to reflect new architecture?

---

## 11. Merge and Artifact Update

**Owner:** Engineer
**Input:** Architectural approval
**Actions:**
- Merge PR
- Update `ROADMAP.md` (mark stage complete)
- Update `CURRENT_STAGE.md` (set next stage)
- Update `TEST_REPORT.md` (record final test state)
- Update `KNOWN_ISSUES.md` (close resolved risks)
- Update `AI_REPO_BRAIN.md` if architecture changed

---

## Workflow Rules

### The Cardinal Rules

1. **Never skip Gemini review.** Gemini must approve before Claude implements.
2. **Never skip preflight grounding.** Claude reads the real repo before touching it.
3. **Never expand scope mid-implementation.** Stop and report if scope needs to change.
4. **Never mix stabilization with new features.** Fix first, then add.
5. **Always update brain files after merge.** The AI Brain must reflect current reality.

### Commit Discipline

- Branch naming: `feat/<short-name>` or `fix/<short-name>`
- Commit early and often (small, verifiable commits)
- Commit message format: `<type>: <short description>` (e.g., `feat: add session analysis context`)
- Never force-push without explicit engineer approval

### Definition of Done

A feature is done when:

- [ ] `format` passes
- [ ] `analyze` / `lint` passes
- [ ] All tests pass
- [ ] No changes outside approved scope
- [ ] PR summary includes: what, why, risks, tests run
- [ ] Brain files updated

---

## Handling Workflow Violations

| Violation | Response |
|-----------|----------|
| Gemini not consulted | Revert implementation; run Gemini review |
| Preflight skipped | Stop; run preflight; address NO-GO items |
| Scope expanded without approval | Revert out-of-scope changes |
| Protected file modified | Revert immediately |
| Tests broken by stabilization | Revert stabilization changes; diagnose separately |
| Brain files not updated | Update before marking stage complete |
