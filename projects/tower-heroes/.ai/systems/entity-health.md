# Entity Health

## Overview
The health system manages HP, damage intake, death signaling, and post-death presentation for all destructible entities — both towers and enemies. A `HealthModule` component is the single source of truth for current HP. It delegates stat sourcing to a `HealthStatSource` subclass and death handling to an `IHealthDeathHandler` implementation, allowing enemies and towers to have different death behaviours without branching inside `HealthModule`.

## How It Works

### Component structure
Every entity that can die has:
- `HealthModule` — tracks `CurrentHealth`, fires `HealthChanged`, dispatches to the death handler.
- A `HealthStatSource` subclass wired to it — provides `MaxHealth`, `Armor`, `AttackType`, and `ArmorType`. Enemies use `EnemyHealthStatSource` (serialized fields on the prefab). Towers use `TowerHealthStatSource` (reads from the `TowerDefinition` ScriptableObject via `TowerTypeReference`).
- An `IHealthDeathHandler` implementation assigned to `deathHandlerBehaviour` — for enemies, this is `EnemyDeathController`; towers fall back to `Destroy(gameObject)` if no handler is assigned.

`EntityRoot` (on tower GameObjects) caches a reference to the `HealthModule` and exposes it to external systems. Enemies expose theirs via `EnemyCombatTarget.HealthModule`.

### Damage flow
1. `EnemyCombatTarget.ReceiveTowerHit(CombatHitRequest)` is the entry point for tower-on-enemy damage. It calls `HealthModule.ReceiveDamage(hitRequest, CombatRulesService.Instance.Profile)`.
2. `HealthModule.ReceiveDamage` (the overload taking a `CombatHitRequest`) calls `CombatDamageCalculator.Resolve` to get a `ResolvedCombatDamage`, then calls `HealthModule.ReceiveDamage(int amount)`.
3. The integer overload clamps `CurrentHealth` to `max(0, current - amount)`, fires `HealthChanged`, and if `CurrentHealth` reaches 0, calls `deathHandler.HandleDeath(this)`.
4. If no handler is assigned, `Destroy(gameObject)` is called directly.

`SetCurrentHealth(int)` is a non-damage path used to restore or set HP (e.g., on save restore), firing `HealthChanged` without triggering death.

### Enemy death (`EnemyDeathController.HandleDeath`)
`EnemyDeathController` implements `IHealthDeathHandler` and is assigned as `deathHandlerBehaviour` on enemy prefabs. On `HandleDeath`:
1. Guard: `isDeathHandled` prevents double invocation.
2. `AudioManager.Instance.PlayEnemyDeathSfx()`.
3. `EnemyDeathPresentationService.Instance.PlaySequence(presentationProfile, position, scale, ...)` — pops an `EnemyDeathSequenceView` from a pool and animates the death/corpse sprite frames. Tick is driven by `GameplaySimulationService.CombatTicked`.
4. `enemyUnit.DeactivateForDeath()` — stops movement, removes the enemy from the crowd/wave tracking.
5. Disables configured `Behaviour` components (e.g., AI), `Collider2D` components, and hides `SpriteRenderer` components (the live sprite).
6. `Destroy(gameObject)`.

The `EnemyDeathPresentationService` manages a pooled stack of `EnemyDeathSequenceView` objects (prewarm 32, grow by 16). Each active sequence plays through `DeathFrames` for `DeathDurationSeconds`, then `CorpseFrames` for `CorpseDurationSeconds`, then returns to the pool.

### Tower death
Tower entities do not have a dedicated `IHealthDeathHandler` — `deathHandlerBehaviour` is left null in `HealthModule`. When a tower's HP reaches 0, `Destroy(gameObject)` is called. `EntityRoot.OnDestroy` notifies `SelectionManager` to deselect. `RuntimeTowerRegistryService.PurgeDestroyedTowers` will detect the null `GameObject` reference on its next query and clean up the registry entry.

### Loot on death
Enemies that drop loot have a `LootModule` component holding an `ItemDefinition` and amount. The `EnemyUnit.DeactivateForDeath` path is where loot award is triggered, not directly from `HealthModule`.

### Health stat sourcing
`HealthStatSource` is an abstract `MonoBehaviour`:
- `EnemyHealthStatSource`: stats serialized directly on the prefab (`maxHealth`, `armor`, `attackType`, `armorType`). Changing enemy stats means editing the prefab.
- `TowerHealthStatSource`: reads `MaxHealth`, `Armor`, `AttackType`, `ArmorType` from `TowerDefinition`. Changing tower stats means editing the ScriptableObject.

Both types validate in `Awake` that stats are in bounds and that types are not `Unknown`.

## Key Classes & Files
| Class | File (relative to Assets/) | Role |
|---|---|---|
| `HealthModule` | `_Project/Scripts/Entities/Modules/HealthModule.cs` | Per-entity. Owns current HP; routes damage to calculator; calls death handler. |
| `HealthStatSource` | `_Project/Scripts/Entities/Modules/HealthStatSource.cs` | Abstract base. Provides MaxHealth, Armor, AttackType, ArmorType. |
| `TowerHealthStatSource` | `_Project/Scripts/Entities/Towers/TowerHealthStatSource.cs` | Reads stats from TowerDefinition ScriptableObject. |
| `EnemyHealthStatSource` | `_Project/Scripts/Waves/EnemyHealthStatSource.cs` | Stats serialized directly on the enemy prefab. |
| `IHealthDeathHandler` | `_Project/Scripts/Entities/Modules/IHealthDeathHandler.cs` | Interface: `HandleDeath(HealthModule)`. Implemented by EnemyDeathController. |
| `EnemyDeathController` | `_Project/Scripts/Waves/EnemyDeathController.cs` | Enemy death handler. Plays presentation, deactivates unit, destroys GameObject. |
| `EnemyDeathPresentationService` | `_Project/Scripts/Waves/EnemyDeathPresentationService.cs` | Singleton. Pooled animation service for death/corpse sprite sequences. |
| `EnemyDeathPresentationProfile` | `_Project/Scripts/Waves/EnemyDeathPresentationProfile.cs` | ScriptableObject per enemy type: DeathFrames, CorpseFrames, durations. |
| `EntityRoot` | `_Project/Scripts/Entities/EntityRoot.cs` | Tower root. Exposes HealthModule to selection and external systems. |
| `EnemyCombatTarget` | `_Project/Scripts/Combat/EnemyCombatTarget.cs` | Enemy entry point for tower hits; calls HealthModule.ReceiveDamage. |
| `LootModule` | `_Project/Scripts/Entities/Modules/LootModule.cs` | Optional per-enemy. Holds ItemDefinition + amount for death loot. |

## Integration Points
- **Called by:** `EnemyCombatTarget.ReceiveTowerHit` (the main damage entry point); `HealthModule.SetCurrentHealth` (used by save/restore or healing effects).
- **Calls into:** `CombatDamageCalculator.Resolve` (type modifier + armor math), `CombatRulesService.Instance.Profile` (rules lookup), `IHealthDeathHandler.HandleDeath` (death dispatch), `EnemyDeathPresentationService.PlaySequence` (visual), `AudioManager` (sound), `EnemyUnit.DeactivateForDeath` (wave/crowd cleanup), `LootModule` (item award).
- **Shared state / data contracts:** `HealthModule.HealthChanged` event (subscribed by `EnemyWorldHealthBarSubject` for UI health bars). `HealthModule.IsDead` bool (checked by `EnemyCombatTarget.ReceiveTowerHit` to guard dead targets). `ResolvedCombatDamage` struct (returned up to `CombatFeedbackManager` for floating damage text).

## Debug Guide
**Enemy does not die at 0 HP:** Check that `EnemyDeathController` is assigned as `deathHandlerBehaviour` in `HealthModule` and that `isDeathHandled` is false. `EnemyDeathController` validates in `Awake` that it is the registered handler — if this check fails, the game throws on startup.

**Double-death / HandleDeath called twice:** `isDeathHandled` guard should prevent this. If it triggers, something is calling `HealthModule.ReceiveDamage` after the entity is already dead — the integer-overload early-returns `if (IsDead)`.

**Death animation not playing:** `EnemyDeathPresentationService.Instance` may be null or the pool exhausted. The service grows by 16 when the stack empties, so exhaustion would mean 32 + N*16 simultaneous deaths. Check that `EnemyDeathPresentationProfile` on the enemy is not null and passes `ValidateData`.

**Tower health bar not updating:** `EnemyWorldHealthBarSubject` subscribes to `HealthModule.HealthChanged`. If `HealthChanged` is not firing, `SetCurrentHealth` or `ReceiveDamage` is not being reached — verify the `EnemyCombatTarget` is being found by the tower's targeting system.

**Stats read as 0 or Unknown for tower:** `TowerHealthStatSource` reads from `TowerDefinition`. If `TowerTypeReference` is unassigned on the prefab, the definition lookup will throw in `Awake`.

## Known Issues / Gotchas
- `HealthModule.ReceiveDamage(int)` does not guard against being called on a destroyed GameObject. If an attack projectile lands after the enemy is already `Destroy`-ed (e.g., a slow projectile), Unity will throw a null reference. `EnemyCombatTarget.ReceiveTowerHit` guards against the dead state but not the destroyed state.
- There is no tower-specific `IHealthDeathHandler`. Tower death results in immediate `Destroy(gameObject)` with no presentation. If a death animation for towers is needed in future, a `TowerDeathController` implementing `IHealthDeathHandler` should be added to the tower prefab and wired to `HealthModule.deathHandlerBehaviour`.
- `LootModule` data is not read by `EnemyDeathController` directly — loot award is handled inside `EnemyUnit.DeactivateForDeath`. Do not move death logic into `HealthModule` without accounting for this.
- `EnemyDeathPresentationService` ticks on `CombatTicked`, so death animations pause when combat is paused. This is intentional but means corpses freeze on screen during a pause.
