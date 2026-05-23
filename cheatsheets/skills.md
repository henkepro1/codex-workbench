# Skills Cheatsheet

Codex may suggest these Skills when they fit the task, using the hybrid recommendation rules in `recommendations.md`. Suggestions are optional unless the workflow requires the context for correctness.

## `$workbench-macro`

Use when invoking explicit `@wb:` workflow codes such as `@wb:bugfix-live`, `@wb:cleanup-live`, `@wb:artgen-project`, or `@wb:unity-sync`.

Impact: routes to other Skills and workbench scripts based on the macro code. It may touch external projects only for macros that explicitly target live project changes.

It also routes manual utilities such as `@wb:unity-mcp-setup` and `@wb:handoff`.

## `$remember`

Use when you want Codex to remember a persistent preference, correction, or repeated rule.

Impact: writes compact feedback notes under `.ai/feedback/` or `projects/<slug>/.ai/feedback/`. It should not store long chat logs.

## `$project-dossier`

Use when creating, selecting, mapping, refreshing, or loading a project dossier.

Impact: may create or update files under `projects/<slug>/` and `.ai/projects/index.json`. It should not modify external source code unless the user asks for project changes.

Before external project edits, it should load `.ai/rules/index.json` and the selected project's `rules/project-rules.md`.

## `$retrieval-router`

Use when you want Codex to choose or explain the retrieval strategy for a non-trivial task.

Impact: reads `.ai/retrieval/index.json`, project indexes, and `projects/<slug>/.ai/scope.json`; prints a retrieval plan. It does not edit external projects.

## `$project-session`

Use when you explicitly want a documented work session with start/progress/result notes.

Impact: creates a new timestamped session folder under `projects/<slug>/.ai/sessions/` and writes new note files. Normal work should not use this automatically.

## `$unity-context`

Use when scanning, loading, refreshing, or reasoning about Unity engine context such as scenes, prefabs, ScriptableObjects, shaders, layers, build settings, and hierarchy docs.

Impact: reads the Unity project source and writes compact context files under `projects/<slug>/.ai/engine/unity/`. It should not change Unity project files unless paired with an explicit project-edit request.

Before Unity edits, it should load the live-project rules and project overlay, then the Unity context.

## `$imagegen`

Use when generating or editing raster images such as concept art, sprites, mockups, textures, or transparent cutouts.

Impact: may create image files. Accepted project assets should be moved into the relevant project asset folder and registered in the project asset manifest.

## `$skill-creator`

Use when creating or updating reusable Codex Skills.

Impact: may create or update files under `C:\Users\henke\.codex\skills`. Skills should contain reusable workflow behavior, not project state.

## `$openai-docs`

Use when asking how to build with OpenAI APIs/products or when current official OpenAI documentation is needed.

Impact: read-only docs lookup unless the task explicitly asks to update code or configuration.
