# Workflow Codes

Use workflow codes when you want Codex to run a known workbench sequence without restating every Skill, rule file, and tracking step.

Workflow codes must be explicit and start with `@wb:`. Normal wording should not trigger these macros.

Codex may suggest a workflow code when `cheatsheets/recommendations.md` says it would add value, but it should not silently run a macro unless the prompt explicitly includes the code or you confirm the suggestion.

## Quick Reference

| Code | Use For | May Touch `D:\GameProjects` |
| --- | --- | --- |
| `@wb:bugfix-live` | Fix a bug in a linked live project | Yes |
| `@wb:cleanup-live` | Targeted cleanup/refactor without behavior changes | Yes |
| `@wb:artgen-project` | Generate or edit project-matching raster art/assets | No, unless import/wiring is requested |
| `@wb:unity-sync` | Refresh Unity context indexes | No |
| `@wb:unity-mcp-setup` | Install or repair Unity MCP integration | Yes |
| `@wb:scene-prefab-change` | Narrow Unity scene/prefab/settings/editor-state changes | Yes, when safe |
| `@wb:attempt-recovery` | Continue from a failed or stalled attempt | Maybe, depending on requested fix |
| `@wb:retrieval-plan` | Choose grep/index, RAG, or hybrid context retrieval before work | No |
| `@wb:review` | Run a fresh findings-only review after substantive work | No |
| `@wb:rag-setup` | Future explicit setup gate for notes-only RAG infrastructure | No |
| `@wb:session-start` | Start explicit project documentation | No |
| `@wb:session-wrap` | Conclude explicit project documentation | No |
| `@wb:handoff` | Write a manual lightweight handoff note | No |

## `@wb:bugfix-live`

Use when fixing a bug inside a linked live project.

Required fields:

- `Project`
- `Bug`
- `Expected behavior`

Skills and context:

- `$project-dossier`
- live-project rules
- `$unity-context` for Unity projects
- focused source inspection

Required cleanup and tracking:

- preserve gameplay/product outcome unless explicitly changed
- verify the fix or explain why verification could not run
- refresh project index
- refresh Unity context when Unity-relevant
- record a project change

Example:

```text
@wb:bugfix-live
Project: tower-heroes
Bug: Towers sometimes stop targeting after enemies are pooled/reused.
Expected behavior: Towers keep targeting valid enemies exactly as before.
```

## `@wb:cleanup-live`

Use for targeted cleanup or refactor work inside a linked live project.

Required fields:

- `Project`
- `Target`
- `Goal`

Skills and context:

- `$project-dossier`
- live-project rules
- `$unity-context` when Unity-relevant
- focused source inspection

Required cleanup and tracking:

- remove dead or obsolete code in the touched area
- preserve gameplay/product behavior exactly unless explicitly changed
- verify or explain verification limits
- record a project change

Example:

```text
@wb:cleanup-live
Project: brawl-survivors
Target: Enemy spawn wave code
Goal: Remove duplication and dead code.
Constraint: Do not change gameplay behavior.
```

## `@wb:artgen-project`

Use for generating project-matching raster art, concept art, sprites, textures, UI mockups, or asset variants.

Required fields:

- `Project`
- `Asset`
- `Style` or `Intent`

Skills and context:

- `$project-dossier`
- project asset map and asset manifest
- optional project style references
- `$imagegen`

Required cleanup and tracking:

- save accepted project-bound outputs under the project dossier assets area
- register accepted assets in the project asset manifest
- store generation metadata
- do not import or wire the asset into Unity unless explicitly requested

Example:

```text
@wb:artgen-project
Project: brawl-survivors
Asset: Top-down enemy slime concept
Style: Match current game readability, transparent background if useful.
```

## `@wb:unity-sync`

Use for read-only refresh of Unity context.

Required fields:

- `Project`

Skills and context:

- `$project-dossier`
- `$unity-context`

Required cleanup and tracking:

- run the Unity context scan
- refresh the project index
- do not modify Unity project files

Example:

```text
@wb:unity-sync
Project: tower-heroes
```

## `@wb:unity-mcp-setup`

Use to install or repair the CoplayDev Unity MCP setup for a linked Unity project and Codex.

Required fields:

- `Project`

Skills and context:

- `$project-dossier`
- `$unity-context`
- live-project rules

Required cleanup and tracking:

- add `com.coplaydev.unity-mcp` to the Unity package manifest when missing
- configure Codex MCP server entry when missing
- refresh Unity context after package restore/open
- update `.ai/integrations/unity-mcp.json`
- record project changes when external Unity files are edited

Example:

```text
@wb:unity-mcp-setup
Project: tower-heroes
```

## `@wb:scene-prefab-change`

Use for narrow Unity scene, prefab, hierarchy, ScriptableObject, shader, layer, sorting layer, or settings changes.

Required fields:

- `Project`
- `Target asset/object`
- `Requested change`

Skills and context:

- `$project-dossier`
- live-project rules
- `$unity-context`
- focused serialized-file inspection only when safe

Required cleanup and tracking:

- edit YAML only when narrow, inspectable, and safe to verify
- otherwise provide exact Unity Editor steps
- refresh Unity context after Unity-relevant edits
- record a project change

Example:

```text
@wb:scene-prefab-change
Project: tower-heroes
Target asset/object: Main gameplay scene, TowerPlacementController object
Requested change: Add the verified missing serialized reference if it is safe to edit directly.
```

## `@wb:handoff`

Use to create a lightweight handoff note only when you explicitly want one.

Required fields:

- `Summary`
- optional `Project`
- optional `Blocked`
- optional `Next`

Skills and context:

- `$workbench-macro`

Required cleanup and tracking:

- write a timestamped handoff note under `.ai/handoffs/` or `projects/<slug>/.ai/handoffs/`
- update the relevant index
- do not create a full project session

Example:

```text
@wb:handoff
Project: tower-heroes
Summary: Unity MCP setup completed and context refreshed.
Next: Open Unity and confirm the MCP bridge connects.
```

## `@wb:attempt-recovery`

Use when a prior task failed, stalled, or produced useful "do not retry" lessons.

Required fields:

- `Project`
- `Problem`

Skills and context:

- `$project-dossier`
- project attempts
- recent project changes
- relevant rules and Unity context

Required cleanup and tracking:

- avoid previously documented failed paths
- write a new attempt note only if the new attempt fails, stalls, or reveals reusable recovery context

Example:

```text
@wb:attempt-recovery
Project: tower-heroes
Problem: Previous targeting fix caused pooled enemies to be ignored after respawn.
```

## `@wb:retrieval-plan`

Use when you want Codex to plan context retrieval before doing non-trivial work.

Required fields:

- `Project`
- `Task`

Optional fields:

- `Force-Strategy`: `grep_and_index`, `rag_semantic`, or `hybrid`

Skills and context:

- `$retrieval-router`
- `$project-dossier`
- `.ai/retrieval/index.json`
- `projects/<slug>/.ai/scope.json`

Required cleanup and tracking:

- no external project writes
- no routing decision log unless explicitly requested later
- if RAG is unavailable, state the grep/index fallback clearly

Example:

```text
@wb:retrieval-plan
Project: tower-heroes
Task: Refactor enemy spawn flow to support multiple game modes.
```

## `@wb:rag-setup`

Use only when you explicitly want to prepare notes-only RAG infrastructure.

Required fields:

- `Project`

Optional fields:

- `Provider`

Skills and context:

- `$retrieval-router`
- `.ai/retrieval/index.json`

Required cleanup and tracking:

- do not install dependencies, build vectors, or configure MCP unless the setup flow is explicitly confirmed
- do not index source code, generated assets, raw logs, screenshots, Unity `Library`, or build outputs

Example:

```text
@wb:rag-setup
Project: brawl-survivors
```

## `@wb:review`

Use when you want a fresh findings-only review after substantive project work.

Required fields:

- `Project`
- `Scope`: `uncommitted`, `base:<branch>`, `commit:<sha>`, or `files:<paths>`

Optional fields:

- `Focus`: `code`, `architecture`, `unity`, `performance`, or `all`
- `Provider`: `local` by default, or `claude` only when you explicitly want to use the existing Claude.ai subscription lane

Skills and context:

- `$project-dossier`
- live-project rules
- `$unity-context` for Unity projects
- `cheatsheets/reviewer.md`

Required cleanup and tracking:

- report findings only
- do not patch source while reviewing
- write review notes to `projects/<slug>/.ai/reviews/`
- update the project review index
- use local/free Ollama unless the provider is explicitly Claude subscription

Example:

```text
@wb:review
Project: tower-heroes
Scope: uncommitted
Focus: unity
Provider: local
```

## `@wb:session-start`

Use to start explicit project documentation.

Required fields:

- `Project`
- `Topic`
- optional `Initial note`

Skills and context:

- `$project-session`

Required cleanup and tracking:

- create a new timestamped session folder
- update session and project indexes

Example:

```text
@wb:session-start
Project: brawl-survivors
Topic: Enemy spawn refactor investigation
Initial note: Capture findings, decisions, and final result.
```

## `@wb:session-wrap`

Use to conclude explicit project documentation.

Required fields:

- `Project`
- `Summary`

Skills and context:

- `$project-session`

Required cleanup and tracking:

- create a timestamped result note
- close the active session
- update session and project indexes

Example:

```text
@wb:session-wrap
Project: brawl-survivors
Summary: Refactor completed, spawn outcomes preserved, follow-up test pass needed in Unity.
```
