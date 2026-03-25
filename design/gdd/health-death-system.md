# GDD: Health & Death System

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 9 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: Character Controller
> **Required By**: Player Spawning & Respawn, HUD, Enemy & Hazard System, Escalation System

---

## 1. Overview

The Health & Death System tracks a player's hit points, processes damage from
all sources, and triggers death when HP reaches zero. It exposes a clean API
(`take_damage`, `heal`, `kill`) so any system can deal damage without knowing
how health works internally. On death it emits a signal — the Player Spawning &
Respawn System listens to this and handles what happens next. For MVP (solo, no
enemies), death is triggered only by fall damage or out-of-bounds volumes.

---

## 2. Player Fantasy

The player feels fragile but competent. Taking damage is a meaningful event —
the screen reacts, the audio reacts — but the player is never one-shotted by
something off-screen. Death is fair. Respawn is fast enough that failure
doesn't feel punishing.

---

## 3. Detailed Rules

### 3.1 HP Pool

Each player has a single HP value that starts at `MAX_HP` and decreases on
damage events. There is no armour, damage resistance, or damage type system
in MVP — all sources deal flat HP reduction.

| Property | Value | Notes |
|----------|-------|-------|
| `MAX_HP` | 100 | Starting and maximum HP |
| `current_hp` | 100 | Decremented by damage events |
| `MIN_HP` | 0 | At zero, death is triggered |

HP does not regenerate passively in MVP. Healing items are Vertical Slice scope.

### 3.2 Damage Sources (MVP)

| Source | Damage | Notes |
|--------|--------|-------|
| Fall damage | variable (see §4) | Triggers when landing velocity exceeds threshold |
| Out-of-bounds volume | instant death (HP → 0) | Area3D trigger placed below the floor |
| Environmental hazards | variable | Defined per hazard in Enemy & Hazard GDD (Vertical Slice) |

### 3.3 Death Trigger

When `current_hp` reaches 0:
1. Set `current_hp = 0` (clamp, never go negative).
2. Emit `died` signal.
3. Disable player input (`set_process_input(false)`, `set_physics_process(false)`).
4. Do NOT free the player node — Player Spawning & Respawn handles that.

The `died` signal carries no payload. Any subscriber that needs context
(position at death, cause of death) must read it from the player directly.

### 3.4 Fall Damage

Fall damage is calculated from the player's downward velocity on landing.
The `CharacterController` emits `landed`; the `HealthComponent` listens and
reads the velocity.

| Velocity (m/s downward) | Damage |
|-------------------------|--------|
| < FALL_DAMAGE_THRESHOLD | 0 |
| ≥ FALL_DAMAGE_THRESHOLD | `(speed - threshold) * FALL_DAMAGE_FACTOR` |

See §4 for formulas and example values.

### 3.5 Component Architecture

Health logic lives in a `HealthComponent` node that is a child of `Player`,
not in `CharacterController`. This keeps the controller script focused on
movement and makes health testable in isolation.

```
Player (CharacterBody3D)
├── HealthComponent   (script: health_component.gd)
├── CollisionShape3D
├── CameraMount
└── ToolManager
```

`CharacterController` does NOT know about health. Systems that deal damage
call `get_node("HealthComponent").take_damage(amount)` or use the player's
exported `health` property that forwards to the component.

### 3.6 Out-of-Bounds Detection

An `Area3D` node named `KillVolume` is placed below each room's floor
(y = -5.0 by default). When the player enters it:

```gdscript
# In main.gd or room template:
kill_volume.body_entered.connect(func(body):
    if body.has_node("HealthComponent"):
        body.get_node("HealthComponent").kill()
)
```

This is not the HealthComponent's responsibility — it is the room's
responsibility to detect out-of-bounds and call `kill()`.

---

## 4. Formulas

### Fall Damage

```
speed = abs(velocity.y) on frame landed

if speed < FALL_DAMAGE_THRESHOLD:
    damage = 0
else:
    damage = (speed - FALL_DAMAGE_THRESHOLD) * FALL_DAMAGE_FACTOR

FALL_DAMAGE_THRESHOLD = 8.0 m/s  (≈ falling 3.3m — meaningful drop)
FALL_DAMAGE_FACTOR    = 10.0     (damage per extra m/s above threshold)

Examples:
  speed = 6.0 m/s  → 0 damage   (short hop)
  speed = 8.0 m/s  → 0 damage   (exactly at threshold)
  speed = 10.0 m/s → 20 damage  (2.0 * 10)
  speed = 14.0 m/s → 60 damage  (6.0 * 10 — near-lethal fall)
```

### Jump Height Reference (from Character Controller GDD)

```
max_height ≈ jump_velocity² / (2 * gravity)
           = 5.0² / (2 * 9.8)
           ≈ 1.28 m

Landing speed after 1.28m fall ≈ 5.0 m/s → no fall damage (below threshold).
Landing speed after 3.3m fall  ≈ 8.0 m/s → threshold, 0 damage.
Landing speed after 5.0m fall  ≈ 9.9 m/s → ~19 damage.
```

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| `take_damage(0)` | Valid — no-op. `health_changed` is NOT emitted for zero-damage calls. |
| `take_damage` when already dead (`current_hp == 0`) | Ignore — do not emit `died` twice. Guard with `if current_hp == 0: return`. |
| `heal()` above MAX_HP | Clamp: `current_hp = min(current_hp + amount, MAX_HP)`. |
| `kill()` called directly | Sets `current_hp = 0`, emits `died`. Bypasses all damage logic. Used by out-of-bounds volume. |
| Player falls through the floor (physics tunnel) | KillVolume below the floor catches this. If KillVolume is also missed, the player drifts forever — acceptable for MVP. Log a warning at y < -20.0. |
| Fall damage when gravity-flipped (hitting the ceiling fast) | The `landed` signal fires on any floor collision (CharacterController uses `is_on_floor()`). Gravity-flipped players ceiling-slam won't trigger `landed`. Out-of-bounds volume handles the case where they fly out of the room. No fall damage from ceiling. |

---

## 6. Dependencies

- **Depends on**:
  - Character Controller (provides `landed` signal for fall damage detection, movement velocity)

- **Required by**:
  - Player Spawning & Respawn (listens to `died`, handles respawn flow)
  - HUD (reads `current_hp` and `MAX_HP` for health bar display)
  - Enemy & Hazard System (calls `take_damage()` on hit — Vertical Slice)
  - Escalation System (may reference player death count as escalation factor)
  - Mission Debrief System (may report deaths in debrief screen)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `MAX_HP` | health_component.gd | 100 | 50–200 | How many hits the player can take |
| `FALL_DAMAGE_THRESHOLD` | health_component.gd | 8.0 m/s | 5.0–15.0 | How far you fall before taking damage |
| `FALL_DAMAGE_FACTOR` | health_component.gd | 10.0 | 5.0–25.0 | Damage per m/s above threshold |
| KillVolume y position | room scene / main.gd | -5.0 | -2.0 to -10.0 | How far below floor triggers instant death |

---

## 8. Acceptance Criteria

- [ ] `HealthComponent` node exists as a child of Player in `Player.tscn`
- [ ] `take_damage(amount)` reduces `current_hp` and emits `health_changed(new_hp, max_hp)`
- [ ] `current_hp` never goes below 0 or above `MAX_HP`
- [ ] `died` signal fires exactly once when HP reaches 0 — not twice if damage over-shoots
- [ ] Fall damage is 0 for a standard jump (≈5 m/s landing) and non-zero for a 5m+ fall
- [ ] KillVolume at y=-5.0 triggers `kill()` and `died` within one physics frame of entry
- [ ] Player input is disabled after `died` fires (player freezes in place)
- [ ] `HealthComponent` can be tested in isolation without the rest of Player scene
