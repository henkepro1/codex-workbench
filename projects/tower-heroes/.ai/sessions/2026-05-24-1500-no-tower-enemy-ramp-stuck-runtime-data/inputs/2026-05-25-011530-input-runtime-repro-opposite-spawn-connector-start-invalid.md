# Runtime repro opposite spawn connector start invalid

Date: 2026-05-25T01:15:30+02:00
Kind: input
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

User reported same invalid current surface level failure for PF_Enemy_Ivanna from the opposite random spawn. Runtime data: Context=blocked_overlap_resolution, CurrentSurfaceLevel=L1, Position=(0.91,0.00), NextCheckpointIndex=1, NextPathPointIndex=2, same-level segment L1->L1, RouteLevelBodyClear L1 false and L0 true, rejection same_level_connector_body_blocked:L1:(55,31). MCP snapshot confirmed spawnPointIndex=0, current route wp0 on L1:(54,30) was connector-owned blocked, while later same-connector route points wp1/wp2 were connector-owned clear.
