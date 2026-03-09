
1. Introduction — Multi-Agent Engineering

Modern AI tools are powerful, but using a single AI model to design, review, and implement software often leads to:

• architecture drift
• uncontrolled refactoring
• incomplete context understanding
• unnecessary token consumption
• unstable implementation

To solve this problem, we designed a Multi-Agent AI Engineering Workflow.

Instead of relying on one AI system, we orchestrate multiple AI agents, each responsible for a specific stage of the development lifecycle.

This approach allows us to:

• use the strongest AI model for each task
• reduce token consumption for expensive models
• enforce architecture discipline
• maintain full project context
• produce predictable engineering artifacts

⸻

2. Traditional Development Workflow

In real software development, work typically follows this structure:

Epic
  └── Feature
        └── Development Workflow

A typical development workflow includes:
	1.	Requirement discussion
	2.	Architecture design
	3.	Feedback collection
	4.	Specification writing
	5.	Implementation planning
	6.	Implementation
	7.	Code review
	8.	Stabilization
	9.	Testing
	10.	PR review

We converted this human development workflow into an AI engineering pipeline.

⸻

3. Converting Development Workflow into AI Workflow

Instead of engineers performing each stage manually, we map each stage to the best AI agent for that task.

ChatGPT → Architecture & Planning
Gemini  → Red Team Review
Claude  → Implementation & Code Execution

This separation ensures that each AI agent operates within its strongest capability domain.

⸻

4. AI Agent Roles

ChatGPT — Architect

ChatGPT is used for:

• architecture discussions
• feature design
• system impact analysis
• writing feature specifications
• writing implementation plans

ChatGPT acts like a technical architect.

⸻

Gemini — Red Team Reviewer

Gemini performs the role of a review engineer.

Responsibilities:

• reviewing architecture decisions
• identifying risks
• validating scope
• challenging assumptions
• ensuring roadmap alignment

Gemini acts as a red-team reviewer.

⸻

Claude — Execution Engineer

Claude acts as the implementation engineer.

Responsibilities:

• repository grounding
• preflight validation
• code implementation
• diff review
• stabilization
• PR validation

Claude is used specifically for code execution tasks.

⸻

5. AI Feature Development Flow

Every feature follows the same AI workflow.

flowchart TD

A[Architecture Discussion - ChatGPT]
B[Feature Design & Risk Analysis - ChatGPT]
C[Gemini Red Team Review]
D[Revise Architecture if needed]

E[Generate Execution Package]
F[Spec File]
G[Plan File]
H[Implementation Instructions]

I[Claude Preflight Grounding]
J[Claude Implementation]
K[Claude Diff Review]
L[Claude Stabilization]
M[Claude PR Check]

N[Final Review - ChatGPT/Gemini]
O[Update Docs / Roadmap / Test Reports]

A --> B
B --> C
C --> D
D --> E

E --> F
E --> G
E --> H

H --> I
I --> J
J --> K
K --> L
L --> M

M --> N
N --> O


⸻

6. Why This Multi-Agent System Works

This design solves several important problems.

Strongest Model for Each Task

Architecture models are different from coding models.

Planning → ChatGPT
Review   → Gemini
Coding   → Claude


⸻

Token Optimization

Claude tokens are expensive.

By moving:

• architecture
• planning
• review

to ChatGPT and Gemini, we significantly reduce Claude token consumption.

Claude is used only when actual code execution is required.

⸻

Architecture Protection

Architecture decisions are locked before implementation begins.

Claude cannot drift architecture because the spec and plan define the allowed scope.

⸻

7. The AI Brain — Solving the Context Problem

One of the biggest challenges when using AI agents is ensuring that they understand the entire repository.

We solved this by creating a repository AI brain.

docs/AI_REPO_BRAIN.md

This document contains:

• architecture overview
• subsystem responsibilities
• repository structure
• invariants
• SDK design rules
• execution constraints

It allows AI models to understand the full system architecture without scanning the entire repository.

⸻

8. AI Project Context

File:

docs/AI_PROJECT_CONTEXT.md

Purpose:

Describe the purpose of the project.

Includes:

• SDK purpose
• package structure
• dependency direction
• system boundaries

This ensures AI agents understand what the project is trying to build.

⸻

9. AI Workflow Definition

File:

docs/AI_WORKFLOW.md

Defines the rules of AI execution.

Includes:

• agent roles
• workflow stages
• execution constraints
• safety invariants
• command templates

This document acts as the operating manual for AI agents.

⸻

10. Session Bootstrap System

AI models require proper session initialization.

We built a bootstrap system to provide agents with repository context.

This includes:

AI_REPO_BRAIN
AI_PROJECT_CONTEXT
AI_WORKFLOW
ROADMAP
CURRENT_STAGE
KNOWN_ISSUES
TEST_REPORT

This ensures AI agents always operate with correct repository awareness.

⸻

11. Execution Package Generation

After architecture is approved, we generate an execution package.

This package contains all files required for implementation.

.ai/specs/
.ai/plans/
.ai/commands/

Execution artifacts include:

• Feature Spec
• Implementation Plan
• Implementation Request
• Stabilization Request
• PR Check Request

⸻

12. Spec File

Example:

.ai/specs/stage_8_feature_x.md

Contains:

• feature description
• scope boundaries
• invariants
• files to modify
• acceptance criteria

⸻

13. Implementation Plan

Example:

.ai/plans/stage_8_feature_x.md

Contains:

• step-by-step implementation
• exact file changes
• test strategy
• validation strategy

⸻

14. Template System

Execution files are not written manually.

Instead, they are generated from templates.

Templates ensure:

• consistent structure
• predictable AI behavior
• scope enforcement

Templates include:

.ai/templates/

Examples:

• plan_template.md
• spec_template.md
• stabilize_template.md
• diff_review_template.md

⸻

15. AI File Index

To improve AI navigation of the repository we created an AI file index.

Purpose:

• reduce file discovery time
• improve repository navigation
• avoid scanning entire codebase

⸻

16. AI Symbol Index

The AI symbol index provides a map of:

• key classes
• critical services
• entry points
• core subsystems

This allows AI agents to quickly understand where important logic lives.

⸻

17. Claude Execution Pipeline

Once the execution package exists, Claude performs the implementation.

Claude follows this pipeline:

flowchart TD

A[Claude Preflight Grounding]
B[Claude Implementation]
C[Claude Diff Review]
D[Claude Stabilization]
E[Claude PR Check]

A --> B
B --> C
C --> D
D --> E


⸻

Preflight

Validates:

• roadmap alignment
• file scope
• invariants
• dependency impact

⸻

Implementation

Claude performs code changes based strictly on the approved plan.

⸻

Diff Review

Claude validates:

• scope correctness
• unintended changes
• architectural impact

⸻

Stabilization

Ensures:

• tests pass
• code compiles
• edge cases are handled

⸻

PR Check

Final validation:

• code quality
• documentation updates
• roadmap alignment

⸻

18. AI Execution CLI

To simplify interactions with AI agents we built a CLI tool.

scripts/ai-run.sh

Installed as:

reviewloop-ai

This tool prepares context bundles for each agent.

Example commands:

reviewloop-ai --chatgpt --full
reviewloop-ai --gemini --full
reviewloop-ai --claude --full


⸻

19. Benefits of This System

Architecture Safety

Implementation cannot drift from architecture.

⸻

Reduced AI Token Cost

Expensive models are used only when necessary.

⸻

Predictable Engineering Process

Every feature follows the same lifecycle.

⸻

Multi-AI Validation

Different AI models review the same feature.

⸻

Platform Engineering Ready

The system works particularly well for:

• SDKs
• infrastructure platforms
• frameworks

⸻

20. Future Evolution

Potential improvements:

• automatic feature scaffolding
• AI-generated test cases
• CI integration with AI validation
• architecture diagram generation

