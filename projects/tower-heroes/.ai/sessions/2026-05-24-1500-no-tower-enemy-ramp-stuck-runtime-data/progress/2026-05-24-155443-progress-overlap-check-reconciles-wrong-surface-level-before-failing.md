# Overlap check reconciles wrong surface level before failing

Date: 2026-05-24T15:54:43+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Live resolver returned level 0 for the stuck Ivanna, but ResolveBlockedSubcellOverlaps threw before route refresh could use that resolver. Patched ResolveBlockedSubcellOverlaps to apply a body-clear level from the current route's explicit levels and return true so the normal route refresh rebuilds from that level. Also changed body-clear level candidates to use current/segment/current-route world point levels, removing arbitrary +/- adjacent levels to avoid selecting hidden level -1.
