# Implementation Plan: Session Analysis Context

**Stage:** Stage 4.2 — Session Analysis Context
**Spec:** `.ai/specs/stage_4_2_session_analysis_context.md`
**Status:** Approved
**Author:** ChatGPT (Architect)
**Date:** 2024-06-01

---

## Overview

We will create two new files: a data class (`SessionAnalysisContext`) and a builder (`SessionAnalysisContextBuilder`). The builder will scan a `SessionEvent[]` and extract three behavioral signals: rage taps, silent stalls, and network failures. Finally we will update the SDK barrel file to export both new types.

---

## Pre-Implementation Checklist

- [ ] Preflight grounding has returned GO
- [ ] `lib/sample_sdk.dart` exists and is readable
- [ ] `lib/src/models/session_event.dart` contains `SessionEvent` with `screenName`, `timestamp`, `type` fields

---

## Implementation Steps

---

### Step 1: Create `SessionAnalysisContext`

**File:** `lib/src/analysis/session_analysis_context.dart`
**Action:** Create

**What to do:**
Create a new file with an immutable data class `SessionAnalysisContext`.

Fields:
- `final List<String> rageTapScreens` — screen names where rage tap signal was detected
- `final List<String> silentStallScreens` — screen names where silent stall signal was detected
- `final List<String> networkFailurePaths` — screen names where network failures occurred

Include a `const` constructor. Do not add any methods — this is a pure data class.

**Why:**
This is the output value object of the analysis pipeline. Keeping it pure simplifies testing.

---

### Step 2: Create `SessionAnalysisContextBuilder`

**File:** `lib/src/analysis/session_analysis_context_builder.dart`
**Action:** Create

**What to do:**
Create a stateless utility class `SessionAnalysisContextBuilder` with one public method:

```
static SessionAnalysisContext build(List<SessionEvent> events)
```

The method should:

1. Group events by `screenName`.
2. For each screen, detect rage taps: 3 or more tap events within a 2-second window. Add screen name to `rageTapScreens` if detected.
3. For each screen, detect silent stalls: screen was present for 5+ seconds with no user-initiated events (tap, scroll, input). Add screen name to `silentStallScreens` if detected.
4. For each screen, detect network failures: at least one `networkFailure` event. Add screen name to `networkFailurePaths` if detected.
5. Return a `SessionAnalysisContext` with the collected lists.

Define thresholds as private constants at the top of the file:
```
const int _rageTapMinCount = 3;
const Duration _rageTapWindow = Duration(seconds: 2);
const Duration _stallThreshold = Duration(seconds: 5);
```

**Why:**
Centralizing signal extraction in one builder makes the logic testable and replaceable without touching the data model.

---

### Step 3: Write Unit Tests

**File:** `test/analysis/session_analysis_context_test.dart`
**Action:** Create

**What to do:**
Write unit tests for `SessionAnalysisContextBuilder.build()`.

Test cases to include:

1. `empty event list returns empty context` — call with `[]`, expect all lists empty.
2. `rage tap detected when 3+ taps within 2 seconds` — create 3 tap events within 2s on same screen, expect screen in `rageTapScreens`.
3. `rage tap not detected when taps are spread across 3 seconds` — 3 taps but over 3s, expect `rageTapScreens` empty.
4. `silent stall detected when no user events for 5+ seconds` — screen with only a view event at t=0 and next event at t=6s, expect screen in `silentStallScreens`.
5. `network failure path detected` — one `networkFailure` event on a screen, expect screen in `networkFailurePaths`.
6. `multiple screens analyzed independently` — events on two different screens, verify signals are attributed to the correct screen.

**Why:**
Each signal type must have at least two test cases (positive and negative or boundary case).

---

### Step 4: Update Barrel Export

**File:** `lib/sample_sdk.dart`
**Action:** Modify

**What to do:**
Add two export lines in the analysis section of the barrel file:

```dart
export 'src/analysis/session_analysis_context.dart';
export 'src/analysis/session_analysis_context_builder.dart';
```

**Why:**
Public types must be accessible via the single barrel import.

---

## Test Plan

| Test File | Test Cases | Behavior Verified |
|-----------|-----------|-------------------|
| `test/analysis/session_analysis_context_test.dart` | 6 test cases | Rage tap, stall, network failure detection |

---

## Verification Commands

```bash
dart format .
dart analyze .
flutter test test/analysis/
```

---

## Notes for Claude

- Do not change `SessionEvent` — read it, do not modify it.
- The `sessionName` and `timestamp` fields on `SessionEvent` — verify the exact field names during preflight.
- Use `DateTime` arithmetic for time window comparisons.
- Preserve immutability: no mutable state in the builder, no mutable lists in the context.
