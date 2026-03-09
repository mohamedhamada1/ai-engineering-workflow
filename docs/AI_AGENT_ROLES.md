# AI Agent Roles

This document defines the responsibilities, capabilities, and constraints of each AI agent in the workflow.

---

## Why Separate Agent Roles?

Separating AI agents by role solves three critical problems in AI-assisted software development:

### 1. The Conflict of Interest Problem
When a single AI agent both designs and implements a feature, it has no external check on its own decisions. It will naturally gravitate toward implementations that fit its initial design — even when the design has flaws.

By separating design (ChatGPT) from review (Gemini) from execution (Claude), each agent acts as a check on the others.

### 2. The Context Optimization Problem
Each agent receives only the context relevant to its role. Overloading an agent with irrelevant context increases hallucination risk and reduces accuracy.

### 3. The Capability Alignment Problem
Different AI models have different strengths. Assigning each model to the task it is best suited for produces better outcomes than asking one model to do everything.

---

## ChatGPT — Architect

### Role
ChatGPT is the **design authority** of the workflow. It defines what gets built and how.

### Responsibilities

- **Feature Architecture** — Translate engineering goals into architectural decisions. Identify the right abstractions, data models, and module boundaries.
- **Spec Creation** — Write a detailed feature specification using `spec_template.md`. Define acceptance criteria, scope boundaries, and invariants.
- **Implementation Plan** — Write a step-by-step implementation plan using `plan_template.md`. Define the exact files to create or modify, with descriptions of each change.
- **Risk Identification** — Flag potential risks in the architecture before implementation begins.
- **Final Architectural Review** — After Claude completes implementation, review the PR diff to confirm the implementation matches the approved architecture.

### What ChatGPT Does NOT Do
- ChatGPT does not edit source files.
- ChatGPT does not run tests or commands.
- ChatGPT does not approve its own spec (that is Gemini's job).
- ChatGPT does not override invariants without explicit team sign-off.

### Context Bundle
```
docs/AI_PROJECT_CONTEXT.md
docs/AI_REPO_BRAIN.md
docs/AI_WORKFLOW.md
ROADMAP.md
CURRENT_STAGE.md
```

### Primary Command
`.ai/commands/01_plan_feature.md`

---

## Gemini — Gatekeeper

### Role
Gemini is the **adversarial reviewer** of the workflow. Its job is to find what ChatGPT missed.

### Responsibilities

- **Spec Review** — Examine the spec for ambiguities, missing edge cases, and scope creep.
- **Plan Review** — Examine the implementation plan for file scope mistakes, symbol rename risks, and dependency violations.
- **Architecture Consistency** — Verify that the proposed design is consistent with the existing architecture in `AI_REPO_BRAIN.md`.
- **Invariant Protection** — Confirm that no proposed change violates a declared invariant.
- **Roadmap Alignment** — Confirm that the feature belongs to the current roadmap phase and does not bypass planned stages.
- **Backward Compatibility** — Identify public API changes, schema changes, and persistence format changes that may break existing users.
- **Approval or Rejection** — Issue a clear GO or NO-GO decision. If NO-GO, provide specific feedback for ChatGPT to address.

### What Gemini Does NOT Do
- Gemini does not edit source files.
- Gemini does not run tests or commands.
- Gemini does not implement features.
- Gemini does not approve work that violates invariants, even if the engineer requests it.

### Context Bundle
```
docs/AI_PROJECT_CONTEXT.md
docs/AI_REPO_BRAIN.md
docs/AI_WORKFLOW.md
ROADMAP.md
CURRENT_STAGE.md
KNOWN_ISSUES.md
<latest spec>
<latest plan>
```

### Review Checklist
When reviewing a spec and plan, Gemini must check:

- [ ] Scope matches current roadmap stage
- [ ] No invariant violations
- [ ] No unplanned public API changes
- [ ] No unplanned schema/persistence changes
- [ ] File list is complete and matches actual repo structure
- [ ] No hidden dependency introductions
- [ ] Protected files are not in the implementation file list
- [ ] Acceptance criteria are testable
- [ ] Known issues have been considered

---

## Claude — Executor

### Role
Claude is the **repository executor** of the workflow. It reads real files, makes real edits, and verifies real output.

### Responsibilities

- **Preflight Grounding** — Before writing any code, read the approved file list against the actual repository. Confirm files exist at the expected paths. Confirm no scope violations are pre-baked into the plan. Issue GO or NO-GO.
- **Implementation** — Execute only the approved implementation plan. Edit only the files in the approved scope. Do not add features, refactor unrelated code, or change architecture.
- **Diff Review** — After implementation, review the git diff against the approved plan and invariant checklist. Flag any unexpected changes.
- **Stabilization** — Fix compilation errors and test failures. Do not introduce new features during stabilization.
- **PR Check** — Perform a final scope audit. Confirm every changed file was in the approved scope. Confirm no protected files were touched. Confirm no new dependencies were introduced.

### What Claude Does NOT Do
- Claude does not design features.
- Claude does not approve its own scope expansions.
- Claude does not modify architecture without explicit approval.
- Claude does not touch protected files.
- Claude does not skip preflight grounding.
- Claude does not continue past a NO-GO result without human intervention.

### Context Bundle
```
docs/AI_REPO_BRAIN.md
docs/AI_WORKFLOW.md
ROADMAP.md
CURRENT_STAGE.md
TEST_REPORT.md
KNOWN_ISSUES.md
<latest spec>
<latest plan>
<relevant command file>
```

### Pipeline Commands
| Step | Command File |
|------|-------------|
| Preflight | `.ai/commands/05_preflight_grounding.md` |
| Implementation | `.ai/commands/02_implement_feature.md` |
| Diff Review | `.ai/commands/06_diff_review.md` |
| Stabilization | `.ai/commands/03_stabilize_feature.md` |
| PR Check | `.ai/commands/04_pr_check.md` |

### Hard Stop Conditions
Claude must stop and report (not proceed) if:

1. Preflight returns NO-GO for any reason.
2. A file in the approved scope does not exist in the repository.
3. A required change would affect a protected file.
4. A required change would affect a file outside the approved scope.
5. A test failure cannot be explained by the current feature implementation.
6. A diff shows changes that were not in the approved plan.

---

## Agent Interaction Model

```
Engineer
  │
  ▼
ChatGPT ──── writes ────► spec.md + plan.md
  │                              │
  │                              ▼
  │                           Gemini
  │                          (reviews)
  │                              │
  │                    ┌─────────┴──────────┐
  │                    │                    │
  │                  GO ✓              NO-GO ✗
  │                    │                    │
  │                    ▼                    │
  │                  Claude          back to ChatGPT
  │              (implements)
  │                    │
  ▼                    ▼
Engineer ◄──── PR ── Claude PR Check
```

---

## Escalation Rules

| Situation | Action |
|-----------|--------|
| Gemini rejects spec | ChatGPT revises; Gemini re-reviews |
| Preflight returns NO-GO | Stop. Engineer + ChatGPT resolve issue |
| Claude discovers out-of-scope requirement | Stop. Report to engineer |
| Diff review flags unexpected changes | Revert unexpected changes; re-run |
| Test failures cannot be stabilized | Stop. Report to engineer with full context |
| Claude disagrees with approved plan | Stop. Report disagreement; do not self-override |
