# Root cause candidate connector guides are point-valid but body-invalid

Date: 2026-05-24T15:04:17+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Analysis from live no-tower repro and source inspection:

The ramp guide points are generated in ElevationConnectorAuthoring.ResolveTraversalGuideWorldPointForSubcell. The current clamp uses insideMargin = max(0.005, subcellSize * 0.05). With subcellSize=0.5, that is only 0.025 world units from a subcell boundary.

Live enemies on the upper ramp lane are routed through guide points around y=-0.04 to y=-0.07 in subcells L1:(55,30)/L1:(56,30). The blocked row above begins at y=0.00. Enemies have compressed radii up to 0.1, so following the generated guide line puts their body circle into blocked subcells L1:(55,31)/L1:(56,31) even though their center subcell is routeable and canRoute=true.

This explains the visible ramp throttling: movement is trying to follow a connector guide line that is point-valid but body-invalid. Some enemies compress enough to barely pass; others stall or trigger repath failure. This is wrong route/connector geometry logic, not a stall-recovery problem.

Proposed root fix: make connector traversal guide points maintain body-clearance margin inside each paired subcell. For the current grid, the margin must be >= 0.1 world units, so use a subcell-relative clearance margin rather than the old 5% containment-only margin. This changes guide generation, not runtime snapping/teleporting.
