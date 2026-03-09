# Preflight Grounding Report

**Stage:** [Stage Name and ID]
**Date:** [Date]
**Agent:** Claude (Executor)

---

## File Verification

| File Path | Expected Action | Exists | Notes |
|-----------|----------------|--------|-------|
| `path/to/file.dart` | Modify | ✅ Yes / ❌ No | [Any mismatch or note] |
| `path/to/new_file.dart` | Create | N/A — parent dir exists: ✅ / ❌ | |
| `path/to/test_file.dart` | Modify | ✅ Yes / ❌ No | |

**File Verification Result:** PASS / FAIL

---

## Symbol Verification

| Symbol | Expected File | Found | Actual Signature | Notes |
|--------|--------------|-------|-----------------|-------|
| `ClassName` | `path/to/file.dart` | ✅ / ❌ | [actual] | |
| `methodName(param)` | `path/to/file.dart` | ✅ / ❌ | [actual] | [mismatch if any] |

**Symbol Verification Result:** PASS / FAIL

---

## Protected File Check

| Protected File | In Approved Scope? | Plan Requires Edit? |
|---------------|-------------------|---------------------|
| `path/to/protected.dart` | ❌ No (correct) | ❌ No (correct) |

**Protected File Check Result:** PASS / FAIL

---

## Baseline Verification

Commands run on the unmodified repository:

```
dart format .
Result: PASS / FAIL
```

```
dart analyze .
Result: PASS / FAIL
Warnings: [list any]
```

```
flutter test
Result: PASS / FAIL
Failures: [list any pre-existing failures]
```

**Pre-Existing Failures:**
[List any failures found, or write "None."]

**Baseline Result:** PASS / FAIL (non-blocking) / FAIL (blocking)

---

## Risk Flags

[Any non-blocking issues discovered during preflight that should be noted.]

- [Risk 1: description]
- [Risk 2: description]
- None.

---

## Planned-to-Actual File Mapping

[Map every file referenced in the plan to its actual path in the repository. This is the key output of preflight.]

| Plan Reference | Actual Path | Match? |
|---------------|-------------|--------|
| `feedback_sheet.dart` | `lib/src/ui/review_feedback_sheet.dart` | ✅ Confirmed |
| `session_model.dart` | `lib/src/models/session.dart` | ✅ Confirmed |

---

## Verdict

**GO / NO-GO**

### Reason (if NO-GO)

[Specific blocking issue. Be precise: file path, symbol name, expected vs. actual.]

### Required Actions Before Proceeding (if NO-GO)

1. [Action 1]
2. [Action 2]
