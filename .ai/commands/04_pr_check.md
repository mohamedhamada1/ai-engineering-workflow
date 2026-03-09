# Command: PR Check

**Agent:** Claude (Executor)
**Stage:** PR Scope Audit
**Prerequisite:** Stabilization complete, all tests passing

---

## Your Task

Perform a final scope and safety audit before the PR is submitted for human review.

This is not a code quality review. It is a compliance check: does this PR contain exactly what was approved and nothing more?

---

## Audit Checklist

Work through each section. Report PASS or FAIL for each item.

---

### Section 1: File Scope Audit

**For every file changed in the diff:**

- [ ] The file is in the approved scope list from `CURRENT_STAGE.md`.
- [ ] No file outside the approved scope was modified.
- [ ] No protected file was modified.

If any file fails this check: **FAIL. List the violating files.**

---

### Section 2: API Surface Audit

- [ ] No public API was added, removed, or changed unless explicitly approved in the spec.
- [ ] No public method signature changed.
- [ ] No public model field was added, removed, or renamed unless explicitly approved.

If any API change was not in the spec: **FAIL. List the unplanned changes.**

---

### Section 3: Dependency Audit

- [ ] No new external packages or libraries were added unless explicitly approved in the spec.
- [ ] No existing dependency version was changed.
- [ ] No new system-level dependencies were introduced.

If any dependency change was not in the spec: **FAIL. List the changes.**

---

### Section 4: Schema and Persistence Audit

- [ ] No data model schema was changed in a backward-incompatible way unless explicitly approved.
- [ ] No storage format, file format, or serialization logic was changed unless explicitly approved.
- [ ] No database migration is required unexpectedly.

If any schema change was not in the spec: **FAIL. List the changes.**

---

### Section 5: Invariant Audit

Review the core invariants listed in `docs/AI_REPO_BRAIN.md` and in `CURRENT_STAGE.md`.

- [ ] No invariant was violated.

For each invariant, state: **CHECKED — PRESERVED** or **VIOLATION DETECTED**.

---

### Section 6: Test Coverage Audit

- [ ] New behavior introduced by this feature has corresponding tests.
- [ ] Modified behavior has updated tests.
- [ ] No tests were deleted unless the feature explicitly removed the behavior being tested.

If coverage is insufficient: **WARN. List uncovered behaviors.**

---

### Section 7: Verification Commands

Confirm the final state of the verification suite:

```bash
dart format .
dart analyze .
flutter test
```

All three must pass cleanly.

- [ ] `format` — PASS
- [ ] `analyze` — PASS
- [ ] `test` — PASS

---

## Output Format

Provide a structured report:

```
## PR Check Report

### File Scope: PASS / FAIL
<findings>

### API Surface: PASS / FAIL
<findings>

### Dependencies: PASS / FAIL
<findings>

### Schema / Persistence: PASS / FAIL
<findings>

### Invariants: PASS / FAIL
<findings>

### Test Coverage: PASS / WARN / FAIL
<findings>

### Verification: PASS / FAIL
format: PASS / FAIL
analyze: PASS / FAIL
test: PASS / FAIL

### Overall Result: PASS / FAIL

### PR Summary Draft
What: <what was implemented>
Why: <why it was needed>
Risks: <any residual risks>
Tests run: <test commands and results>
```
