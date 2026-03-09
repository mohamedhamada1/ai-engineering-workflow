# Implementation Plan: [Feature Name]

**Stage:** [Stage ID]
**Spec:** `.ai/specs/[spec_filename].md`
**Status:** Draft / Approved
**Author:** ChatGPT (Architect)
**Date:** [Date]

---

## Overview

[One paragraph summarizing what will be implemented and in what order. This gives Claude a mental model before reading the steps.]

---

## Pre-Implementation Checklist

Before writing any code, Claude must verify:

- [ ] Preflight grounding has returned GO
- [ ] All files in the approved scope exist in the repository
- [ ] All symbols referenced in this plan exist with the expected signatures
- [ ] No protected files appear in the scope list

---

## Implementation Steps

Steps must be executed in order. Each step must be complete before the next begins.

---

### Step 1: [Step Name]

**File:** `path/to/file.dart`
**Action:** Create / Modify / Delete

**What to do:**
[Clear, specific description of the change. Describe the structure, not pseudo-code.]

**Why:**
[One sentence explaining why this step is needed.]

**Notes:**
[Any caveats, edge cases, or things to be careful about.]

---

### Step 2: [Step Name]

**File:** `path/to/another_file.dart`
**Action:** Modify

**What to do:**
[Description]

**Why:**
[Reason]

**Notes:**
[Any caveats]

---

### Step 3: [Step Name]

**File:** `path/to/test_file.dart`
**Action:** Create / Modify

**What to do:**
[Describe what tests to write: class name, test cases, what behavior is being verified.]

**Why:**
[Reason]

---

[Add as many steps as needed. Every file in the approved scope should appear in at least one step.]

---

## Test Plan

| Test File | Test Cases | Behavior Verified |
|-----------|-----------|-------------------|
| `test/path/to/test_file.dart` | [List test case names] | [What behavior] |

---

## Verification Commands

After implementation is complete, run:

```bash
# Format
dart format .

# Static analysis
dart analyze .

# Tests
flutter test

# (Adjust commands to match your project's tooling)
```

All three must pass before moving to diff review.

---

## Rollback Plan

If implementation must be abandoned mid-way:

```bash
git stash
# or
git checkout -- path/to/affected/files
```

[Note any special cleanup steps if files were created.]

---

## Notes for Claude

[Any additional context ChatGPT wants to communicate to Claude about the implementation.]

- [Note 1]
- [Note 2]
