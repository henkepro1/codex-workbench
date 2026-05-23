# Workspace Summary

This is a lean solo developer workbench for Codex-assisted projects.

## First Files

- `AGENTS.md` defines operating rules.
- `.ai/index.json` is the compact AI workspace map.
- `.ai/projects/index.json` is the registry of project dossiers.
- `.ai/assets/index.json` tracks generated and reusable assets.
- `docs/workflow.md` contains the human-facing daily workflow.
- `cheatsheets/README.md` explains callable Skills and their impact.

## Separation

- Human-facing documentation: `docs/`
- Human-facing reusable assets: `assets/`
- Human-facing project dossiers: `projects/<slug>/`
- Project-specific AI memory: `projects/<slug>/.ai/`
- Unity engine context: `projects/<slug>/.ai/engine/unity/`
- Workbench-level AI memory, summaries, prompts, generation records, and attempts: `.ai/`

## Token Strategy

Read the indexes first, then inspect only the specific linked docs, manifests, or task notes needed for the current request.

Real Unity source projects usually stay under `D:\GameProjects`.
