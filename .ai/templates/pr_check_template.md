# PR Check Template

## Inputs
- Spec:
- Plan:
- Diff / Branch:
- Related issue:
- Reviewer:

---

## 1. Pass List
List what is correct and compliant.

- ...
- ...
- ...

---

## 2. Issues
For every issue include:
- exact file path
- line pointer(s) if possible
- why it violates a guardrail, acceptance criterion, or scope rule
- minimal fix only

### Issue 1
- File:
- Lines:
- Problem:
- Minimal Fix:

---

## 3. Suggested Fixes
Minimal corrections only.

- ...
- ...
- ...

Do not include broad refactors.

---

## 4. Commands to Run
Non-destructive only.

```bash
dart format .
dart analyze .
flutter test
```