# Tower Heroes Project Rules

These rules apply before changing the linked live project at:

`D:\GameProjects\TowerHeroes(x)\TowerHeroes`

## Required Rule Sources

- Global live-project policy: `rules/live-project-code-rules.md`
- Token-friendly rules index: `.ai/rules/index.json`
- Existing source-side project rules: `D:\GameProjects\TowerHeroes(x)\CodeRules.txt`
- Ramp/enemy movement protocol: `projects/tower-heroes/rules/ramp-traversal-root-fix-protocol.md`
- Project context: `projects/tower-heroes/.ai/index.json`
- Unity context: `projects/tower-heroes/.ai/engine/unity/index.json`

## Project-Specific Overlay

- Treat `D:\GameProjects\TowerHeroes(x)\CodeRules.txt` as an active project-specific rules file.
- The source-side rules include strict dependency ownership, lifecycle, scene reference, singleton, and editor wiring constraints.
- If the global policy and `CodeRules.txt` differ, use the stricter rule unless the user explicitly overrides it for the current task.
- Do not change Tower Heroes gameplay mechanics unless the user explicitly requests a mechanic change.
- Enemy movement fixes must preserve physical route rules. Do not fix stuck enemies by teleporting, snapping, ghosting, disabling collision, bypassing blockers, or otherwise moving enemies through invalid space. Root-fix the route, level, connector, collision, or constraint bug that produced the bad movement state.
- Before every ramp, connector, stuck enemy, or narrow-passage movement edit, follow `projects/tower-heroes/rules/ramp-traversal-root-fix-protocol.md` and explicitly pass its step gate.
- Record every external Tower Heroes edit with `scripts/record-project-change.ps1`.
