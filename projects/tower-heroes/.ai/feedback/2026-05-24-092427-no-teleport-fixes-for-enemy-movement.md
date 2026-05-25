---
id: 2026-05-24-092427-no-teleport-fixes-for-enemy-movement
created_at: 2026-05-24T09:24:27+02:00
scope: project
applies_to: tower-heroes
---

# Feedback: No teleport fixes for enemy movement

## Rule

Enemy movement bugs must not be fixed by teleporting, snapping, ghosting, disabling collision, bypassing blockers, or moving enemies through invalid space. Fix the route, level, connector, collision, or constraint root cause instead.

## Why

Teleport-style fixes violate Tower Heroes movement rules and hide the deterministic stuck-state bug instead of solving it.

## When To Apply

Apply before changing enemy movement, stall recovery, connector traversal, route refresh, overlap resolution, or narrow-passage behavior.

## Source

user feedback
