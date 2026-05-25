# Contextual Recommendations

Codex should actively notice when a Skill, macro, MCP check, verification step, documentation note, or cleanup flow would help. It should suggest these only when they add real value.

Default mode: hybrid.

- Pause before optional side effects, external writes, expensive checks, or optional MCP/tool usage.
- Finish normal work first, then suggest up to two useful follow-ups.
- Skip suggestions for trivial prompts or obvious one-step work.
- Required context is not optional. Codex should load required indexes/rules silently.
- `@wb:` macros remain explicit. Codex may suggest one, but should not silently convert normal wording into a macro.

## Useful Suggestions

### Live Project Bugfix

Suggest: `@wb:bugfix-live`

Use when a bug affects a linked live project and the prompt did not already include a macro.

Impact: loads project dossier context, live-project rules, and engine context when relevant. May edit external source only when the request clearly targets live project changes. Records a project change after work.

### Live Project Cleanup

Suggest: `@wb:cleanup-live`

Use when the user asks for targeted cleanup or refactor in a linked live project.

Impact: loads rules, preserves behavior unless explicitly changed, may edit external source, and records the change.

### Unity Scene Or Prefab Work

Suggest: `@wb:scene-prefab-change`, `$unity-context`, Unity MCP, or exact Unity Editor steps.

Use when the task touches Unity scenes, prefabs, hierarchy, ScriptableObjects, shaders, layers, sorting layers, or ProjectSettings.

Impact: reads Unity context. Serialized Unity edits may touch `D:\GameProjects` only when narrow, safe, and inspectable. Risky edits become Editor steps instead.

### Unity Verification

Suggest: Unity MCP, `scripts/run-unity-tests.ps1`, or `scripts/tail-unity-log.ps1`.

Use when editor/runtime confirmation would materially improve confidence, such as serialized references, playmode behavior, package restore, or log-driven bugs.

Impact: may take time. Batchmode tests/logs write ignored output under project `.ai/tmp/`.

### Art Or Asset Generation

Suggest: `@wb:artgen-project` or `$imagegen`

Use for raster art, sprites, textures, concept art, UI mockups, transparent cutouts, or project-matching visuals.

Impact: may generate image files. Accepted project-bound assets should be registered in manifests.

### Attempt Recovery

Suggest: `@wb:attempt-recovery`

Use when the user is retrying a failed/stalled task or references previous failed work.

Impact: reads attempts and recent changes. Writes a new attempt note only if the new attempt fails, stalls, or reveals useful "do not retry" context.

### Retrieval Strategy

Suggest: `@wb:retrieval-plan`

Use when the request is broad, architectural, multi-file, history-oriented, fuzzy, or unclear enough that retrieval strategy affects cost or quality.

Impact: reads retrieval policy and project scope, then proposes `grep_and_index`, `rag_semantic`, or `hybrid`. It does not write external project files. If RAG is not configured, Codex must say so and use grep/index fallback unless `@wb:rag-setup` is explicitly invoked.

### Local Model Session

Suggest: `scripts/start-local-codex.ps1`

Use when the next task is simple enough for local/free model work or the user is explicitly trying to avoid extra spend.

Impact: starts a new Codex session using Ollama local models only. It does not use API keys, hosted cloud models, provider credits, or new billing.

### Claude Subscription Session

Suggest: `scripts/start-claude-code.ps1` or `scripts/run-claude-review.ps1`

Use only when the user explicitly asks for Claude Code through an existing Claude.ai subscription.

Impact: uses Claude Code only with `forceLoginMethod=claudeai`. The scripts refuse Anthropic Console/API billing, provider credits, cloud model billing, and new subscriptions.

### Post-Change Review

Suggest: `@wb:review`

Use after substantive code changes, especially refactors, multi-file edits, Unity lifecycle work, serialized reference changes, or performance-sensitive code.

Impact: reads rules and project context, then writes a findings-only review note under `projects/<slug>/.ai/reviews/`. It does not patch source.

### Persistent Preference

Suggest: `$remember`

Use when the user gives a repeated preference, correction, or rule that should apply later.

Impact: writes compact feedback memory under `.ai/feedback/` or `projects/<slug>/.ai/feedback/`.

### Handoff Or Session Docs

Suggest: `@wb:handoff`, `@wb:session-start`, or `@wb:session-wrap`

Use handoff for lightweight next-step context after a solved or paused task. Use session docs only for long, strategic, or explicitly documented work.

Impact: handoff writes a small timestamped note. Session docs create session folders and timestamped note files.

### Task Ceremony Threshold

Right-size effort. Trivial wording does not unlock the trivial path — the threshold is about *effect*, not *phrasing*.

**No macro, no session docs, no change record** — answer or edit directly:

- Typos / single-line edits in workbench-local code
- Formatting-only changes
- "Where is X" / "how does Y work" questions resolvable with one or two reads
- Reading existing docs, summarizing files, explaining behavior
- Trivial cheatsheet / index touch-ups

**Use the appropriate `@wb:` macro + standard tracking**:

- Any edit to `D:\GameProjects\*` external project source
- Any change touching more than 2 files
- Any change to scenes, prefabs, ScriptableObjects, shaders, ProjectSettings
- Any change that alters gameplay behavior (intended or not)
- Anything where rules-load matters

**Documented session (`@wb:session-start`)**:

- Multi-hour debugging spanning multiple compile-test cycles
- Work that will continue across multiple AI / Codex sessions
- Deliberate retrospective on a tricky incident
- User explicitly asks for documented session notes

When in doubt, lean toward less ceremony for read-only / single-edit work, and toward more ceremony for anything that touches external project source or rules-bound changes.

### Plan Mode Workflow Recommendations

Suggest: a `## Recommended Macros & Skills` section appended to every written plan.

Use whenever a plan is being produced — Claude Code's formal plan mode, or any explicit "plan this" / "make a plan for" request handled by any AI tool.

Format each entry as:

- `<macro or skill>` — execution phase: **pre-work / during / post-work tracking / post-work follow-up**. One sentence of plan-specific reasoning.

If nothing applies, write exactly: `No macros or skills recommended for this plan.` Do not invent recommendations.

Impact: read-only annotation in the plan output. Does not invoke anything; the user must still explicitly run each macro. The "Do Not Suggest" rules below still apply — keep the list short and concrete.

Example (for a hypothetical movement-bug plan in tower-heroes):

```text
## Recommended Macros & Skills

- `@wb:bugfix-live` — execution phase: **pre-work**. This plan edits live tower-heroes code to fix a movement bug, so the bugfix macro loads rules and queues the change record.
- `@wb:update-system enemy-movement` — execution phase: **post-work tracking**. The plan touches files matching the `enemy-movement` system's `key_file_patterns`, so its doc needs refreshing after the fix.
- `@wb:review` — execution phase: **post-work follow-up**. The plan changes a hot per-frame path, so a findings-only review pass is worth offering after the fix lands.
```

## Do Not Suggest

- A Skill or macro for a simple question that can be answered directly.
- Unity MCP for purely static code inspection when editor state is irrelevant.
- Session documentation after a tiny edit or one-off answer.
- `$remember` for a casual preference that is unlikely to matter later.
- Cleanup macros unless there is concrete code, generated state, or documentation worth cleaning up.

## Example Phrasing

Pre-work gate:

```text
This looks like a Unity editor-state issue. I can first use Unity MCP/log checks, which may take time and write ignored logs under the project dossier. Want me to include that verification?
```

Post-work follow-up:

```text
Useful follow-up: this fix touched Unity-facing behavior, so `@wb:unity-sync` would refresh the project context. A lightweight `@wb:handoff` would also preserve the next test step.
```
