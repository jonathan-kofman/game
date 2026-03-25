# GDD: Physics Interaction Layer

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 7 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: Godot Jolt Physics (engine)
> **Required By**: Physics Tool System, Base Building System

---

## 1. Overview

The Physics Interaction Layer defines the contract between the game's gameplay
systems and Godot's Jolt physics engine. It specifies which objects are
"physics objects" (interactable by tools), what properties they must expose,
how gravity and velocity are managed, and what the Jolt-specific quirks are
that every system must account for. It is not a runtime system — it is a
design contract enforced through a base class and collision layer conventions.

---

## 2. Player Fantasy

The world feels physically real. When a tool acts on an object, the object
responds with believable weight, momentum, and chaos. Every object the player
can see can be interacted with — there are no invisible physics barriers or
mysteriously immovable objects.

---

## 3. Detailed Rules

### 3.1 What Makes a Physics Object

An object is a physics object if and only if it:
1. Is a `RigidBody3D` node
2. Has the `physics_object` collision layer bit set (layer 2)
3. Has a `PhysicsObject` script attached (see 3.2)

`StaticBody3D` nodes (walls, floor, terrain) are **not** physics objects and
cannot be targeted by tools.

### 3.2 PhysicsObject Base Script

Every physics object attaches `scripts/core/physics_object.gd`, which:
- Exposes `original_gravity_scale: float` — cached on `_ready()` for restoration
- Exposes `is_gravity_flipped: bool` — true when gravity_scale is negative
- Exposes `is_time_slowed: bool` — true when under time slow effect
- Emits `physics_state_changed(body: RigidBody3D)` when any tool state changes

The Physics Tool System writes to these properties. Other systems (VFX, Audio)
read them without touching physics internals directly.

### 3.3 Collision Layers

| Layer | Name | Used By |
|-------|------|---------|
| 1 | `world` | StaticBody3D walls, floor, terrain |
| 2 | `physics_objects` | All RigidBody3D physics objects |
| 3 | `player` | CharacterBody3D player |
| 4 | `enemies` | Enemy CharacterBody3D nodes (future) |
| 5 | `triggers` | Area3D volumes (extraction zones, hazards) |

Tools use layer masks to query only `physics_objects` (layer 2).
The player RayCast3D targets layers 2 + 1 (can aim at objects and walls).

### 3.4 Jolt Physics — Known Behaviours

These are Jolt-specific quirks that differ from Godot's legacy physics:

| Behaviour | Detail | Impact on Systems |
|-----------|--------|-------------------|
| **Sleep / deactivation** | Resting RigidBody3D nodes are put to "sleep" to save CPU. Velocity reads as zero while sleeping. | Time Slow must call `sleeping = false` on all bodies before applying velocity changes, or changes will have no visible effect. |
| **gravity_scale latency** | Changes to `gravity_scale` take effect next physics frame, not the current one. | Gravity Flip will show a 1-frame delay before the object starts moving in the new direction. Acceptable for MVP. |
| **Discrete collision** | Jolt uses speculative CCD by default. Fast-moving objects (Force Push at high speed) may still tunnel through thin walls. | Keep wall thickness ≥ 0.2 m and Force Push impulse ≤ 50N to avoid tunnelling. |
| **Continuous sync** | MultiplayerSynchronizer syncs transform, not velocity. Velocity must be synced separately via @rpc. | Networking Layer design must account for this (not MVP scope). |

### 3.5 Mass and Default Properties

All physics objects use default mass unless explicitly overridden:

| Property | Default | Notes |
|----------|---------|-------|
| `mass` | 1.0 kg | Boxes and spheres in test room |
| `gravity_scale` | 1.0 | Positive = falls down |
| `linear_damp` | 0.0 | No drag by default |
| `angular_damp` | 0.0 | No rotational drag by default |
| `physics_material` | default | Friction 1.0, bounce 0.0 |

---

## 4. Formulas

### Force Push Impulse → Velocity

```
impulse = F * direction   (Vector3, applied via apply_central_impulse)

resulting_velocity ≈ impulse / mass
                   = F / 1.0 kg
                   = F m/s  (for default 1kg objects)

Example: F=12N → ~12 m/s initial velocity
```

### Gravity Flip

```
new_gravity_scale = -abs(original_gravity_scale)
                  = -1.0   (for default objects)

acceleration = gravity_scale * world_gravity
             = -1.0 * -9.8
             = +9.8 m/s² upward
```

### Time Slow (production approach — replaces prototype velocity scaling)

```
# Instead of velocity snapshot, scale gravity to create the slow effect:
rb.gravity_scale = original_gravity_scale * TIME_SLOW_FACTOR
rb.linear_damp   = HIGH_DAMP_VALUE  (e.g. 8.0) to bleed off existing velocity

# On release:
rb.gravity_scale = original_gravity_scale
rb.linear_damp   = 0.0

TIME_SLOW_FACTOR = 0.15  (starting value — tune upward per prototype finding)
HIGH_DAMP_VALUE  = 8.0   (bleeds momentum rapidly without snapping to zero)
```

This approach works even on sleeping bodies because changing `gravity_scale`
wakes them via Jolt's activation system.

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Tool targets a StaticBody3D | RayCast3D check: `if not target is RigidBody3D → ignore`. Feedback text shown. |
| Physics object falls out of the room | Reset to nearest spawn point or simply respawn at original position after 3s below floor threshold (y < -5.0). |
| Object is time-slowed AND gravity-flipped simultaneously | Both effects apply independently. gravity_scale is set by whichever tool acted last — tools must preserve each other's state via PhysicsObject flags. |
| Object is force-pushed while time-slowed | Impulse is applied at full strength. The high linear_damp of time slow will bleed the velocity off slowly — this creates the "slow bullet" visual feel. Intentional. |
| Two players target the same object with different tools simultaneously (co-op) | Server-authoritative — server processes one at a time. No conflict resolution needed on client. |
| Physics object tunnels through a wall at high speed | Acceptable for MVP. Reduce Force Push impulse if it occurs frequently. Wall thickness 0.2m minimum. |

---

## 6. Dependencies

- **Depends on**: Godot Jolt Physics (engine, no code dependency)
- **Required by**:
  - Physics Tool System (reads and writes RigidBody3D properties via PhysicsObject API)
  - Visual Effects & Juice System (reads `is_gravity_flipped`, `is_time_slowed` for particle effects)
  - Base Building System (physics-simulated structures use the same RigidBody3D contract)
  - Networking Layer (must sync RigidBody3D state using conventions defined here)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| Default object mass | physics_object.gd | 1.0 kg | 0.5–10.0 | Affects how far force push moves objects |
| TIME_SLOW_FACTOR | physics_tools.gd | 0.15 | 0.05–0.5 | How slow "slow" is — prototype found 0.15 too subtle; increase |
| HIGH_DAMP_VALUE | physics_tools.gd | 8.0 | 4.0–20.0 | How quickly time-slowed objects bleed momentum |
| FORCE_PUSH_IMPULSE | physics_tools.gd | 12.0 N | 5.0–30.0 | Prototype at 18N was too strong; 12N is new starting point |
| Wall minimum thickness | scene design | 0.2 m | 0.2+ | Below this, fast objects may tunnel |

---

## 8. Acceptance Criteria

- [ ] A resting (sleeping) RigidBody3D reacts to time slow without requiring it to already be in motion
- [ ] Gravity flip shows visual movement within 2 frames of G key press
- [ ] Force push at 12N moves a 1kg box to the opposite wall of a 10m room without tunnelling
- [ ] `is_gravity_flipped` and `is_time_slowed` flags on PhysicsObject accurately reflect current state
- [ ] Tools never read `gravity_scale` directly — they always go through PhysicsObject API
- [ ] Collision layers 1–5 are configured in project.godot with correct names
