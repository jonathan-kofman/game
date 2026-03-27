# Prototype Concept: Physics Tools

> **Prototype ID**: physics-tools
> **Date**: 2026-03-25
> **Status**: COMPLETE — verdict PROCEED
> **Full report**: [REPORT.md](REPORT.md)

## Hypothesis

Three physics tools — Gravity Flip, Time Slow, Force Push — will each feel
satisfying in isolation AND create interesting emergent combos when combined.
The 30-second loop (aim → activate → watch physics react) will be intrinsically
fun without any progression, story, or reward structure.

## What Was Built

A first-person test room in Godot 4.6 with Jolt Physics. Three tools mapped to
G/T/F. 10–15 RigidBody3D objects in the room. No UI, no audio, no networking.

**Files:**
- `scripts/physics_tools.gd` — all three tools in one prototype script
- `scripts/player.gd` — minimal FPS controller + input routing
- `scripts/physics_object.gd` — random-color RigidBody3D component

## Result

PROCEED. Gravity flip and force push both produced positive feel responses.
Combo loop was replayed 10 times voluntarily with no reward structure.
Time slow could not be properly evaluated — Jolt puts resting bodies to sleep,
so velocity scaling had no visible effect (see known issue below).

## Key Findings

| Finding | Impact |
|---------|--------|
| Core loop is intrinsically fun (replayed 10× with no reward) | Confirms Physics Tool System is worth building |
| Jolt Physics sleeps resting RigidBody3Ds — velocity scaling is invisible | Time Slow must use gravity/damp scaling instead, and must wake bodies first |
| Force push at 18N is too strong for 1kg objects | Production starting point: 12N |
| Mouse capture in editor preview degraded feel test | Future playtests: run exported build |

## Production Differences

The production implementation (`src/scripts/tools/`) differs from this prototype:

| Prototype | Production |
|-----------|------------|
| All tools in one `physics_tools.gd` | One script per tool, `BaseTool` base class |
| Velocity scaling for time slow | `gravity_scale` + `linear_damp` scaling (wakes sleeping bodies) |
| Hardcoded tuning values | `@export` vars — editor-adjustable |
| No audio or VFX | `tool_activated` / `tool_deactivated` signals for Audio/VFX systems |
| No collision layer filter | Layer 2 (`physics_objects`) mask enforced |

## Known Issues (Prototype Only)

- Time Slow unverified — needs retest with moving objects (S5-07: ramp test scene)
- No audio feedback — silence makes interactions feel weightless
- No visual feedback on gravity-flipped objects
