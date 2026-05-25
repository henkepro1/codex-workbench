# No-tower ramp stuck screenshot and live observations

Date: 2026-05-24T15:02:36+02:00
Kind: input
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

User screenshot/comment: no towers built. Enemies are clustered at the upper ramp mouth and visibly throttle hard to descend the ramp. User says this looks like wrong logic/fallback behavior, not acceptable narrow-passage struggle.

Live console during Play showed repeated fail-fast stall-repath errors:
EnemyUnit 'PF_Enemy_Ivanna' cannot repath from its current routeable origin without relocating the enemy. Positions around (1.45..1.49, -0.04..-0.08), CurrentSurfaceLevel=1, NextCheckpointIndex=2, TopologyVersion=9.

Key live dump observations from 10 enemies:
- All 10 enemies are on level 1, checkpoint 2, clustered around connector.l0_to_l1.ramp.
- Multiple enemies on L1:(55,30), connector routeable, canRoute=true, but bodyClear=false because their compressed body overlaps blocked subcells L1:(55,31) and L1:(56,31), i.e. cells above the upper ramp lane.
- Nearby enemy distances are extremely small (some < 0.01 world units), so crowd compression is severe at the ramp mouth.
- Several routes show suspicious local ordering around the ramp, e.g. current points include L1:(56,30) -> L1:(55,30) -> L1:(54,30) while enemies are trying to descend/get through; path line visually crosses/angles through the ramp.
- Some enemies have verifiedPost=true/canSkipPost=true while on connector routeable cells; others are bodyClear=false and stalledSeconds > 0.1. This suggests movement verification/connector branch decisions may be accepting or suppressing post-move checks inconsistently across the same cluster.

Current hypothesis to investigate next: the issue is not stall recovery. Root likely sits in connector route-point generation/progression or branch selection for descending ramp traversal, causing enemies to target/advance through a route sequence that presses them into the connector lane edge/blocked shoulder and then relies on fallback/throttled movement.
