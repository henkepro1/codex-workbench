# Runtime still fails after connector guide margin patch

Date: 2026-05-24T15:10:10+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Live no-tower run after increasing connector guide inside margin still produces EnemyUnitStallRecovery.EnsureRouteableRepathOrigin failures. Current positions are on connector routeable ramp subcells but bodyClear is false near adjacent blocked row cells, especially L1 row 30/31 and L0 row 29/30 around connector.l0_to_l1.ramp. Next step is to dump connector routeable/blocked/guide data while Play remains running.
