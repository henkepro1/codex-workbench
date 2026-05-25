# Removed premature pre-progress ramp surface fail-fast

Date: 2026-05-25T00:38:41+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Runtime stuck repro after connector-authority patch produced pre_path_progress fail-fast before movement: PF_Enemy_Nastia at (3.51,-2.10), active segment L0->L0, L0 body blocked by L0:(57,30), same XY body-clear on L1. The issue was the new connector-authority validation firing before AdvancePathProgress and before canonical movement had a chance to move along the connector segment. Removed the pre_path_progress and post_path_progress reconciliation calls; connector-authority reconciliation remains after actual movement and inside blocked-overlap handling without route refresh.
