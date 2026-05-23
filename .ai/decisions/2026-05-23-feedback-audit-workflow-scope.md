---
id: 2026-05-23-feedback-audit-workflow-scope
created_at: 2026-05-23T15:08:03+02:00
status: accepted
---

# Decision: Feedback audit workflow scope

## Decision Made

Implement Unity MCP support, feedback memory, decision logs, bootstrap snapshots, package-lock Unity context, Unity verification scripts, project summaries, performance budgets, and manual handoff notes; keep session documentation and handoffs explicit rather than automatic.

## Alternatives Considered

Always-on session tails, git cache indexes, generated dashboards, broad docs generation, and model config changes were deferred because they add noise, stale cache risk, or belong in personal Codex settings.

## Why This Won

The workbench should improve context reuse and recovery while staying lean and deliberate. Durable state belongs in compact indexes and explicit notes, not hidden automatic logs.

## Scope

workbench

## Linked Tasks Or Sessions

- codex-workbench-feedback.md,AGENTS.md,.ai/workflows/index.json,.ai/integrations/unity-mcp.json
