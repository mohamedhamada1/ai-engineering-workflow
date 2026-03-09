# Command: Implement Feature

**Agent:** Claude (Executor)
**Stage:** Implementation
**Prerequisite:** Preflight returned GO

---

## Your Task

You are implementing an approved feature plan.

Preflight grounding has already passed. You have:
- A confirmed file list that exists in the real repository
- A confirmed scope boundary
- A verified set of protected files

Your job is to execute the implementation plan step by step.

---

## Rules

### Scope Rules (Non-Negotiable)
- Edit **only** the files listed in the approved scope.
- Do **not** edit protected files under any circumstance.
- Do **not** refactor, clean up, or improve code outside the approved scope.
- Do **not** add features that are not in the plan.
- Do **not** add comments, documentation, or type annotations to files you are not changing.

### Quality Rules
- Prefer the simplest correct implementation over a clever one.
- Do not add error handling for scenarios that cannot happen.
- Do not add configuration options that are not required.
- Do not create helper utilities for one-time operations.

### Safety Rules
- Do not introduce new external dependencies unless explicitly approved in the plan.
- Do not change public API signatures unless explicitly approved in the plan.
- Do not change persistence schemas or data formats unless explicitly approved in the plan.
- Guard any retained context (e.g., callbacks, streams) to prevent memory leaks.

---

## Execution Process

### For each step in the plan:

1. **Read the file** before editing it. Never edit a file you haven't read.
2. **Make the change** described in the plan.
3. **Run format and analyze** after each logical unit of work.
4. **Stop and report** if anything unexpected is discovered.

### After all steps:

Run the full verification suite:

```bash
dart format .         # or your project's formatter
dart analyze .        # or your project's linter
flutter test          # or your project's test command
```

Report the result of each command.

---

## Stop Conditions

Stop immediately and report if:

- A required change would affect a file not in the approved scope.
- A required change would affect a protected file.
- A file you need to edit does not exist (and was not in the plan as a new file).
- A symbol you need to use does not exist with the expected signature.
- Test failures appear that are unrelated to this feature.
- Any compilation error cannot be explained by the current feature.

When stopping: do not attempt to fix out-of-scope issues. Report what you found and wait for instructions.

---

## Output Format

After implementation, provide:

1. **Summary of changes** — one bullet per file changed, describing what was done.
2. **Verification results** — output of format, analyze, and test commands.
3. **Unexpected findings** — anything discovered during implementation that was not in the plan.
4. **Next step** — confirm that diff review is the next action.
