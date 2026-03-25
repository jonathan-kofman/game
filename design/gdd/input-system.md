# GDD: Input System

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 2 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: nothing
> **Required By**: Character Controller, Physics Tool System, all UI

---

## 1. Overview

The Input System defines every action the player can perform and maps them to
physical inputs (keyboard, mouse, gamepad). It is a thin abstraction layer:
game systems never poll hardware directly — they check named actions defined
here. This decouples control schemes from gameplay logic and makes remapping
possible without touching game code.

---

## 2. Player Fantasy

Controls feel immediate and predictable. The player never fights the input —
pressing a key does exactly what the label says, every time. On keyboard/mouse
the game feels like a tight FPS. Future gamepad support requires no gameplay
changes, only a new input mapping.

---

## 3. Detailed Rules

### 3.1 Action List

| Action Name | Default Key | Type | Description |
|-------------|-------------|------|-------------|
| `move_forward` | W | held | Move forward relative to player facing |
| `move_back` | S | held | Move backward relative to player facing |
| `move_left` | A | held | Strafe left |
| `move_right` | D | held | Strafe right |
| `jump` | Space | pressed | Apply jump impulse if grounded |
| `tool_gravity` | G | pressed | Activate Gravity Flip tool |
| `tool_time_slow` | T | pressed | Toggle Time Slow tool |
| `tool_force_push` | F | pressed | Activate Force Push tool |
| `interact` | E | pressed | Interact with world objects (doors, terminals) |
| `pause` | Escape | pressed | Open/close pause menu |

### 3.2 Input Polling Rules

- Movement actions use `Input.get_vector("move_left", "move_right", "move_forward", "move_back")` — returns a normalized Vector2.
- Tool actions use `event.is_action_pressed()` inside `_input()` — not `_process()` — to guarantee one-shot detection and avoid missed frames.
- Mouse look reads `InputEventMouseMotion.relative` directly (not an action) in `_input()`.
- No game system calls `Input.is_key_pressed()` with a raw keycode. Always use action names.

### 3.3 Mouse Capture

- On game start: `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`.
- On pause/Escape: `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`.
- On resume: `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`.
- Mouse sensitivity is a tuning knob on the Character Controller, not the Input System.

### 3.4 Remapping (Future Scope)

- Remapping is **not** in MVP. The action names in `project.godot` are the contract.
- When remapping is added (Settings & Options — Full Vision), it will write to a
  user-specific override file. No game code changes required.

### 3.5 Gamepad (Future Scope)

- Not in MVP. When added, each action in the Input Map gets a second event
  (joypad button or axis). No game code changes required.

---

## 4. Formulas

No math required — the Input System is pure mapping, not calculation.

The only numeric value owned here:

```
deadzone = 0.5   (applied to all actions in project.godot)
```

Deadzone affects analog stick sensitivity when gamepad is added. Has no effect
on keyboard input.

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Player presses two opposing movement keys (W+S) | `get_vector()` returns zero — player stops. Godot handles this automatically. |
| Tool key pressed with no valid target | Each tool handles the no-target case internally and shows feedback text. |
| Window loses focus mid-game | Godot auto-releases mouse capture. Input events stop firing. Mouse recaptures on window click. |
| `pause` pressed during tool activation | Tool activation is one-shot (already fired). Pause opens normally next frame. |
| Multiple tool keys pressed same frame | Each fires independently. Combo behaviour is the Physics Tool System's responsibility. |

---

## 6. Dependencies

- **Depends on**: Nothing — this is a foundation system.
- **Required by**:
  - Character Controller (reads move_forward/back/left/right, jump)
  - Physics Tool System (reads tool_gravity, tool_time_slow, tool_force_push)
  - Interact System (reads interact)
  - UI / Pause (reads pause)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `deadzone` | project.godot input map | 0.5 | 0.1–0.9 | Analog dead zone (no effect on keyboard) |
| Mouse sensitivity | character_controller.gd | 0.003 | 0.001–0.01 | How fast the camera rotates per pixel of mouse movement |

Mouse sensitivity lives on the Character Controller (not here) because it affects
camera rotation math, not raw input detection.

---

## 8. Acceptance Criteria

- [ ] All 10 actions listed in section 3.1 are present in `project.godot` input map
- [ ] No GDScript file uses `Input.is_key_pressed()` with a raw keycode
- [ ] Mouse capture engages on game start and releases on Escape
- [ ] Pressing W+S simultaneously results in zero movement (verified in play)
- [ ] All tool keys fire exactly once per press (no repeat-fire from hold)
