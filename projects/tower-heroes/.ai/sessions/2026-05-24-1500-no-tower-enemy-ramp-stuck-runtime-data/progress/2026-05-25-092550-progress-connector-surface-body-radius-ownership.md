# Connector Surface Body-Radius Ownership

## Runtime Evidence

The latest runtime samples were current compiled code, not stale code:

- `PF_Enemy_Nastia`: `same_level_connector_body_blocked:L0:(57,30)`, position `(3.51,-2.09)`, `CurrentSurfaceLevel=0`, `NextPathPointIndex=1`, alternate route level L1 body-clear.
- `PF_Enemy_Ivanna`: `same_level_connector_body_blocked:L1:(55,31)`, position `(0.91,0.00)`, `CurrentSurfaceLevel=1`, `NextPathPointIndex=2`, alternate route level L0 body-clear.

Both failures happened at connector-owned body-clear around the ramp entry/exit footprint. The connector lane center was routeable, but the body radius overlapped adjacent connector-footprint subcells not owned by the traversal surface.

## Change

Connector runtime-data generation now builds traversal surface ownership with the configured minimum navigation body radius, clipped to the authored connector footprint. This keeps center movement restricted to routeable lane/portal subcells while allowing connector-owned clearance to include the legal body footprint around the lane.

Changed files:

- `Assets/_Project/Scripts/GridSystem/Elevation/ElevationConnectorTraversalSurfaceBuilder.cs`
- `Assets/_Project/Scripts/GridSystem/Elevation/ElevationConnectorAuthoring.cs`
- `Assets/_Project/Scripts/GridSystem/Elevation/ConnectorNavigationLineBuilder.cs`
- `Assets/_Project/Scripts/GridSystem/GameplayMapInstaller.cs`
- `Assets/_Project/Scripts/GridSystem/GameplayStaticObstacleBlockSource.cs`
- `Assets/_Project/Scripts/Rendering/GameplayRampNavigationLineController.cs`

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore`: passed with the existing `System.Net.Http` and `System.IO.Compression` warnings.
- Unity script validation: changed scripts passed with no errors.
- Unity console after refresh: 0 errors.

Runtime no-tower ramp traversal from both spawn directions still needs a Play-mode pass.
