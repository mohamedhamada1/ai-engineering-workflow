# Command: Stabilize Feature

**Agent:** Claude (Executor)
**Stage:** Stabilization
**Prerequisite:** Implementation complete, diff review passed

---

## Your Task

Stabilization fixes compilation errors and test failures introduced by the feature implementation.

This is a **repair phase**, not a feature phase. You must not add new functionality, refactor unrelated code, or change architecture during stabilization.

---

## What Stabilization Is

Stabilization addresses:

- Compilation errors caused by your implementation
- Import errors or missing references
- Test failures caused by changed behavior (correct the test or the implementation)
- Format or lint violations introduced by your changes

---

## What Stabilization Is NOT

Stabilization does not include:

- Adding features that were missed in implementation
- Refactoring code that was not changed by this feature
- Fixing pre-existing bugs unrelated to this feature
- Updating tests for behavior you did not change

If you discover a pre-existing failure during stabilization: **stop and report it** rather than fixing it. Pre-existing failures must be tracked in `KNOWN_ISSUES.md` and addressed separately.

---

## Stabilization Process

### Step 1: Reproduce the failure

Run the verification suite and capture the full output:

```bash
dart format .
dart analyze .
flutter test
```

List every failure with:
- File and line number
- Error or failure message
- Your diagnosis (what caused it)

### Step 2: Categorize each failure

For each failure, categorize it as:

- **A** — Caused by this feature's implementation (fix it)
- **B** — Pre-existing failure unrelated to this feature (do not fix; report)
- **C** — Test assertion mismatch because behavior intentionally changed (update the test)
- **D** — Missing piece of the implementation (complete the implementation)

### Step 3: Fix Category A and C failures only

Apply the minimal fix for each.

Rules:
- Fix only the lines directly responsible for the failure.
- Do not rewrite functions that work.
- Do not change test behavior — only update assertions where behavior intentionally changed.

### Step 4: Re-run verification

After each fix batch, re-run:

```bash
dart format .
dart analyze .
flutter test
```

Repeat until all Category A and C failures are resolved.

---

## Stop Conditions

Stop and report if:

- A failure cannot be fixed without editing a protected file.
- A failure cannot be fixed without editing a file outside the approved scope.
- A failure cannot be fixed without changing a public API or persistence schema.
- A Category B (pre-existing) failure is blocking the test suite.
- You cannot determine the root cause of a failure after careful analysis.

---

## Output Format

After stabilization, provide:

1. **Failure list** — each failure with category, root cause, and fix applied.
2. **Verification results** — final output of format, analyze, and test.
3. **Pre-existing failures** — any Category B failures found (for `KNOWN_ISSUES.md`).
4. **Status** — STABILIZED (all A/C failures fixed) or BLOCKED (stop condition hit).
