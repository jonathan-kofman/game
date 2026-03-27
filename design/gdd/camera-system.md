# GDD: Camera System

> **Status**: In Review
> **Created**: 2026-03-27
> **System ID**: 25 (see systems-index.md)
> **Priority**: Vertical Slice
> **Depends On**: Character Controller, Physics Tool System, Health & Death System
> **Required By**: Visual Effects & Juice System

---

## 1. Overview

The Camera System layers three kinematic effects — headbob, landing thud, and
shake — on top of the bare-bones mouse-look already implemented in
`CharacterController`. All effects operate by offsetting or rotating the
existing `CameraMount` Node3D rather than moving the `Camera3D` directly,
which keeps the aim ray and mouse-look logic in `character_controller.gd`
unchanged. Every value is an `@export` on a new `CameraEffects` node, which
means any effect can be zeroed out without breaking other systems. A low-priority
FOV sprint boost is included as a designed but off-by-default feature. The system
has no third-person mode and no cinematic cutout capability; those are out of
scope for MVP and Vertical Slice.

---

## 2. Player Fantasy

The camera should make the player feel like a body moving through a physical
space, not a floating eye gliding over a tileset. When sprinting, the slight
FOV push communicates momentum. The headbob reminds the player that they have
weight. The landing thud snaps them back to earth after a jump, punctuating the
bounce of Jolt physics below their feet. Camera shake on tool activation makes
each tool feel like a physical discharge of force — Gravity Flip should feel
different from Force Push should feel different from Time Slow, because each has
its own shake signature.

The target MDA aesthetics this mechanic primarily serves are:
- **Sensation**: the camera makes the game world feel tactile and present
- **Challenge**: readable visual feedback helps players parse the state of their
  physics interactions without additional UI overhead

The system must be invisible when nothing is happening. A player who is standing
still aiming carefully should feel zero camera movement. Effects activate only in
response to player actions, never ambiguously.

---

## 3. Detailed Rules

### 3.1 Node Architecture

A new `CameraEffects` node (script: `src/scripts/core/camera_effects.gd`) is
added as a child of `CameraMount`. It does NOT reparent the `Camera3D` — it
only writes to `CameraMount`'s `position` (for headbob and landing thud
offsets) and `rotation` (for shake). The `Camera3D` remains a direct child of
`CameraMount` so the existing `RayCast3D` hierarchy is undisturbed.

```
Player (CharacterBody3D / CharacterController)
└── CameraMount (Node3D)          — mouse-look rotates this (X axis, ±90°)
    ├── CameraEffects (Node3D)    — NEW: owns all offset state
    │   └── Camera3D              — moved here from CameraMount root
    │       └── RayCast3D
    └── (nothing else)
```

> **Implementation note for programmer**: `CharacterController._input()` already
> references `camera_mount` for mouse-look rotation. The camera effects script
> applies its offsets to `CameraMount.position` (a separate axis from rotation),
> so the two subsystems do not stomp each other. Confirm with a programmer that
> moving `Camera3D` one level deeper under `CameraEffects` does not break
> `get_aim_ray()` — the path `$CameraMount/Camera3D/RayCast3D` in
> `character_controller.gd` will need updating to
> `$CameraMount/CameraEffects/Camera3D/RayCast3D`.

Alternatively, `CameraEffects` can be a sibling of `Camera3D` under
`CameraMount` and write only to `CameraMount.position`. This keeps the existing
node paths valid. The programmer should choose whichever approach requires fewer
path changes. Either is acceptable; the design is path-agnostic.

### 3.2 Effect: Headbob

Headbob is a sinusoidal vertical (Y-axis) oscillation of `CameraMount.position`
that is active only while the player is moving on the ground.

**Activation conditions**:
- `CharacterController.is_on_floor()` is true
- The horizontal velocity magnitude (`Vector2(velocity.x, velocity.z).length()`)
  exceeds `BOB_VELOCITY_THRESHOLD` (default: 0.5 m/s — just above the
  `move_toward` deceleration floor)

**Deactivation**: When either condition is false, the bob phase freezes. The
accumulated Y offset decays back to zero using `lerp` toward 0.0 each frame at
rate `BOB_RETURN_SPEED`. This prevents a jarring snap when the player stops.

**Phase accumulation**: Each physics frame, a `_bob_time` accumulator increments
by `delta * BOB_FREQUENCY * speed_ratio`, where `speed_ratio` is the current
horizontal speed divided by `CharacterController.move_speed`. This makes the
headbob tempo proportional to actual movement speed, so partial-speed strafes
produce a slower, shorter bob than full-speed running.

**Bob output**: `CameraMount.position.y += sin(_bob_time * TAU) * BOB_AMPLITUDE`

The bob resets `_bob_time` to 0.0 when the player stops, so the next motion
always starts from the neutral zero-crossing of the sine wave, avoiding a sudden
offset jump.

### 3.3 Effect: Landing Thud

On `CharacterController.landed`, the camera snaps downward by a displacement
proportional to the landing velocity, then springs back to the neutral position
over a short duration.

**Steps**:
1. `CharacterController.landed` fires. Read `CharacterController.last_landing_velocity`
   (the cached pre-slide downward velocity, always negative or zero).
2. Calculate thud displacement:
   `thud_offset = clamp(abs(last_landing_velocity) * THUD_VELOCITY_SCALE, 0.0, THUD_MAX_OFFSET)`
3. Apply `CameraMount.position.y -= thud_offset` instantly (same frame as signal).
4. Each subsequent frame, lerp `CameraMount.position.y` back toward `0.0` at
   `THUD_RETURN_SPEED`. The spring-back is complete when the absolute Y offset
   is below `0.001` metres.

**Interaction with headbob**: The thud offset and the headbob offset are tracked
in separate variables (`_thud_offset_y` and `_bob_offset_y`) and summed on
write: `CameraMount.position.y = _bob_offset_y + _thud_offset_y`. They do not
stomp each other.

**Jump suppression**: The `jumped` signal fires when the player leaves the floor.
On `jumped`, reset `_bob_time` to 0.0 so the headbob does not continue while
airborne (see §3.2 activation conditions — `is_on_floor()` will already be
false, but the phase reset ensures a clean re-entry on landing).

### 3.4 Effect: Camera Shake

Camera shake applies a random offset to `CameraMount.rotation` (in radians)
that decays exponentially to zero. The offset is applied in addition to, and
additively with, the mouse-look rotation — the `_shake_rotation` variable is
added to `CameraMount.rotation` each frame and decays independently.

> **Implementation note**: Because `CharacterController._input()` writes to
> `camera_mount.rotation.x` directly, the shake system must NOT write to
> `CameraMount.rotation` as a whole. Instead, `CameraEffects` maintains a
> `_shake_rotation: Vector3` accumulator. Each `_process()` frame it applies
> `camera_mount.rotation += _shake_rotation` AFTER mouse-look has already
> been handled. The physics process order must guarantee mouse-look runs in
> `_input()` before `CameraEffects._process()` runs. Because `_input()` is
> always processed before `_process()` in Godot's frame loop, this is safe.

**Shake trigger sources**:

| Source | Signal | Profile Name |
|--------|--------|-------------|
| Gravity Flip activated | `BaseTool.tool_activated` where `tool_name == "gravity_flip"` | `SHAKE_GRAVITY` |
| Time Slow activated | `BaseTool.tool_activated` where `tool_name == "time_slow"` | `SHAKE_TIME_SLOW` |
| Force Push activated | `BaseTool.tool_activated` where `tool_name == "force_push"` | `SHAKE_FORCE_PUSH` |
| Player took damage | `HealthComponent.took_damage` (see §6 — this signal does not yet exist) | `SHAKE_DAMAGE` |

**Shake profile structure** (one per profile, stored as exported sub-resources
or as named `@export` groups):

| Parameter | Description |
|-----------|-------------|
| `magnitude: float` | Peak rotation magnitude in radians |
| `frequency: float` | How many direction reversals per second (trauma oscillation rate) |
| `decay: float` | Exponential decay constant (larger = faster decay) |
| `axis_bias: Vector2` | Relative weight of X (pitch) vs Y (yaw) shake — e.g., Force Push is mostly Y |

**Shake accumulation**: Multiple simultaneous triggers add their magnitudes
(with a hard cap at `SHAKE_MAX_MAGNITUDE` radians). This means taking damage
while activating a tool produces a stronger combined shake, which is the
intended behavior.

**Per-frame shake calculation**:
```
_shake_trauma = max(0.0, _shake_trauma - decay * delta)
shake_angle   = _shake_trauma ^ 2 * magnitude   # squaring gives smoother onset
offset_x      = shake_angle * axis_bias.x * sin(time * frequency * TAU)
offset_y      = shake_angle * axis_bias.y * cos(time * frequency * TAU * 1.3)
_shake_rotation = Vector3(offset_x, offset_y, 0.0)
```

The 1.3 multiplier on the Y cosine frequency desynchronizes the two axes so the
pattern does not repeat visibly over the shake duration.

### 3.5 Effect: FOV Sprint Boost (Low Priority)

When the player's horizontal speed equals `CharacterController.move_speed` (full
speed, all input directions), the Camera3D's `fov` property is lerped upward by
`FOV_BOOST_DEGREES`. When speed drops below `move_speed * FOV_BOOST_THRESHOLD`,
the FOV lerps back to the base value.

This effect is **disabled by default** (`FOV_BOOST_DEGREES = 0.0`). It is
included in the design for Vertical Slice experimentation but must not ship
enabled until validated in a playtest. Reason: in a physics puzzle game where
aim precision matters, unwanted FOV shift can mislead spatial judgement.

**FOV interpolation**:
```
target_fov = BASE_FOV + (FOV_BOOST_DEGREES if is_at_full_speed else 0.0)
camera.fov  = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)
```

---

## 4. Formulas

### 4.1 Headbob Sine Offset

```
speed_ratio    = clamp(horizontal_speed / move_speed, 0.0, 1.0)
_bob_time     += delta * BOB_FREQUENCY * speed_ratio

bob_y          = sin(_bob_time * TAU) * BOB_AMPLITUDE * speed_ratio
```

**Variable definitions**:

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `horizontal_speed` | float | 0.0 – `move_speed` | `Vector2(velocity.x, velocity.z).length()` |
| `move_speed` | float | 1.0 – 20.0 m/s | From `CharacterController.move_speed` |
| `BOB_FREQUENCY` | float | 0.5 – 4.0 Hz | Oscillations per second at full speed |
| `BOB_AMPLITUDE` | float | 0.0 – 0.05 m | Peak vertical displacement |
| `_bob_time` | float | 0.0 – unbounded (wraps at 1.0) | Phase accumulator (reset to 0 on stop or jump) |
| `speed_ratio` | float | 0.0 – 1.0 | Scales both frequency and amplitude |
| `BOB_RETURN_SPEED` | float | 1.0 – 20.0 | lerp rate (per second) back to zero when stopped |

**Example calculation** (defaults):
- `BOB_FREQUENCY = 1.8`, `BOB_AMPLITUDE = 0.012 m`, `move_speed = 6.0 m/s`
- Player at full speed (6.0 m/s): one full bob cycle every 0.56 s, ±1.2 cm peak
- Player at half speed (3.0 m/s): one full bob cycle every 1.1 s, ±0.6 cm peak

**Why 1.8 Hz at full speed**: walking cadence is ~1.7–2.0 steps/sec. Matching
the bob to the natural pace avoids the "swimming" feeling common when frequency
mismatches movement tempo.

### 4.2 Landing Thud Displacement

```
thud_offset = clamp(abs(last_landing_velocity) * THUD_VELOCITY_SCALE, 0.0, THUD_MAX_OFFSET)

# Each frame after landing:
_thud_offset_y = lerp(_thud_offset_y, 0.0, THUD_RETURN_SPEED * delta)
```

**Variable definitions**:

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `last_landing_velocity` | float | ≤ 0.0 m/s | Cached in `CharacterController` before `move_and_slide` |
| `THUD_VELOCITY_SCALE` | float | 0.0 – 0.05 | Converts m/s downward to metres of camera drop |
| `THUD_MAX_OFFSET` | float | 0.0 – 0.15 m | Hard cap on maximum thud displacement |
| `THUD_RETURN_SPEED` | float | 2.0 – 20.0 | lerp rate (per second) returning to neutral |
| `_thud_offset_y` | float | –`THUD_MAX_OFFSET` – 0.0 | Current thud contribution |

**Example calculation** (defaults):
- `THUD_VELOCITY_SCALE = 0.008`, `THUD_MAX_OFFSET = 0.06 m`, `THUD_RETURN_SPEED = 8.0`
- Falling at 5.0 m/s: `thud_offset = clamp(5.0 * 0.008, 0, 0.06) = 0.04 m`
- At `THUD_RETURN_SPEED = 8.0`, after 0.125 s the offset is ~36% of original
  (lerp geometry), effectively invisible within 0.4 s

### 4.3 Camera Shake Decay

```
# On trigger (additive accumulation):
_shake_trauma = min(_shake_trauma + profile.magnitude, SHAKE_MAX_MAGNITUDE)

# Each frame:
_shake_trauma  = max(0.0, _shake_trauma - profile.decay * delta)
effective_mag  = _shake_trauma ^ 2
offset_x       = effective_mag * profile.axis_bias.x * sin(_shake_time * profile.frequency * TAU)
offset_y       = effective_mag * profile.axis_bias.y * cos(_shake_time * profile.frequency * TAU * 1.3)
_shake_time   += delta
_shake_rotation = Vector3(offset_x, offset_y, 0.0)
```

**Variable definitions**:

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `_shake_trauma` | float | 0.0 – `SHAKE_MAX_MAGNITUDE` | Current trauma level (decays each frame) |
| `profile.magnitude` | float | 0.0 – 0.15 rad | Peak trauma added per trigger event |
| `profile.frequency` | float | 2.0 – 20.0 Hz | Direction reversal rate |
| `profile.decay` | float | 0.5 – 10.0 | Trauma units lost per second |
| `profile.axis_bias` | Vector2 | (0.0,0.0) – (1.0,1.0) | Relative X:Y shake weight; magnitude is not required to sum to 1.0 |
| `SHAKE_MAX_MAGNITUDE` | float | 0.05 – 0.2 rad | Hard cap on accumulated trauma |
| `_shake_time` | float | 0.0 – unbounded | Monotonically increasing; used for sin/cos phase |

**Default profiles**:

| Profile | magnitude | frequency | decay | axis_bias |
|---------|-----------|-----------|-------|-----------|
| `SHAKE_GRAVITY` | 0.04 rad | 6.0 Hz | 4.0 | (0.7, 0.3) — mostly pitch |
| `SHAKE_TIME_SLOW` | 0.02 rad | 3.0 Hz | 3.0 | (0.5, 0.5) — even |
| `SHAKE_FORCE_PUSH` | 0.06 rad | 8.0 Hz | 5.0 | (0.3, 0.7) — mostly yaw |
| `SHAKE_DAMAGE` | 0.08 rad | 10.0 Hz | 6.0 | (0.6, 0.4) |

**Example calculation** — Force Push at t=0:
- `_shake_trauma = 0.06`, `frequency = 8.0`, `decay = 5.0`
- At t=0.1 s: `_shake_trauma = 0.06 - (5.0 * 0.1) = 0.01`, `effective_mag = 0.0001 rad` — nearly imperceptible
- Total shake visible duration: ~0.12 s at these defaults. Feels like a quick hit, not a sustained wobble.

### 4.4 FOV Interpolation

```
is_at_full_speed = (horizontal_speed >= move_speed * FOV_BOOST_THRESHOLD)
target_fov       = BASE_FOV + (FOV_BOOST_DEGREES if is_at_full_speed else 0.0)
camera.fov       = lerp(camera.fov, target_fov, clamp(FOV_LERP_SPEED * delta, 0.0, 1.0))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `BASE_FOV` | float | 60.0 – 110.0 deg | Godot Camera3D default is 75.0 |
| `FOV_BOOST_DEGREES` | float | 0.0 – 15.0 deg | Extra FOV at full speed. **Default: 0.0 (disabled)** |
| `FOV_BOOST_THRESHOLD` | float | 0.7 – 1.0 | Speed fraction at which boost engages |
| `FOV_LERP_SPEED` | float | 1.0 – 10.0 | Degrees-per-second feel of the transition |

---

## 5. Edge Cases

### 5.1 Landing while already in a thud animation

If the player lands, bounces, and lands again before `_thud_offset_y` has
returned to zero: add the new thud displacement on top of the current
`_thud_offset_y` (do not reset it). Clamp the sum to `-THUD_MAX_OFFSET` so
stacked landings cannot push the camera below the maximum design threshold.

### 5.2 Landing from gravity-flip fall

When the player is subject to Gravity Flip on themselves (future feature) or
falls from a flipped-gravity object, `last_landing_velocity` may be positive
(moving upward when they "land" on a ceiling). `CameraEffects` must use
`abs(last_landing_velocity)` for the thud calculation regardless of sign, and
apply the thud in the direction of the floor normal. For MVP (no gravity flip on
player), the landing velocity is always negative; this note is a forward-looking
guard.

### 5.3 Zero move_speed (divide-by-zero in headbob)

`CharacterController.move_speed` is used as a divisor. If it is set to 0.0
(e.g., during debugging), `speed_ratio` must be clamped: use
`move_speed if move_speed > 0.0 else 1.0` as the denominator. The bob simply
treats 0.0 m/s as no movement and does not oscillate.

### 5.4 Simultaneous shake from multiple tools in one frame

Because `tool_activated` is emitted once per activation call, and tool
activations are input-gated (one tool fires at most once per `_input` frame),
simultaneous multi-tool activation in one frame is not possible for a single
player. In co-op, each player's `CameraEffects` is a separate node instance;
they do not share state. There is no cross-player contamination.

### 5.5 Rapid repeated tool activations (shake spam)

A player may rapidly toggle Gravity Flip to accumulate trauma. The
`SHAKE_MAX_MAGNITUDE` cap handles this — additional trauma events above the
cap are silently discarded. The result is a sustained shake at the cap level
rather than an unreadable screen.

### 5.6 took_damage signal not yet emitted (forward dependency)

The `HealthComponent.took_damage` signal listed in §3.4 does not yet exist in
the codebase (as of 2026-03-27). The `SHAKE_DAMAGE` profile is designed and
ready; the `CameraEffects` node should connect to this signal in `_ready()` with
a null-safe check:

```gdscript
var health := get_parent().get_parent().get_node_or_null("HealthComponent")
if health and health.has_signal("took_damage"):
    health.took_damage.connect(_on_took_damage)
```

This means `SHAKE_DAMAGE` silently does nothing until `HealthComponent` adds the
signal. See §6 for the formal dependency note.

### 5.7 Mouse look during active shake

Mouse look is applied by `CharacterController._input()` which writes directly to
`camera_mount.rotation`. Shake writes an additive offset in `_process()`. Because
`_input()` always runs before `_process()` in Godot's frame order, mouse look
executes first each frame, and shake offsets are layered on top. The player can
look freely during shake — the shake offset is purely cosmetic and does not
redirect the aim ray.

### 5.8 Headbob and motion sickness accessibility

All three motion effects (headbob, thud, shake) are individually zero-able via
their `@export` knobs. If an Accessibility System is added (Full Vision tier),
it should write to these knobs. Until then, a developer can zero them in the
Inspector for testing. An explicit "reduced motion" preset in the Settings system
is tracked as a dependency for the Accessibility System (not in scope here).

### 5.9 CameraMount.position conflict with other systems

No other current system writes to `CameraMount.position`. If a future system
(e.g., a crouch mechanic) also writes to this node's position, a shared offset
accumulator pattern must be introduced. Document this risk at implementation
time.

---

## 6. Dependencies

### What Camera System requires

| System | Dependency | Direction |
|--------|-----------|-----------|
| **Character Controller** | `landed` signal, `jumped` signal, `last_landing_velocity`, `move_speed`, `velocity`, `camera_mount` node reference | Camera reads from CharacterController |
| **Physics Tool System** | `BaseTool.tool_activated(tool_name, target)` signal | Camera listens; Physics Tool System is unaware of Camera |
| **Health & Death System** | `HealthComponent.took_damage` signal (not yet emitted — forward dependency, see §5.6) | Camera listens; HealthComponent is unaware of Camera |

### What Camera System provides to other systems

| System | What it provides |
|--------|-----------------|
| **Visual Effects & Juice System** | Camera shake and FOV are owned here; VFX system should NOT independently modify Camera3D properties. Coordinate through `CameraEffects` public methods (`trigger_shake(profile)`, `trigger_thud(velocity)`) if VFX needs to drive camera reactions. |
| **Settings & Options System** (Full Vision) | All `@export` tuning knobs are the interface for a future "reduced motion" accessibility setting. The Settings system writes to `BOB_AMPLITUDE`, `THUD_MAX_OFFSET`, `SHAKE_MAX_MAGNITUDE` to implement accessibility presets. |

### Bidirectional notes for other GDDs

- **Character Controller GDD** (`character-controller.md`): Should note in its
  Dependencies section that `CameraEffects` connects to `landed`, `jumped`, and
  reads `last_landing_velocity`. This is currently absent from that document.
- **Physics Tool System GDD** (`physics-tool-system.md`): Should note in its
  Required By section that Camera System subscribes to `tool_activated`. It is
  currently listed as required by VFX and Audio only.
- **Health & Death System GDD** (`health-death-system.md`): Should note that a
  `took_damage` signal is required by Camera System. This signal is not yet
  specified in that document; adding it is a prerequisite for `SHAKE_DAMAGE` to
  function.

---

## 7. Tuning Knobs

All values are `@export` on `CameraEffects`. All effects can be disabled by
zeroing the relevant amplitude knob. Safe ranges are conservatively wide —
stay near the defaults for first playtest.

### Headbob Knobs

| Knob | Category | Default | Safe Range | Effect of Increasing |
|------|----------|---------|------------|---------------------|
| `BOB_AMPLITUDE` | feel | 0.012 m | 0.0 – 0.05 m | Larger vertical swing; can cause motion sickness above 0.03 m |
| `BOB_FREQUENCY` | feel | 1.8 Hz | 0.5 – 4.0 Hz | Faster step cadence; feels unnatural above ~2.5 Hz |
| `BOB_VELOCITY_THRESHOLD` | gate | 0.5 m/s | 0.0 – 3.0 m/s | Higher value means bob only activates during faster movement |
| `BOB_RETURN_SPEED` | feel | 8.0 | 1.0 – 20.0 | Faster return to neutral when stopping; higher prevents visible hang |

### Landing Thud Knobs

| Knob | Category | Default | Safe Range | Effect of Increasing |
|------|----------|---------|------------|---------------------|
| `THUD_VELOCITY_SCALE` | feel | 0.008 | 0.0 – 0.05 | More camera drop per m/s of fall velocity |
| `THUD_MAX_OFFSET` | gate | 0.06 m | 0.0 – 0.15 m | Hard cap on camera drop; prevents disorientation on extreme falls |
| `THUD_RETURN_SPEED` | feel | 8.0 | 2.0 – 20.0 | Faster spring-back; lower values feel more rubbery |

### Shake Knobs (per profile)

Each shake profile (`SHAKE_GRAVITY`, `SHAKE_TIME_SLOW`, `SHAKE_FORCE_PUSH`,
`SHAKE_DAMAGE`) exports these four values:

| Knob | Category | Default range | Effect of Increasing |
|------|----------|--------------|---------------------|
| `magnitude` | feel | 0.02–0.08 rad | Stronger initial trauma; FORCE_PUSH should be highest |
| `frequency` | feel | 3.0–10.0 Hz | Faster oscillation; lower is more "sway", higher is more "impact" |
| `decay` | feel | 3.0–6.0 | Faster shake resolution; increase if shake feels too long |
| `axis_bias` | feel | (0.3–0.7, 0.3–0.7) | Tool identity; each tool should have a distinct signature |

Global cap:

| Knob | Category | Default | Safe Range | Effect of Increasing |
|------|----------|---------|------------|---------------------|
| `SHAKE_MAX_MAGNITUDE` | gate | 0.10 rad | 0.0 – 0.20 rad | Maximum simultaneous trauma; higher allows more extreme stacking |

### FOV Knobs

| Knob | Category | Default | Safe Range | Effect of Increasing |
|------|----------|---------|------------|---------------------|
| `BASE_FOV` | gate | 75.0 deg | 60.0 – 110.0 deg | Wider field of view at all times |
| `FOV_BOOST_DEGREES` | feel | 0.0 deg | 0.0 – 15.0 deg | **Default off.** Larger boost on sprint feels faster but risks aim error |
| `FOV_BOOST_THRESHOLD` | gate | 0.9 | 0.7 – 1.0 | Lower means boost engages earlier in the speed range |
| `FOV_LERP_SPEED` | feel | 4.0 | 1.0 – 10.0 | Faster transition between base and boosted FOV |

---

## 8. Acceptance Criteria

### Functional Criteria (automated or manual check)

| ID | Criterion | Pass Condition | Fail Condition |
|----|-----------|---------------|---------------|
| CAM-F1 | Headbob activates on movement | With `BOB_AMPLITUDE = 0.012`, `CameraMount.position.y` oscillates while player moves at full speed | Position is static while moving |
| CAM-F2 | Headbob stops when still | Within 0.5 s of stopping, `abs(_bob_offset_y) < 0.001` | Camera continues bobbing after player stops |
| CAM-F3 | Headbob is proportional to speed | At half speed, bob peak amplitude is ≤ 60% of full-speed amplitude | Amplitude is identical at all non-zero speeds |
| CAM-F4 | Landing thud fires on landed signal | On any landing from ≥ 1 m height, `CameraMount.position.y` drops by at least `0.005` m then returns to 0.0 | No camera movement on landing |
| CAM-F5 | Landing thud returns to zero | Within 1.0 s of landing, `abs(_thud_offset_y) < 0.001` | Camera remains depressed after landing |
| CAM-F6 | Tool shake fires on activation | Activating Gravity Flip produces a measurable non-zero `_shake_rotation` within the same frame | No rotation change after tool activation |
| CAM-F7 | Shake decays to zero | For all profiles, `abs(_shake_rotation.x) < 0.001` and `abs(_shake_rotation.y) < 0.001` within 1.0 s of trigger with no further triggers | Shake persists indefinitely |
| CAM-F8 | Shake cap is respected | Activating all three tools in rapid succession does not produce `_shake_trauma > SHAKE_MAX_MAGNITUDE` | Trauma exceeds cap |
| CAM-F9 | Zero-amplitude disables effects | Setting `BOB_AMPLITUDE = 0`, `THUD_MAX_OFFSET = 0`, `SHAKE_MAX_MAGNITUDE = 0` produces no camera movement under any input | Effects still visible at zero amplitude |
| CAM-F10 | Mouse look unaffected by shake | Aiming at a fixed point, firing a tool, and immediately releasing — the final resting aim angle equals the starting aim angle (within mouse precision) | Aim is permanently deflected by shake |
| CAM-F11 | Each tool has distinct shake signature | `SHAKE_GRAVITY`, `SHAKE_FORCE_PUSH`, and `SHAKE_TIME_SLOW` produce visibly different camera responses | Shakes are perceptually identical |

### Experiential Criteria (playtest validation)

| ID | Criterion | Validation Method |
|----|-----------|-----------------|
| CAM-E1 | Headbob feels grounded, not nauseating | 15-minute playtest session; ask 3 testers "did the camera movement bother you?" Target: ≤ 1 of 3 reports discomfort at default values |
| CAM-E2 | Landing thud reads as "weight" not "bug" | Blind playtest: ask testers to describe what they feel on landing. Target: at least 2 of 3 use words like "thud", "impact", or "weight" without prompting |
| CAM-E3 | Tool shakes feel distinct and intentional | Playtest with all three tools. Ask "can you tell which tool you used by feel alone?" Target: 2 of 3 testers correctly associate shake signatures to tools after 5 minutes |
| CAM-E4 | No motion sickness reports at defaults | 20-minute continuous play session with 3 testers. Target: zero nausea reports at default values |
| CAM-E5 | Zero-effect setting is genuinely neutral | Tester plays with all amplitudes zeroed. Confirm the camera "feels like a floating eye" — no unintended residual motion |
| CAM-E6 | Aim precision unaffected | Tester completes a tool-targeting task (e.g., gravity-flip a box from 10 m) during active shake. Task completion rate should match the no-shake baseline within 10% |
