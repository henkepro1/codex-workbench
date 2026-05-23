# Workflow Cheatsheet

-- Shortcuts --
Use @wb:bugfix-live for a bundled live-project bugfix workflow.
Use @wb:cleanup-live for targeted live-project cleanup/refactor.
Use @wb:artgen-project for project-matching raster art generation.
Use @wb:unity-mcp-setup to install or repair Unity MCP integration.
Use @wb:retrieval-plan to choose grep/index, RAG, or hybrid retrieval before non-trivial work.
Use @wb:review to run a findings-only review after substantive work.
Use @wb:rag-setup only when explicitly preparing notes-only RAG infrastructure.
Use @wb:handoff to create a lightweight handoff note.
Use scripts\start-local-codex.ps1 to launch a local/free Codex + Ollama session.
Use scripts\start-claude-code.ps1 only when explicitly using the existing Claude.ai subscription.
Use $project-dossier to create a dossier for <project name> linked to <source path>.
Use $unity-context to refresh the Unity context for <project-slug>.
For <project-slug>, change <specific behavior>. Update the workbench tracking after the edit.
For <project-slug>, update <scene/prefab/hierarchy detail>. If direct YAML editing is risky, give Unity Editor steps instead.
Use $project-session to start a documented session for <project-slug> about <topic>.

See `workflow-codes.md` for explicit `@wb:` macro codes.

## Create A Project Dossier

Prompt:

```text
Use $project-dossier to create a dossier for <project name> linked to <source path>.
```

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-project.ps1 -Title "<Project Name>" -SourcePath "<source path>"
```

## Refresh Unity Context

Prompt:

```text
Use $unity-context to refresh the Unity context for <project-slug>.
```

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\scan-unity-context.ps1 -Slug "<project-slug>"
```

## Plan Retrieval

Prompt:

```text
@wb:retrieval-plan
Project: <project-slug>
Task: <task to plan retrieval for>
```

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\plan-retrieval.ps1 -Slug "<project-slug>" -Task "<task to plan retrieval for>"
```

Use this for broad, fuzzy, architectural, history-oriented, or unclear tasks. Skip it for exact files, symbols, stack traces, compile errors, and obvious one-file work.

## Start A Local/Free Model Session

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-local-codex.ps1 -Slug "<project-slug>"
```

This uses Codex with local Ollama and refuses API-key or cloud-billing routes.

## Start A Claude Subscription Session

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-claude-code.ps1 -Model sonnet -Slug "<project-slug>"
```

Use this only when explicitly choosing the existing Claude.ai subscription lane. It requires `~/.claude/settings.json` to set `forceLoginMethod` to `claudeai`.

## Run A Findings-Only Review

Prompt:

```text
@wb:review
Project: <project-slug>
Scope: uncommitted
Focus: all
Provider: local
```

Default command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-local-review.ps1 -Slug "<project-slug>" -Scope uncommitted
```

Optional Claude subscription review:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-claude-review.ps1 -Slug "<project-slug>" -Scope uncommitted -Model sonnet
```

Reviews report findings only and write to `projects/<project-slug>/.ai/reviews/`.

## Request A Project Code Change

Prompt:

```text
For <project-slug>, change <specific behavior>. Update the workbench tracking after the edit.
```

Codex should read `.ai/rules/index.json`, `rules/live-project-code-rules.md`, and `projects/<project-slug>/rules/project-rules.md` before touching the external source project.

Expected tracking:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-project-change.ps1 -Slug "<project-slug>" -Category code -Summary "<summary>" -Verification "<checks>" -RulesChecked "rules/live-project-code-rules.md","projects/<project-slug>/rules/project-rules.md" -MechanicsPreserved "<how behavior stayed the same>" -EditorChangesRequired "<none or exact editor steps>"
```

## Request A Unity Scene Or Prefab Change

Prompt:

```text
For <project-slug>, update <scene/prefab/hierarchy detail>. If direct YAML editing is risky, give Unity Editor steps instead.
```

Expected tracking: refresh Unity context and record the change if files were edited.

Direct YAML edits should happen only when the change is narrow and inspectable. Otherwise Codex should list exact Unity Editor steps.

## Start And Conclude A Documented Session

Start:

```text
Use $project-session to start a documented session for <project-slug> about <topic>.
```

Conclude:

```text
Use $project-session to conclude the current session for <project-slug> with result and next steps.
```
