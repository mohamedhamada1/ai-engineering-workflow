# Diff Review Report

**Stage:** [Stage Name and ID]
**Date:** [Date]
**Agent:** Claude (Executor)

---

## Changed Files

| File | Classification | Notes |
|------|---------------|-------|
| `path/to/file.dart` | APPROVED | As expected |
| `path/to/test_file.dart` | APPROVED | Test updated for new behavior |
| `path/to/unexpected.dart` | UNEXPECTED | [Explain why it was changed] |
| `path/to/protected.dart` | PROTECTED ❌ | CRITICAL VIOLATION |

**File Classification Result:** PASS / FAIL

---

## Unexpected Changes

[For each UNEXPECTED file, explain:]

### `path/to/unexpected_file.dart`

**Reason changed:** [Why did this file get touched?]
**Change summary:** [What was changed — minimal description]
**Assessment:** Necessary transitive change / Accidental change / Scope creep
**Action:** Keep (if necessary) / Revert

---

## API Surface Changes

| Symbol | Change Type | In Spec? | Assessment |
|--------|------------|----------|------------|
| `ClassName.newMethod()` | Added | ✅ Yes | PLANNED |
| `ExistingClass.renamedField` | Renamed | ❌ No | UNPLANNED ⚠️ |

**API Surface Result:** PASS / FAIL

---

## Dependency Changes

| Package / Import | Change | In Spec? | Assessment |
|-----------------|--------|----------|------------|
| `package:example/module.dart` | Added import | ✅ Yes | PLANNED |
| `package:new_package` | New dependency | ❌ No | UNPLANNED ⚠️ |

**Dependency Result:** PASS / FAIL

---

## Invariant Check

| Invariant | Status | Notes |
|-----------|--------|-------|
| [Invariant 1 from CURRENT_STAGE.md] | ✅ PRESERVED | |
| [Invariant 2] | ✅ PRESERVED | |
| [Invariant 3] | ⚠️ REVIEW NEEDED | [Description] |
| [Invariant 4] | ❌ VIOLATED | [Description of violation] |

**Invariant Result:** PASS / FAIL

---

## Test Coverage

| New/Changed Behavior | Has Test? | Test File |
|---------------------|-----------|-----------|
| [Behavior 1] | ✅ Yes | `test/path/to/test.dart` |
| [Behavior 2] | ❌ No | — |

**Test Coverage Result:** PASS / WARN / FAIL

---

## Verdict

**SAFE / WARN / UNSAFE**

---

## Spec Checklist Conformance

Evaluate each item from the spec's Verification Checklist against the actual implementation.

### Mandatory Items

| Checklist Item | Status | Evidence |
|----------------|--------|----------|
| [item from spec] | SATISFIED / PARTIAL / MISSING | [file path, test name, grep match, or code snippet] |
| [item from spec] | SATISFIED | `apps/api/.../ProviderCallbackRoutes.kt` |
| [item from spec] | SATISFIED | `ProviderCallbackServiceTest.kt::duplicate_callback_is_ignored` |

### Optional / Quality Items

| Checklist Item | Status | Evidence |
|----------------|--------|----------|
| [item from spec] | SATISFIED / SKIPPED | [evidence or reason skipped] |

### Assumptions Made During Implementation

| Assumption | Risk If Wrong | Affected Checklist Items |
|------------|--------------|------------------------|
| [assumption description] | [what breaks] | [which items it affects] |

**Checklist Conformance Result:** PASS / PARTIAL / FAIL

> **PASS** = all mandatory items satisfied
> **PARTIAL** = some mandatory items partial or missing, but no safety violations
> **FAIL** = mandatory safety/invariant items missing or violated

---

## Required Actions

[If WARN or UNSAFE, list specific actions required before proceeding.]

1. [Revert `path/to/file.dart` — change was outside approved scope]
2. [Add test for [behavior] in `test/path/to/test.dart`]
3. [None — verdict is SAFE]
