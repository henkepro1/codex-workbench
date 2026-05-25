# Spawn cache uses connector-aware route origin

Date: 2026-05-25T00:52:05+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Tightened the spawn-start root fix in EnemyPathService: BuildWorldCaches now derives spawnWorldPositions with ResolveConnectorAwareRouteableWorldPosition(spawnSubcell, subcellCenter) instead of raw SubcellToWorldCenter. This makes the cached spawn world position, cached route plan start, and authored spawn level agree for connector-routeable spawn subcells before EnemyUnit initialization. Verification after this change: dotnet build passed; Unity MCP validate_script passed for EnemyPathService.cs and EnemyUnit.cs.
