# AI Repo Brain

Replace this file with your project's architectural overview.

---

## How to Use This File

`AI_REPO_BRAIN.md` is the primary architectural reference for AI agents.

It gives agents enough context to reason about the codebase without reading every source file.

All AI agents read this file. Keep it accurate, lean, and up to date.

**Update when:** Architecture changes, new modules added, invariants modified.
**Do not update for:** Minor refactors, file renames, implementation details.

---

## Template

```markdown
## Project Purpose

[One sentence: what the project does and why it exists.]

---

## Repository Structure

[Describe the top-level directory structure with one-line descriptions.]

---

## Key Modules

[Describe each major module: what it does, what it owns, what it depends on.]

---

## Core Data Models

[List the primary data models with field descriptions and relationships.]

---

## Core Invariants

[List invariants that must never be violated without explicit architectural approval.]

Example invariants:
- Session schema must not change without a migration plan
- Public API must not change without a major version bump
- All user data must be masked before encoding
- StreamSubscriptions must be cancelled in dispose()
- No new external dependencies without explicit approval

---

## Public API Surface

[Document the exported public API symbols.]

---

## Data Flow

[Describe the primary data flows through the system.]

---

## Architecture Constraints

[List any hard architectural constraints.]
```

---

## Example

### Project Purpose

Sample SDK is a mobile SDK for capturing structured product feedback from running applications.

---

### Repository Structure

```
packages/
  sample_sdk/                    Core SDK package
    lib/
      sample_sdk.dart            Public API barrel
      src/
        sdk/                     SDK entry point and config
        capture/                 Screenshot and frame capture
        recording/               Session recorder and event pipeline
        models/                  Data models
        analysis/                Session analysis and signal extraction
        artifacts/               Artifact generators (bug reports, test cases)
        queue/                   Local disk persistence
        upload/                  Upload interface and worker
        ui/                      Overlay and feedback UI
        mask/                    Privacy masking system

example/                         Demo application
```

---

### Core Invariants

- Session schema must not change without a migration plan
- Screenshots must be masked before encoding — never after
- Public API must not change without version bump
- No external media processing libraries
- StreamSubscriptions must be cancelled in dispose()
- No retained BuildContext across async gaps without mounted guard
