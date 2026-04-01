# Command: Plan Feature

**Agent:** ChatGPT (Architect)
**Stage:** Architecture + Spec + Plan
**Triggered by:** Engineer providing a feature goal

---

## Your Task

You are acting as the Architect for this project.

The engineer has provided a feature goal. Your job is to:

1. Discuss the architecture for this feature.
2. Write a complete feature spec using the spec template.
3. Write a complete implementation plan using the plan template.

---

## Step 1: Architecture Discussion

Before writing any artifacts, reason through the following:

**What problem does this feature solve?**
State the user-facing or engineering problem in one or two sentences.

**Where does it belong in the existing architecture?**
Reference the AI Brain (`docs/AI_REPO_BRAIN.md`) to identify:
- Which modules are affected
- Which data models are involved
- Which public APIs change (if any)

**What is the minimal viable implementation?**
Define the smallest correct implementation. Prefer small and correct over large and speculative.

**What invariants must be preserved?**
List any system invariants (from `docs/AI_REPO_BRAIN.md`) that this feature must not violate.

**Are there any known risks?**
Reference `KNOWN_ISSUES.md` for any relevant open risks.

---

## Step 2: Write the Spec

Use the template in `.ai/templates/spec_template.md`.

Save the output as: `.ai/specs/<stage_id>_<feature_name>.md`

The spec must include:
- Feature name and stage ID
- Problem statement
- Acceptance criteria (each one must be testable)
- In-scope items (explicit list)
- Out-of-scope items (explicit list)
- Files to create (with purpose)
- Files to modify (with description of change)
- Protected files (must not be touched)
- Core invariants
- **Preflight Clarification Intent** (mandatory — see below)
- **Verification Checklist** (mandatory — see below)
- Open questions

---

## Step 3: Write the Implementation Plan

Use the template in `.ai/templates/plan_template.md`.

Save the output as: `.ai/plans/<stage_id>_<feature_name>.plan.md`

The plan must include:
- Ordered implementation steps
- For each step: file path, what to add or change, why
- Test plan: what to add or update
- Verification commands

**Plan Quality Rules:**
- Steps must be specific enough for Claude to execute without architectural decisions.
- Each step must reference a file path and a description of the change.
- Do not write pseudo-code in the plan — write intent and structure.
- Do not include steps that are outside the spec's scope.

---

## Step 3.5: Required Spec Sections

You must include these two mandatory sections in every spec:

### Preflight Clarification Intent

```markdown
## Preflight Clarification Intent
- Executor should ask questions if ambiguity affects correctness, safety, architecture, or protected boundaries.
- Maximum grouped questions: [number, default 5]
- If unanswered, executor may proceed only with explicit assumptions when risk is acceptable.
```

This tells the executor (Claude) when and how to ask questions before coding.

### Verification Checklist

```markdown
## Verification Checklist

### Required Artifacts
- [ ] [file/endpoint/component expected]

### Core Behavior
- [ ] [functional requirement]

### Safety / Invariants
- [ ] [constraint that must hold]

### Tests
- [ ] [test coverage expectation]
```

This becomes the conformance target. Every item must be machine-verifiable (greppable file names, endpoint paths, test class names).

---

## Step 4: Self-Check

Before handing off to Gemini, verify:

- [ ] The spec's acceptance criteria are all testable.
- [ ] The file list matches the spec's scope.
- [ ] No protected files are in the implementation file list.
- [ ] The plan's steps map one-to-one with the spec's scope.
- [ ] No invariants are violated by the proposed design.
- [ ] Out-of-scope items are explicitly listed.
- [ ] **Preflight Clarification Intent section exists.**
- [ ] **Verification Checklist section exists with items in all 4 categories.**
- [ ] **Every checklist item maps to at least one plan step.**

---

## Output Format

Provide both artifacts in full:

```
### SPEC
<full spec content>

### PLAN
<full plan content>
```

Then summarize in one paragraph: what was decided architecturally and why.
