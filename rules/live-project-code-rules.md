# Live Project Code Rules

These rules apply when editing external/live project files linked from the workbench, including Unity projects under `D:\GameProjects`.

They are mandatory unless the user explicitly overrides a specific rule for a specific task. If a proposed solution conflicts with these rules, the rule wins.

## 0. Preconditions

- Read the workbench context first: `AGENTS.md`, `.ai/index.json`, `.ai/projects/index.json`, `.ai/rules/index.json`, and the selected project's `.ai/index.json`.
- Read the selected project's rule overlay before changing external files.
- For Unity projects, read the project Unity context before editing scripts, scenes, prefabs, ScriptableObjects, shaders, layers, sorting layers, settings, or editor-state files.
- Do not write or suggest project code from memory alone. Verify against the real project files.
- If required context is missing, stop and request or gather the missing data before editing.
- If a system, script, prefab, scene object, service, or asset is not found in the project files, treat it as nonexistent.

## 1. Failure Handling

- No hidden fallbacks.
- No dummy values, placeholder values, fake success paths, or null-coalescing defaults just to satisfy an error.
- Guards must fail fast: log clearly, stop execution immediately, and do not continue in a best-effort state.
- Never suppress, bypass, swallow, or silence errors.
- Solve errors at the root cause. Do not cosmetically remove symptoms.
- Use defaults only when the domain explicitly defines a valid default and the existing architecture confirms that behavior.
- Use `try`/`catch` only for expected, verified failure modes where the handling is technically correct. Otherwise let the error fail loudly.

## 2. Gameplay Behavior Preservation

- Do not change existing game mechanics unless the user explicitly asks for a mechanic change.
- Refactors, optimizations, dependency rewiring, and bug fixes must preserve the same player-visible outcome.
- If the old outcome is "the player can place the tower", the new outcome must still be "the player can place the tower" unless the request says otherwise.
- Performance fixes may change how work is done internally, but not what the player can do, what happens, or what result they receive.
- If a mechanic is ambiguous, inspect the current code, scenes, prefabs, ScriptableObjects, and tests before deciding.
- If preserving behavior and fixing the issue conflict, stop and explain the conflict instead of silently changing the mechanic.

## 3. Architecture And Design

- Follow the existing clean architecture of the project.
- No god classes. Split responsibilities into cohesive components.
- SRP is mandatory: each class should have one reason to change.
- Each C# class must live in its own `.cs` file unless the project has a verified, intentional exception for a tiny nested type.
- Put every class in the correct folder for its architectural role. If the folder does not exist, create the proper folder instead of placing the class conveniently.
- Design for scale from the start. Assume 1000+ active entities where gameplay systems can reach that scale.
- Keep domain logic out of view/controller glue unless the project architecture intentionally places it there.
- Do not introduce global state, static convenience access, or singleton shortcuts unless the project already uses that exact contract for that dependency.

## 4. System Reuse And Integrity

- Reuse existing systems.
- Do not reimplement behavior that already exists.
- If a system is unclear, inspect the project files and references. Do not infer.
- Prefer extending the established abstraction over creating a parallel system.
- Remove dead or obsolete code after replacing behavior.
- Do not preserve bad logic purely to avoid touching related code.
- Technical correctness and long-term maintainability take priority over short-term convenience.

## 5. Performance And Load Constraints

- Assume high load for gameplay systems, including 1000+ enemies or entities.
- Respect existing tick budgets, pooling systems, prewarm logic, update loops, and batching patterns.
- Do not introduce per-frame allocations, repeated LINQ in hot paths, uncached component lookups, broad scene searches, or hidden polling costs.
- Do not move expensive work into `Update`, `FixedUpdate`, `LateUpdate`, animation events, or frequent tick callbacks without proving the cost is acceptable.
- Prefer cached references, explicit dependencies, pooled objects, event-driven updates, and existing schedulers.
- Any optimization must preserve gameplay outcomes exactly unless a behavior change was requested.

## 6. Dependency Rules

- Avoid `GetComponent`, `Find`, `FindObjectOfType`, `FindFirstObjectByType`, `GetBy*`, tag searches, name searches, and similar broad lookups.
- Prefer explicit dependencies, serialized references, constructor/runtime injection, existing service locators, or existing project-specific dependency mechanisms.
- Lookup methods are allowed only when the existing architecture proves they are correct, bounded, and not on a hot path.
- Before adding, changing, or replacing any dependency, verify where it lives:
  - bootstrap scene singleton or service
  - gameplay scene object or controller
  - runtime-spawned object
  - prefab reference
  - ScriptableObject asset
  - project setting or manager
- Every dependency used in code must match its real ownership and lifetime.
- Never invent or assume a dependency source.
- Never replace an existing same-scene serialized reference with a singleton lookup unless the project already uses that exact singleton contract for that dependency.
- Never replace an existing singleton dependency with a serialized scene reference unless the project already uses same-scene serialized wiring for that dependency.
- Never create bootstrap-to-gameplay or gameplay-to-bootstrap cross-scene serialized references unless the real hierarchy and existing architecture prove that this is intended.
- Do not add `Awake`, `OnEnable`, `Start`, or subscription logic against singleton instances unless initialization order is verified from project files.
- If initialization order is not proven, stop and verify before wiring the dependency.
- Preserve dependency categories unless the project files prove the new category is correct:
  - same-scene serialized reference stays same-scene serialized
  - bootstrap singleton stays bootstrap singleton
  - runtime object dependency stays runtime-injected or resolved by the existing runtime pattern
  - prefab reference stays prefab-owned unless the architecture says otherwise
- No scene mismatch references.
- No lifecycle mismatch references.
- No cross-scene convenience wiring.

## 7. Refactors, Renames, And Breaking Changes

- Renames must be explicit and intentional.
- Refactors are allowed and encouraged when they improve correctness, clarity, or maintainability.
- Breaking API changes are acceptable when technically correct, but the impact and required follow-up fixes must be explained.
- Do not avoid refactoring just to protect bad internals.
- Do not change gameplay mechanics as part of a refactor unless explicitly requested.
- Keep changes scoped to the requested problem and the architecture required to solve it correctly.

## 8. Unity Editor And Asset Changes

- Required Unity Editor changes must be explicitly listed.
- Do not hide editor configuration behind runtime code unless explicitly requested.
- Direct serialized YAML edits to scenes, prefabs, ScriptableObjects, shaders, layers, tags, sorting layers, or ProjectSettings are allowed only when narrow, inspectable, and safe to verify.
- If YAML editing is risky or the intent depends on Unity-generated data, provide exact Unity Editor steps instead of editing blindly.
- Any code change that requires inspector wiring must list the exact objects/assets and fields that need wiring.
- Do not add runtime discovery code to avoid proper editor wiring.

## 9. Code Quality Requirements

- No guessing.
- No unverified assumptions.
- No partial methods.
- No architectural shortcuts.
- No convenience solutions at the cost of correctness.
- No broad "try this, and if it fails use some random default" logic.
- Keep comments concise and useful. Do not use comments to excuse unclear code.
- Keep public APIs intentional. Do not expose fields or methods only to make an implementation easier.
- Keep naming specific to the domain and existing project language.
- Keep tests, validation steps, or manual verification aligned with the risk of the change.

## 10. Enforcement

- If a rule conflicts with a proposed solution, the rule wins.
- If the best solution requires refactoring, breaking APIs, asset changes, or editor wiring, do the technically correct work and explain the impact.
- If a direct edit would be unsafe, stop and provide exact user/editor steps instead.
- After any external project edit, update the workbench tracking: project index, Unity context when relevant, and a project change record.
