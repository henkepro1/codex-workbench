# Repath level selection now checks adjacent body-clear runtime levels

Date: 2026-05-24T15:48:38+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Runtime dump after the prior patch showed PF_Enemy_Ivanna at (0.91,-0.004), CurrentSurfaceLevel=1, with bodyClear=false on L1 and bodyClear=true on L0. The rebuilt route had wp0 L1 bodyClear=false and wp1-> onward clear. Updated ResolveRepathStartLevel to choose only explicit body-clear runtime levels, checking current level, active segment levels, and adjacent runtime levels. This keeps the selection explicit and does not move/teleport the enemy.
