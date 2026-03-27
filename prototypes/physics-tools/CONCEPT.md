---
status: reverse-documented
source: prototypes/physics-tools/
date: 2026-03-26
verified-by: Prototype playtest (2026-03-25)
---

# Concept Document: Physics Tools

> **Note**: Reverse-engineered from prototype code and playtest report.
> Captures validated feel and technical insights to inform the production
> Physics Tool System design. Do not migrate prototype code — rewrite to standards.

## Core Mechanic

Three targeted physics tools usable in first-person: **Gravity Flip** (per-object
gravity reversal), **Time Slow** (area-of-effect velocity reduction), and **Force
Push** (instant impulse on a targeted object). The 30-second loop: aim → activate
→ watch physics react.

## Player Fantasy

The player feels like a physicist with godlike control over the environment —
flicking gravity, freezing time, blasting objects. The fantasy is "casual
omnipotence": tools respond instantly, physics reactions are legible and dramatic,
and no tutorial is needed.

## What Was Prototyped

**Tool 1: Gravity Flip**
- Targeted via raycast; toggleable per-object
- Flips `gravity_scale` to negative; second activation restores
- Duration: permanent toggle (`GRAVITY_FLIP_DURATION = 0.0`)
- Supports multiple simultaneous flipped objects

**Tool 2: Time Slow**
- Area-of-effect (6m radius sphere overlap centered on player)
- Per-body: scales `gravity_scale × 0.15` and velocity `× 0.15`
- Toggle on/off; releasing restores velocity (divides by factor)
- Does NOT use `Engine.time_scale` — isolates effect to physics objects only

**Tool 3: Force Push**
- Targeted via raycast; instant, no toggle
- `apply_central_impulse` in collision normal direction at 18N

**Player Controller**
- FPS CharacterBody3D, WASD + mouse look
- Raycast from camera; crosshair highlights valid physics targets (cyan)
- Tools bound to G / T / F keys

## Emergent Gameplay Patterns Observed

| Combo | Description | Potential |
|-------|-------------|-----------|
| Gravity + Push | Flip object → push it horizontally — flies at ceiling height without falling | Spatial puzzle / traversal |
| Slow + Push | Slow objects → push one through others — predictable, controlled chaos | Skill expression |
| Triple combo | Gravity flip → slow → push — "sniper shot" moment, one dramatic outcome | Signature move |
| Stack disruption | Flip bottom object in a stack → satisfying cascade collapse | Environmental destruction |

Combo loop was **voluntarily replayed 10 times** with no progression or reward
structure — confirms intrinsic fun.

## What Worked

| Finding | Detail |
|---------|--------|
| Gravity Flip feel | Immediate, satisfying — strong positive response |
| Force Push feel | Strong kinetic satisfaction even at 18N (too high, but felt powerful) |
| Triple combo | "Cool" — the sequence itself is the reward |
| Core loop duration | 30-second aim→activate→react loop holds attention without reward |
| Replayability | "Wants to keep playing but needs more" — strong foundation |

## What Didn't Work / Needs Retesting

| Issue | Root Cause | Mitigation |
|-------|-----------|------------|
| Time Slow had no visible effect | **Jolt Physics sleeps resting RigidBody3D objects** — velocity scaling does nothing on sleeping bodies | Retest with objects in motion (ramps, dropped objects); wake bodies before slowing in production |
| Force Push 18N too strong | 1kg box launched too far | Sweet spot likely 8–12N; consider hold-to-charge |
| Mouse feel degraded | Tested in Godot editor preview window (unreliable mouse capture) | Future playtests: exported build or maximized Project > Run |
| Time Slow inconclusive | Couldn't evaluate feel when nothing visibly changed | Needs dedicated retest before production design is committed |

## Technical Feasibility

**Confirmed feasible:**
- Per-body `gravity_scale` manipulation — works cleanly with Jolt
- Raycast targeting with crosshair feedback — low cost, high clarity
- `PhysicsShapeQueryParameters3D` sphere overlap for AoE — fine for prototype

**Confirmed problematic:**
- Velocity snapshot for time slow — does not work on sleeping bodies;
  produces inconsistent results; do not carry this approach forward
- All tools in one script — works for prototype, unacceptable for production

**Production architecture required:**
- `BaseTool` class — one GDScript file per tool, shared interface
- Time Slow: wake bodies before slowing, or use per-body drag/gravity scaling
  instead of velocity snapshot
- Audio feedback — silence makes interactions feel weightless
- Visual indicators: gravity flip needs particle trail / color tint; force push
  needs shockwave VFX + screen shake
- Networking: all activations server-authoritative; `@rpc` + `MultiplayerSynchronizer`
- Performance: cache or event-drive the sphere overlap query; target 20+ slowed
  objects at 60fps on mid-range hardware

## Scope Considerations

| Option | Rationale |
|--------|-----------|
| Limit gravity flip to one object at a time | Reduces networked state complexity |
| Hold-to-charge force push | Variable strength adds skill expression |
| Time slow as limited resource (cooldown / energy) | Adds strategic depth; prevents hold-and-forget |

## Recommendation

**PROCEED** to production implementation of the Physics Tool System.

- **Gravity Flip** and **Force Push**: validated as satisfying — implement first.
- **Time Slow**: requires a **retest with moving objects** before committing to
  production design. The prototype implementation is architecturally invalid.
- Rewrite from scratch to production standards — do not migrate prototype code.

## Follow-Up Actions

- [ ] Retest Time Slow with ramps / falling objects in motion
- [ ] Design production `BaseTool` interface (ADR recommended)
- [ ] Tune Force Push to 8–12N range in production
- [ ] Evaluate hold-to-charge Force Push as scope option
- [ ] Evaluate time slow as limited resource (energy/cooldown)
- [ ] Add Jolt sleep-waking strategy to Time Slow production design
- [ ] Run `/design-review` on `design/gdd/physics-tool-system.md` using these findings
