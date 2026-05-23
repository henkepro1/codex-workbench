# Retrieval Strategies

Use retrieval routing when the task is large, vague, architectural, cross-system, or about prior work. Do not use it for trivial questions, exact symbols, known files, compile errors, or single-file edits.

## Strategies

### `grep_and_index`

Default strategy.

Use for source code, exact names, known files, stack traces, compile errors, Unity scripts, and focused implementation work.

Impact: read-only context loading through `rg`, project indexes, Unity context indexes, and focused file reads. Low cost.

### `rag_semantic`

Use for fuzzy memory and history retrieval only after RAG setup exists.

Good for questions like:

- "Have we tried this before?"
- "What did we decide about targeting?"
- "Find notes about failed spawn refactors."
- "Was there a handoff about this system?"

Impact: searches AI/workbench memory such as attempts, decisions, feedback, sessions, changes, summaries, handoffs, and project maps. It should not index source code.

Current status: setup required. Until `@wb:rag-setup` is explicitly invoked later, this degrades to grep/index over `.ai/` and project maps.

### `hybrid`

Use for broad refactors, architectural questions, cross-cutting work, and unclear scope.

Default sequence:

1. Use project indexes, scope, and maps.
2. Use RAG for memory/history only if configured.
3. Use grep/index for source-code details.

Impact: medium to high context cost, read-only until paired with a later edit workflow.

## Workflow Codes

### `@wb:retrieval-plan`

Use this when you want Codex to plan how it will retrieve context before doing work.

Required fields:

- `Project`
- `Task`

Optional:

- `Force-Strategy`: `grep_and_index`, `rag_semantic`, or `hybrid`

Example:

```text
@wb:retrieval-plan
Project: tower-heroes
Task: Refactor enemy spawn flow to support multiple game modes.
```

### `@wb:rag-setup`

Use this only when you explicitly want to set up RAG infrastructure.

Impact: future setup path for notes-only vector search. It should not index source code, generated assets, logs, screenshots, Unity `Library`, or build outputs.

## Overrides

- "use grep only" forces `grep_and_index`.
- "use RAG" requests `rag_semantic`; if RAG is not configured, Codex must say so and use fallback unless setup is explicitly requested.
- "plan retrieval first" asks for a retrieval planning pass before work.

## Failure Modes

- Over-triggering: do not gate for small obvious tasks.
- Fake RAG: do not imply semantic search is available until setup exists.
- Source-code RAG: do not use embeddings for code search in this workbench; grep/index wins there.
- Stale scope: refresh project indexes and scope when project size/context changes.
