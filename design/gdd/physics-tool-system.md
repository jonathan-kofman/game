# GDD: Physics Tool System

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 2 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: Physics Interaction Layer, Input System, Character Controller
> **Required By**: Visual Effects & Juice System, Audio System, Networking Layer

---

## 1. Overview

The Physics Tool System gives players three tools — Gravity Flip, Time Slow, and
Force Push — that manipulate `RigidBody3D` physics objects in the environment.
Each tool is its own GDScript class inheriting from a `BaseTool` base class. A
`ToolManager` node on the player reads input actions and routes activation calls
to the appropriate tool. All tool activations write exclusively through the
`PhysicsObject` API (see Physics Interaction Layer); no tool reads `gravity_scale`
or `linear_velocity` directly.

This is the **production redesign** of the `physics_tools.gd` prototype script.
The prototype validated the core loop; the architecture here addresses the
prototype's known failure modes (Jolt sleep, velocity scaling, no audio, no VFX).

---

## 2. Player Fantasy

The player feels like a force of nature. They pick up a box with gravity, slow it
mid-air, then blast it through a wall — in one fluid gesture. The tools feel
physical and weighty: there is audio and visual feedback for every activation.
Players experiment with combos without being told to. The tools are the game.

---

## 3. Detailed Rules

### 3.1 Tool Architecture

Each tool is a `Node` child of `ToolManager`, with a script extending `BaseTool`:

```
Player (CharacterBody3D)
└── ToolManager         (script: tool_manager.gd)
    ├── GravityFlipTool (script: gravity_flip_tool.gd)
    ├── TimeSlowTool    (script: time_slow_tool.gd)
    └── ForcePushTool   (script: force_push_tool.gd)
```

`ToolManager` reads from the player's `RayCast3D` (via `CharacterController.get_aim_ray()`)
and routes `activate` / `deactivate` calls to the correct tool based on input actions.

### 3.2 BaseTool Contract

Every tool extends `scripts/tools/base_tool.gd`:

| Member | Type | Description |
|--------|------|-------------|
| `activate(target: Node, normal: Vector3) -> void` | method | Called when the tool action is pressed. `target` is the raycast collider; `normal` is `get_collision_normal()`. |
| `deactivate() -> void` | method | Called when the tool action is released (for toggle tools). No-op for instantaneous tools. |
| `is_active: bool` | property | True while the tool has an ongoing effect. |
| `tool_activated(tool_name: String, target: Node)` | signal | Emitted on `activate()`. Consumed by VFX and Audio systems. |
| `tool_deactivated(tool_name: String)` | signal | Emitted on `deactivate()`. Consumed by VFX and Audio systems. |
| `tool_failed(tool_name: String, reason: String)` | signal | Emitted when activation is rejected (wrong target type, already active, etc.). |

No tool may access physics state except through the `PhysicsObject` script on the
target body. This is enforced by convention — tools call `target.get_node(".")` cast
to `PhysicsObject`, never `RigidBody3D` properties directly.

### 3.3 Tool: Gravity Flip

**Input action**: `tool_gravity` (G key)
**Target type**: Single `RigidBody3D` with `PhysicsObject` script (layer 2)
**Behaviour**: Toggle. On first activation, sets `is_gravity_flipped = true` on the
target's `PhysicsObject`; this negates `gravity_scale`. On second activation on the
same object, restores `gravity_scale` to `original_gravity_scale`.

Rules:
- Only one object may be gravity-flipped per player at a time (MVP constraint).
  Activating on a second object silently restores the first before flipping the new one.
- If the target is already flipped by a teammate (co-op), emit `tool_failed` and show
  "GRAVITY — already flipped" feedback text.
- Gravity flip persists until the player re-activates on the same object, the object
  is destroyed, or the run ends. No automatic timeout in MVP.

### 3.4 Tool: Time Slow

**Input action**: `tool_time_slow` (T key)
**Target type**: All `RigidBody3D` with `PhysicsObject` script within `TIME_SLOW_RADIUS`
metres of the player
**Behaviour**: Toggle. Hold to slow; release to restore.

**Production implementation** (replaces prototype velocity scaling):

```
# On activate (begin time slow):
for each body in PhysicsObject bodies within radius:
    body.sleeping = false                            # wake Jolt-sleeping bodies
    rb.gravity_scale = original_gravity_scale * TIME_SLOW_FACTOR
    rb.linear_damp   = HIGH_DAMP_VALUE               # bleed existing velocity

# On deactivate (end time slow):
for each body in _slowed_bodies:
    rb.gravity_scale = original_gravity_scale
    rb.linear_damp   = 0.0
```

Why this approach:
- `linear_velocity` scaling (prototype) had no effect on sleeping bodies — Jolt
  never activated them. Setting `sleeping = false` first, then changing `gravity_scale`,
  activates the body through Jolt's own wakeup path.
- `linear_damp = 8.0` bleeds off existing momentum without snapping to zero, creating
  the "everything is treacle" feel instead of a hard freeze.
- Changing `gravity_scale` wakes sleeping bodies even if they were never moving —
  this is the key discovery from prototype debugging.

Rules:
- Time slow is a player-wide area effect, not targeted at a single object.
- Objects affected by gravity flip are NOT excluded from time slow — both effects
  apply simultaneously via separate `PhysicsObject` flags.
- Force push impulse applied while time slow is active is applied at full strength;
  the high `linear_damp` bleeds it off slowly — this creates the "slow bullet" feel.
  This is intentional.

### 3.5 Tool: Force Push

**Input action**: `tool_force_push` (F key)
**Target type**: Single `RigidBody3D` with `PhysicsObject` script (layer 2)
**Behaviour**: Instantaneous. Single `apply_central_impulse` call on the target.

Push direction resolution:
1. Use `get_collision_normal()` from the player's `RayCast3D` if length > 0.1.
2. Fallback: `(body.global_position - player.global_position).normalized()`.

Rules:
- `apply_central_impulse(direction * FORCE_PUSH_IMPULSE)` — no hold-to-charge in MVP.
  (Charge mechanic is a Vertical Slice scope item.)
- Force push has no cooldown in MVP.
- If target is `StaticBody3D` or has no `PhysicsObject` script, emit `tool_failed`.
  Show feedback: "PUSH — aim at a physics object".

### 3.6 Tool Manager Input Loop

`ToolManager._unhandled_input(event)` handles all tool input:

```
if event.is_action_pressed("tool_gravity"):
    gravity_flip_tool.activate(ray.get_collider(), ray.get_collision_normal())

if event.is_action_pressed("tool_time_slow"):
    time_slow_tool.activate(null, Vector3.ZERO)    # area effect, no target
elif event.is_action_released("tool_time_slow"):
    time_slow_tool.deactivate()

if event.is_action_pressed("tool_force_push"):
    force_push_tool.activate(ray.get_collider(), ray.get_collision_normal())
```

`ToolManager` does not process tool logic — it only routes. Logic lives in each tool.

### 3.7 Feedback: Audio and Visual

All feedback is triggered via signals, not by the tool itself. Tools emit signals;
Audio and VFX systems subscribe:

| Event | Signal | Expected Response |
|-------|--------|-------------------|
| Gravity flip activated | `tool_activated("gravity_flip", target)` | Audio: whoosh SFX; VFX: blue particle trail on target |
| Gravity flip restored | `tool_deactivated("gravity_flip")` | Audio: reverse whoosh; VFX: trail stops |
| Time slow activated | `tool_activated("time_slow", null)` | Audio: deep resonance; VFX: desaturation + blur vignette |
| Time slow released | `tool_deactivated("time_slow")` | Audio: release snap; VFX: desaturation removed |
| Force push activated | `tool_activated("force_push", target)` | Audio: thud SFX; VFX: shockwave ring at hit point |
| Any tool failed | `tool_failed(name, reason)` | Audio: dull click; VFX: HUD feedback text |

Audio and VFX assets are **not** in scope for MVP implementation of this system.
The signal contract is defined here so Audio/VFX can be wired in independently.
For MVP: tools emit signals; no subscriber is required. `print()` debug output is
acceptable until Audio/VFX systems are ready.

---

## 4. Formulas

### Gravity Flip — Resulting Acceleration

```
new_gravity_scale = -abs(original_gravity_scale)
                  = -1.0   (for default 1kg objects)

upward_acceleration = |new_gravity_scale| * world_gravity
                    = 1.0 * 9.8
                    = 9.8 m/s² upward
```

### Time Slow — Velocity Bleed

```
# Under time slow, net vertical acceleration is:
net_accel = gravity_scale * world_gravity
          = (1.0 * TIME_SLOW_FACTOR) * -9.8
          = 0.15 * -9.8
          = -1.47 m/s²  (versus normal -9.8 m/s²)

# linear_damp bleeds existing velocity each physics frame:
velocity(t) ≈ velocity(0) * e^(-linear_damp * t)
            = v0 * e^(-8.0 * t)
            # at t=0.5s: v0 * e^-4 ≈ v0 * 0.018  (98% of momentum gone)
```

### Force Push — Resulting Velocity

```
impulse = FORCE_PUSH_IMPULSE * direction  (Vector3)
resulting_velocity ≈ impulse / mass
                   = 12.0 / 1.0 kg
                   = 12.0 m/s  (for default 1kg object)

# To prevent tunnelling through 0.2m walls:
max_safe_velocity = wall_thickness / physics_step
                  = 0.2 / (1/60)
                  = 12.0 m/s
# 12N is exactly at this boundary — monitor in playtesting.
```

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Ray hits nothing (pointing at sky) | `ray.get_collider()` returns `null`. All targeted tools emit `tool_failed`. No crash — guard at top of `activate()`. |
| Ray hits `StaticBody3D` (wall, floor) | Body is not `RigidBody3D`. Emit `tool_failed("... aim at a physics object")`. |
| Target has no `PhysicsObject` script | Emit `tool_failed`. Log warning. Do not attempt to access physics properties. |
| Gravity flip activated on already-flipped object (same player) | Toggle off — restores gravity. This is the intended undo gesture. |
| Gravity flip activated while object is already time-slowed | Both effects apply. `PhysicsObject` tracks both `is_gravity_flipped` and `is_time_slowed` independently. |
| Time slow toggle while no physics objects in radius | `_slowed_bodies` is empty. No error. Emit `tool_activated` anyway (VFX/audio should still play for player feedback). |
| Force push applied while target is time-slowed | Impulse applies at full strength. `linear_damp = 8.0` bleeds it off quickly. Result: object moves slowly but noticeably. This is the "slow bullet" combo — intentional. |
| Player activates tool then immediately leaves the room | Tool state (flipped bodies, slowed bodies) belongs to the player node. When the player is freed, the `PhysicsObject` flags are left in whatever state they were. Future: tool cleanup on `_exit_tree`. |
| Two co-op players force push the same object simultaneously | Server processes one impulse at a time. Both are applied; the combined result may exceed intended range. Acceptable for MVP — document as "combo potential". |

---

## 6. Dependencies

- **Depends on**:
  - Physics Interaction Layer (defines `PhysicsObject` API, collision layers, Jolt quirks)
  - Input System (provides `tool_gravity`, `tool_time_slow`, `tool_force_push` actions)
  - Character Controller (provides `get_aim_ray()` for targeted tools)

- **Required by**:
  - Visual Effects & Juice System (subscribes to `tool_activated` / `tool_deactivated` signals)
  - Audio System (subscribes to tool signals for SFX)
  - Networking Layer (tool activations must be server-authoritative RPCs in co-op)
  - HUD System (subscribes to `tool_failed` for feedback text display)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `FORCE_PUSH_IMPULSE` | force_push_tool.gd | 12.0 N | 5.0–20.0 | How far a 1kg object travels; prototype 18N was too strong |
| `TIME_SLOW_FACTOR` | time_slow_tool.gd | 0.15 | 0.05–0.5 | How slow "slow" is; 0.15 was barely visible in prototype — start higher |
| `HIGH_DAMP_VALUE` | time_slow_tool.gd | 8.0 | 4.0–20.0 | How quickly slowed objects bleed momentum; 8.0 = ~98% gone in 0.5s |
| `TIME_SLOW_RADIUS` | time_slow_tool.gd | 6.0 m | 3.0–12.0 | Radius of time slow area effect |
| `MAX_GRAVITY_FLIPPED` | gravity_flip_tool.gd | 1 | 1–4 | Max simultaneous gravity-flipped objects per player (MVP = 1) |

---

## 8. Acceptance Criteria

- [ ] `BaseTool` class exists at `scripts/tools/base_tool.gd` with `activate()`, `deactivate()`, `is_active`, and three signals
- [ ] `GravityFlipTool`, `TimeSlowTool`, `ForcePushTool` each extend `BaseTool` in separate files
- [ ] `ToolManager` routes input actions to the correct tool without containing physics logic
- [ ] Gravity flip on a resting object causes it to rise within 2 frames
- [ ] Time slow affects a resting (sleeping) object — it must visibly slow its fall — no more "nothing happens" prototype failure
- [ ] Time slow applied to a moving object visibly reduces its velocity within 1 second
- [ ] Force push at 12N moves a 1kg box across a 10m room without tunnelling through the far wall
- [ ] All three tools work in combination without errors (`is_gravity_flipped` and `is_time_slowed` remain accurate)
- [ ] `tool_activated` and `tool_deactivated` signals fire on every tool use (verify with a `print()` listener)
- [ ] No tool reads `RigidBody3D.gravity_scale` or `linear_velocity` directly — all access via `PhysicsObject` API
