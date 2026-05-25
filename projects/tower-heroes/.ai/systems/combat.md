# Combat

## Overview
The combat system drives towers attacking enemies each simulation tick. It handles target selection via `TowerTargetingModule`, projectile/hit request dispatch through `CombatFeedbackManager`, and damage resolution via a type-modifier matrix and an armor mitigation curve defined in `CombatRulesProfile`. Every tower that can attack has an `AttackModule`; every enemy that can be attacked has an `EnemyCombatTarget`.

## How It Works

### Simulation loop
`TowerAttackSimulationService` subscribes to `GameplaySimulationService.CombatTicked`. On each tick it iterates all registered `AttackModule` instances and calls `attackModule.TickSimulation(combatTime)`. Registration is self-managed: `AttackModule.OnEnable` registers with the service and `OnDisable` unregisters.

### Attack tick (`AttackModule.TickSimulation`)
1. If `IsOperational` is false (tower under construction or disabled) the method returns early.
2. `RefreshFocusIndicatorTarget` updates the target-lock visual for manual priority targets.
3. If `combatTime < nextAttackTime`, no attack this tick.
4. Otherwise, enter a catch-up loop: while `combatTime >= nextAttackTime`, call `TowerTargetingModule.ResolveAttackTarget(attackOrigin, range, targetMask)`. If no target in range, reset `nextAttackTime` to `combatTime` (no phantom cooldown accumulation) and break.
5. For each caught-up attack, build a `CombatHitRequest(baseDamage, attackType)` from `TowerCombatProfile` and call `CombatFeedbackManager.Instance.LaunchProjectile(origin, target, hitRequest, presentation, textAnchor)`.
6. Increment `nextAttackTime` by `AttackIntervalSeconds` for each attack fired.

### Targeting
`TowerTargetingModule` resolves the target according to the tower's configured priority criteria (e.g., closest to exit, most health). If the player has manually pinned a `EnemyCombatTarget` via `SetManualPriorityTarget`, that target takes precedence as long as it is in range and alive.

### Projectile and hit delivery (`CombatFeedbackManager`)
`CombatFeedbackManager.LaunchProjectile` plays the projectile visual and, when it arrives, calls `EnemyCombatTarget.ReceiveTowerHit(hitRequest)`.

### Damage calculation (`EnemyCombatTarget.ReceiveTowerHit`)
1. Guards against dead targets (returns `null` if already dead).
2. Calls `HealthModule.ReceiveDamage(hitRequest, CombatRulesService.Instance.Profile)`.
3. `HealthModule` delegates to `CombatDamageCalculator.Resolve`.
4. `CombatDamageCalculator` computes: `typeMultiplier = CombatRulesProfile.GetDamageMultiplier(attackType, armorType)` (looks up the 6×N modifier matrix). Then `armorMitigation = maxArmorDamageReduction * armor / (armor + armorHalfReductionPoint)` (diminishing returns curve). Final damage = `max(1, round(baseDamage * typeMultiplier * (1 - armorMitigation)))`.
5. `CombatFeedbackManager.PlayHitFlash` plays the hit visual; `AudioManager.PlayEnemyHitSfx` plays the sound.

### Type modifier matrix
`CombatRulesProfile` (ScriptableObject, `SO_CombatRules`) holds exactly 6 `CombatAttackModifierRow` entries, one per `CombatAttackType` (Divine, Ruin, Nether, Cataclysmic, Abyssal, Primordial). Each row contains per-`CombatArmorType` multipliers. `ValidateData` enforces exactly one row per attack type. `CombatRulesService` is the singleton that exposes the active profile.

### Armor types
`CombatArmorType` (enum) mirrors the attack type space. Enemies set their `ArmorType` in `EnemyHealthStatSource` (serialized fields on the prefab). Towers set their `AttackType` in `TowerDefinition`. The combination determines the effective damage multiplier before armor mitigation.

## Key Classes & Files
| Class | File (relative to Assets/) | Role |
|---|---|---|
| `AttackModule` | `_Project/Scripts/Entities/Modules/AttackModule.cs` | Per-tower. Owns cooldown, registers with simulation service, fires hit requests. |
| `TowerAttackSimulationService` | `_Project/Scripts/Entities/Modules/TowerAttackSimulationService.cs` | Singleton. Drives all registered AttackModules each combat tick. |
| `TowerCombatProfile` | `_Project/Scripts/Entities/Towers/TowerCombatProfile.cs` | ScriptableObject. AttackRange, AttackIntervalSeconds, Damage, presentation profile. |
| `CombatRulesProfile` | `_Project/Scripts/Combat/CombatRulesProfile.cs` | ScriptableObject. Full 6-row type modifier matrix + armor mitigation parameters. |
| `CombatDamageCalculator` | `_Project/Scripts/Combat/CombatDamageCalculator.cs` | Static. Resolves base damage → type multiplier → armor mitigation → final int. |
| `CombatHitRequest` | `_Project/Scripts/Combat/CombatHitRequest.cs` | Value type: BaseDamage + AttackType. Passed from tower to target. |
| `EnemyCombatTarget` | `_Project/Scripts/Combat/EnemyCombatTarget.cs` | Per-enemy. Entry point for tower hits; bridges to HealthModule and feedback. |
| `CombatAttackType` | `_Project/Scripts/Combat/CombatAttackType.cs` | Enum: Unknown, Divine, Ruin, Nether, Cataclysmic, Abyssal, Primordial. |
| `CombatArmorType` | `_Project/Scripts/Combat/CombatArmorType.cs` | Enum (mirrors attack types). |
| `CombatAttackModifierRow` | `_Project/Scripts/Combat/CombatAttackModifierRow.cs` | One row of the modifier matrix: AttackType + per-ArmorType float multipliers. |
| `CombatFeedbackManager` | `_Project/Scripts/Combat/CombatFeedbackManager.cs` | Singleton. Pools and drives projectile visuals, hit flashes. |
| `CombatFeedbackSettings` | `_Project/Scripts/Combat/CombatFeedbackSettings.cs` | ScriptableObject. Projectile speed, hit flash duration, floating damage text settings. |
| `CombatTypeIconDatabase` | `_Project/Scripts/Combat/CombatTypeIconDatabase.cs` | ScriptableObject. Maps CombatAttackType/CombatArmorType to UI icons. |

## Integration Points
- **Called by:** `TowerAttackSimulationService` drives `AttackModule` each tick via `GameplaySimulationService.CombatTicked`. Manual target assignment comes from `EntityCommandInputController` → `AttackModule.SetPriorityTarget`.
- **Calls into:** `TowerTargetingModule` (target selection), `CombatFeedbackManager` (projectile launch), `EnemyCombatTarget.ReceiveTowerHit` (hit delivery), `CombatDamageCalculator` (damage math), `CombatRulesService` (active profile), `HealthModule.ReceiveDamage` (HP change), `AudioManager` (sound).
- **Shared state / data contracts:** `CombatHitRequest` (baseDamage + attackType). `ResolvedCombatDamage` (returned by calculator: baseDamage, typeMultiplier, armorMitigation, finalDamage). `CombatRulesProfile` — single global rules asset; all damage anywhere uses the same profile.

## Debug Guide
**Tower not attacking:** Check `AttackModule.IsOperational` — it is false while the tower is in `Building` or `WaitingForActivation` phase. Also check that `TowerAttackSimulationService.Instance` exists and that `GameplaySimulationService.IsCombatPaused` is false.

**Tower fires but does zero damage:** Verify `CombatRulesProfile` has a row for the tower's `AttackType`. Missing or wrong `ArmorType` on the enemy's `EnemyHealthStatSource` will resolve to `Unknown`, which throws rather than silently returns zero.

**Damage seems incorrect:** Log the `ResolvedCombatDamage` struct returned by `ReceiveTowerHit`. It contains `TypeMultiplier` and `ArmorMitigation` to identify which factor is off. The armor formula is `maxArmorDamageReduction * armor / (armor + armorHalfReductionPoint)`, with defaults 0.99 max and 16 half-reduction point.

**Tower does not catch up when unpaused:** Catch-up uses `nextAttackTime` accumulation. If `nextAttackTime` was set far in the past (e.g. from `RearmFromCurrentCombatTime` not being called), the catch-up loop may fire many attacks on the first tick after re-enable. `RearmFromCurrentCombatTime` sets `nextAttackTime = CombatTime` to avoid this.

## Known Issues / Gotchas
- `TowerAttackSimulationService` uses a swap-and-remove pattern for its internal list, so unregister order does not matter, but indices shift. Do not cache indices externally.
- `AttackModule.TickSimulation` can be called directly via `TryAttack()` from outside the service (e.g. for player unit attacks), bypassing the normal batch tick.
- `CombatRulesProfile.ValidateData` requires exactly 6 rows with no duplicates. Adding a new `CombatAttackType` value requires both updating the enum and adding a row to every `SO_CombatRules` asset in the project.
- The armor mitigation curve is asymptotic; `MaxArmorDamageReduction` is capped at 0.99 and never reaches 1.0 — minimum final damage is always 1 (enforced by `Mathf.Max(1, roundedDamage)`).
