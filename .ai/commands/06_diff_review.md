# Command: Diff Review

**Agent:** Claude (Executor)
**Stage:** Diff Review — runs after implementation, before stabilization
**Input:** Git diff of implementation changes
**Output:** Safety assessment

---

## Your Task

Review the git diff produced by your implementation against the approved plan and invariant checklist.

This is a safety gate. You are checking whether what you actually changed matches what you were approved to change.

---

## Diff Review Process

### Step 1: List Changed Files

From the diff, extract every file that was added, modified, or deleted.

For each file, classify it as:
- **APPROVED** — in the approved scope list from `CURRENT_STAGE.md`
- **UNEXPECTED** — not in the approved scope list
- **PROTECTED** — in the protected file list (critical violation)

### Step 2: Review Each Changed File

For each APPROVED file, check:

- Does the change match the intent described in the plan?
- Is there any change that was not in the plan?
- Are there any accidental deletions?
- Are there any scope creep additions (new features, new abstractions, new configs)?

For each UNEXPECTED file:
- Why was it changed?
- Is it a necessary transitive change (e.g., a barrel export file)?
- If it was necessary, is the change minimal?
- Should it have been in the approved scope?

For any PROTECTED file: **immediate FAIL**.

### Step 3: API Surface Check

From the diff, identify any changes to public symbols (exported classes, public methods, enums, constants).

For each public symbol change:
- Is it in the approved spec?
- If not: flag as UNPLANNED API CHANGE.

### Step 4: Dependency Check

From the diff, check:
- Any changes to `pubspec.yaml`, `package.json`, `Gemfile`, `requirements.txt`, etc.
- Any new import statements referencing packages not previously used.

For each dependency change:
- Is it in the approved spec?
- If not: flag as UNPLANNED DEPENDENCY CHANGE.

### Step 5: Invariant Check

Review the core invariants from `docs/AI_REPO_BRAIN.md` and `CURRENT_STAGE.md`.

For each invariant, check whether any diff change violates it.

Common invariants to check:
- Memory/resource management (subscriptions cancelled, controllers disposed)
- Masking/privacy (sensitive data not bypassed)
- Schema stability (no unplanned schema changes)
- API stability (no unplanned API changes)
- Test coverage (new behavior has tests)

### Step 6: Issue Verdict

**SAFE** — All changes are approved, no invariants violated, no unexpected files.

**WARN** — Minor unexpected changes that are explainable and low-risk. List them.

**UNSAFE** — Any of the following:
- Protected file was modified
- Unplanned public API change
- Unplanned dependency added
- Invariant violation detected
- Significant changes outside approved scope

---

## Output Format

Use the diff review template from `.ai/templates/diff_review_template.md`.

```
## Diff Review Report

### Changed Files
<file | classification (APPROVED/UNEXPECTED/PROTECTED) | notes>

### Unexpected Changes
<list each with explanation>

### API Surface Changes
<list each with PLANNED/UNPLANNED classification>

### Dependency Changes
<list each with PLANNED/UNPLANNED classification>

### Invariant Check
<list each invariant: PRESERVED / VIOLATED>

### Verdict
SAFE / WARN / UNSAFE

### Required Actions (if WARN or UNSAFE)
<specific changes that must be reverted or explained>
```
