# AI Workspace

This folder is for workbench-level Codex-facing memory. It keeps global indexes, project registry data, generated context, asset manifests, attempt notes, prompt records, and compact summaries separate from human-facing project files.

Start with `index.json`, then `.ai/projects/index.json`, then the specific project dossier's `.ai/index.json`. For Unity projects, continue to `projects/<slug>/.ai/engine/unity/index.json`.

Real game project sources usually live under `D:\GameProjects`; this workbench stores dossier metadata and context, not copied source.

Keep bulky raw files in ignored folders such as `.ai/tmp/`, `.ai/raw/`, `.ai/logs/`, `.ai/screenshots/`, and `.ai/exports/`.

Use `.ai/feedback/` for persistent user preferences and corrections, `.ai/decisions/` for durable decisions, `.ai/workflows/` for macro-code indexes, `.ai/recommendations/` for optional workflow suggestion routing, and `.ai/handoffs/` for manual lightweight handoff notes.
