# AI Project Context

Replace this file with your project's product and package context.

---

## How to Use This File

`AI_PROJECT_CONTEXT.md` gives AI agents the high-level product and team context they need to make architectural decisions that align with the project's purpose.

ChatGPT reads this during architecture and spec creation.
Gemini reads this during spec/plan review.

---

## Template

```markdown
## Project Purpose

[One to three paragraphs describing what the project does, who uses it, and what problem it solves.]

## Target Platforms

[List target platforms: iOS, Android, Web, macOS, etc.]

## Technology Stack

[Describe primary languages, frameworks, and tooling.]

## Package Structure

[Describe the top-level packages or modules and their responsibilities.]

## Key External Dependencies

[List significant external dependencies and why they are used.]

## Team Context

[Optional: describe team size, release cadence, deployment environment.]
```

---

## Example

### Project Purpose

Sample SDK is a mobile SDK that allows product teams to capture structured feedback directly from mobile applications. It records screenshots, user actions, and session timelines, then converts them into structured engineering artifacts.

Target use cases: QA testing, design review, business feedback, crash reporting.

### Target Platforms

- iOS (Flutter)
- Android (Flutter)

### Technology Stack

- Dart / Flutter
- Firebase (Firestore + Storage) for upload
- Local disk queue for offline persistence

### Package Structure

- `packages/sample_sdk/` — Core SDK
- `packages/sample_sdk_firebase/` — Firebase upload plugin
- `packages/sample_sdk_devtools/` — Developer tooling UI
- `example/` — Demo application

### Key External Dependencies

- `firebase_core`, `cloud_firestore`, `firebase_storage` — backend upload
- No heavy media processing dependencies (enforced by architecture rules)
