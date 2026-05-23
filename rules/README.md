# Live Project Rules

This folder contains the human-facing rules for changing external/live projects that are linked from this workbench.

Use these rules when Codex is asked to edit code, Unity assets, scenes, prefabs, settings, shaders, ScriptableObjects, or other project files outside the workbench, especially under `D:\GameProjects`.

- `live-project-code-rules.md` is the canonical policy for live project code and Unity edits.
- Project-specific overlays live under `projects/<slug>/rules/project-rules.md`.
- Token-friendly rule references live in `.ai/rules/index.json` and each project `.ai/index.json`.

These rules do not replace `AGENTS.md`. `AGENTS.md` controls how this workbench is operated; this folder controls how linked live projects are changed.
