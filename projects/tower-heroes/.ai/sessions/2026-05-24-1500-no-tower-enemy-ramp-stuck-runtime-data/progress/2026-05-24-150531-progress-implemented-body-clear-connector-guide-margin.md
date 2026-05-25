# Implemented body-clear connector guide margin

Date: 2026-05-24T15:05:31+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented root-fix candidate in D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assets\_Project\Scripts\GridSystem\Elevation\ElevationConnectorAuthoring.cs.

Change: connector traversal guide inside margin changed from max(0.005, subcellSize * 0.05) to max(0.005, subcellSize * 0.22). On the current 0.5 subcell grid this moves ramp guide points at least 0.11 world units away from subcell boundaries, enough for 0.1 body radius clearance. This targets the root data issue where ramp guides were point-valid but body-invalid near blocked shoulder cells.

Verification so far: dotnet build Assembly-CSharp.csproj --no-restore succeeded with existing MSB3277 warnings only; Unity validate_script for ElevationConnectorAuthoring.cs returned 0 diagnostics.

Next runtime validation: fresh Play run, no towers built, spawn same enemies and check whether upper-ramp cluster stops throttling and no longer shows bodyClear=false at L1:(55,30)/L1:(56,30) guide positions.
