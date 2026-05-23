# Impact Guide

## Read-Only

- Inspecting `.ai/index.json`, `.ai/projects/index.json`, project indexes, and cheatsheets.
- Reading `.ai/rules/index.json`, `rules/live-project-code-rules.md`, and project rule overlays.
- Running context snapshots.
- Running retrieval planning with `@wb:retrieval-plan` or `scripts/plan-retrieval.ps1`.
- Reading Unity context files already stored in the workbench.
- Reading feedback, decisions, handoffs, and integration status indexes.

## Workbench-Only Changes

- Creating or refreshing project dossiers.
- Running `scan-unity-context.ps1`.
- Creating session notes with `$project-session`.
- Recording changes with `record-project-change.ps1`.
- Updating cheatsheets or workflow docs.
- Updating retrieval policy and project scope files.
- Updating live-project rule references and workbench-side project rule overlays.
- Writing feedback memory, decision logs, bootstrap summaries, and manual handoff notes.

## May Touch `D:\GameProjects`

- Explicit requests to change real project code.
- Explicit, targeted Unity scene, prefab, ScriptableObject, shader, layer, or settings changes.
- `@wb:unity-mcp-setup`, which may update Unity package manifests and Codex MCP config.

When Unity serialized-file editing is uncertain, Codex should provide Unity Editor steps instead of editing project YAML.

Before touching external project files, Codex must load the live-project rules and preserve existing gameplay outcomes unless the requested change explicitly changes them.

## Token Cost

- Cheapest: read project `.ai/index.json` and Unity `index.json`.
- Moderate: read focused map files and specific Unity context JSON.
- Expensive: scan Unity `Assets/` or inspect many `.unity`/`.prefab` files.
- Very expensive: deep scene/prefab YAML analysis. Do this only when needed.
- RAG setup is optional and explicit. Until configured, semantic retrieval falls back to grep/index over `.ai/` and project maps.
