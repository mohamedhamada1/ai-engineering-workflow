# AI Brain — Context System Architecture

The AI Brain is the **central context layer** of the AI Engineering Workflow.

It is a set of curated, living documents that give AI agents enough information to reason accurately about a software project — without scanning every source file.

---

## The Problem the AI Brain Solves

AI agents working on large codebases face a fundamental challenge: **context is expensive and unreliable**.

If an agent reads raw source files directly:
- It may read stale, partial, or irrelevant files.
- It may hallucinate relationships that do not exist.
- It has no understanding of what is stable vs. in-flux.
- It has no understanding of what is intentionally protected.

The AI Brain solves this by providing **curated, structured, human-maintained summaries** that agents are trained to trust over raw file scanning.

---

## Brain File Definitions

### `docs/AI_REPO_BRAIN.md` — Architecture Overview

The primary architectural reference for the codebase.

Contains:
- Project purpose and core philosophy
- Repository structure with module descriptions
- Key data models and their relationships
- Critical invariants (things that must never change without approval)
- Public API surface
- Persistence and upload behavior
- Known architectural constraints

**When to update:** When architecture changes, new modules are added, or invariants are modified.
**When NOT to update:** For minor refactors, file renames, or implementation details.

---

### `docs/AI_PROJECT_CONTEXT.md` — Product and Package Context

High-level product and team context.

Contains:
- What the product does and who uses it
- Package structure and ownership
- Technology stack
- External dependencies and integrations
- Target platforms

**When to update:** When product purpose changes, packages are added/removed, or major dependencies change.

---

### `docs/AI_WORKFLOW.md` — Process Rules

The engineering process rules specific to this repository.

Contains:
- AI agent workflow rules
- Commit discipline
- Branching conventions
- Command execution safety rules
- Definition of done

**When to update:** When team process or workflow rules change.

---

### `ROADMAP.md` — Canonical Feature Roadmap

The single source of truth for what features exist, what is planned, and what is complete.

Contains:
- Phases and stages
- Stage names, descriptions, and status
- Completion notes per stage

**Source of truth for:** roadmap status.
**When to update:** When a stage is completed or a new stage is planned.

---

### `CURRENT_STAGE.md` — Active Execution State

Describes exactly what is being worked on right now.

Contains:
- Active feature name and status
- Workflow position (which steps are complete)
- Current goal
- Core invariants for this stage
- Files in approved scope
- Protected files (must not be touched)
- Last reviewer notes
- Next action

**Source of truth for:** what Claude is allowed to edit.
**When to update:** At each workflow stage transition.

---

### `KNOWN_ISSUES.md` — Risks and Deferred Items

Tracks active risks, deferred items, and resolved issues.

Contains:
- Active risks with descriptions and mitigations
- Deferred items that were intentionally out of scope
- Closed (resolved) items

**When to update:** When a new blocker is found, a risk is deferred, or a risk is resolved.

---

### `TEST_REPORT.md` — Latest Test Verification State

Tracks the most recent test run results.

Contains:
- Feature being tested
- Commands run and their outcomes
- Known failures and their status
- Date of last run

**Source of truth for:** test state.
**When to update:** After every test run.

---

## Supplementary Brain Files

These files are optional but recommended for larger projects.

### `.ai/AI_FILE_INDEX.md` — Source File Map

Maps source file paths to their purpose.

Example:
```
lib/src/capture/screenshot_service.dart   — Captures PNG frames during session recording
lib/src/models/session.dart               — Core session data model
lib/src/upload/upload_worker.dart         — Background queue processor for uploads
```

Agents use this to navigate to the right file without scanning directories.

---

### `.ai/AI_SYMBOL_INDEX.md` — Public Symbol Index

Lists public API symbols with their signatures and locations.

Example:
```
FeatureSDK.init(config: FeatureConfig) → void
  File: lib/src/sdk/feature_sdk.dart:42
  Description: Initializes the SDK. Must be called before any other API.

SessionRecorder.start() → void
  File: lib/src/recording/session_recorder.dart:87
  Description: Begins a new recording session.
```

Agents use this to find the right symbols without reading implementation files.

---

### `.ai/AI_FLOW_INDEX.md` — Data Flow Index

Documents key data flows through the system.

Example:
```
Recording Flow:
  SessionRecorder.start()
    → CaptureRoot (widget tree)
    → ScreenshotService.capture()
    → FrameQueue.enqueue()
    → UploadWorker.process()
    → Uploader.upload()
```

Agents use this to understand impact radius before making changes.

---

## Source of Truth Hierarchy

When brain files appear to disagree:

```
1. ROADMAP.md           → defines roadmap status
2. CURRENT_STAGE.md     → defines active scope and approved file list
3. Approved spec/plan   → defines exact feature scope
4. TEST_REPORT.md       → defines verification state
5. AI_REPO_BRAIN.md     → defines architecture and invariants
```

If an agent detects a contradiction between these files, it should **stop and report** the contradiction rather than making an assumption.

---

## Brain Maintenance Rules

### Keep Brain Files Lean

Brain files should be **summaries**, not complete source listings. If a brain file grows beyond 300 lines, consider splitting it.

### Update Brain Files After Each Stage

At the end of every feature lifecycle:
- Update `ROADMAP.md` to mark the stage complete.
- Update `CURRENT_STAGE.md` to reflect the next stage.
- Update `TEST_REPORT.md` with the latest test results.
- Update `KNOWN_ISSUES.md` to close resolved risks and add new ones.

### Protect Invariants in the Brain

The `AI_REPO_BRAIN.md` should explicitly list invariants — constraints that must never be violated:

Example:
```
## Core Invariants
- Session schema must not change without a migration plan
- Public API surface must not change without a major version bump
- All screenshots must be masked before encoding
- StreamSubscriptions must be cancelled in dispose()
```

Agents are instructed to treat invariant violations as blockers.

---

## How Agents Use the Brain

### ChatGPT (Architect)

Reads: `AI_REPO_BRAIN.md`, `AI_PROJECT_CONTEXT.md`, `AI_WORKFLOW.md`, `ROADMAP.md`, `CURRENT_STAGE.md`

Uses the brain to:
- Understand what already exists before designing new features
- Avoid designing features that conflict with existing architecture
- Identify invariants that must be preserved

### Gemini (Reviewer)

Reads: All ChatGPT files + `KNOWN_ISSUES.md` + spec + plan

Uses the brain to:
- Verify the spec/plan does not violate architecture invariants
- Check for known risks that may be triggered
- Confirm roadmap alignment

### Claude (Executor)

Reads: All files + `TEST_REPORT.md` + commands

Uses the brain to:
- Ground itself against the real repository before touching any file
- Verify the approved file list against what actually exists
- Understand protected files that must not be modified
- Detect out-of-scope changes in its own diff
