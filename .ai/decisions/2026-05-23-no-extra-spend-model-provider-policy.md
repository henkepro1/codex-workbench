---
id: 2026-05-23-no-extra-spend-model-provider-policy
created_at: 2026-05-23T19:35:23+02:00
status: accepted
---

# Decision: No-extra-spend model provider policy

## Decision Made

Use local/free Ollama as the default alternate model lane. Allow Claude Code only when explicitly selected through the existing Claude.ai subscription. Block API keys, cloud model billing, provider credits, new subscriptions, upgrades, and automatic paid fallback.

## Alternatives Considered

Paid model tier registry, automatic model switching, Anthropic Console/API billing, OpenAI API-key billing, and cloud-hosted Ollama models.

## Why This Won

The user wants model choice without extra spend beyond existing subscriptions. A launcher-plus-guard design can enforce provider boundaries while still allowing local review and optional Claude Code review.

## Scope

workbench model providers and review workflow

## Linked Tasks Or Sessions

- .ai/models/index.json,cheatsheets/model-providers.md,cheatsheets/reviewer.md
