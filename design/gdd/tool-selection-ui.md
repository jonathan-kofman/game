# Tool Selection UI GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-09
**Created**: 2026-03-25

---

## 1. Overview

The Tool Selection UI is a fixed HBox interface anchored to the bottom-center of the viewport that displays the player's three equipped physics tools (GravityFlipTool, TimeSlowTool, ForcePushTool) and provides real-time visual feedback on tool state. Each tool occupies a fixed UI slot with a visual highlight indicating the active tool, a label showing the tool name, and (for TimeSlowTool only) a draining bar that visualizes held-down duration while the tool is active. The UI receives state from tool-emitted signals (tool_activated, tool_deactivated, tool_failed) and does not handle tool switching in MVP; input routing to the correct tool is managed by a separate input system. This UI exists in single-player (split into a dedicated viewport quadrant in future co-op) and must persist across room transitions.

---

## 2. Player Fantasy

The player feels in control of a quick, responsive ability set. The UI is **always visible and trustworthy**: they can glance at the bottom of the screen at any moment and instantly know which tool they are holding. When they activate a tool (press a key), the UI **confirms the activation visually** and **tracks the duration** of held tools (TimeSlowTool) with a draining bar so they understand resource constraints (future energy system) or task duration. Failed activations (e.g., "No valid target") appear briefly and vanish, informing without nagging. The three tools form a visual trio—spatially close together at screen-bottom—so the player builds muscle memory: *gravity is left, time is center, force is right*. In co-op, each player's own tools appear in their split-screen quadrant, never mixing with teammates' tools, so there's no confusion during hectic moments.

---

## 3. Detailed Rules

### 3.1 Tool Slot Layout
- **Container**: HBoxContainer with fixed width = 3 × (slot_width + slot_spacing) pixels.
- **Anchor**: bottom-center of viewport (MarginContainer with Anchor preset = bottom-center, margins = 0).
- **Tool Order**: Left-to-right: GravityFlipTool (tool_gravity input), TimeSlowTool (tool_time_slow input), ForcePushTool (tool_force_push input).
- **Slot Dimensions**: Each slot is a fixed 64×64 PanelContainer with a VBoxContainer child for label + draining bar.

### 3.2 Visual State: Active Tool Highlight
- **Appearance**: When a tool is active (tool_activated signal received), its slot background color changes to `accentColor` (tint overlay or stylebox change).
- **Inactive State**: Default background is `primaryColor` (faded, 40% alpha).
- **Transition**: Highlight applies immediately on signal reception (no animation in MVP, instant swap).
- **Reset Trigger**: tool_deactivated signal restores the slot to inactive state.

### 3.3 Tool Label
- **Content**: Tool friendly name (e.g., "Gravity Flip", "Time Slow", "Force Push").
- **Position**: Centered in the slot below the icon (future: icon not implemented in MVP, label only).
- **Font**: Monospace, 14px, white text.
- **Always Visible**: Label is always readable whether the slot is active or inactive.

### 3.4 Draining Bar (TimeSlowTool Only)
- **Purpose**: Visual feedback of held duration while TimeSlowTool is active.
- **Appearance**: Horizontal progress bar, full width of the slot, positioned below the label.
- **Fill Direction**: Left-to-right, fills from 0% → 100% as the player holds the tool.
- **Color**: Green-to-red gradient (full hold = red warning).
- **Update Rate**: Every frame, bar percentage = `current_held_time / max_display_duration`.
- **Visibility**: Only appears when TimeSlowTool is active; hidden when tool is deactivated.
- **Interaction**: Purely visual—bar does NOT enforce a hard limit in MVP, but shows intended duration ceiling.
- **Other Tools**: GravityFlip and ForcePush do not display a draining bar (single-frame activations).

### 3.5 Activation Feedback
- **Signal**: tool_activated(tool_name, target) received from the tool system.
- **UI Response**: Set slot highlight color and update internal state (active_tool variable).
- **Order**: Signal listeners execute in this order: set highlight → update active_tool flag → reset any error message.

### 3.6 Deactivation Feedback
- **Signal**: tool_deactivated(tool_name) received from the tool system.
- **UI Response**: Clear slot highlight, reset draining bar to 0%, remove active_tool flag.
- **Timing**: Immediate on signal (no fade-out animation in MVP).

### 3.7 Failure Feedback
- **Signal**: tool_failed(tool_name, reason) received from the tool system (reason = string, e.g., "No valid target").
- **UI Response**: Display reason string as a temporary floating label at the top of the slot (or center screen, TBD in prototype).
- **Appearance**: Red text, 12px, semi-transparent background.
- **Duration**: 2 seconds, then fade out and remove node.
- **Behavior**: If a new failure arrives while one is displayed, replace the old message with the new one.

### 3.8 Co-op Quadrant Placement (Future)
- **Single-Player**: HBox anchored to screen-bottom-center (as above).
- **Co-op (Split-Screen)**: Each player's Tool Selection UI is cloned and placed in that player's viewport quadrant:
  - Player 1: Bottom-left
  - Player 2: Bottom-right
  - Player 3: Top-left (if 4-player)
  - Player 4: Top-right (if 4-player)
- **Signal Routing**: Each UI instance listens only to its owner player's tool signals.

---

## 4. Formulas

### 4.1 Draining Bar Fill Percentage
```
bar_fill_percent = (current_held_time / max_display_duration) × 100

Variables:
  current_held_time (float, seconds): Time elapsed since TimeSlowTool was activated.
  max_display_duration (float, seconds): Target max duration for visual feedback.
                                         Tuning knob, default = 5.0s.

Expected Range:
  current_held_time: [0.0, ∞) seconds (unbounded in MVP, but display caps at 100%).
  bar_fill_percent: [0%, 100%] (clamped to prevent overflow UI).

Example Calculation:
  If max_display_duration = 5.0s and player has held for 2.5s:
    bar_fill_percent = (2.5 / 5.0) × 100 = 50%

  If player holds for 7.0s (exceeds max):
    bar_fill_percent = min((7.0 / 5.0) × 100, 100%) = 100%
```

### 4.2 Highlight Transition (MVP: Instant)
```
highlight_alpha = active ? 1.0 : 0.4

Variables:
  active (bool): True if slot's tool is currently active.
  highlight_alpha (float): Target background opacity for the slot.

Expected Range:
  highlight_alpha: [0.4, 1.0] (40% inactive, 100% active).

Behavior:
  On signal reception, alpha is set immediately (no easing in MVP).
```

### 4.3 Color Gradient (Draining Bar)
```
bar_color = lerp(green_color, red_color, fill_fraction)

Variables:
  green_color (Color): RGB(0, 255, 100) or #00FF64 (ready/safe).
  red_color (Color): RGB(255, 50, 50) or #FF3232 (warning/limit approaching).
  fill_fraction (float): Normalized [0.0, 1.0] representation of bar_fill_percent.

Example:
  At 0% fill: bar_color = green_color (full green).
  At 50% fill: bar_color = lerp(green, red, 0.5) = yellow-ish.
  At 100% fill: bar_color = red_color (full red warning).
```

### 4.4 Failure Message Fade-Out (Optional Animation)
```
message_alpha = max(0.0, 1.0 - (elapsed_time / fade_duration))

Variables:
  elapsed_time (float, seconds): Time since failure message appeared.
  fade_duration (float, seconds): Total time to fade out. Tuning knob, default = 0.5s.
  display_duration (float, seconds): Total time before removal. Default = 2.0s.

Behavior:
  message_alpha = 1.0 until (display_duration - fade_duration).
  At t = (display_duration - fade_duration), fade begins.
  At t = display_duration, message is removed from scene tree.

Example:
  display_duration = 2.0s, fade_duration = 0.5s:
    t ∈ [0.0, 1.5): alpha = 1.0 (fully opaque).
    t ∈ [1.5, 2.0): alpha = 1.0 - ((t - 1.5) / 0.5) (linear fade).
    t ≥ 2.0: message removed.
```

---

## 5. Edge Cases

### 5.1 Rapid Tool Activation/Deactivation
**Scenario**: Player taps tool key twice in quick succession (< 0.1 second apart).
**Expected Behavior**:
- First tool_activated signal → slot highlight applied, active_tool = tool A.
- Second tool_activated signal → slot highlight swaps to tool B, active_tool = tool B. First slot reverts to inactive.
- If deactivate signal arrives before second activate, first slot reverts to inactive before second highlight applies.
- **Result**: UI always reflects the most recent signal; no ghost highlights remain.

### 5.2 tool_failed During Active Tool
**Scenario**: Player holds TimeSlowTool, then presses a different tool that fails (e.g., ForcePush with no target).
**Expected Behavior**:
- tool_deactivated(TimeSlowTool) is NOT sent (tool is still held).
- tool_failed(ForcePush, reason) is received.
- Failure message displays for 2 seconds; TimeSlowTool highlight remains active; draining bar continues updating.
- TimeSlowTool slot stays highlighted; ForcePush slot does not highlight.
- **Result**: Failure message is non-blocking; active tool state is unaffected.

### 5.3 Tool Deactivated During Failure Message Display
**Scenario**: tool_deactivated signal arrives while a failure message is visible.
**Expected Behavior**:
- Active tool slot reverts to inactive highlight immediately.
- Failure message continues its 2-second timer (messages are independent of tool state).
- Draining bar (if visible) is hidden immediately on deactivation.
- **Result**: Tool state and failure feedback are independent; both update correctly.

### 5.4 Room Transition (Persistence)
**Scenario**: Player exits a room and enters a new room while holding a tool (e.g., TimeSlowTool is still active).
**Expected Behavior**:
- Tool Selection UI persists in the scene tree (not freed on room exit).
- On room entry, the new room's tool system connects its signals to the same UI.
- Highlight and draining bar remain active if the tool is still held; no visual flicker.
- If tool is released during transition, deactivated signal resets UI cleanly.
- **Result**: UI seamlessly follows the player across room boundaries.

### 5.5 No Tools Equipped (Scenario: Future Loadout System)
**Scenario**: In future, a player temporarily has no tools (e.g., loadout not initialized).
**Expected Behavior**:
- All three slots remain visible but disabled (greyed out, non-interactive).
- Tool signals are not connected, so no activation/deactivation occurs.
- Labels still show tool names (for clarity).
- **Result**: UI gracefully handles an empty tool state without crashing or hiding.

### 5.6 Signal Received Before UI Node Ready
**Scenario**: tool_activated signal fires before the Tool Selection UI node is added to the scene tree.
**Expected Behavior**:
- Signal is queued or deferred until the UI node is ready (via call_deferred or signal.connect() in _ready()).
- UI connects to signals in _ready(), ensuring all listeners are active before gameplay resumes.
- **Result**: No missed or orphaned signals.

### 5.7 Extreme Held Duration (TimeSlowTool)
**Scenario**: Player holds TimeSlowTool for 30 seconds (far exceeds max_display_duration = 5.0s).
**Expected Behavior**:
- bar_fill_percent is clamped at 100% (draining bar stays at full red).
- Tool remains active; no forced deactivation in MVP.
- Draining bar does not overflow, stretch, or cause layout issues.
- **Result**: UI remains stable and readable regardless of hold duration.

### 5.8 Simultaneous Tool Activations (Co-op)
**Scenario**: In co-op, both players activate their own tools at the same frame.
**Expected Behavior**:
- Each player's UI receives their own tool_activated signal independently.
- Player 1's slot highlights in their quadrant; Player 2's slot highlights in their quadrant.
- No visual or state collision between players' UIs.
- **Result**: Co-op UI updates are asynchronous and isolated per player.

---

## 6. Dependencies

### 6.1 Direct Dependencies
- **Tool System** (tool_activation.gd or equivalent):
  - Emits signals: tool_activated(tool_name, target), tool_deactivated(tool_name), tool_failed(tool_name, reason).
  - Executes input routing (tool_gravity, tool_time_slow, tool_force_push input actions).
  - Provides tool name strings and target feedback.

- **Input System** (Godot InputMap):
  - Requires three input actions to exist: tool_gravity, tool_time_slow, tool_force_push.
  - Input handling is NOT in the UI; input is routed to the tool system, which then signals the UI.

- **Godot UI Framework**:
  - HBoxContainer, PanelContainer, Label, ProgressBar (or custom bar), MarginContainer, Control.
  - Anchors and margins for viewport-relative positioning.
  - Signal system (connect, disconnect, emit_signal).

### 6.2 Indirect Dependencies
- **Room System** (room_manager.gd or scene loader):
  - Tool Selection UI must persist across room transitions.
  - Room transitions should NOT reset tool state or disconnect signals.

- **Co-op Synchronization** (future):
  - Multiplayer system must provide each player with a unique player ID and viewport quadrant.
  - UI instances are cloned and parented to each player's HUD quadrant.
  - Tool signals are routed per-player (e.g., emitted by player-specific tool instances).

### 6.3 Optional Dependencies
- **Cooldown System** (future):
  - If cooldown is added, tool_failed(tool_name, "On cooldown") signals will be displayed.
  - UI remains unchanged; cooldown logic is in the tool system.

- **Animation System** (future):
  - If highlight transitions are animated, use Tweens or AnimationPlayer.
  - No animations in MVP; all changes are instant.

---

## 7. Tuning Knobs

### 7.1 Visual Parameters
| Knob | Type | Default | Range | Impact | Notes |
|------|------|---------|-------|--------|-------|
| `slot_width` | int (px) | 64 | 48–96 | Physical size of each tool slot | Larger slots = more readable, more screen space consumed |
| `slot_height` | int (px) | 64 | 48–96 | Physical height of each slot | Match width for square appearance |
| `slot_spacing` | int (px) | 8 | 0–20 | Gap between slots | Larger spacing = visual separation, easier to target hover |
| `label_font_size` | int (px) | 14 | 10–18 | Tool name label readability | Larger = more readable, may overflow small slots |
| `label_color` | Color | white | Any | Foreground of tool name | Contrast against background |
| `inactive_alpha` | float | 0.4 | 0.2–0.6 | Opacity of inactive slots | Higher = easier to see unselected tools; lower = clearer active highlight |
| `active_alpha` | float | 1.0 | 0.8–1.0 | Opacity of active slot | Almost always 1.0; no reason to reduce |
| `draining_bar_height` | int (px) | 8 | 4–12 | Visual thickness of TimeSlowTool bar | Thicker = easier to see, more space consumed |
| `draining_bar_margin_bottom` | int (px) | 4 | 0–8 | Space between label and bar | Tuning for visual balance |

### 7.2 Timing Parameters
| Knob | Type | Default | Range | Impact | Notes |
|------|------|---------|-------|--------|-------|
| `max_display_duration` | float (s) | 5.0 | 1.0–15.0 | TimeSlowTool held duration ceiling for draining bar | Longer = more visual feedback time, implies longer tool activation window |
| `failure_message_display_duration` | float (s) | 2.0 | 0.5–5.0 | How long failure message remains on screen | Shorter = less clutter; longer = more time to read |
| `failure_message_fade_duration` | float (s) | 0.5 | 0.2–1.0 | Fade-out animation duration | Longer = smoother exit; shorter = snappier removal |

### 7.3 Behavioral Parameters
| Knob | Type | Default | Notes |
|------|------|---------|-------|
| `show_draining_bar_for_other_tools` | bool | false | If true, GravityFlip and ForcePush also show a quick bar. Likely false in MVP. |
| `highlight_transition_animated` | bool | false | If true, highlight color lerps over a short duration. Instant in MVP. |
| `preserve_ui_on_death` | bool | true | If true, UI persists in the death screen; if false, UI is hidden/freed. |

### 7.4 Layout Parameters (Viewport Anchoring)
| Knob | Type | Default | Notes |
|------|------|---------|-------|
| `anchor_position` | String | "bottom_center" | "bottom_left", "bottom_center", "bottom_right", "top_center", etc. |
| `margin_top` | int (px) | 0 | Space from anchor edge; can adjust if UI overlaps other elements |
| `margin_bottom` | int (px) | 16 | Space above the bottom edge of viewport (default: 16px clearance) |
| `margin_left` | int (px) | 0 | Left margin when anchor is center or right (default: centered) |
| `margin_right` | int (px) | 0 | Right margin when anchor is center or left (default: centered) |

All tuning knobs must be exported variables in the script (e.g., `@export var slot_width: int = 64`) so designers can adjust values in the inspector without code changes.

---

## 8. Acceptance Criteria

### 8.1 Visual & Layout Acceptance Criteria

**AC-1.1**: Tool Selection UI renders in a HBoxContainer with exactly 3 tool slots (GravityFlipTool, TimeSlowTool, ForcePushTool) in left-to-right order, anchored to the bottom-center of the viewport.
**Verification**: Screenshot comparison: UI is visible at screen-bottom, center-aligned. Slot order matches expected order.

**AC-1.2**: Each slot displays a readable label with the tool's friendly name (e.g., "Gravity Flip").
**Verification**: Screenshot of running game. Text is legible; font size matches `label_font_size` tuning knob.

**AC-1.3**: Inactive tool slots display with `inactive_alpha` opacity (default 0.4); active tool slot displays with `active_alpha` opacity (default 1.0).
**Verification**: Measure pixel opacity in screenshot; compare inactive vs. active slots side-by-side.

**AC-1.4**: Draining bar for TimeSlowTool appears only when the tool is active and updates every frame to reflect held duration.
**Verification**: Activate TimeSlowTool, hold key for 3 seconds. Record video. Bar should fill from 0% to ~60% (assuming max_display_duration = 5.0s). No bar visible for other tools.

**AC-1.5**: Failure message displays as red text, overlaid on the UI, and disappears after `failure_message_display_duration` seconds.
**Verification**: Trigger a tool_failed signal (e.g., ForcePush with no target). Screenshot captures message. Timer confirms removal after 2.0s (default).

### 8.2 State & Signal Acceptance Criteria

**AC-2.1**: When a tool_activated(tool_name, target) signal is received, the corresponding slot highlight is applied immediately.
**Verification**: Test script: emit tool_activated("Time Slow", null) and confirm TimeSlowTool slot is highlighted (opacity = 1.0).

**AC-2.2**: When a tool_deactivated(tool_name) signal is received, the corresponding slot reverts to inactive state and the draining bar is hidden.
**Verification**: Test script: activate TimeSlowTool, record bar visible and highlighted. Emit deactivated; confirm bar hidden and slot opacity = 0.4.

**AC-2.3**: Multiple rapid activations (< 0.1s apart) correctly swap the highlight without leaving ghost highlights on previous slots.
**Verification**: Test script: emit tool_activated("Gravity Flip"), then immediately emit tool_activated("Force Push"). Confirm only Force Push slot is highlighted; Gravity Flip slot is inactive.

**AC-2.4**: tool_failed signals do not interrupt active tool state; failure message displays independently of highlight.
**Verification**: Activate TimeSlowTool, emit tool_failed("Gravity Flip", "No target"), confirm TimeSlowTool slot remains highlighted and bar continues updating; failure message appears temporarily.

### 8.3 Draining Bar Acceptance Criteria

**AC-3.1**: Draining bar fill percentage is calculated as `(current_held_time / max_display_duration) × 100` and clamped to [0%, 100%].
**Verification**: Test script: activate TimeSlowTool, measure bar fill at 1.0s (expect 20%), 2.5s (expect 50%), 5.0s (expect 100%), 10.0s (expect 100%, clamped).

**AC-3.2**: Bar color transitions from green (0%) to red (100%) via linear interpolation.
**Verification**: Pixel color sampling in screenshot at 0%, 50%, 100% fill. Confirm green ≈ (0,255,100), 50% ≈ yellow, 100% ≈ red (255,50,50).

**AC-3.3**: Draining bar updates every frame (no skipped frames or lag).
**Verification**: Video capture at 60fps. Bar should animate smoothly without stuttering as hold duration increases.

### 8.4 Persistence & Transitions Acceptance Criteria

**AC-4.1**: Tool Selection UI persists in the scene tree across room transitions and does not flicker or disappear.
**Verification**: Play game, exit room (press a room-exit trigger), enter new room. Confirm UI is continuously visible; no black frames or reinitialization.

**AC-4.2**: Tool signals remain connected after room transition; UI updates reflect the new room's tool state.
**Verification**: Activate tool, transition to new room, activate same tool. Confirm highlight updates in both rooms without needing to reconnect signals.

### 8.5 Co-op Readiness Acceptance Criteria (Future, Informational)

**AC-5.1**: UI architecture supports per-player signal routing (each player's UI listens only to their own tool system).
**Verification**: Code review: confirm UI receives player_id parameter and subscribes to player-specific tool signals only.

**AC-5.2**: UI can be cloned and positioned in different viewport quadrants without signal interference.
**Verification**: Duplicate UI in scene tree, assign one to split-screen quadrant 1 and one to quadrant 2, connect different tool systems to each. Activate tools in both; confirm independent highlight updates.

### 8.6 Input Responsiveness Acceptance Criteria

**AC-6.1**: UI responds to tool signals with zero visible latency (highlight applied in the same frame as signal emission).
**Verification**: Test script: emit tool_activated and screenshot immediately (next frame). Highlight is present and matches expected state.

**AC-6.2**: No input buffering issues: if player rapidly presses multiple tool keys, each is routed and responded to correctly by the UI.
**Verification**: Test script or manual: press tool keys in quick succession (simulating mashing). Confirm no skipped activations or missing highlight updates.

### 8.7 Robustness Acceptance Criteria

**AC-7.1**: Signals received before UI node is ready (in _ready()) do not cause crashes or orphaned state.
**Verification**: Modify scene tree so tool system initializes before UI; emit signals before UI _ready() completes. Confirm no errors in console; UI updates correctly once ready.

**AC-7.2**: Receiving tool_failed while no tool is active displays the message without errors.
**Verification**: Game start state (no tool active), emit tool_failed("Gravity Flip", "Example error"). Confirm message appears and no null reference errors.

**AC-7.3**: Extremely long hold durations (30+ seconds) do not cause draining bar overflow, visual glitches, or memory leaks.
**Verification**: Activate TimeSlowTool, hold for 30 seconds. Record memory usage; confirm bar remains at 100%, UI layout is stable, no visual artifacts.

### 8.8 Tuning Knob Acceptance Criteria

**AC-8.1**: All tuning knobs are exported variables and adjustable in the Godot Inspector without code changes.
**Verification**: Open ToolSelectionUI.gd in Inspector; confirm all knobs (slot_width, label_font_size, etc.) appear as editable fields.

**AC-8.2**: Changing tuning knob values updates the UI in real-time (play mode) and persists correctly in saved scenes.
**Verification**: Play game, adjust `slot_width` in Inspector, confirm slots resize immediately. Stop and reopen scene; confirm value is retained.

---

## Sign-Off

**Document Author**: (To be filled in by implementer)
**Design Review**: (Pending)
**Technical Review**: (Pending)
**QA Sign-Off**: (Pending)
**Revision History**:
- v1.0 (2026-03-25): Initial draft created.
