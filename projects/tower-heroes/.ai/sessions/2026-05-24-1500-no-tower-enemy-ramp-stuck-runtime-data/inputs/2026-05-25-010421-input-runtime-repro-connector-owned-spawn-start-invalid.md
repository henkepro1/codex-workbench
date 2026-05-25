# Runtime repro connector-owned spawn start invalid

Date: 2026-05-25T01:04:21+02:00
Kind: input
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

User reported the repeated runtime error: PF_Enemy_Nastia fails in blocked_overlap_resolution at NextPathPointIndex=1 with currentSurfaceLevel L0. Live MCP snapshot showed spawnPointIndex=1, route wp0=(3.51,-2.09) on L0:(57,29), wp1=(3.68,-2.21) on the same connector, generic/body-clear by route level L0 false and L1 true, and connector-owned clearance for wp0 false blocked by L0:(57,30) while wp1 was connector-owned clear. This proves the invalid state is created at connector-routeable spawn/route start, before movement.
