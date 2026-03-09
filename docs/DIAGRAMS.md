# AI Engineering Workflow — Diagrams

---

## 1. Feature Development Pipeline

End-to-end lifecycle of a feature from goal to merged PR.

```mermaid
flowchart TD
    A([Engineer: Feature Goal]) --> B[ChatGPT: Architecture Discussion]
    B --> C[ChatGPT: Write Spec + Plan]
    C --> D{Gemini: Review}
    D -->|NO-GO| C
    D -->|GO| E[Claude: Preflight Grounding]
    E --> F{Preflight Result}
    F -->|NO-GO| G([Stop: Engineer Resolves])
    F -->|GO| H[Claude: Implementation]
    H --> I[Claude: Diff Review]
    I --> J{Diff Safe?}
    J -->|Issues Found| K([Stop: Fix + Re-review])
    J -->|Clean| L[Claude: Stabilization]
    L --> M[Claude: PR Check]
    M --> N{PR Passes?}
    N -->|Fail| O([Stop: Fix Violations])
    N -->|Pass| P[ChatGPT: Final Review]
    P --> Q([Engineer: Merge + Update Brain Files])
```

---

## 2. AI Brain Architecture

How the AI Brain documents feed each agent in the workflow.

```mermaid
flowchart LR
    subgraph Brain ["AI Brain (Living Documents)"]
        RB[AI_REPO_BRAIN.md]
        PC[AI_PROJECT_CONTEXT.md]
        WF[AI_WORKFLOW.md]
        RM[ROADMAP.md]
        CS[CURRENT_STAGE.md]
        KI[KNOWN_ISSUES.md]
        TR[TEST_REPORT.md]
        SP[spec.md]
        PL[plan.md]
    end

    subgraph Agents ["AI Agents"]
        GPT[ChatGPT\nArchitect]
        GEM[Gemini\nReviewer]
        CL[Claude\nExecutor]
    end

    RB --> GPT
    PC --> GPT
    WF --> GPT
    RM --> GPT
    CS --> GPT

    RB --> GEM
    PC --> GEM
    WF --> GEM
    RM --> GEM
    CS --> GEM
    KI --> GEM
    SP --> GEM
    PL --> GEM

    RB --> CL
    WF --> CL
    RM --> CL
    CS --> CL
    KI --> CL
    TR --> CL
    SP --> CL
    PL --> CL
```

---

## 3. Multi-Agent Responsibility Model

How responsibilities are divided across agents.

```mermaid
flowchart TD
    subgraph ChatGPT ["ChatGPT — Architect"]
        A1[Feature Architecture]
        A2[Spec Writing]
        A3[Plan Writing]
        A4[Final Review]
    end

    subgraph Gemini ["Gemini — Gatekeeper"]
        B1[Spec Review]
        B2[Plan Review]
        B3[Risk Detection]
        B4[Invariant Check]
        B5[GO / NO-GO Decision]
    end

    subgraph Claude ["Claude — Executor"]
        C1[Preflight Grounding]
        C2[Implementation]
        C3[Diff Review]
        C4[Stabilization]
        C5[PR Check]
    end

    subgraph Engineer ["Engineer"]
        E1[Goal Definition]
        E2[Merge Decision]
        E3[Brain File Updates]
    end

    E1 --> ChatGPT
    ChatGPT --> Gemini
    Gemini -->|Approved| Claude
    Claude --> E2
    E2 --> E3
```

---

## 4. AI Engineering Operating System

High-level view of the full system including context, tooling, and execution layers.

```mermaid
flowchart TD
    subgraph Context ["AI Brain Layer (Context)"]
        B1[AI_REPO_BRAIN.md\nArchitecture + Invariants]
        B2[CURRENT_STAGE.md\nActive Scope]
        B3[ROADMAP.md\nFeature Roadmap]
        B4[KNOWN_ISSUES.md\nRisks + Deferrals]
        B5[TEST_REPORT.md\nVerification State]
    end

    subgraph Tooling ["CLI Layer (Tooling)"]
        T1[ai-run.sh\nContext Bundle Generator]
        T2[--chatgpt bundle]
        T3[--gemini bundle]
        T4[--claude pipeline]
    end

    subgraph Commands ["Command Layer (Execution)"]
        CMD1[01_plan_feature.md]
        CMD2[02_implement_feature.md]
        CMD3[03_stabilize_feature.md]
        CMD4[04_pr_check.md]
        CMD5[05_preflight_grounding.md]
        CMD6[06_diff_review.md]
    end

    subgraph Agents ["Agent Layer"]
        A1[ChatGPT]
        A2[Gemini]
        A3[Claude]
    end

    Context --> Tooling
    Tooling --> T2 --> A1
    Tooling --> T3 --> A2
    Tooling --> T4 --> A3
    Commands --> A3
    CMD1 --> A1
```

---

## 5. Preflight Grounding Decision Tree

How Claude decides GO or NO-GO during preflight.

```mermaid
flowchart TD
    A[Load spec + plan] --> B[Read approved file list]
    B --> C{All files exist\nin repo?}
    C -->|No| NOGOA([NO-GO: Missing files])
    C -->|Yes| D{Protected files\nin scope list?}
    D -->|Yes| NOGOB([NO-GO: Protected file violation])
    D -->|No| E{Symbol names\nmatch actual code?}
    E -->|No| NOGOC([NO-GO: Symbol mismatch])
    E -->|Yes| F{Pre-existing test\nfailures?}
    F -->|Yes| NOGOD([NO-GO: Pre-existing failures])
    F -->|No| GO([GO: Begin implementation])
```

---

## 6. CLI Context Bundle Flow

How `ai-run.sh` assembles and delivers context bundles.

```mermaid
sequenceDiagram
    participant Eng as Engineer
    participant CLI as ai-run.sh
    participant FS as File System
    participant Agent as AI Agent

    Eng->>CLI: ./ai-run.sh --claude-preflight
    CLI->>FS: Read AI_REPO_BRAIN.md
    CLI->>FS: Read AI_WORKFLOW.md
    CLI->>FS: Read ROADMAP.md
    CLI->>FS: Read CURRENT_STAGE.md
    CLI->>FS: Read TEST_REPORT.md
    CLI->>FS: Read KNOWN_ISSUES.md
    CLI->>FS: Read latest spec + plan
    CLI->>FS: Read 05_preflight_grounding.md
    CLI->>Agent: Pipe assembled context
    Agent->>Agent: Execute preflight grounding
    Agent-->>Eng: GO / NO-GO report
```
