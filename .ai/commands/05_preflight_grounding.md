# Command: Preflight Grounding

**Agent:** Claude (Executor)
**Stage:** Preflight — runs before any code is written
**Output:** GO or NO-GO

---

## Your Task

Ground yourself against the real repository before implementing anything.

The purpose of preflight is to:

1. Verify the approved plan can actually be executed against the real codebase.
2. Detect mismatches between the plan's assumptions and the actual repo state.
3. Identify risks that were not visible during spec/plan creation.

**You must not write any code during preflight.** Read only.

---

## Preflight Steps

### Step 1: Read the Approved Scope

Read `CURRENT_STAGE.md` and extract:
- The approved file list (files to create or modify)
- The protected file list (files that must not be touched)
- The core invariants for this stage

### Step 2: Verify Every File in the Approved Scope

For each file in the approved scope:

- **If it should be modified:** Read the file. Confirm it exists at the expected path.
- **If it should be created:** Confirm the parent directory exists.

For each file that should be modified, check:
- Does the file exist at the exact path stated in the plan?
- Do the class names, method names, and symbol names referenced in the plan exist in the actual file?
- Does the file's current structure match what the plan assumes?

### Step 3: Verify Protected Files

Read the protected file list.

Confirm:
- None of the protected files appear in the approved scope list.
- None of the changes described in the plan would require editing a protected file.

### Step 4: Verify Symbol References

For every symbol the plan references (class names, method names, enums, etc.):

- Read the relevant source file.
- Confirm the symbol exists with the expected name and signature.
- Flag any mismatches (renamed symbols, moved files, signature changes).

### Step 5: Run Baseline Verification

Run the verification suite on the current (unchanged) codebase:

```bash
dart format .         # or your project's formatter
dart analyze .        # or your project's linter
flutter test          # or your project's test runner
```

Report the result. If there are pre-existing failures:
- List them with file + line + error message.
- Determine if they will block the implementation.
- These are NOT your responsibility to fix — report them as pre-existing.

### Step 6: Issue GO or NO-GO

Based on steps 1–5, issue a verdict.

**Issue NO-GO if:**
- A file in the approved scope does not exist in the repository.
- A symbol referenced in the plan does not exist.
- A protected file appears in the approved scope.
- A plan step would require modifying a file outside the approved scope.
- Pre-existing failures exist that would block implementation.
- Any plan assumption is contradicted by the actual repository state.

**Issue GO if:**
- All files exist at expected paths.
- All symbols match.
- No protected files are in scope.
- Baseline verification passes (or pre-existing failures are non-blocking).

---

## Output Format

Use the preflight template from `.ai/templates/preflight_template.md`.

```
## Preflight Report

### Stage
<stage name>

### File Verification
<for each file: path, exists (yes/no), notes>

### Symbol Verification
<for each symbol: name, found (yes/no), actual signature vs expected>

### Protected File Check
<confirmation that no protected files are in scope>

### Baseline Verification
format: PASS / FAIL
analyze: PASS / FAIL
test: PASS / FAIL
<list any pre-existing failures>

### Risk Flags
<any issues found that don't block but should be noted>

### Verdict
GO / NO-GO

### Reason (if NO-GO)
<specific blocking issue>
```
