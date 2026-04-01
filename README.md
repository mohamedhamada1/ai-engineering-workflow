# AI Engineering Workflow v2

A production-hardened, multi-agent AI engineering system for real software development.

Orchestrate **ChatGPT** (Architect), **Gemini** (Gatekeeper), and **Claude** (Executor) in a disciplined, stage-driven development workflow with automated conformance verification, artifact versioning, and operational intelligence.

**Battle-tested:** 76 stages executed, 2,000+ tests generated, 6,400+ lines of workflow automation across a production marketplace platform.

---

## Quick Start

```bash
# 1. Clone into your project
git clone https://github.com/mohamedhamada1/ai-engineering-workflow.git .ai-engine
cp -r .ai-engine/scripts ./scripts
cp -r .ai-engine/.ai ./.ai
cp -r .ai-engine/.claude ./.claude
cp .ai-engine/flow_commands.md ./

# 2. Install (one-time — sets up alias + autocompletion)
./scripts/ai install
source ~/.zshrc

# 3. Start your first stage
ai gpt                        # copy context → paste to ChatGPT for spec
pbpaste > tmp/chatgpt.md      # save ChatGPT output
ai start 1.0                  # import + validate + branch
ai exec                       # execute full pipeline
ai done 1.0                   # complete stage (merge to main)
```

---

## What's Included

### 20 Automation Scripts (6,400+ lines)

| Command | What It Does |
|---------|-------------|
| `ai start <id>` | Import artifacts + validate spec + create branch |
| `ai exec` | Full pipeline: preflight → implement → post-checks → commit |
| `ai done <id>` | Complete stage: update roadmap + merge to main |
| `ai gpt` | Generate ChatGPT context bundle (~69KB, auto-clipboard) |
| `ai gemini` | Generate Gemini context bundle (auto-clipboard) |
| `ai check` | Conformance verification (nested route detection) |
| `ai review` | Post-review bundle → versioned folder |
| `ai sync` | Reality sync snapshot |
| `ai dashboard` | Visual stage overview with progress bar |
| `ai status` | Current stage + git status |
| `ai import` | Parse ChatGPT output → 4 artifact files (auto-fixes headings) |
| `ai install` | One-time setup: alias + Zsh autocompletion + tool check |

Run `ai help` for the full command list with tab-autocomplete.

### 4 Claude Code Hooks

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `session-start.sh` | Session start/resume | Auto-loads stage context, recent commits, spec summary |
| `session-save.sh` | Session end | Saves session log to `.ai/sessions/` |
| `post-compact.sh` | Context compaction | Reloads stage context after compaction |
| `pre-commit-check.sh` | Before git commit | Scans for secrets (API keys, tokens, credentials) |

### Artifact Templates & Commands

- 7 templates (spec, plan, preflight, diff review, stabilize, PR check, task checklist)
- 6 command files (plan feature, implement, stabilize, PR check, preflight, diff review)
- Project config template (`.ai/config/project.conf`)

---

## Multi-Agent Architecture

```
┌─────────────────────────────────────────────────────┐
│                  ENGINEER (You)                      │
│          Define goal → Review → Merge                │
├──────────┬──────────┬──────────┬────────────────────┤
│ ChatGPT  │  Gemini  │  Claude  │     Automated      │
│ Architect│Gatekeeper│ Executor │    Verification     │
│          │          │          │                      │
│ • Spec   │ • Review │ • Preflight  │ • Conformance  │
│ • Plan   │ • GO/NO-GO│• Implement  │ • Reality sync │
│ • Review │ • Edge   │ • Diff review│ • Secret scan  │
│          │   cases  │ • Stabilize  │ • Post-review  │
└──────────┴──────────┴──────────┴────────────────────┘
```

| Agent | Role | Strength |
|-------|------|----------|
| **ChatGPT** | Architect / Planner | Long-context reasoning, spec design, verification checklists |
| **Gemini** | Red Team Reviewer | Challenge assumptions, detect missing edge cases, GO/NO-GO |
| **Claude** | Repository Executor | Grounded implementation, diff safety, conformance verification |

---

## Stage Lifecycle

Every feature follows this automated pipeline:

```
1. ai gpt              → ChatGPT creates spec + plan + review + implementation
2. ai gemini            → Gemini red-team reviews (GO / NO-GO)
3. ai start <id>        → Import artifacts + validate + branch
4. ai exec              → Claude executes:
                            ├── Preflight Clarification Check
                            ├── Implementation
                            ├── Diff Review + Spec Checklist Conformance
                            ├── Stabilization
                            ├── Post-review bundle (v{N}/ folder)
                            ├── Conformance check (joins v{N}/)
                            ├── Reality sync (joins v{N}/)
                            └── Auto-commit + push
5. ai review            → Share bundle with ChatGPT/Gemini
6. ai done <id>         → Merge to main, update roadmap
```

### Pre-Start Validation

`ai start` validates artifacts **before branching**:
- Spec has `## Verification Checklist` → FAIL if missing
- Spec has `Preflight Clarification Intent` → WARN if missing
- Review doesn't say NO-GO → FAIL if rejected
- Use `--force` to override

### Versioned Review Artifacts

```
.ai/reviews/stage_1_0/
├── v1/
│   ├── post_review.md       ← first review cycle
│   ├── conformance.md
│   └── reality_sync.md
├── v2/
│   ├── post_review.md       ← after revision
│   ├── conformance.md
│   └── reality_sync.md
└── stage_1_0_name.review.md  ← Gemini review (imported)
```

---

## Conformance Engine

The `ai check` command verifies spec-to-code alignment:

- **Structural gates:** Spec has Verification Checklist, implementation has Preflight Check
- **File detection:** Referenced files/classes exist in repo
- **Endpoint detection:** Routes found including Ktor nested routes (`route("/parent") { post("/child") }`)
- **Test detection:** Test files exist for referenced test classes
- **Scope check:** Changes are within expected package boundaries
- **Protected files:** Engine-level + project-level protected paths enforced

Failures are categorized: `STRUCTURE` / `CHECKLIST` / `SCOPE` / `TEST`

---

## Project Configuration

### `.ai/config/project.conf`

```bash
# Protected paths (project-specific)
PROTECTED_PATHS=packages/shared_contracts/src/main

# Build system override (auto-detected if not set)
# BUILD_SYSTEM=gradle

# Context files to exclude from bundles
# CONTEXT_EXCLUDES=BUSINESS_PLAN.md
```

### `.ai/stage_package_map.sh`

```bash
stage_package_map() {
  case "$1" in
    "1.0") echo "packages/core" ;;
    "2.*") echo "packages/feature_x" ;;
    *) echo "" ;;
  esac
}
```

---

## Repository Structure

```
your-project/
├── scripts/
│   ├── ai                          # Short command wrapper (25 commands)
│   ├── _ai                         # Zsh autocompletion
│   ├── ai-run.sh                   # Main orchestrator
│   ├── ai-common.sh                # Shared library (700+ lines)
│   ├── ai-install.sh               # One-time device setup
│   ├── ai-stage-start.sh           # Start stage (import + validate + branch)
│   ├── ai-stage-execute.sh         # Full pipeline execution
│   ├── ai-stage-complete.sh        # Complete stage (merge to main)
│   ├── ai-stage-revise.sh          # Address reviewer feedback
│   ├── ai-stage-post-review.sh     # Generate review bundle
│   ├── ai-stage-status.sh          # Status + dashboard
│   ├── ai-verify-stage.sh          # Build + test + artifact checks
│   ├── ai-verify-conformance.sh    # Spec-to-code conformance
│   ├── ai-import-chatgpt.sh        # Parse ChatGPT → 4 artifact files
│   ├── ai-generate-reality-sync.sh # Post-stage reality snapshot
│   ├── ai-review-bundle.sh         # State snapshot
│   ├── ai-diff-evidence.sh         # Changes + protected file check
│   ├── ai-update-context.sh        # Context refresh generation
│   └── ai-engine-selftest.sh       # 26-checkpoint self-test
│
├── .ai/
│   ├── config/
│   │   └── project.conf            # Project-specific configuration
│   ├── stage_package_map.sh        # Stage → package mapping
│   ├── templates/                   # 7 artifact templates
│   ├── commands/                    # 6 command files
│   ├── specs/                       # Stage specifications
│   ├── plans/                       # Implementation plans
│   ├── reviews/                     # Review artifacts (versioned v{N}/ folders)
│   ├── implementations/            # Implementation requests
│   └── exports/                     # Generated context bundles (gitignored)
│
├── .claude/
│   ├── settings.json               # Claude Code settings + hooks
│   └── hooks/
│       ├── session-start.sh         # Auto-load stage context
│       ├── session-save.sh          # Save session log
│       ├── post-compact.sh          # Reload after compaction
│       └── pre-commit-check.sh      # Secret detection
│
├── docs/
│   ├── AI_WORKFLOW.md              # Process rules
│   ├── AI_AGENT_ROLES.md           # Agent responsibilities
│   ├── AI_REPO_BRAIN.md            # Architecture overview (you create)
│   └── AI_PROJECT_CONTEXT.md       # Product context (you create)
│
├── ROADMAP.md                       # Stage roadmap
├── CURRENT_STAGE.md                 # Active stage
├── TEST_REPORT.md                   # Test state
├── KNOWN_ISSUES.md                  # Risks + deferred items
└── flow_commands.md                 # Full command reference
```

---

## How to Adopt

### New Project

```bash
# Clone the engine
git clone https://github.com/mohamedhamada1/ai-engineering-workflow.git

# Copy into your project
cp -r ai-engineering-workflow/scripts your-project/scripts
cp -r ai-engineering-workflow/.ai your-project/.ai
cp -r ai-engineering-workflow/.claude your-project/.claude
cp ai-engineering-workflow/flow_commands.md your-project/

# Install
cd your-project
./scripts/ai install
source ~/.zshrc

# Create your project docs
# Edit: docs/AI_REPO_BRAIN.md (your architecture)
# Edit: docs/AI_PROJECT_CONTEXT.md (your product)
# Edit: ROADMAP.md (your stages)
# Edit: .ai/config/project.conf (your protected paths)
# Edit: .ai/stage_package_map.sh (your stage → package mapping)
```

### Existing Project

Same steps — the engine doesn't modify your source code. It adds workflow automation alongside your existing structure.

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Multi-agent chain of command** | ChatGPT → Gemini → Claude with role separation |
| **Pre-start validation** | Validates spec quality before branching |
| **Post-exec auto-chain** | Review + conformance + sync + auto-commit after implementation |
| **Nested route detection** | Conformance finds Ktor/Express nested routes |
| **Spec heading auto-fix** | Import auto-adds `## ` prefix to bare headings |
| **Versioned review folders** | v1/, v2/, v3/ per review cycle |
| **Visual dashboard** | Progress bar + stage counts + status icons |
| **Secret detection** | Pre-commit hook scans for API keys, tokens, credentials |
| **Token optimization** | Autocompact at 50% context usage |
| **Zsh autocompletion** | Tab-complete all 25 commands |
| **One-command install** | `ai install` sets up everything |

---

## Comparison

| Capability | This Engine | spec-kit (GitHub) | everything-claude-code |
|---|---|---|---|
| Multi-agent orchestration | 4 agents, role-separated | Single agent | Single agent |
| Spec enforcement | Verification Checklist + Conformance | Constitution + clarify | Rules files |
| Pre-start validation | Validates before branching | None | None |
| Post-exec auto-chain | Review + conformance + sync + commit | Manual checklist | Manual loops |
| Artifact versioning | v1/v2/v3 folders | Flat | None |
| Secret detection | Pre-commit hook | None | AgentShield |
| CLI shortcuts | 25 commands + tab-complete | 2 commands | Slash commands |

---

## License

MIT
