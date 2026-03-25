# GDD: Character Controller

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 6 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: Input System
> **Required By**: Physics Tool System, Health & Death System, Player Spawning, Camera System

---

## 1. Overview

The Character Controller owns all first-person player movement: walking, strafing,
jumping, landing, and mouse-look. It is a `CharacterBody3D` driven by
`move_and_slide()`. It reads from the Input System's named actions and exposes
signals so other systems can react to movement events without polling. It does
not own tools, health, or camera effects — those are separate systems that attach
to or listen to the controller.

---

## 2. Player Fantasy

Movement feels responsive and trustworthy. The player can precisely position
themselves to aim a tool at a target. There is no floatiness or input lag.
Stopping is immediate. Jumping has a satisfying arc — not too floaty, not too
snappy. The player feels physically present in the space without fighting the
controls.

---

## 3. Detailed Rules

### 3.1 Node Structure

```
CharacterBody3D  [character_controller.gd]
├── CollisionShape3D  (CapsuleShape3D, height=1.8, radius=0.4)
└── CameraMount  (Node3D, position y=1.6)
    └── Camera3D
        └── RayCast3D  (target_position=(0,0,-10), enabled=true)
```

The Camera is parented to a `CameraMount` node so camera effects (bob, shake)
can transform the mount without touching the controller's rotation.

### 3.2 Movement

- Player moves relative to horizontal facing (yaw only — no pitch affects movement).
- Input vector from `Input.get_vector("move_left","move_right","move_forward","move_back")`.
- Direction projected onto `transform.basis` XZ plane and normalized.
- When input is held: `velocity.x/z = direction * MOVE_SPEED`.
- When no input: velocity.x/z decelerate via `move_toward(v, 0, MOVE_SPEED)` per frame.
- No acceleration curve — stopping and starting are instant (feels snappy, fits physics tool gameplay).
- Vertical velocity (gravity, jump) is independent of horizontal.

### 3.3 Gravity

- Applied every frame when `not is_on_floor()`.
- Uses `get_gravity()` which reads Godot's project gravity setting (default 9.8 m/s²).
- Formula: `velocity += get_gravity() * delta`
- The player is never affected by `gravity_scale` changes (that is only for RigidBody3D physics objects).

### 3.4 Jump

- Trigger: `Input.is_action_just_pressed("jump")` AND `is_on_floor()`.
- Applies an instant upward velocity: `velocity.y = JUMP_VELOCITY`.
- No coyote time or jump buffering in MVP — direct and simple.
- No double jump in MVP.

### 3.5 Mouse Look

- Reads `InputEventMouseMotion.relative` in `_input()`.
- Horizontal mouse movement rotates the CharacterBody3D on Y axis (yaw).
- Vertical mouse movement rotates the CameraMount on X axis (pitch).
- Pitch is clamped to `[-90°, +90°]` to prevent flipping.
- Formulas:
  ```
  rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
  camera_mount.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
  camera_mount.rotation.x = clamp(camera_mount.rotation.x, -PI/2, PI/2)
  ```

### 3.6 Signals Emitted

| Signal | When | Payload |
|--------|------|---------|
| `landed` | First frame `is_on_floor()` is true after being airborne | — |
| `jumped` | Frame jump velocity is applied | — |

These let the Audio System and Camera System react without polling.

---

## 4. Formulas

### Move Speed

```
horizontal_velocity = direction.normalized() * MOVE_SPEED

MOVE_SPEED = 6.0  (m/s)
direction  = Vector3 from input, projected onto XZ plane
```

### Jump Arc

```
velocity.y = JUMP_VELOCITY  (applied once on jump frame)
velocity.y += gravity.y * delta  (each frame while airborne)

JUMP_VELOCITY = 5.0  (m/s upward)
gravity.y     = -9.8 (m/s² — Godot default, negative = downward)
```

Approximate jump height:
```
max_height ≈ JUMP_VELOCITY² / (2 * |gravity.y|)
           ≈ 25 / 19.6
           ≈ 1.28 metres
```

Approximate hang time:
```
total_time ≈ 2 * JUMP_VELOCITY / |gravity.y|
           ≈ 10 / 9.8
           ≈ 1.02 seconds
```

### Mouse Sensitivity

```
yaw_delta   = -mouse_delta.x * MOUSE_SENSITIVITY  (radians)
pitch_delta = -mouse_delta.y * MOUSE_SENSITIVITY  (radians)

MOUSE_SENSITIVITY = 0.003  (radians per pixel)
```

At 1080p with a 400 DPI mouse at normal speed (~800 counts/second),
`0.003` gives roughly 180°/s rotation speed — standard FPS feel.

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Jump pressed while in the air | Ignored — `is_on_floor()` check blocks it |
| Jump pressed same frame as landing | `is_on_floor()` is true → jump fires. Intentional. |
| Player walks off a ledge (no jump) | Gravity applies immediately. No coyote time in MVP. |
| Player hits a ceiling mid-jump | `move_and_slide()` stops vertical velocity naturally (Godot default). |
| Two players collide (co-op, future) | CharacterBody3D ignores other CharacterBody3Ds by default. Acceptable for MVP. |
| Extreme mouse delta spike (frame drop) | Pitch clamp prevents flipping. Yaw has no clamp — acceptable for 360° rotation. |
| Physics object falls on player's head | CharacterBody3D + Jolt handle this via collision layers. Player is not pushed. |

---

## 6. Dependencies

- **Input System** — reads move_forward, move_back, move_left, move_right, jump
- **Godot Physics (Jolt)** — `move_and_slide()`, `is_on_floor()`, `get_gravity()`
- **Physics Tool System** — attaches to the RayCast3D under CameraMount/Camera3D
- **Health & Death System** — listens on this node for death triggers (knockback, respawn position)
- **Audio System** (Vertical Slice) — listens to `landed` and `jumped` signals for footstep/land SFX
- **Camera System** (Vertical Slice) — uses CameraMount for bob/shake effects

---

## 7. Tuning Knobs

| Knob | Constant | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| Move speed | `MOVE_SPEED` | 6.0 m/s | 4.0–10.0 | How fast the player traverses the room |
| Jump height | `JUMP_VELOCITY` | 5.0 m/s | 3.0–8.0 | Arc height — higher = more floaty |
| Mouse sensitivity | `MOUSE_SENSITIVITY` | 0.003 rad/px | 0.001–0.010 | Camera rotation speed |
| Capsule height | CapsuleShape3D | 1.8 m | 1.6–2.0 | Player collision height |
| Capsule radius | CapsuleShape3D | 0.4 m | 0.3–0.5 | How wide doorways need to be |
| Camera mount Y | CameraMount position | 1.6 m | 1.4–1.8 | Eye height |

---

## 8. Acceptance Criteria

- [ ] Player moves at 6.0 m/s on flat ground (verify with a timed known-distance test)
- [ ] Player reaches ~1.28m peak jump height (verify against a 1m reference cube)
- [ ] Pitch cannot exceed ±90° no matter how fast the mouse moves
- [ ] Pressing W+S simultaneously results in zero horizontal movement
- [ ] Player does not slide after releasing movement keys
- [ ] `landed` signal fires exactly once per landing (not every frame while grounded)
- [ ] `jumped` signal fires exactly once per jump
- [ ] No physics jitter when standing still against a wall or in a corner
