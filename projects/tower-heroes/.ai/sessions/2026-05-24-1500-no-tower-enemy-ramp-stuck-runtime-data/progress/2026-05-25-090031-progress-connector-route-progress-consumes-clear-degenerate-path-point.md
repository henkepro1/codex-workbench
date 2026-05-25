# Connector route progress consumes clear degenerate path point

Date: 2026-05-25T09:00:31+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented the degenerate connector segment root fix in D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assets\_Project\Scripts\Waves\EnemyUnitMovement.cs.

HasReachedRoutePathPoint now resolves connector-routeable path points through connector-owned body clearance before generic body-clear. Zero-length connector route path points advance only when the current position is connector-owned clear for the mapped connector and level; if not clear, the code fails fast with route point diagnostics instead of allowing movement constraints to receive a degenerate active segment.

TryResolveActiveConnectorRouteableSegment now fail-fasts before accepting a same-level connector routeable segment with identical start/end world points. The diagnostic includes nextPathPointIndex, route point indices, start/end subcells, segment level, connector id, current/segment connector-owned clearance, blocking subcells, and nearby route world points.

Verification: dotnet build Assembly-CSharp.csproj --no-restore passed with existing MSB3277 warnings; Unity MCP validate_script passed for EnemyUnitMovement.cs with 0 diagnostics; Unity console reported 0 errors. Runtime snapshot was not available because Unity Application.isPlaying=false. Still requires fresh no-tower ramp traversal validation from both spawn directions and narrow tower-built passage validation in Play mode.
