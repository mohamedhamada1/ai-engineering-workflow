# AI Workflow Commands

This file defines the standard execution flow for stage-based AI work in this repository.

> **Plans guide execution order, but specs define required behavior, clarification policy, and conformance targets.**

---

## Quick Reference — `ai` Shortcuts

All commands use the `ai` shortcut. Run `ai help` for the full list.

```
  LIFECYCLE                              VERIFICATION
    ai start <id>    Start new stage       ai check       Conformance check
    ai exec          Execute pipeline      ai verify      Quick verify
    ai done <id>     Complete stage        ai verify full Build + test + verify
    ai status        Current status        ai selftest    Engine self-test
    ai dashboard     All stages overview   ai revise "msg" Address feedback

  CONTEXT BUNDLES                        REVIEW & SYNC
    ai gpt           ChatGPT (compact)     ai review      Post-review bundle
    ai gpt full      ChatGPT (full)        ai sync        Reality sync
    ai gemini        Gemini bundle         ai diff        Changes + protected check
    ai claude        Claude bundle         ai bundle      State snapshot

  IMPORT                                 SETUP & OTHER
    ai import f.md   Import from file      ai install     One-time device setup
    ai import --paste From clipboard       ai context     Context refresh
                                           ai preflight   Claude preflight only
                                           ai implement   Claude implement only
```

### Setup (one-time)

Run the install script on any new device:

```bash
./scripts/ai install
source ~/.zshrc
```

Or manually add to `~/.zshrc`:

```bash
alias ai='./scripts/ai'
fpath+=("/Users/adres/Documents/GitHub/supply_orchestration_sdk/scripts")
autoload -Uz compinit && compinit
```

Then `source ~/.zshrc`. Tab-completion works after setup.

> **Note:** The `ai` shortcut wraps `./scripts/ai-run.sh`. All long-form commands still work.

---

## Standard Hardened Stage Flow

All new stage work must follow this sequence:

```
1. ChatGPT planning          →  ai gpt + paste to ChatGPT
2. Gemini red-team review     →  ai gemini + paste to Gemini
3. Stage start                →  ai start <id>
4. Claude execution           →  ai exec
5. Conformance verification   →  ai check
6. Reality sync               →  ai sync
7. External review            →  ai review + paste to ChatGPT/Gemini
8. Revision if needed         →  ai revise "feedback"
9. Stage completion           →  ai done <id>
```

Visual flow:

```
Spec (+ Preflight Clarification Intent + Verification Checklist)
→ Gemini review
→ Preflight Clarification Check
→ Implementation
→ Conformance Verification
→ Diff Review with Spec Checklist Conformance
→ Stabilization
→ Reality Sync
→ External Review
→ Complete Stage
```

---

## Required Artifact Sections

### Every spec must include
- `## Preflight Clarification Intent`
- `## Verification Checklist`

### Every implementation artifact must include
- `## Preflight Clarification Check`

### Every diff review must include
- `## Spec Checklist Conformance`

If any of these sections are missing, the stage is not compliant.

---

## Verification Checklist Rules

Every checklist item must be machine-verifiable.

Allowed checklist item types:
- artifact/file exists
- endpoint/route/contract exists
- invariant/safety rule enforced
- test exists
- migration/data rule enforced

Do not use vague checklist items such as:
- "implementation is correct"
- "logic is robust"
- "handled properly"

Checklist tiers:

### Mandatory (blocks stage completion if missing)

#### Required Artifacts
- [ ] ...

#### Core Behavior
- [ ] ...

#### Safety / Invariants
- [ ] ...

#### Tests
- [ ] ...

### Optional / Quality (does not block, but should be addressed)
- [ ] ...

---

## Preflight Clarification Rules

Claude must emit a Preflight Clarification Check before coding.

Allowed statuses:
- `READY`
- `READY_WITH_ASSUMPTIONS`
- `NEEDS_CLARIFICATION`
- `BLOCKED`

Questions are allowed only when ambiguity materially affects:
- correctness
- safety
- architecture
- public contracts
- migrations
- test expectations
- protected boundaries

Rules:
- ask only high-impact questions
- group questions together
- maximum 5 questions
- if safe, proceed with explicit assumptions

Required format:

```md
## Preflight Clarification Check
Status: READY | READY_WITH_ASSUMPTIONS | NEEDS_CLARIFICATION | BLOCKED

### Questions
1. ...
2. ...

### Assumptions
- ...
- ...

### Risk If Assumptions Are Wrong
- ...
```

---

## Command Flow — Step by Step

### 1) ChatGPT Planning

Generate the context bundle and copy to clipboard:

```bash
ai gpt                   # compact (~69KB) — fits paste limit
ai gpt full              # full (~153KB) — use as file upload
```

The file is saved to `.ai/exports/chatgpt_context.md` and auto-copied to clipboard.

Paste into ChatGPT with instruction:

> Plan stage [STAGE_ID] using the spec template exactly as shown.
> The spec must include:
> - Preflight Clarification Intent
> - Verification Checklist
>
> All 4 checklist categories must be present:
> - Required Artifacts
> - Core Behavior
> - Safety / Invariants
> - Tests
>
> Every checklist item must be machine-verifiable.

Save ChatGPT output:

```bash
pbpaste > tmp/chatgpt.md
```

---

### 2) Gemini Red-Team Review

Generate Gemini context bundle:

```bash
ai gemini                # full context → file + clipboard
```

The file is saved to `.ai/exports/gemini_context.md` and auto-copied to clipboard.

Paste into Gemini along with the ChatGPT spec/plan.

Prompt Gemini to review:

> Review this spec and plan.
>
> Audit specifically:
> 1. Is the Verification Checklist complete?
> 2. Are there missing edge cases, invariants, or test expectations?
> 3. Are all checklist items machine-verifiable?
> 4. GO / NO-GO / GO WITH CHANGES

If Gemini returns GO WITH CHANGES, update the spec in ChatGPT before continuing.

---

### 3) Start the Stage

```bash
ai start <stage-id>
```

This:
- auto-imports `tmp/chatgpt.md` into `.ai/` artifact files
- **auto-fixes spec headings** (`Verification Checklist` → `## Verification Checklist`)
- **validates artifacts before branching:**
  - spec has `## Verification Checklist` → FAIL if missing
  - spec has `Preflight Clarification Intent` → WARN if missing
  - checklist has enough items (3+) → WARN if too few
  - review doesn't say NO-GO → FAIL if rejected
- creates the feature branch
- commits the planning artifacts
- pushes to remote

Options:
```bash
ai start <id> --no-push        # skip push
ai start <id> --import file.md # import from specific file
ai start <id> --paste          # import from clipboard
ai start <id> --force          # skip validation errors
```

---

### 4) Claude Execution

Run the full executor pipeline:

```bash
ai exec
```

Claude will:
1. Emit Preflight Clarification Check
2. Run preflight grounding (GO / NO-GO)
3. Implement against the plan
4. Run diff review with Spec Checklist Conformance
5. Stabilize (fix issues found)
6. Commit + push

**After implementation, auto-runs post-checks:**
1. `ai review` — generates post-review bundle (creates `v{N}/` folder)
2. `ai check` — conformance verification (joins same `v{N}/` folder)
3. `ai sync` — reality sync snapshot (joins same `v{N}/` folder)
4. Auto-commits all post-check artifacts to branch
5. Auto-pushes to remote

Resume if interrupted:
```bash
ai exec --resume          # pick up from last checkpoint
ai exec --from 4          # restart from step 4
```

---

### 5) Conformance Verification

```bash
ai check
```

This verifies:
- spec contains `## Verification Checklist`
- implementation contains `## Preflight Clarification Check`
- review contains Spec Checklist Conformance
- expected files/endpoints/tests are present where detectable

Failures are categorized: STRUCTURE / CHECKLIST / SCOPE / TEST.

Output saved to `.ai/reviews/stage_X_Y/v{N}/conformance.md`.

---

### 6) Reality Sync

```bash
ai sync                   # snapshot what actually changed
ai sync --append          # also append to architect context
```

Output saved to `.ai/reviews/stage_X_Y/v{N}/reality_sync.md`.

---

### 7) External Review

Generate and share the post-review bundle:

```bash
ai review                 # generates bundle → .ai/reviews/stage_X_Y/v{N}/post_review.md
```

Copy the file path and upload to ChatGPT/Gemini, or:

```bash
cat .ai/reviews/stage_*/v*/post_review.md | pbcopy
```

Prompt for review:

> Review this implementation.
>
> Check the Spec Checklist Conformance section carefully:
> - Are all mandatory checklist items satisfied?
> - Is there evidence for each satisfied item?
> - GO / NO-GO / GO WITH CHANGES

If changes are required:

```bash
ai revise "reviewer feedback here"
```

Then re-generate the bundle and re-review.

---

### 8) Complete the Stage

```bash
ai done <stage-id>
```

This:
- updates ROADMAP, CURRENT_STAGE, REPO_BRAIN
- commits and pushes
- merges to main
- cleans up feature branch

Preview mode:
```bash
ai done <id> --dry-run     # preview only, no changes
```

---

## Review Artifact Versioning

Review artifacts use versioned folders inside each stage directory:

```
.ai/reviews/stage_7_15/
├── v1/
│   ├── post_review.md
│   ├── conformance.md
│   └── reality_sync.md
├── v2/
│   ├── post_review.md      ← re-run after revision
│   ├── conformance.md
│   └── reality_sync.md
└── stage_7_15_set.review.md  ← imported Gemini review (stays at stage level)
```

- `ai review` creates a new `v{N+1}/` folder
- `ai check` and `ai sync` join the latest `v{N}/` folder
- Each re-review cycle gets its own version for audit trail

---

## Enforcement Gates

The following are mandatory gates. The conformance script checks these automatically:

```bash
# In spec artifact (.ai/specs/stage_*.md)
grep "^## Verification Checklist" "$SPEC_FILE"

# In implementation artifact (.ai/implementations/stage_*.implementation.md)
grep "^## Preflight Clarification Check" "$IMPL_FILE"

# In review artifact (.ai/reviews/*.review.md)
grep "Spec Checklist Conformance" "$REVIEW_FILE"
```

If any gate fails, the stage is non-compliant.

Run the engine self-test to validate all wiring:
```bash
ai selftest
```

---

## Context Bundles

| Agent | Short | Long | Output File | Includes |
|-------|-------|------|-------------|----------|
| **ChatGPT** | `ai gpt` | `--chatgpt --compact` | `.ai/exports/chatgpt_context.md` | PROJECT_CONTEXT, REPO_BRAIN (trimmed), ROADMAP (Phase 8 + progress), AI_WORKFLOW, CURRENT_STAGE, spec template, latest artifacts |
| **ChatGPT** | `ai gpt full` | `--chatgpt --full` | `.ai/exports/chatgpt_context.md` | Full: all context files, full ROADMAP, full REPO_BRAIN |
| **Gemini** | `ai gemini` | `--gemini --full` | `.ai/exports/gemini_context.md` | PROJECT_CONTEXT, REPO_BRAIN, AI_WORKFLOW, ROADMAP, CURRENT_STAGE, KNOWN_ISSUES, spec template, task checklist |
| **Claude** | `ai claude` | `--claude --full` | stdout | Full context + all command files |

All bundle commands auto-copy to clipboard and save to `.ai/exports/`.

---

## Command Reference — Full

### Stage Lifecycle

| Short | Long | Description |
|-------|------|-------------|
| `ai start <id>` | `--stage-start <id>` | Start new stage (import + validate + branch + commit) |
| `ai start <id> --force` | `--stage-start <id> --force` | Start even if validation fails |
| `ai exec` | `--stage-execute` | Full pipeline (preflight → implement → post-checks → commit) |
| `ai exec --resume` | `--stage-execute --resume` | Resume from last checkpoint |
| `ai exec --from N` | `--stage-execute --from N` | Restart from step N |
| `ai done <id>` | `--complete-stage <id>` | Complete stage (merge to main) |
| `ai done <id> --dry-run` | `--complete-stage <id> --dry-run` | Preview only |
| `ai status` | `--stage-status` | Current stage + git status |
| `ai dashboard` | `--stage-status --all` | Visual overview of ALL stages with progress bar |
| `ai revise "msg"` | `--stage-revise "msg"` | Address reviewer feedback |
| `ai install` | `ai-install.sh` | One-time device setup (alias + completion + tool check) |

### Verification

| Short | Long | Description |
|-------|------|-------------|
| `ai check` | `--verify-conformance` | Spec-to-code conformance check (nested route detection) |
| `ai verify` | `--verify-stage --quick` | Artifacts + protected files |
| `ai verify full` | `--verify-stage --full` | Build + test + artifacts |
| `ai selftest` | `ai-engine-selftest.sh` | Engine self-test (26 checkpoints) |

### Review & Sync

| Short | Long | Description |
|-------|------|-------------|
| `ai review` | `--post-review` | Generate post-review bundle |
| `ai sync` | `--reality-sync` | Reality sync snapshot |
| `ai diff` | `--diff-evidence` | All changes + protected file check |
| `ai bundle` | `--review-bundle` | Snapshot current state |

### Import & Context

| Short | Long | Description |
|-------|------|-------------|
| `ai import file.md` | `--import-chatgpt file.md` | Import ChatGPT output (auto-fixes spec headings) |
| `ai import --paste` | `--import-chatgpt --paste` | Import from clipboard (auto-fixes spec headings) |
| `ai context` | `--update-context` | Generate/apply context refresh |

### Claude Manual Steps

| Short | Long | Description |
|-------|------|-------------|
| `ai preflight` | `--claude-preflight` | Preflight grounding only |
| `ai implement` | `--claude-implement` | Implementation only |
| `ai stabilize` | `--claude-stabilize` | Stabilization only |

---

## Typical Workflow (Copy-Paste Ready)

```bash
# 1. Plan with ChatGPT
ai gpt                              # copy context to clipboard
# → paste to ChatGPT, get spec/plan/review/impl
pbpaste > tmp/chatgpt.md            # save ChatGPT output

# 2. Review with Gemini
ai gemini                           # copy context to clipboard
# → paste to Gemini with spec, get GO/NO-GO

# 3. Start stage
ai start 8.0e                       # branch + import + commit

# 4. Execute
ai exec                             # full pipeline

# 5. Verify + review
ai check                            # conformance check
ai sync                             # reality sync
ai review                           # post-review bundle
# → paste bundle to ChatGPT/Gemini for approval

# 6. Complete
ai done 8.0e                        # merge to main
```

---

## Scripts Inventory

| Script | Purpose |
|--------|---------|
| `ai` | Short command wrapper with Zsh autocompletion |
| `_ai` | Zsh completion definitions |
| `ai-common.sh` | Shared library (helpers, validation, protected files, build detection, versioning) |
| `ai-run.sh` | Main orchestrator — routes all commands |
| `ai-install.sh` | One-time device setup (alias, completion, tool check, self-test) |
| `ai-stage-start.sh` | Begin new stage (import + validate artifacts + branch + commit) |
| `ai-stage-execute.sh` | Full pipeline: preflight → implement → post-checks (review+conformance+sync) → commit+push |
| `ai-stage-revise.sh` | Address reviewer feedback → re-verify → commit+push → new bundle |
| `ai-stage-complete.sh` | Mark stage done (ROADMAP, REPO_BRAIN, commit, push, merge to main) |
| `ai-stage-post-review.sh` | Generate package-scoped review bundle → `.ai/reviews/stage_X_Y/v{N}/post_review.md` |
| `ai-stage-status.sh` | Quick stage status + visual dashboard (`--all`) |
| `ai-verify-stage.sh` | Build + test + artifact + protected file checks |
| `ai-verify-conformance.sh` | Spec-to-code conformance (nested Ktor route detection) → `.ai/reviews/stage_X_Y/v{N}/conformance.md` |
| `ai-diff-evidence.sh` | All changes + protected files + dependency changes |
| `ai-review-bundle.sh` | Snapshot repo state → `.ai/reviews/stage_X_Y/v{N}/review_bundle.txt` |
| `ai-import-chatgpt.sh` | Parse ChatGPT output into .ai/ files (auto-fixes spec headings) |
| `ai-update-context.sh` | Generate/apply context refresh → `.ai/context_updates/v{N}/context_refresh.md` |
| `ai-generate-reality-sync.sh` | Post-stage reality snapshot → `.ai/reviews/stage_X_Y/v{N}/reality_sync.md` |
| `ai-engine-selftest.sh` | Workflow engine self-test (26 checkpoints across templates, commands, docs, config) |

---

## Terminology

| Term | Definition |
|------|-----------|
| **Verification Checklist** | Machine-verifiable stage requirements attached to the spec |
| **Preflight Clarification Check** | Executor readiness check before coding |
| **Spec Checklist Conformance** | Review section that compares implementation against the spec checklist |
| **Reality Sync** | Post-implementation alignment check against actual repo state |
| **Mandatory item** | Checklist item that blocks stage completion if missing |
| **Optional item** | Checklist item that should be addressed but does not block |
| **Version folder** | `v1/`, `v2/`, etc. — incremental review artifact directories per review cycle |

---

## Extraction Guidance

This repository currently contains a repo-native hardened workflow.

Later extraction to the AI-workflow-engine repo should move only generic workflow machinery:
- templates
- generic commands
- preflight rules
- conformance rules
- generic verification scripts

Do not move project-specific rules such as:
- package ownership tiers
- protected paths
- domain invariants
- project architecture constraints
- stage-specific mappings

See `.ai/config/project.conf` for the current project-specific configuration that would remain in the project repo after extraction.
