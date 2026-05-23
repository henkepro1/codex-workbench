---
id: 2026-05-23-retrieval-router-uses-rag-setup-gate
created_at: 2026-05-23T15:44:55+02:00
status: accepted
---

# Decision: Retrieval router uses RAG setup gate

## Decision Made

Use grep/index as the default and source-code retrieval strategy. Add retrieval routing and project scope now. Keep RAG as an explicit setup gate for AI/workbench memory only, not source code.

## Alternatives Considered

Full RAG immediately was rejected because the current notes corpus is small and source-code work is better served by grep/index. A fake RAG recommendation without a setup path was rejected because it creates ceremony without capability.

## Why This Won

The workbench needs flexible retrieval choices without installing vector infrastructure before there is enough notes/history corpus to justify it.

## Scope

workbench retrieval

## Linked Tasks Or Sessions

- .ai/retrieval/index.json,scripts/plan-retrieval.ps1,cheatsheets/retrieval-strategies.md
