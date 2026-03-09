# Feature Spec: Session Analysis Context

**Stage:** Stage 4.2 — Session Analysis Context
**Status:** Approved
**Author:** ChatGPT (Architect)
**Reviewer:** Gemini (Gatekeeper)
**Date:** 2024-06-01

---

## Problem Statement

The SDK captures raw event streams during sessions, but currently provides no way to summarize behavioral patterns from those events. Engineers debugging issues must manually scan raw event lists. We need a structured analysis layer that extracts behavioral signals from a session's event stream.

---

## Acceptance Criteria

- [ ] `SessionAnalysisContext` is a data class containing extracted behavioral signals.
- [ ] `SessionAnalysisContextBuilder.build(events)` produces a `SessionAnalysisContext` from a list of `SessionEvent` objects.
- [ ] Rage tap screens are detected (3+ taps on the same screen within 2 seconds).
- [ ] Silent stall screens are detected (screen present for 5+ seconds with no user events).
- [ ] Network failure paths are detected (screens where network requests failed).
- [ ] `SessionAnalysisContext` is immutable.
- [ ] Unit tests cover each signal type with at least two test cases.

---

## In Scope

- `SessionAnalysisContext` data class (models layer)
- `SessionAnalysisContextBuilder` (analysis layer)
- Unit tests for builder and context

---

## Out of Scope

- UI rendering of analysis results (deferred to Stage 4.5)
- LLM-based analysis (deferred to Stage 9.0)
- Persistence of analysis results (deferred)
- Network request body/response inspection (deferred)

---

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `lib/src/analysis/session_analysis_context.dart` | Data class holding extracted behavioral signals |
| `lib/src/analysis/session_analysis_context_builder.dart` | Builds context from a `SessionEvent[]` |
| `test/analysis/session_analysis_context_test.dart` | Unit tests |

---

## Files to Modify

| File Path | Change Description |
|-----------|-------------------|
| `lib/sample_sdk.dart` | Export `SessionAnalysisContext` and `SessionAnalysisContextBuilder` |

---

## Protected Files

- `lib/src/recording/session_recorder.dart` — Do not touch the recording engine
- `lib/src/queue/session_queue_store.dart` — Do not touch persistence

---

## Core Invariants

- No changes to session persistence schema
- No changes to public recording API
- No new external dependencies
- All new types must be immutable

---

## Architecture Notes

`SessionAnalysisContext` is a pure value object — it carries results but has no methods that compute anything. All computation happens in `SessionAnalysisContextBuilder`, which is a stateless utility class with a single `build()` method. This makes the analysis deterministic and trivially testable.

---

## Data Model Changes

New types:

```
SessionAnalysisContext {
  rageTapScreens: List<String>      // screen names with rage tap signals
  silentStallScreens: List<String>  // screen names with stall signals
  networkFailurePaths: List<String> // screen names with network failures
}
```

---

## Public API Changes

Two new exports added to the barrel file:
- `SessionAnalysisContext`
- `SessionAnalysisContextBuilder`

---

## Dependencies

None.

---

## Open Questions

1. Should rage tap threshold (3 taps / 2 seconds) be configurable? — Deferred. Use hardcoded constants for now.

---

## Reviewer Notes

- Gemini confirmed: scope is clean, no invariant violations.
- Hardcoded thresholds are acceptable for first pass; document them as constants.
- Immutability rule confirmed: use `const` constructors or `final` fields.

**Decision:** Approved
