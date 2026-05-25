# Codex Instructions

This workspace is a professional solo developer workbench for tracking and building many projects. Keep human-facing project material clean, and use root/project `.ai/` folders for structured AI context, indexes, generation records, prompt results, session notes, and failed-attempt memory.

<!-- @section: session-startup -->
## Session Startup

- Read this file first.
- Read `.ai/index.json` early in a new session before broad repo searches.
- Read `.ai/feedback/index.json` for persistent cross-session preferences before broad work.
- Read `.ai/projects/index.json` before working on a project dossier.
- Read `.env` early when it exists. Treat `WORKBENCH_ACTIVE_PROJECT` and `WORKBENCH_ACTIVE_SOURCE_PATH` as the default project for ambiguous project work.
- Read `.ai/retrieval/index.json` before non-trivial retrieval planning or `@wb:retrieval-plan`.
- Read `.ai/models/index.json` before suggesting or launching any alternate model/provider workflow.
- For project work, read `projects/<slug>/.ai/index.json` before scanning that project's files or external source path.
- If the user names a different project than `.env`, the named project overrides the active `.env` project for that request.
- For project work, read `projects/<slug>/.ai/feedback/index.json` when it exists.
- Use `.ai/assets/index.json` before scanning `assets/` for generated or reusable assets.
- Prefer targeted searches with `rg` and small file reads over loading large folders.
- Treat `docs/` as curated human-facing documentation and `.ai/` as compact AI workspace memory.

<!-- @section: workspace-map -->
## Workspace Map

- `src/` contains application or script source code.
- `tests/` contains tests and verification helpers.
- `docs/` contains polished human-readable notes, workflows, decisions, and project writeups.
- `assets/` contains useful generated or curated assets that a human may want to inspect or reuse.
- `cheatsheets/` contains human-facing quick references for Skills, workflows, and impact.
- `rules/` contains human-facing rules for editing external/live projects.
- `scripts/` contains local automation for this workbench.
- `projects/` contains project dossiers. Each dossier has its own human map and project-local `.ai/` memory.
- `.ai/` contains workbench-level indexes, task context, generation metadata, prompt results, summaries, and attempt notes.

<!-- @section: project-dossiers -->
## Project Dossiers

- Use `projects/<slug>/` as the standard project container.
- Treat `projects/<slug>/README.md` as the human entry point for that project.
- Treat `projects/<slug>/map/` as the human-readable project map. Split map content into small files instead of one large document.
- Treat `projects/<slug>/.ai/index.json` as the first project-specific AI context file.
- Keep project-specific assets, generations, prompts, sessions, summaries, and attempts under `projects/<slug>/.ai/`.
- A project dossier may point to an external source path. Do not copy a large codebase into this workbench unless the user explicitly asks.
- After changing project code, assets, prompts, docs, or session state, refresh the relevant project index with `scripts/update-project-index.ps1`.
- Real game projects usually live under `D:\GameProjects`; use that as the default external source root unless the user gives another path.

<!-- @section: external-project-edits -->
## External Project Edits

- Code edits in external source projects are allowed when the user explicitly asks for project changes.
- Before changing external project code, read `.ai/rules/index.json`, `rules/live-project-code-rules.md`, and the selected project's `projects/<slug>/rules/project-rules.md`.
- Follow live-project coding rules exactly: fail fast, do not hide errors, preserve existing gameplay outcomes unless the user explicitly requests a mechanic change, reuse existing systems, avoid god classes, and verify dependencies before editing.
- For Unity projects, scene, prefab, hierarchy, ScriptableObject, shader, layer, and ProjectSettings edits are allowed only when the change is narrow, inspectable, and Codex is confident in the file format impact.
- For Unity project edits, read the selected project's Unity context before touching scripts, scenes, prefabs, ScriptableObjects, shaders, layers, sorting layers, settings, or editor-state files.
- If a Unity editor-state change is risky to perform through serialized files, give exact Unity Editor steps instead of editing YAML blindly.
- After external project edits, update the workbench tracking: run `scripts/update-project-index.ps1`, refresh Unity context when relevant, and create a compact change record with `scripts/record-project-change.ps1` including rule/audit fields when useful.
- After external project edits, check whether any edited file matches a system slug in `projects/<slug>/.ai/systems/index.json` (compare against `key_file_patterns`). If yes, run `@wb:update-system <slug>` for each affected system.
- Do not store bulky copied source from `D:\GameProjects` inside this workbench unless the user explicitly asks.

<!-- @section: system-knowledge-base -->
## System Knowledge Base

- Read `projects/<slug>/.ai/systems/index.json` before debugging a named system, starting multi-system investigation, or beginning a session that names a known system.
- Use the `tag_index` in `systems/index.json` to map a symptom or topic to a system slug (e.g., "stuck" → elevation-ramp, enemy-movement). This is a cheap single-file read.
- Read the relevant `systems/{slug}.md` for the full context: how the system works, key classes, integration points, debug guide, and known issues.
- When reading `systems/index.json`, also read `sessions/index.json` to surface any past sessions whose tags overlap — load past effort context before starting new work.
- After external project edits that touch a system's `key_file_patterns`, update that system's doc using `@wb:update-system <slug>`. This is part of the standard post-edit tracking step for `@wb:bugfix-live` and `@wb:cleanup-live`.
- Run `@wb:map-systems` when a system is new, heavily refactored, or the doc is clearly stale.
- Do not rewrite a system doc from memory; always re-read the relevant source files first. Summaries must stay accurate.
- Do not create system docs for trivial helpers or utilities — only for systems that have their own service/manager class and meaningful interaction surface.

<!-- @section: unity-context -->
## Unity Context

- For Unity dossiers, read `projects/<slug>/.ai/engine/unity/index.json` before scanning Unity assets.
- Unity context files should stay token-friendly: prefer versions, package summaries, scene lists, build scenes, prefab paths, ScriptableObject types, shader paths, layers, sorting layers, settings references, and hierarchy-doc links.
- Unity package context should include both `Packages/manifest.json` and `Packages/packages-lock.json` summaries when available.
- Refresh Unity context with `scripts/scan-unity-context.ps1` after Unity-relevant code, scene, prefab, ScriptableObject, shader, layer, or settings changes.
- Do not deep-read all scene/prefab YAML unless the task requires it.

<!-- @section: ai-workspace-rules -->
## AI Workspace Rules

- Keep root `.ai/index.json` compact and current when workbench structure, active tasks, important docs, or recent attempts change.
- Keep `.ai/workflows/index.json` current when workflow macro codes are added, removed, or changed.
- Keep `.ai/feedback/index.json` current when persistent user preferences or corrections are added.
- Keep `.ai/decisions/index.json` current when architectural or workflow decisions are recorded.
- Keep `.ai/retrieval/index.json` current when retrieval strategies, RAG status, or routing heuristics change.
- Keep `.ai/models/index.json` current when allowed model providers, launchers, or no-extra-spend guardrails change.
- Keep `.ai/projects/index.json` current when project dossiers are created, renamed, paused, completed, or linked to source paths.
- Keep `.ai/assets/index.json` current when generating, accepting, modifying, moving, or removing useful assets.
- Store final or reusable files in `assets/`; store metadata about those files in `.ai/`.
- Store generation records in `.ai/generations/` when an asset, mockup, image, dataset, or prompt-driven artifact is created.
- Store prompt experiments and notable prompt outputs in `.ai/prompts/` when they are likely to be reused.
- Store task notes and handoff context in `.ai/tasks/` when work spans more than one short turn.
- Store manual lightweight handoffs under `.ai/handoffs/` or `projects/<slug>/.ai/handoffs/` only when explicitly requested.
- Write an attempt note in `.ai/attempts/` when a task fails, stalls, is abandoned, or has a useful "do not retry this" lesson.
- Keep `.ai/` concise. Summaries should explain what matters and where to look next, not duplicate full logs.
- Do not promote `.ai/` scratch content into `docs/` unless it has been cleaned up for human reading.

<!-- @section: project-sessions -->
## Project Sessions

- Read `projects/<slug>/.ai/sessions/index.json` at session start when the task names a system or symptom. The `tag_index` shows past sessions by topic — load relevant ones before beginning work.
- When creating a new session, add a `tags` array to `session.json` that reflects the systems and symptoms involved. Update `sessions/index.json` to register the new session and its tags.
- Do not create detailed session documentation during normal work unless the user explicitly invokes the `project-session` workflow or asks to start/document/conclude a project session.
- When session documentation is active, create a new session folder under `projects/<slug>/.ai/sessions/YYYY-MM-DD-HHMM-topic/`.
- Create a new timestamped file for every session input, progress note, and result note.
- Do not append all progress into one long markdown file.
- Only JSON indexes such as `session.json`, project `.ai/index.json`, and `.ai/projects/index.json` should be updated in place.

<!-- @section: workflow-macros -->
## Workflow Macro Codes

- Treat `@wb:` codes as explicit workflow macros. Do not infer macro use from ordinary wording.
- Read `.ai/workflows/index.json` and `cheatsheets/workflow-codes.md` when a prompt includes an `@wb:` code.
- Use the global `workbench-macro` Skill when a prompt includes an `@wb:` code.
- Macro codes route existing Skills and workbench scripts; they do not override live-project rules, Unity safety rules, or tracking requirements.
- If a macro is missing required fields such as project, target, bug, expected behavior, or asset intent, ask for the missing field before making changes.
- Do not create detailed project-session documentation during normal macro use unless the code is `@wb:session-start`, `@wb:session-wrap`, or the user explicitly asks for documented session notes.

<!-- @section: contextual-recommendations -->
## Contextual Recommendations

- Actively consider whether a Skill, `@wb:` macro, MCP check, verification step, documentation note, handoff, or cleanup workflow would help the user's request.
- Use `.ai/recommendations/index.json` as the compact routing map and `cheatsheets/recommendations.md` for human-facing explanation.
- Required context and rules are not optional suggestions. Load required indexes, project context, live-project rules, and Unity context when the workflow requires them.
- Use hybrid suggestion mode: pause before optional side effects, external writes, significant runtime, or optional MCP/tool usage; otherwise finish the normal task and suggest at most two useful follow-ups.
- Suggestions must explain impact briefly: what it reads, what it writes, whether it may touch external projects, and whether it costs time/tool usage.
- Do not suggest extra workflows for trivial prompts, obvious one-step answers, or cases where a Skill or macro would add ceremony without value.
- Unity-specific suggestions apply only to Unity dossiers. General suggestions such as `$remember`, `@wb:handoff`, `@wb:attempt-recovery`, or `$project-session` can apply to any project type.
- `@wb:` macros remain explicit. Codex may suggest a macro, but must not silently treat ordinary wording as a macro invocation.

<!-- @section: retrieval-strategy -->
## Retrieval Strategy

- Default to grep plus indexes for source code, exact symbols, known files, compile errors, stack traces, and single-file edits.
- Use `.ai/retrieval/index.json` and `projects/<slug>/.ai/scope.json` when a task is broad, architectural, multi-system, fuzzy, history-oriented, or unclear.
- Use `@wb:retrieval-plan` when the user explicitly asks for a retrieval planning pass or when contextual recommendations say a pre-work gate is useful.
- RAG is for AI/workbench memory only: attempts, decisions, feedback, handoffs, sessions, changes, summaries, and project maps.
- Do not recommend RAG for source code in this workbench. Use `rg`, structured indexes, and focused file reads for code.
- If `rag_semantic` would be useful but RAG is not configured, state that and use grep/index fallback unless the user invokes `@wb:rag-setup`.
- Do not log every retrieval decision. Add routing history only if the heuristics need tuning later.

<!-- @section: model-providers -->
## Model Providers

- Default alternate model work to local/free Ollama through `scripts/start-local-codex.ps1`.
- Read `.ai/models/index.json` and `cheatsheets/model-providers.md` before suggesting provider changes.
- Allowed model use means local/free models or already-active user subscriptions explicitly selected by the user.
- Block new metered API usage, hosted cloud model billing, provider credits, new subscriptions, subscription upgrades, Ollama cloud models, Anthropic Console/API billing, and OpenAI API key billing.
- Never auto-switch providers and never fall back from local/free to billed/cloud routes.
- Use `scripts/assert-no-extra-spend.ps1` in provider scripts to fail fast on API keys, non-local Ollama endpoints, Claude Console/API routing, Bedrock/Vertex routing, or cloud model names.
- Claude Code is allowed only when explicitly requested and only through existing Claude.ai subscription authentication with `forceLoginMethod=claudeai`.

<!-- @section: reviewer-workflow -->
## Reviewer Workflow

- Use `@wb:review` or `scripts/run-local-review.ps1` after substantive live-project changes when a fresh rule-checking pass would add value.
- Default reviews use local/free Ollama. Use `scripts/run-claude-review.ps1` only when the user explicitly asks for Claude Code through the existing Claude.ai subscription lane.
- Reviewer output is findings-only. Do not patch, edit, rewrite, format, or create source files while reviewing.
- Write review notes under `projects/<slug>/.ai/reviews/` and keep that review index current.
- Read `cheatsheets/reviewer.md`, live-project rules, project rules, project index, and Unity context when relevant before reviewing.
- Skip reviewer workflow for trivial edits unless the user explicitly requests it.

<!-- @section: persistent-feedback -->
## Persistent Feedback

- Use `.ai/feedback/` for workbench-level persistent preferences and corrections.
- Use `projects/<slug>/.ai/feedback/` for project-specific corrections.
- Use `scripts/remember-feedback.ps1` or the global `remember` Skill when the user says to remember a preference, correction, or repeated rule.
- Feedback entries should include the rule, why it matters, and when to apply it.
- Do not store bulky discussion logs as feedback memory.

<!-- @section: decisions -->
## Decision Logs

- Use `.ai/decisions/` for architectural and workflow decisions that should not be re-litigated.
- Use `scripts/new-decision.ps1` when a durable decision is made.
- Read recent decisions before proposing broad architecture, workflow, or rule changes.

<!-- @section: attempt-notes -->
## Attempt Notes

Use `scripts/new-attempt-note.ps1` or the `.ai/attempts/_template.md` template. Each attempt note should include:

- goal
- context
- attempted steps
- failure or error
- suspected cause
- next recommended approach
- things not to retry

<!-- @section: asset-tracking -->
## Asset Tracking

Use `scripts/register-asset.ps1` when adding useful generated assets. Manifest entries in `.ai/assets/index.json` should include:

- `id`
- `type`
- `path`
- `source`
- `prompt_ref`
- `created_at`
- `status`
- `notes`

Use stable, descriptive IDs such as `hero-bg-v1`, `logo-study-2026-05-23`, or `sample-dataset-orders-v1`.

<!-- @section: token-discipline -->
## Token Discipline

- Start with `.ai/index.json`, then specific docs or manifests.
- Summarize long files instead of pasting or rereading them wholesale.
- Prefer structured manifests and summaries over repeated folder scans.
- Do not write bulky raw outputs, logs, screenshots, or temporary exports into committed context.
- Put bulky or noisy AI-only material in `.ai/raw/`, `.ai/tmp/`, `.ai/logs/`, `.ai/screenshots/`, or `.ai/exports/`; these paths are ignored by Git.

<!-- @section: git-and-editing-safety -->
## Git And Editing Safety

- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested workflow or feature.
- Use `apply_patch` for manual file edits.
- Run focused validation after changing scripts or structured JSON.
- If a command fails because of sandboxing or network restrictions, request approval rather than working around the restriction.

<!-- @section: skills -->
## Skills

- Use Skills for reusable workflows that should apply across workspaces.
- Do not put this workspace's actual project state, asset manifests, attempt notes, or generation records inside a Skill.
- Use the global `project-dossier` Skill for creating, finding, and loading project dossiers.
- Use the global `project-session` Skill only when the user explicitly wants documented project-session notes.
- Use the global `workbench-macro` Skill when the user invokes an explicit `@wb:` workflow code.
- Use the global `retrieval-router` Skill when the user invokes `@wb:retrieval-plan`, asks to choose grep/index vs RAG, or requests retrieval planning.
- Use the global `remember` Skill when the user asks Codex to remember a preference or correction.
