# Task Checklist

## Feature
- Name:
- Spec:
- Plan:
- Owner:
- Branch:

---

## Pre-Architecture
- [ ] Roadmap item identified
- [ ] Current stage reviewed
- [ ] Prior related stages reviewed
- [ ] Core invariants identified

---

## Architecture / Spec
- [ ] Spec exists in `.ai/specs/`
- [ ] Scope is approved
- [ ] Files to Touch are explicit
- [ ] Out-of-scope items are explicit
- [ ] Prior-stage behavior to preserve is documented
- [ ] Risks / inconsistencies are documented
- [ ] Required tests are defined
- [ ] Verification commands are defined

---

## Planning
- [ ] Exact files to create identified
- [ ] Exact files to modify identified
- [ ] Call-site migrations identified
- [ ] Backward decode compatibility considered
- [ ] JSON safety considered
- [ ] Rollback approach documented

---

## Reviewer / Red Team
- [ ] Gemini review completed
- [ ] Valid reviewer feedback incorporated
- [ ] Spec revised if needed
- [ ] Plan revised if needed

---

## Preflight Clarification
- [ ] Preflight Clarification Check emitted before coding
- [ ] Status declared: READY / READY_WITH_ASSUMPTIONS / NEEDS_CLARIFICATION / BLOCKED
- [ ] Questions grouped (max 5) if status is NEEDS_CLARIFICATION
- [ ] Assumptions explicitly listed if status is READY_WITH_ASSUMPTIONS
- [ ] Risk of wrong assumptions documented
- [ ] No implementation started before clarification check completed

## Preflight / Grounding
- [ ] Stage exists in canonical roadmap
- [ ] Spec and plan align
- [ ] All Files to Touch were verified
- [ ] Missing files mapped explicitly if needed
- [ ] Whole-repo symbol impact scan completed
- [ ] Scope conflicts checked
- [ ] Invariant check completed
- [ ] GO / NO-GO decision recorded
- [ ] GO achieved before implementation

---

## Implementation
- [ ] Only approved files were edited
- [ ] No scope expansion occurred
- [ ] No destructive commands were used
- [ ] Public API changes match plan
- [ ] Sensitive files were not changed unless approved
- [ ] Persistence payloads remain JSON-safe
- [ ] Decode compatibility for missing optional fields is preserved
- [ ] Prior-stage behavior remains intact where required

---

## Diff Review
- [ ] Diff review completed
- [ ] Scope drift checked
- [ ] Symbol drift checked
- [ ] Missing tests / coverage gaps reviewed
- [ ] Spec Checklist Conformance section completed
- [ ] All checklist items evaluated (satisfied / partial / missing)
- [ ] Executor assumptions documented
- [ ] Stabilization readiness confirmed

---

## Stabilization
- [ ] Syntax issues fixed
- [ ] Compile issues fixed
- [ ] Analyzer issues fixed
- [ ] Test failures fixed
- [ ] No unrelated refactors introduced
- [ ] Branch is runnable/testable
- [ ] Ready for PR check

---

## PR Check
- [ ] Diff matches approved spec
- [ ] Diff matches approved plan
- [ ] Files to Touch were respected
- [ ] Acceptance criteria are covered
- [ ] Tests were added/updated as required
- [ ] Minimal diff principle respected
- [ ] Guardrails from workflow/spec were respected
- [ ] Merge readiness confirmed

---

## Local Verification
- [ ] `dart format .`
- [ ] `dart analyze .`
- [ ] `flutter test`

Add narrower/manual checks if needed:

- [ ] Manual app validation completed
- [ ] Firebase / emulator validation completed
- [ ] Crash flow validation completed
- [ ] Replay/masking validation completed

---

## Artifact Updates
- [ ] `CURRENT_STAGE.md` updated
- [ ] `TEST_REPORT.md` updated
- [ ] `ROADMAP.md` updated if stage status changed
- [ ] `KNOWN_ISSUES.md` updated

---

## Merge Readiness
- [ ] PR title drafted
- [ ] PR summary drafted
- [ ] Known risks documented
- [ ] Rollback plan documented
- [ ] Ready for review