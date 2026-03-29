# GDD: Enemy & Hazard System

> **Status**: Draft
> **Created**: 2026-03-27
> **System ID**: 16 (see systems-index.md)
> **Priority**: Vertical Slice
> **Depends On**: Character Controller, Health & Death System, Physics Tool System,
>                 Physics Interaction Layer, Escalation System
> **Required By**: HUD, Audio System, Visual Effects & Juice System, Solo/Co-op Scaling System

---

## 1. Overview

The Enemy & Hazard System introduces active opposition to breach missions. For the
Vertical Slice, it defines one enemy archetype (the Patrol Guard) and two hazard
types (the Alarm Laser and the Pressure Plate). The Patrol Guard is a
`CharacterBody3D` that walks a fixed route and transitions into a detection-and-pursuit
state when it sees a player within line-of-sight. Guards call in alerts that feed
the Escalation System's pressure accumulation. The Alarm Laser is a static
beam-segment that triggers an immediate escalation pressure spike and an audio alarm
when any player body crosses it. The Pressure Plate is an `Area3D` trigger that
activates on any body (player or physics object) and is the only hazard that can
be defeated through clever tool use without triggering escalation. All three physics
tools interact with guards and hazards in ways that reward experimentation: guards
can be stunned by Force Push, slowed by Time Slow, and repositioned by Gravity Flip;
the Pressure Plate can be held down indefinitely by a Force-Pushed crate; the
Alarm Laser can be crossed safely while Time Slow is active via tool combo setup.
The system is designed to be server-authoritative to support future co-op
networking, with all guard state machines and hazard triggers driven on the server
and results broadcast to clients.

---

## 2. Player Fantasy

The player feels like a precision infiltrator who turns the facility's own physics
against its security. An alert guard is not a wall to run past — it is a puzzle to
solve. Gravity-flipping a guard off its patrol route, then force-pushing a crate
onto a pressure plate to hold it silent, then slow-walking under the laser with
time frozen: each solution feels authored by the player, not the game. Failing a
hazard check — tripping the laser, stepping on the plate accidentally — should
create a spike of controlled panic: not "I died unfairly" but "I made a mistake
and now the clock is faster." The system primarily serves the MDA aesthetic of
Challenge (mechanical mastery, environmental reading) and Fantasy (stealth
operative fantasy, physics power fantasy), with secondary Discovery (finding
tool-hazard combos the tutorial never showed you).

---

## 3. Detailed Rules

### 3.1 Entity Inventory (Vertical Slice Scope)

| Entity | Type | Node Class | Count per Run |
|--------|------|------------|---------------|
| Patrol Guard | Enemy | `CharacterBody3D` | 2–4 (tunable) |
| Alarm Laser | Hazard | `StaticBody3D` + `Area3D` | 1–3 (tunable) |
| Pressure Plate | Hazard | `StaticBody3D` + `Area3D` | 1–2 (tunable) |

"Count per run" is the default seeded by the procedural generator. Counts are
tuning knobs, not hard limits.

---

### 3.2 Patrol Guard

#### 3.2.1 Node Structure

```
PatrolGuard (CharacterBody3D)  [patrol_guard.gd]
├── CollisionShape3D            (CapsuleShape3D, height=1.8, radius=0.4 — identical to player)
├── NavigationAgent3D           (for pathfinding along patrol route)
├── DetectionRayCast3D          (RayCast3D, length=DETECTION_RANGE, cast_to=(0,0,-DETECTION_RANGE))
├── DetectionArea (Area3D)      (SphericalCollisionShape3D, radius=DETECTION_RADIUS)
│   └── CollisionShape3D
└── HealthComponent             (same script as player: health_component.gd)
```

The guard uses the same `health_component.gd` as the player. It is instantiated with
`MAX_GUARD_HP` (not `MAX_HP`). All damage callbacks work identically.

The guard is a **placeholder visual**: a capsule `MeshInstance3D` with a solid color
material. No animation system is required. Color changes on state transition
communicate state to the player (see 3.2.5).

#### 3.2.2 Patrol Route

Each guard is assigned a `patrol_route: Array[Vector3]` of world-space waypoints at
scene instantiation time. The procedural generator assigns routes from the room
template's exported patrol point list (see Room Template Data System). The guard
cycles through waypoints in order, looping back to index 0 after the last point.

- Movement speed in patrol state: `GUARD_PATROL_SPEED` (default 2.5 m/s).
- The guard uses `NavigationAgent3D.set_target_position()` for each waypoint and calls
  `move_and_slide()` each physics frame.
- If `NavigationAgent3D` cannot find a path to the next waypoint (nav mesh gap), the
  guard stands still at current position and tries again after `PATROL_STUCK_RETRY`
  seconds (default 2.0 s). This is the nav-mesh fallback; it does not trigger a state
  change.

#### 3.2.3 State Machine

The guard has four states managed in `patrol_guard.gd` as a GDScript enum:

```
enum GuardState { PATROL, ALERT, PURSUE, STUNNED }
```

State transition table:

| From State | Trigger | To State | Action on Entry |
|------------|---------|----------|-----------------|
| PATROL | LOS confirmed (see 3.2.4) | ALERT | Start `ALERT_BUILDUP_TIME` timer; play alert VFX |
| ALERT | Timer expires AND LOS still confirmed | PURSUE | Emit `guard_alerted` signal |
| ALERT | LOS lost before timer expires | PATROL | Resume patrol from current position |
| PURSUE | Player distance > `PURSUIT_GIVE_UP_RANGE` for `PURSUIT_GIVE_UP_TIME` s | PATROL | Resume patrol |
| PURSUE | Guard HP reaches 0 | STUNNED | Emit `guard_stunned` signal |
| STUNNED | `STUN_DURATION` timer expires | PATROL | Restore HP to `STUN_RECOVERY_HP`; resume patrol |
| Any | Force Push impact (see 3.6.2) | STUNNED | Interrupt current state immediately |
| Any | Gravity Flip applied (see 3.6.1) | (no state change) | Guard floats — see 3.6.1 |

There is no DEAD state. Guards do not permanently die in Vertical Slice. They stun
and recover. Permanent death is Full Vision scope.

#### 3.2.4 Detection: Line-of-Sight + Proximity

Detection uses a **two-stage gate**:

**Stage 1 — Proximity Check (continuous):**
`DetectionArea` (Area3D sphere, radius `DETECTION_RADIUS` = 8.0 m) passively overlaps
player bodies. When a player enters `DetectionArea.body_entered`, the guard begins a
`DetectionRayCast3D` check on every `_physics_process` frame for that player.

When the player exits `DetectionArea`, the guard stops raycasting for that player.

**Stage 2 — Line-of-Sight Raycast (per-frame while in detection area):**
`DetectionRayCast3D` is rotated each physics frame to point from the guard's head
position (`global_position + Vector3(0, 1.6, 0)`) toward the target player's position.
The ray uses collision layer 1 (world geometry) and layer 4 (players) only.

LOS is **confirmed** when ALL of the following are true simultaneously:
1. The raycast hits a collider on layer 4 (a player body).
2. The horizontal angle between the guard's forward vector and the direction to the
   player is within `DETECTION_CONE_DEGREES` / 2 (default 70 degrees half-angle, i.e.,
   140-degree total forward cone).
3. The player's escalation-state modifier is not zero (the player is not using a
   "stealth" tool — there are no stealth tools in Vertical Slice, so this is always
   true in VS scope; it is documented here for Alpha scope compatibility).

LOS is **not** blocked by other guards. Only world geometry on layer 1 blocks LOS.

**Why Two-Stage:** The `DetectionArea` is a cheap broadphase that limits the number
of per-frame raycasts. Without it, every guard would raycast toward every player every
frame regardless of distance.

#### 3.2.5 State Visual Cues (Placeholder)

Since there is no animation system, color material on the guard capsule indicates state:

| State | Capsule Color |
|-------|--------------|
| PATROL | Grey (`#808080`) |
| ALERT | Yellow (`#FFD700`) |
| PURSUE | Red (`#FF2200`) |
| STUNNED | Dark blue (`#1A1AFF`) |

Color is set via `get_node("MeshInstance3D").material_override.albedo_color = color`.
The `MeshInstance3D` must use a non-shared `StandardMaterial3D` (set `local_to_scene = true`).

#### 3.2.6 Guard Pursuit Movement

In PURSUE state:
- `NavigationAgent3D.set_target_position(player.global_position)` is called every
  `PURSUE_UPDATE_INTERVAL` seconds (default 0.25 s) — not every frame, to reduce
  nav-mesh query cost.
- Movement speed: `GUARD_PURSUE_SPEED` (default 4.5 m/s).
- Guard does not attack in Vertical Slice. It only closes distance, maintaining
  `PURSUE_EMIT_PROXIMITY_DISTANCE` (default 1.5 m) minimum distance from player.
- If guard reaches `PURSUE_EMIT_PROXIMITY_DISTANCE`, it emits `guard_reached_player`
  signal once per contact (not continuously). The Escalation System listens to this
  signal and applies `GUARD_CONTACT_PRESSURE` pressure (default +40, same magnitude as
  `enemy_alerted`). The guard does not deal direct damage in Vertical Slice.

---

### 3.3 Alarm Laser

#### 3.3.1 Node Structure

```
AlarmLaser (Node3D)           [alarm_laser.gd]
├── LaserBeam (StaticBody3D)   (thin CylinderShape3D or BoxShape3D along laser axis)
│   └── CollisionShape3D
├── TriggerVolume (Area3D)     (slightly larger volume surrounding the beam)
│   └── CollisionShape3D
├── LaserVisual (MeshInstance3D) (thin cylinder mesh, emissive red material)
└── LaserMount (Node3D)        (origin end of the beam)
```

The `TriggerVolume` is 15% larger in radius than the visible laser beam. This gives
a forgiving detection volume so players feel the laser is slightly larger than it
looks — preventing the degenerate feel of "I clearly didn't touch it." The `LaserBeam`
`StaticBody3D` is present for physical collision (physics objects can rest on it) but
does NOT trigger alarm logic — only the `Area3D` does.

#### 3.3.2 Trigger Conditions

`TriggerVolume.body_entered` fires when any `CharacterBody3D` or `RigidBody3D` enters.
The `alarm_laser.gd` script filters the incoming body:

- If body is on collision layer 4 (player): trigger alarm (see 3.3.3).
- If body is on collision layer 2 (physics object): do NOT trigger alarm. Physics
  objects passing through the laser beam are silent. (This is intentional: players can
  use Force Push to send crates through the laser to test whether it is armed without
  risking an alarm.)
- If body is another guard (layer 3): do NOT trigger alarm. Guards walk through lasers
  on patrol because the lasers are "on their side."

#### 3.3.3 Alarm Sequence

When a player body triggers the laser:

1. `AlarmLaser` emits `laser_triggered(laser_id: int, triggering_player: Node)`.
2. Escalation System receives `laser_triggered` and immediately applies
   `LASER_PRESSURE` pressure points (default +60 — same as `player_detected_by_camera`).
3. `AlarmLaser` transitions to ARMED_TRIGGERED state:
   - Laser visual flashes red at `LASER_FLASH_RATE` Hz (default 4 Hz) for
     `LASER_ALARM_DURATION` seconds (default 8.0 s).
   - After `LASER_ALARM_DURATION`, laser visual returns to steady red (reset to ARMED state).
4. `laser_triggered` is NOT emitted again while the laser is in ARMED_TRIGGERED state
   (the re-trigger lockout prevents repeated pressure spam from a player standing in
   the beam).

#### 3.3.4 Laser States

```
enum LaserState { ARMED, ARMED_TRIGGERED, DISARMED }
```

| State | Visual | Triggers on body_entered? |
|-------|--------|--------------------------|
| ARMED | Steady red emissive | Yes (players only) |
| ARMED_TRIGGERED | Flashing red | No (lockout active) |
| DISARMED | No visual, no collision | No |

The laser cannot be disarmed in Vertical Slice. DISARMED state is defined for Alpha
scope (where tool upgrades may include a disabler). The state is documented now so
the signal contract does not need to change.

#### 3.3.5 Laser Orientation

`AlarmLaser` is placed by the level designer (room template) with `LaserMount` at
the origin and the beam extending along the local +X axis by `LASER_LENGTH` units.
The `CollisionShape3D` inside `TriggerVolume` is a `BoxShape3D` sized to
`(LASER_LENGTH, LASER_DIAMETER * 1.15, LASER_DIAMETER * 1.15)`. `LASER_LENGTH` is
set per-instance as an exported variable; `LASER_DIAMETER` is a class constant (0.05 m).

---

### 3.4 Pressure Plate

#### 3.4.1 Node Structure

```
PressurePlate (StaticBody3D)    [pressure_plate.gd]
├── CollisionShape3D             (BoxShape3D: 1.0m × 0.05m × 1.0m — low, wide trigger)
├── TriggerArea (Area3D)         (BoxShape3D: 1.0m × 0.3m × 1.0m — slightly taller for reliable detection)
│   └── CollisionShape3D
└── PlateVisual (MeshInstance3D) (flat box mesh, 1.0m × 0.05m × 1.0m)
```

The `StaticBody3D` at the root provides a physical floor surface — physics objects
and players can stand on the plate without falling through. The `TriggerArea`
detection volume is taller (0.3 m) than the visual mesh (0.05 m) to ensure
`body_entered` fires even if a physics object is placed on top of the plate rather
than inside it.

#### 3.4.2 Trigger Conditions

The pressure plate triggers when its `TriggerArea` contains at least one body with
sufficient mass or player presence.

- **Players**: Any player `CharacterBody3D` entering the trigger area activates the
  plate immediately. Player "mass" is not simulated — presence alone is sufficient.
- **Physics objects**: Any `RigidBody3D` with `PhysicsObject` script entering the
  trigger area activates the plate. There is no mass threshold in Vertical Slice.
  Any physics object is sufficient.
- **Guards**: Guards (layer 3) do NOT activate the plate. The plate is a security
  system tuned to unauthorized personnel. Guards stepping on plates is a visual only
  (they pass through the `TriggerArea`) — no game event fires.

The plate is ACTIVE while at least one qualifying body overlaps `TriggerArea`.
The plate is INACTIVE when `TriggerArea` contains zero qualifying bodies.

#### 3.4.3 State Transitions and Consequences

```
enum PlateState { INACTIVE, ACTIVE, TRIPPED }
```

| Transition | Trigger | Consequence |
|------------|---------|-------------|
| INACTIVE → ACTIVE | Qualifying body enters `TriggerArea` | Plate depresses visually (Y-translate -0.03 m). No alarm yet. |
| ACTIVE → INACTIVE | Last qualifying body exits `TriggerArea` | Plate rises back. `plate_tripped` signal emitted. Escalation receives `PLATE_PRESSURE` (+40). |
| ACTIVE → TRIPPED | ACTIVE state held for `PLATE_HOLD_ALARM_TIME` seconds | `plate_alarm_triggered` signal emitted. Escalation receives `PLATE_ALARM_PRESSURE` (+60). Plate stays ACTIVE. |
| TRIPPED → ACTIVE | (automatic) | TRIPPED is a sub-state of ACTIVE. Once `plate_alarm_triggered` fires, the plate remains in ACTIVE and will fire TRIPPED again after another `PLATE_HOLD_ALARM_TIME` if still occupied. |

**Key design intent:** The plate fires `plate_tripped` on RELEASE, not on entry.
Stepping onto the plate and immediately jumping off trips the alarm. Staying on the
plate triggers the alarm after `PLATE_HOLD_ALARM_TIME` seconds (default 3.0 s) — this
is the "oh no, I'm standing on it" window where quick thinking (Force Push a crate
onto it to hold it down, then step off) can save the run. The release-trigger design
means a crate placed on the plate before the player steps on it holds the plate down
safely (preventing the release-trip alarm), though the sustained alarm still fires after
3 seconds if a body remains on the plate — this is the intended "correct solution."

Visual states:

| Plate State | Visual |
|-------------|--------|
| INACTIVE | Flat on floor, amber emissive edge |
| ACTIVE | Depressed 0.03 m, green emissive edge (pressure registered — no alarm yet) |
| TRIPPED | Red emissive edge (alarm fired) |

---

### 3.5 Escalation Integration

All three entities communicate with EscalationManager exclusively through signals.
`EscalationManager` is never referenced directly by enemy/hazard scripts —
they emit signals that `EscalationManager` subscribes to. This maintains the
dependency direction: enemy/hazard depends on nothing about escalation's internals.

Signal routing:

| Signal | Emitter | Escalation Response | Pressure Applied |
|--------|---------|---------------------|-----------------|
| `guard_alerted(guard: Node)` | PatrolGuard (ALERT→PURSUE) | `on_guard_alerted()` handler | +40 (`ALERT_PRESSURE`) |
| `guard_reached_player(guard: Node, player: Node)` | PatrolGuard (in PURSUE, on contact) | `on_guard_contact()` handler | +40 (`GUARD_CONTACT_PRESSURE`) |
| `laser_triggered(laser_id, player)` | AlarmLaser (ARMED→ARMED_TRIGGERED) | `on_laser_triggered()` handler | +60 (`LASER_PRESSURE`) |
| `plate_tripped(plate: Node)` | PressurePlate (ACTIVE→INACTIVE release) | `on_plate_tripped()` handler | +40 (`PLATE_PRESSURE`) |
| `plate_alarm_triggered(plate: Node)` | PressurePlate (TRIPPED after hold) | `on_plate_alarm()` handler | +60 (`PLATE_ALARM_PRESSURE`) |

The `EscalationManager.gd` must connect to these signals in `_ready()`. For
server-authoritative networking, signal emission and handler execution happen only
on the server.

The Escalation System's existing `alert_entered` and `hostile_entered` signals
already specify patrol expansion and reinforcement behavior. The enemy/hazard
system activates in response to these level transitions:

| Escalation Level Entered | Enemy/Hazard Response |
|-------------------------|-----------------------|
| CALM | Guards patrol normally. All hazards ARMED. |
| ALERT | Guards increase patrol speed by `ALERT_SPEED_MULTIPLIER` (1.2×). `DetectionRayCast3D` range increases by `ALERT_DETECTION_MULTIPLIER` (1.25×). |
| HOSTILE | `ALERT_BUILDUP_TIME` is bypassed entirely (treated as 0.0 s) for all guards — any guard with LOS confirmed immediately enters PURSUE with no timer. Detection cone widens to `HOSTILE_CONE_DEGREES` (160°). |
| CRITICAL | `CRITICAL` has no additional enemy/hazard modifiers in Vertical Slice — the extraction countdown and overtime damage (defined in Escalation GDD) are sufficient pressure. |

---

### 3.6 Physics Tool Interactions

All three tools interact with guards. Interactions with static hazards (laser,
pressure plate) are covered per-hazard above. This section covers guard interactions only.

#### 3.6.1 Gravity Flip on a Guard

Guards are `CharacterBody3D`, not `RigidBody3D`. Gravity Flip cannot call
`PhysicsObject.set_gravity_flipped()` on them — they have no `PhysicsObject` script.
Instead, `GravityFlipTool.activate()` performs a type check on the target:

- If target has `PhysicsObject` script: normal flip (existing behavior).
- If target has `patrol_guard.gd` script (is a guard): call
  `guard.apply_gravity_flip()` — a custom method on the guard.

`patrol_guard.apply_gravity_flip()`:
1. Sets `guard.up_direction = Vector3.DOWN` on the `CharacterBody3D`.
2. Applies `velocity.y = GUARD_FLIP_LAUNCH_VELOCITY` (default +6.0 m/s — upward
   kick to separate the guard from the floor).
3. Transitions guard to STUNNED state (gravity-flipped guard cannot patrol).
4. After `GRAVITY_FLIP_STUN_DURATION` seconds (default 5.0 s), `up_direction` is
   restored to `Vector3.UP`, guard is returned to PATROL state from its current
   position.
5. Emits `guard_stunned` signal.

The guard does NOT float up indefinitely — `up_direction = Vector3.DOWN` combined
with `move_and_slide()` means the guard walks on ceilings if a ceiling exists
directly above. If no ceiling exists (guard is on the top floor), it rises until it
exits the room and the KillVolume catches it, triggering `HealthComponent.kill()`
and transitioning guard to permanent STUNNED (cannot recover from KillVolume death).

`GravityFlipTool` emits `tool_activated("gravity_flip", guard)` normally — the signal
contract does not change.

#### 3.6.2 Force Push on a Guard

`ForcePushTool.activate()` performs the same type check as Gravity Flip:

- If target has `PhysicsObject` script: normal push impulse.
- If target has `patrol_guard.gd` script: call `guard.apply_force_push(direction, impulse)`.

`patrol_guard.apply_force_push(direction: Vector3, impulse: float)`:
1. Adds a velocity kick: `velocity += direction * impulse * GUARD_PUSH_SCALE`
   where `GUARD_PUSH_SCALE` = 0.6 (guards are heavier than typical 1kg crates —
   same impulse moves them 60% as far).
2. Transitions guard to STUNNED state immediately.
3. `STUN_DURATION` begins. Guard slides along `move_and_slide()` with the added
   velocity (it is still a CharacterBody3D — it decelerates with friction, it does
   not receive physics simulation).
4. Guard velocity decelerates to zero at `GUARD_FRICTION_DECEL` m/s² per frame
   (default 8.0 m/s² — fast stop, guards should not slide forever).
5. Emits `guard_stunned` signal.

Numerical example (using `FORCE_PUSH_IMPULSE` = 12.0 N from Physics Tool GDD):
```
guard_push_velocity = 12.0 * 0.6 = 7.2 m/s
time_to_stop = 7.2 / 8.0 = 0.9 s
distance_slid = 0.5 * 7.2 * 0.9 = 3.24 m
```
A force-pushed guard slides roughly 3 meters before stopping — far enough to
clear a doorway or push off a ledge.

#### 3.6.3 Time Slow on a Guard

`TimeSlowTool` affects all bodies within `TIME_SLOW_RADIUS`. Guards are
`CharacterBody3D` — they do not have `gravity_scale` and are not `RigidBody3D`.

Time Slow on a guard calls `guard.apply_time_slow(factor)`:
1. Sets guard's navigation speed: `GUARD_PATROL_SPEED * factor` and
   `GUARD_PURSUE_SPEED * factor`.
2. Sets `NavigationAgent3D` max_speed to the slowed value.
3. On `TimeSlowTool.deactivate()`, speed is restored to normal.

This means a guard caught in Time Slow moves at `TIME_SLOW_FACTOR` (15%) of normal
speed — slow enough to walk around without triggering ALERT state (guard will still
detect the player but the ALERT_BUILDUP_TIME countdown runs at normal speed, giving
the player more time to act before ALERT transitions to PURSUE).

Time Slow does NOT pause the guard's state machine timers. ALERT_BUILDUP_TIME and
STUN_DURATION continue at real time even while the guard's movement is slowed.

#### 3.6.4 Tool Interaction Matrix Summary

| Tool | Target | Effect | State Change |
|------|--------|--------|-------------|
| Gravity Flip | Guard | Guard floats to ceiling, walks ceiling | → STUNNED (5 s) |
| Gravity Flip | Alarm Laser | No effect (StaticBody3D with no PhysicsObject) | None |
| Gravity Flip | Pressure Plate | No effect (StaticBody3D with no PhysicsObject) | None |
| Force Push | Guard | Guard slides ~3 m, stunned | → STUNNED (STUN_DURATION) |
| Force Push | Alarm Laser | No effect (StaticBody3D) | None |
| Force Push | Crate near plate | Crate enters TriggerArea, holds plate ACTIVE | Plate stays ACTIVE |
| Time Slow | Guard | Guard moves at 15% speed | No state change |
| Time Slow | Alarm Laser | No effect (StaticBody3D) | None |
| Time Slow | Physics objects near laser | Physics objects slow but laser still triggers on player | None |

---

### 3.7 Server Authority Note

All guard AI state machines, escalation signal emissions, and hazard trigger logic
execute exclusively on the server (or host in listen-server mode). For Vertical Slice
(no networking), this constraint is trivially satisfied — there is only one instance.
For future co-op networking integration:

- `PatrolGuard` and `AlarmLaser` and `PressurePlate` scripts check
  `Multiplayer.is_server()` before emitting escalation signals.
- Guard position and state are synchronized to clients via `MultiplayerSynchronizer`.
- Tool interaction calls (`apply_gravity_flip`, `apply_force_push`, `apply_time_slow`)
  must be wrapped as `@rpc("authority")` calls when networking is introduced.
- No game-affecting logic runs on clients — clients render received state only.

---

## 4. Formulas

### 4.1 Guard Detection Angle Check

```
guard_forward = -patrol_guard.global_transform.basis.z  (forward in local space)
to_player     = (player.global_position - guard_head_position).normalized()

cos_angle = guard_forward.dot(to_player)
angle_deg = rad_to_deg(acos(cos_angle))

LOS_confirmed_angle = angle_deg <= (DETECTION_CONE_DEGREES / 2.0)

# With DETECTION_CONE_DEGREES = 140:
# LOS confirmed if player is within 70 degrees of guard forward vector.
# At HOSTILE level (cone = 160), threshold becomes 80 degrees.

Example:
  guard facing (0, 0, -1), player at (3, 0, -5) relative to guard:
  to_player = normalize(3, 0, -5) ≈ (0.514, 0, -0.857)
  dot = (0)(0.514) + (0)(-0.857) + (-1)(0) ... wait, guard forward = (0,0,-1)
  dot = (0)(0.514) + (0)(0) + (-1)(-0.857) = 0.857
  angle = acos(0.857) ≈ 31 degrees → within 70 degrees → LOS angle confirmed
```

### 4.2 Guard Detection Range

```
DETECTION_RADIUS = 8.0 m    (proximity sphere — broadphase)
DETECTION_RANGE  = 10.0 m   (raycast max length — LOS distance)

At ALERT escalation level:
  effective_range = DETECTION_RANGE * ALERT_DETECTION_MULTIPLIER
                  = 10.0 * 1.25 = 12.5 m

A guard at ALERT can confirm LOS up to 12.5 m away (if broadphase sphere is also
expanded: DETECTION_RADIUS * 1.25 = 10.0 m).
Note: The broadphase sphere must also be enlarged at ALERT — the RayCast3D length
alone expanding is not sufficient because body_entered fires off the sphere radius.
```

### 4.3 Guard Alert Buildup

```
ALERT_BUILDUP_TIME = 1.5 s   (time from LOS confirmed to guard_alerted signal)

If the player breaks LOS before ALERT_BUILDUP_TIME expires, the guard returns
to PATROL. The remaining buildup time does NOT persist — it resets to 0 each
time the guard re-enters ALERT state. There is no "suspicion meter."

Time-to-alert under Time Slow (from player's perspective):
  Guard movement is at 15% speed, but ALERT_BUILDUP_TIME runs at real time.
  Player has exactly ALERT_BUILDUP_TIME (1.5 s) to break LOS before the alarm fires.
  Time Slow does NOT extend this window.
```

### 4.4 Guard HP Budget

```
MAX_GUARD_HP          = 50 HP
STUN_RECOVERY_HP      = 25 HP   (guard recovers to half health after stun)
STUN_DURATION         = 8.0 s   (time guard is disabled after stun trigger)
GRAVITY_FLIP_STUN_DURATION = 5.0 s

Stun threshold: guard enters STUNNED when HP reaches 0. Tools do not deal HP
damage directly — only Force Push can trigger STUNNED via impact (HP bypass,
see 3.6.2). HealthComponent damage is reserved for Alpha scope (combat tools).

For completeness: if a future system deals damage to a guard:
  time_to_stun_via_damage = MAX_GUARD_HP / damage_per_hit
  (e.g., at 25 damage/hit: 2 hits to stun)
```

### 4.5 Pressure Plate Hold Alarm Timer

```
PLATE_HOLD_ALARM_TIME = 3.0 s   (standing on plate before sustained alarm fires)
PLATE_PRESSURE        = 40      (pressure on release-trip)
PLATE_ALARM_PRESSURE  = 60      (pressure on hold-alarm, same as laser)

Combined worst case (player stands on plate for 3+ seconds, then steps off):
  Total pressure = PLATE_ALARM_PRESSURE + PLATE_PRESSURE = 60 + 40 = 100
  = PRESSURE_THRESHOLD exactly → guaranteed level advance
  This is intentional: lingering on a plate AND releasing it is maximally punishing.

Optimal play (crate holds plate, player never steps on it):
  Pressure = 0
```

### 4.6 Force Push Slide Distance on Guard

```
guard_push_velocity  = FORCE_PUSH_IMPULSE * GUARD_PUSH_SCALE
                     = 12.0 * 0.6
                     = 7.2 m/s

GUARD_FRICTION_DECEL = 8.0 m/s²

time_to_stop  = guard_push_velocity / GUARD_FRICTION_DECEL
              = 7.2 / 8.0
              = 0.9 s

distance_slid = 0.5 * guard_push_velocity * time_to_stop
              = 0.5 * 7.2 * 0.9
              = 3.24 m

Max slide distance if FORCE_PUSH_IMPULSE raised to 20.0:
  velocity  = 20.0 * 0.6 = 12.0 m/s
  time      = 12.0 / 8.0 = 1.5 s
  distance  = 0.5 * 12.0 * 1.5 = 9.0 m
  (9 m slide is excessive — this is why the safe upper range caps at 20 N)
```

---

## 5. Edge Cases

| Scenario | Explicit Behavior |
|----------|-------------------|
| Guard enters STUNNED while already STUNNED | `STUN_DURATION` timer is reset to full — stun is refreshed, not stacked. HP is NOT restored until stun ends. |
| Gravity Flip applied to guard while guard is in PURSUE | Guard transitions to STUNNED immediately; PURSUE is interrupted. If `gravity_flip` duration expires while guard is above a pit, the guard falls and hits KillVolume — permanent stun (no recovery). |
| Force Push knocks guard through a wall (high impulse) | Guard is `CharacterBody3D` with `move_and_slide()` — it cannot tunnel through walls. It stops at the wall collision surface. Guard still enters STUNNED state. |
| Force Push applied to guard while guard is already STUNNED | Velocity kick is applied (guard slides again), STUN_DURATION timer resets. Guard does not snap to PATROL. |
| Two players Force Push the same guard simultaneously | Server applies both impulse calls sequentially in the same physics frame. Combined velocity = sum of both pushes. This can launch the guard farther than intended — acceptable for VS, document as emergent co-op potential. |
| Player steps onto Pressure Plate and another player immediately places a crate on it | Both bodies are in TriggerArea. When the first player steps off, the crate still holds the plate ACTIVE — no trip signal fires. The plate stays ACTIVE (and silent) indefinitely until the crate is removed or falls off. This is the intended "correct solution." |
| Pressure Plate held ACTIVE by crate for >3 s | `plate_alarm_triggered` fires after `PLATE_HOLD_ALARM_TIME` regardless of what body is holding the plate. A crate holding a plate does NOT prevent the sustained alarm — only the release-trip. Implication: players must act quickly after placing a crate; they cannot just put a crate on a plate and walk away safely. |
| Alarm Laser triggered while Escalation is at CRITICAL | `laser_triggered` signal fires and pressure is applied. Pressure exceeds PRESSURE_THRESHOLD but EscalationManager already guards `advance_escalation()` — excess pressure is discarded (per Escalation GDD §5 edge case). No crash or double-signal. |
| Player stands inside Alarm Laser TriggerVolume for extended time | `body_entered` fires once on entry; ARMED_TRIGGERED state prevents re-trigger for `LASER_ALARM_DURATION` (8 s). After 8 s, laser resets to ARMED. If player is STILL inside, `body_entered` will NOT re-fire (body is already overlapping). Player can stand in laser indefinitely after the initial trigger without spamming escalation. |
| Guard NavMesh path not found to patrol waypoint | Guard stands still, retries after `PATROL_STUCK_RETRY` (2 s). Does not alert or pursue. Does not fire any signal. After 5 consecutive failed retries (10 s), guard emits `guard_nav_error(guard_id)` for debug logging. No player-facing consequence. |
| All guards are STUNNED simultaneously | No consequence — escalation continues via passive timer. No special behavior. The run can be trivially completed with all guards stunned; this is an acceptable skill expression outcome, not an exploit, because stun duration (8 s) is shorter than the typical objective completion time. |
| Guard alert timer and guard_alerted signal fire while LOS interrupted by a physics object flying through the air | LOS raycast on the frame of timer expiry determines if ALERT progresses. If the raycast is blocked by the physics object in that frame, LOS is not confirmed — guard returns to PATROL. Timing inconsistency from frame-rate differences is acceptable for VS. |
| Time Slow active when guard's ALERT_BUILDUP_TIME expires | Timer runs in real time (not slowed). Guard transitions to PURSUE normally. Player is not protected by Time Slow from ALERT escalation. |
| Gravity Flip applied to guard while guard is on top floor (no ceiling above) | Guard rises, exits room above, enters KillVolume. `HealthComponent.kill()` called. Guard enters permanent STUNNED (KillVolume death bypasses HP system). Guard does not recover. No signal emitted beyond `guard_stunned`. |
| `guard_reached_player` fires when escalation is already at HOSTILE or CRITICAL | Pressure is applied and may cross PRESSURE_THRESHOLD. EscalationManager handles the level-cannot-advance-past-CRITICAL guard (per Escalation GDD). No error. |
| Force Push impulse on guard who is standing at a ledge edge | Guard slides off the ledge, falls, takes fall damage via HealthComponent (same formula as player: `(speed - 8.0) * 10.0`). If fall damage reduces guard HP to 0, `HealthComponent.died` fires → guard enters STUNNED state (permanent — no recovery from HP-0 trigger during forced fall). |

---

## 6. Dependencies

### This system depends on:

| System | What this system requires from it |
|--------|----------------------------------|
| **Character Controller** | Player collision layer (layer 4), player `global_position` for guard targeting and raycast targeting. Player `CharacterBody3D` as the detectable entity. |
| **Health & Death System** | `health_component.gd` script reused for guards. Guard takes damage via `take_damage()`, emits `died` signal. `kill()` used by KillVolume for out-of-bounds guard death. |
| **Physics Tool System** | `GravityFlipTool`, `ForcePushTool`, `TimeSlowTool` must perform type checks and call `patrol_guard.apply_gravity_flip()`, `apply_force_push()`, `apply_time_slow()` for guard targets. |
| **Physics Interaction Layer** | Collision layer definitions (layer 1 = world, layer 2 = physics objects, layer 3 = guards, layer 4 = players). Guard nav-mesh relies on physics geometry being on layer 1. |
| **Escalation System** | EscalationManager must subscribe to `guard_alerted`, `guard_reached_player`, `laser_triggered`, `plate_tripped`, `plate_alarm_triggered` signals from this system. Escalation signals `alert_entered` and `hostile_entered` are received by this system to modify guard behavior. |

### Systems that depend on this system:

| System | What it requires from this system |
|--------|----------------------------------|
| **Escalation System** | Receives `guard_alerted`, `guard_reached_player`, `laser_triggered`, `plate_tripped`, `plate_alarm_triggered` signals to advance pressure. |
| **HUD** | Subscribes to `guard_stunned` for optional guard-status feedback (Alpha scope HUD extension). |
| **Audio System** | Subscribes to `guard_alerted`, `laser_triggered`, `plate_tripped`, `plate_alarm_triggered` for SFX/music cues. |
| **Visual Effects & Juice System** | Subscribes to tool interaction signals on guards for particle/screen-space effects. |
| **Solo/Co-op Scaling System** | Guard count and escalation pressure values are scaling knobs (see Tuning Knobs §7). |

### New collision layer allocation:

The Physics Interaction Layer GDD must be updated to define:
- **Layer 3 = Guards** (`collision_layer = 4` in bitmask). Guards must be on this
  layer so alarm lasers and pressure plates can exclude them via layer filtering.
  The Physics Interaction Layer GDD does not currently define layer 3.

---

## 7. Tuning Knobs

All knob values live in `assets/data/enemy_hazard_config.tres` (a `Resource` file
with exported variables), never hardcoded in scripts.

### Guard Knobs

| Knob | Category | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `MAX_GUARD_HP` | curve | 50 | 25–150 | How many tool hits a guard can absorb before stun |
| `STUN_RECOVERY_HP` | curve | 25 | 10–50 | HP guard wakes with after stun |
| `STUN_DURATION` | gate | 8.0 s | 3.0–20.0 s | How long a stunned guard is neutralized |
| `GRAVITY_FLIP_STUN_DURATION` | gate | 5.0 s | 3.0–15.0 s | Stun length for gravity-flip method specifically |
| `GUARD_PATROL_SPEED` | feel | 2.5 m/s | 1.0–4.0 m/s | How fast guards patrol; affects tension pacing |
| `GUARD_PURSUE_SPEED` | feel | 4.5 m/s | 3.0–7.0 m/s | How fast guards chase; must stay above player walk speed (3.0 m/s) to feel threatening |
| `GUARD_PUSH_SCALE` | feel | 0.6 | 0.3–1.0 | How far a force push moves a guard relative to crate; 1.0 = same as crate |
| `GUARD_FRICTION_DECEL` | feel | 8.0 m/s² | 4.0–20.0 m/s² | How quickly a pushed guard decelerates |
| `GUARD_FLIP_LAUNCH_VELOCITY` | feel | 6.0 m/s | 3.0–10.0 m/s | Upward kick applied when gravity-flipped |
| `DETECTION_RADIUS` | curve | 8.0 m | 4.0–15.0 m | Broadphase proximity detection sphere |
| `DETECTION_RANGE` | curve | 10.0 m | 6.0–16.0 m | LOS raycast max range |
| `DETECTION_CONE_DEGREES` | curve | 140° | 90–180° | Guard's forward field of view |
| `ALERT_BUILDUP_TIME` | gate | 1.5 s | 0.5–4.0 s | Reaction time before guard calls alert; lower = harsher stealth |
| `ALERT_SPEED_MULTIPLIER` | curve | 1.2 | 1.0–1.5 | Guard speed multiplier at ALERT escalation |
| `ALERT_DETECTION_MULTIPLIER` | curve | 1.25 | 1.0–2.0 | Detection range multiplier at ALERT escalation |
| `HOSTILE_CONE_DEGREES` | curve | 160° | 140–180° | Guard FOV at HOSTILE level |
| `PURSUE_UPDATE_INTERVAL` | feel | 0.25 s | 0.1–1.0 s | How often guard recalculates path to player |
| `PURSUIT_GIVE_UP_RANGE` | curve | 15.0 m | 8.0–25.0 m | Distance at which guard abandons pursuit |
| `PURSUIT_GIVE_UP_TIME` | gate | 5.0 s | 2.0–15.0 s | How long guard must be out-of-range before giving up |
| `PURSUE_EMIT_PROXIMITY_DISTANCE` | feel | 1.5 m | 1.0–3.0 m | How close guard gets before emitting guard_reached_player |
| `GUARD_CONTACT_PRESSURE` | curve | 40 | 20–80 | Pressure added when guard reaches player |
| `PATROL_STUCK_RETRY` | gate | 2.0 s | 1.0–5.0 s | Retry interval when nav path fails |

### Alarm Laser Knobs

| Knob | Category | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `LASER_PRESSURE` | curve | 60 | 30–100 | Pressure spike on laser trigger |
| `LASER_ALARM_DURATION` | gate | 8.0 s | 3.0–20.0 s | Re-trigger lockout duration |
| `LASER_FLASH_RATE` | feel | 4 Hz | 1–8 Hz | Visual flash rate during alarm; too fast = seizure risk (cap at 8) |
| `LASER_DIAMETER` | feel | 0.05 m | 0.02–0.1 m | Visual beam width (detection volume scales at 1.15×) |

### Pressure Plate Knobs

| Knob | Category | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `PLATE_HOLD_ALARM_TIME` | gate | 3.0 s | 1.0–10.0 s | Window to place crate before sustained alarm fires |
| `PLATE_PRESSURE` | curve | 40 | 20–80 | Pressure on release-trip event |
| `PLATE_ALARM_PRESSURE` | curve | 60 | 30–100 | Pressure on sustained hold alarm |

### Spawn Count Knobs (set by Procedural Generator)

| Knob | Category | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `GUARDS_PER_RUN_MIN` | gate | 2 | 1–6 | Minimum guards per generated facility |
| `GUARDS_PER_RUN_MAX` | gate | 4 | 2–8 | Maximum guards per generated facility |
| `LASERS_PER_RUN_MIN` | gate | 1 | 0–4 | Minimum alarm lasers per run |
| `LASERS_PER_RUN_MAX` | gate | 3 | 1–6 | Maximum alarm lasers per run |
| `PLATES_PER_RUN_MIN` | gate | 1 | 0–3 | Minimum pressure plates per run |
| `PLATES_PER_RUN_MAX` | gate | 2 | 1–4 | Maximum pressure plates per run |

---

## 8. Acceptance Criteria

A QA tester can verify each criterion independently with no additional tooling
beyond the Godot editor's play mode and a print-to-console listener.

### Patrol Guard

| ID | Criterion | Pass Condition | Fail Condition |
|----|-----------|---------------|---------------|
| EH-01 | Guard patrols between waypoints | Guard visually moves between assigned patrol points in sequence, loops back to start | Guard stands still, moves wrong direction, or freezes after first waypoint |
| EH-02 | Guard enters ALERT state on LOS with player | Capsule turns yellow within DETECTION_RANGE when player is in cone and no geometry between them | Guard stays grey, turns yellow through walls, or turns yellow outside the cone |
| EH-03 | Guard returns to PATROL if LOS broken before ALERT_BUILDUP_TIME | Breaking LOS within 1.5 s resets guard to PATROL (grey) | Guard enters PURSUE despite LOS broken |
| EH-04 | Guard emits `guard_alerted` signal on ALERT → PURSUE transition | `print()` listener confirms signal fires; escalation pressure increases by 40 | Signal not emitted, or pressure unchanged |
| EH-05 | Guard capsule turns red on PURSUE | Guard in PURSUE state is visibly red | Guard stays yellow or grey during pursuit |
| EH-06 | Escalation level advances when `guard_alerted` fills pressure to threshold | Emit 3× `guard_alerted` events (3×40=120 > PRESSURE_THRESHOLD=100) without timer; confirm escalation level advances | Level unchanged after 3 alert events |
| EH-07 | Guard enters STUNNED on Force Push | Force Pushing a guard turns it dark blue and stops its AI movement for STUN_DURATION | Guard ignores Force Push, or continues moving while dark blue |
| EH-08 | Guard enters STUNNED on Gravity Flip | Gravity Flipping a guard turns it dark blue and inverts its up_direction (guard rises toward ceiling) | Guard stays grey or falls through floor |
| EH-09 | Guard recovers from STUN | After STUN_DURATION, guard turns grey and resumes patrol from current position | Guard stays dark blue indefinitely, or teleports to original position |
| EH-10 | Guard in Time Slow moves at reduced speed | Guard movement visibly slower while player's Time Slow is active; returns to normal speed on deactivate | Guard moves at full speed during Time Slow |
| EH-11 | ALERT escalation level expands guard detection range | At ALERT level, guard detects player at 12.5 m (DETECTION_RANGE × 1.25); at CALM, 10 m is the limit | No change in detection range between CALM and ALERT |

### Alarm Laser

| ID | Criterion | Pass Condition | Fail Condition |
|----|-----------|---------------|---------------|
| EH-12 | Laser triggers on player entry | Stepping through laser fires `laser_triggered` signal; print listener confirms; escalation pressure +60 | Signal not fired, or pressure unchanged |
| EH-13 | Laser does NOT trigger on physics object | Force Pushing a crate through laser does not fire `laser_triggered` | Signal fires on crate contact |
| EH-14 | Laser does NOT trigger on guard | Guard patrolling through laser (set guard route through laser in test scene) does not fire signal | Signal fires on guard contact |
| EH-15 | Laser re-trigger lockout works | Walking through laser twice within LASER_ALARM_DURATION fires signal only once; second crossing does not add pressure | Signal fires twice, or pressure +120 instead of +60 |
| EH-16 | Laser resets after LASER_ALARM_DURATION | 8 s after trigger, laser visual returns to steady red and can be triggered again | Laser stays in flashing state indefinitely, or never resets |

### Pressure Plate

| ID | Criterion | Pass Condition | Fail Condition |
|----|-----------|---------------|---------------|
| EH-17 | Plate turns green when player stands on it | Plate emissive turns green and visually depresses while player is on it | No visual change, or plate turns red immediately |
| EH-18 | `plate_tripped` fires on player stepping OFF | Stepping on and then stepping off fires `plate_tripped`; escalation +40 | Signal fires on step-on, or not at all |
| EH-19 | `plate_alarm_triggered` fires after PLATE_HOLD_ALARM_TIME | Standing on plate for 3+ seconds fires `plate_alarm_triggered`; escalation +60 | Signal fires immediately, fires too late, or not at all |
| EH-20 | Crate on plate holds it ACTIVE (no release-trip) | Force Push a crate onto plate; player walks away; `plate_tripped` does NOT fire | Signal fires even with crate present |
| EH-21 | Crate on plate still fires sustained alarm after 3 s | Crate on plate for 3+ seconds fires `plate_alarm_triggered` regardless | Signal not fired because crate (not player) holds plate |
| EH-22 | Guard stepping on plate does NOT trigger | Guard patrol route crossing the plate (test scene) does not fire any plate signal | Signal fires on guard contact |

### Escalation Integration

| ID | Criterion | Pass Condition | Fail Condition |
|----|-----------|---------------|---------------|
| EH-23 | Combined worst-case pressure from plate causes level advance | Player steps on plate for 3+ s then steps off: total pressure 60+40=100 = threshold; escalation level advances | Level does not advance, or advances twice |
| EH-24 | Guard detection range increases at ALERT escalation level | Manually set escalation to ALERT; guard detects player at 12.5 m not 10 m | Detection range unchanged at ALERT |
| EH-25 | Guard pursuit activates immediately on LOS at HOSTILE level | Manually set escalation to HOSTILE; guard with LOS on player transitions to PURSUE without ALERT_BUILDUP_TIME | Guard still waits 1.5 s at HOSTILE before pursuing |
