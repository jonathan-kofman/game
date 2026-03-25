# HUD GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-10
**Created**: 2026-03-25

---

## 1. Overview

The HUD is a signal-driven overlay system rendered as a CanvasLayer in the main scene, providing real-time feedback on player health, escalation level, and mission objectives. The MVP delivers four core elements: a health bar with color coding and smooth animation, an escalation level indicator with dynamic color shifts and critical-state pulsing, an objective tracker showing progress toward mission goals, and a countdown timer for extraction (future sprint). All HUD data flows through signals only—the HUD never polls game state directly, ensuring clean separation between gameplay systems and presentation layer.

## 2. Player Fantasy

Players want instant, intuitive feedback on "how much danger am I in right now?" The HUD should feel like a responsive instrument panel that breathes with the game's tension. Health should feel fragile at low values through visual urgency (red, smooth animation). Escalation should feel like a building storm—calm green at the start, escalating to pulsing red as the mission gets harder. Squad status (future) should let co-op players glance and know their teammate is alive. The HUD should never obscure critical gameplay or demand conscious reading—it communicates through color, position, and animation as much as numbers.

## 3. Detailed Rules

### 3.1 Health Bar
- **Display**: Horizontal bar anchored to bottom-left of screen, showing current HP / max HP in text overlay.
- **Fill logic**: `fill_percent = current_health / max_health`, clamped to [0, 1].
- **Color mapping**:
  - Green: ≥ 75% health
  - Yellow: 25–75% health
  - Red: < 25% health
- **Animation**: When health changes, lerp the bar fill and color over 0.2 seconds (smooth tween, not instant snap).
- **Signal source**: `HealthComponent.health_changed(new_health, max_health)`.
- **Text format**: `"45 / 100"` (no unit label in MVP).

### 3.2 Escalation Level Indicator
- **Display**: Vertical or horizontal bar + text label below/beside it showing escalation level name (e.g., "CALM", "ALERT", "HOSTILE", "CRITICAL").
- **Bar fill logic**: `fill_percent = (current_level + 1) / (total_levels + 1)` to ensure visual feedback at each level transition.
- **Color mapping by level**:
  - CALM (level 0): Green (#00FF00)
  - ALERT (level 1): Yellow (#FFFF00)
  - HOSTILE (level 2): Orange (#FFA500)
  - CRITICAL (level 3+): Red (#FF0000)
- **Critical pulsing**: At CRITICAL, pulse the bar opacity (alpha 1.0 → 0.6 → 1.0) over 0.5 seconds, loop continuously.
- **Signal source**: `EscalationManager.escalation_level_changed(new_level, level_name)`.
- **Text format**: Level name in uppercase, e.g., `"HOSTILE"`.

### 3.3 Objective Tracker
- **Display**: Primary objective name + progress string, anchored top-center or top-left of screen.
- **Text format**: `"Objective: Activate Terminals [1/3]"` or similar (format depends on objective type).
- **Update logic**: Show only the primary (active) objective; if no objective is active, hide the tracker.
- **Progress string**: Dynamically generated from objective state (e.g., `"[terminals_activated / terminals_total]"`).
- **Signal source**: `ObjectiveManager.objective_state_changed(objective_id, objective_name, progress_data)`.
- **No progress animation**: Text updates instantly when progress changes.

### 3.4 Extraction Countdown Timer
- **Display**: Large, centered countdown (e.g., `"2:34"` for 2 minutes 34 seconds remaining).
- **Visibility**: Only shown when extraction is active AND countdown > 0. Hidden at all other times.
- **Color logic** (future spec, implemented in S4-11):
  - White: > 1 minute remaining
  - Yellow: 30 seconds – 1 minute
  - Red: < 30 seconds
- **Signal source**: Will be driven by `ExtractionZone.extraction_countdown(seconds_remaining)` or similar (not yet implemented in S4-10).
- **Format**: `"M:SS"` (e.g., `"2:34"`, `"0:05"`).

### 3.5 Layout & Positioning
- **Health bar**: Bottom-left corner, 200px wide × 20px tall, 16px margin from edges.
- **Escalation indicator**: Top-left corner, 200px wide × 20px tall, 16px margin from edges.
- **Objective tracker**: Top-center, 400px wide, 48px tall, centered horizontally.
- **Extraction timer**: Center of screen (viewport center), font size 72, bold, monospace.
- **CanvasLayer sort order**: 100 (above all gameplay and world-space elements).

### 3.6 Signal Contracts
All HUD updates come through signals only. The HUD subscribes to:
1. `HealthComponent.health_changed(new_health: int, max_health: int)`
2. `EscalationManager.escalation_level_changed(new_level: int, level_name: String)`
3. `ObjectiveManager.objective_state_changed(objective_id: String, objective_name: String, progress_data: Dictionary)`
4. `ExtractionZone.extraction_countdown(seconds_remaining: float)` (future)

The HUD **never** calls methods on HealthComponent, EscalationManager, or ObjectiveManager—it only listens.

## 4. Formulas

### 4.1 Health Bar Fill Percentage
```
fill_percent = current_health / max_health
clamped_fill = clamp(fill_percent, 0.0, 1.0)
```
**Variables**:
- `current_health`: Player's current HP (integer, from HealthComponent)
- `max_health`: Player's maximum HP (integer, typically 100)

**Example**: Player has 45 HP / 100 max:
```
fill_percent = 45 / 100 = 0.45
clamped_fill = 0.45 (no clamping needed)
Bar rendered at 45% width.
Color = yellow (25% ≤ 45% < 75%).
```

### 4.2 Health Bar Color Interpolation
```
if current_health >= 0.75 * max_health:
    target_color = GREEN (#00FF00)
elif current_health >= 0.25 * max_health:
    target_color = YELLOW (#FFFF00)
else:
    target_color = RED (#FF0000)

current_color = lerp(current_color, target_color, delta_time / 0.2)
```
**Variables**:
- `current_health`: Player's current HP
- `max_health`: Player's maximum HP
- `delta_time`: Frame delta time (seconds)
- `lerp()`: Linear interpolation function

**Example**: Player takes damage from 80 HP to 45 HP at frame time 0:
- Frame 0: target_color = YELLOW, current_color = GREEN, lerp progresses
- Frame 1 (0.016s later): current_color ≈ blend(GREEN, YELLOW, 0.016 / 0.2) = ~12.5% toward YELLOW
- Frame 13 (0.2s later): current_color = YELLOW (lerp complete)

### 4.3 Escalation Bar Fill Percentage
```
fill_percent = (current_level + 1) / (total_levels + 1)
clamped_fill = clamp(fill_percent, 0.0, 1.0)
```
**Variables**:
- `current_level`: Current escalation level (0-indexed integer: 0=CALM, 1=ALERT, 2=HOSTILE, 3+=CRITICAL)
- `total_levels`: Total number of escalation levels (typically 4: 0, 1, 2, 3)

**Example 1**: At CALM (level 0), total_levels = 4:
```
fill_percent = (0 + 1) / (4 + 1) = 1 / 5 = 0.2
Bar rendered at 20% width.
```

**Example 2**: At CRITICAL (level 3), total_levels = 4:
```
fill_percent = (3 + 1) / (4 + 1) = 4 / 5 = 0.8
Bar rendered at 80% width.
```

### 4.4 Escalation Level Color Selection
```
level_colors = {
    0: GREEN (#00FF00),
    1: YELLOW (#FFFF00),
    2: ORANGE (#FFA500),
    3+: RED (#FF0000)
}
bar_color = level_colors[min(current_level, 3)]
```
**Variables**:
- `current_level`: Current escalation level
- `level_colors`: Lookup table mapping level to color

**Example**: At HOSTILE (level 2):
```
bar_color = level_colors[2] = ORANGE (#FFA500)
```

### 4.5 Critical Pulsing Animation
```
pulse_time = fmod(current_time, 0.5)  // 0.5s cycle
pulse_phase = pulse_time / 0.5         // 0.0 to 1.0
pulse_alpha = 0.6 + (0.4 * sin(pulse_phase * PI))  // Oscillates 0.6–1.0

if current_level >= 3:  // CRITICAL
    bar_opacity = pulse_alpha
else:
    bar_opacity = 1.0
```
**Variables**:
- `current_time`: Game time in seconds (monotonically increasing)
- `pulse_time`: Time within current pulse cycle (0–0.5s)
- `pulse_phase`: Normalized pulse phase (0.0–1.0)
- `pulse_alpha`: Calculated opacity (0.6–1.0)

**Example**: At t=0.125s (25% through a pulse cycle):
```
pulse_phase = 0.125 / 0.5 = 0.25
pulse_alpha = 0.6 + (0.4 * sin(0.25 * PI)) ≈ 0.6 + (0.4 * 0.707) ≈ 0.883
Bar opacity set to 0.883.
```

### 4.6 Extraction Countdown Display
```
seconds_remaining = extraction_countdown_value
minutes = int(seconds_remaining / 60)
seconds = int(seconds_remaining) % 60
display_string = f"{minutes}:{seconds:02d}"  // Zero-padded seconds
```
**Variables**:
- `extraction_countdown_value`: Seconds remaining (float)

**Example 1**: 154 seconds remaining:
```
minutes = 154 / 60 = 2 (integer division)
seconds = 154 % 60 = 34
display_string = "2:34"
```

**Example 2**: 5 seconds remaining:
```
minutes = 5 / 60 = 0
seconds = 5 % 60 = 5
display_string = "0:05"
```

## 5. Edge Cases

### 5.1 Health Bar at Zero
**Scenario**: Player health reaches 0 HP (character dies).
**Expected behavior**: Health bar fill = 0%, color = red, bar remains visible (does not disappear). HUD does not hide—player may see death sequence or respawn prompt overlaid on HUD.

### 5.2 Health Exceeding Max
**Scenario**: Player picks up a health pack and current_health + heal_amount > max_health.
**Expected behavior**: Health is clamped to max_health by HealthComponent before signal fires. HUD fill_percent = clamp(current_health / max_health, 0, 1) = 1.0. Bar animates to 100% over 0.2s.

### 5.3 Escalation Level Increases Mid-Animation
**Scenario**: Health bar is animating from red (25% HP) to yellow (receives heal), but during animation, escalation jumps from ALERT to CRITICAL, causing escalation bar to start pulsing.
**Expected behavior**: Both animations run independently and simultaneously. Health bar continues its color lerp. Escalation bar color snaps instantly to red and begins pulsing. No interference between the two animations.

### 5.4 No Active Objective
**Scenario**: Player completes all objectives or mission has no primary objective defined.
**Expected behavior**: Objective tracker text is hidden (not visible in scene tree, or opacity = 0). If a new objective fires later, tracker reappears with new text.

### 5.5 Objective Progress Exceeds Total
**Scenario**: ObjectiveManager sends `objective_state_changed(id="terminals", name="Activate Terminals", progress_data={"current": 5, "total": 3})` due to a bug.
**Expected behavior**: HUD displays the data as-is: `"Activate Terminals [5/3]"`. No clamping or validation in the HUD itself—data correctness is ObjectiveManager's responsibility. (This is testable via a regression test in ObjectiveManager.)

### 5.6 Negative Health Signal
**Scenario**: HealthComponent fires `health_changed(-10, 100)` due to a bug.
**Expected behavior**: HUD clamps: `fill_percent = clamp(-10 / 100, 0, 1) = 0.0`. Bar renders at 0% and color = red. No error thrown.

### 5.7 Extraction Timer Never Fires (Extraction Not Implemented)
**Scenario**: In S4-10 (MVP), ExtractionZone.extraction_countdown signal is not yet connected.
**Expected behavior**: Extraction timer remains hidden at all times. Game loop continues normally. Code for timer color logic exists but is unreachable (future-proofed for S4-11).

### 5.8 Rapid Health Changes
**Scenario**: Player takes 10 damage per frame for 5 frames (total 50 damage in 0.083s).
**Expected behavior**: Each damage event signals health_changed. Health bar lerp queues up 5 animations, each targeting a new color/fill. Final visible result is smooth animation from start to end state over 0.2s after the last signal (not cumulative 5 × 0.2s). Implementation: tween-based animation cancels and restarts on each signal.

### 5.9 HUD Shown in Paused Game
**Scenario**: Player pauses game. Delta time = 0, but HUD is still rendered on screen.
**Expected behavior**: Health/escalation bars freeze at their current state. Critical pulsing animation freezes mid-pulse (does not advance). Text remains static. When game resumes, animations resume smoothly without jumps.

### 5.10 Co-op Squad Panel Before Implementation (Future)
**Scenario**: In S4-10, squad health panel code is stubbed but not active.
**Expected behavior**: Squad panel is hidden or not rendered. Single-player health bar displays normally. When S4-11 implements squad panel, it adds a second UI element without modifying the existing player health bar.

## 6. Dependencies

### 6.1 Core Systems
- **HealthComponent**: Provides `health_changed(new_health, max_health)` signal. Must exist on the player entity and fire signal on every health change (heal or damage).
- **EscalationManager**: Provides `escalation_level_changed(new_level, level_name)` signal. Must track current escalation level (0–3 in MVP) and fire signal when level changes.
- **ObjectiveManager**: Provides `objective_state_changed(objective_id, objective_name, progress_data)` signal. Must track primary objective and fire when objective state or progress changes.
- **ExtractionZone** (future): Will provide `extraction_countdown(seconds_remaining)` signal. Not yet required for S4-10 MVP.

### 6.2 Engine Dependencies
- **CanvasLayer**: HUD is a CanvasLayer node (built-in Godot 4.6.1 node). No addon required.
- **Control nodes**: Uses Label, TextureProgressBar (or custom ProgressBar), AnimatedLabel nodes (built-in).
- **Tween system**: Uses Godot's built-in Tween API for color/fill animations (Godot 4.6.1 built-in).

### 6.3 Data Structures
- **Escalation levels enum or constant**: Must be defined in EscalationManager or shared config. HUD expects level names as strings ("CALM", "ALERT", "HOSTILE", "CRITICAL").
- **Color constants**: Recommend centralizing color definitions in a shared config (e.g., `HUDTheme.gd`) with RGB hex values for consistency.

### 6.4 Script Dependencies
- **Main scene**: HUD must be a child node of the main scene (or accessible via `get_tree().root` singleton reference) to receive signals from gameplay systems.
- **Signal wiring**: The main scene, gameplay orchestrator, or a dedicated "signal hub" must connect all three signals to the HUD instance at game start. HUD does not self-wire; signals are set up externally.

### 6.5 No Dependencies
- HUD does not depend on camera, physics, or procedural generation systems.
- HUD does not depend on any third-party addons or external libraries.
- HUD does not modify any game state; it is read-only.

## 7. Tuning Knobs

### 7.1 Animation Timings
| Parameter | Default (MVP) | Range | Notes |
|-----------|---------------|-------|-------|
| Health bar animation duration | 0.2s | 0.1–0.5s | Increase for slower, more dramatic changes; decrease for snappier feedback. |
| Escalation bar pulsing frequency | 0.5s per cycle | 0.3–1.0s | Decrease (faster) for more urgency at CRITICAL; increase for less disruptive pulsing. |
| Escalation bar color transition | Instant | 0.0–0.2s | If desired, add ease-in color changes when escalating (future enhancement). |

### 7.2 Visual Metrics
| Parameter | Default (MVP) | Range | Notes |
|-----------|---------------|-------|-------|
| Health bar width | 200px | 150–300px | Adjust for screen resolution and readability. |
| Health bar height | 20px | 16–32px | Taller = easier to see at a glance; too tall = consumes screen space. |
| Escalation bar width | 200px | 150–300px | Match health bar for cohesion, or size separately. |
| Escalation bar height | 20px | 16–32px | Same bar height as health bar recommended. |
| Objective tracker width | 400px | 300–600px | Increase if objective names are long. |
| Objective tracker font size | 20px | 16–28px | Must remain readable at all game resolutions. |
| Extraction timer font size | 72px | 48–96px | Larger for mobile/far distances; smaller if screen space is constrained. |

### 7.3 Color Tuning
| Parameter | Default (MVP) | Notes |
|-----------|---------------|-------|
| Health bar green threshold | ≥ 75% HP | Increase if "full health" should feel rarer. |
| Health bar yellow threshold | 25–75% HP | Middle ground; changes color as player takes damage. |
| Health bar red threshold | < 25% HP | Urgency indicator; consider lowering to < 20% if red should appear less frequently. |
| Escalation CALM color | #00FF00 (pure green) | Can adjust hue/saturation for brand consistency. |
| Escalation ALERT color | #FFFF00 (pure yellow) | Consider #FFD700 (gold) for softer appearance. |
| Escalation HOSTILE color | #FFA500 (orange) | Can shift toward #FF8C00 (darker orange) for intensity. |
| Escalation CRITICAL color | #FF0000 (pure red) | Consider #DC143C (crimson) for slight variation. |
| Critical pulsing opacity range | 0.6–1.0 | Decrease floor (e.g., 0.3–1.0) for more dramatic pulsing. |

### 7.4 Layout & Positioning (Screen Anchors)
| Parameter | Default (MVP) | Options |
|-----------|---------------|---------|
| Health bar anchor | Bottom-left | Bottom-right, top-left, center (depends on HUD style). |
| Escalation bar anchor | Top-left | Top-right, bottom-left, center. |
| Objective tracker anchor | Top-center | Top-left, top-right, center. |
| Extraction timer anchor | Viewport center | Off-center (e.g., top-right) if center conflicts with other HUD elements. |
| Margin from screen edges | 16px | 8–32px depending on safe area and readability. |

### 7.5 Future Tuning (Not MVP)
- **Co-op squad panel layout**: Will add tuning for squad member panel width, height, inter-player spacing, and positioning (top-left, top-right, etc.).
- **Extraction timer color thresholds**: Finalize cutoff points for white → yellow → red transitions when implemented.
- **Font families & weights**: Centralize font selections in a theme resource for consistent branding.

## 8. Acceptance Criteria

### 8.1 Health Bar
- [ ] **AC-HUD-001**: Health bar displays at bottom-left corner of screen, 200px wide × 20px tall.
- [ ] **AC-HUD-002**: Health bar fill represents `current_health / max_health` as a percentage, updated in real time.
- [ ] **AC-HUD-003**: Health bar color is green when ≥ 75% HP, yellow when 25–75% HP, red when < 25% HP.
- [ ] **AC-HUD-004**: Color transitions smoothly over 0.2 seconds using lerp (no instant snaps).
- [ ] **AC-HUD-005**: Health bar displays text overlay showing `"current / max"` (e.g., `"45 / 100"`).
- [ ] **AC-HUD-006**: Health bar animates smoothly when player takes damage (no jumps or glitches).
- [ ] **AC-HUD-007**: Health bar remains visible and renders correctly when health is at 0 HP.
- [ ] **AC-HUD-008**: Health bar correctly handles overheal (clamped to max HP by HealthComponent, bar stays at 100%).

### 8.2 Escalation Level Indicator
- [ ] **AC-HUD-009**: Escalation bar displays at top-left corner of screen, 200px wide × 20px tall.
- [ ] **AC-HUD-010**: Escalation bar fill represents `(current_level + 1) / (total_levels + 1)` as a percentage.
- [ ] **AC-HUD-011**: Level name text displays below/beside bar in uppercase (e.g., `"CALM"`, `"ALERT"`, `"HOSTILE"`, `"CRITICAL"`).
- [ ] **AC-HUD-012**: Bar color matches level: CALM=green, ALERT=yellow, HOSTILE=orange, CRITICAL=red.
- [ ] **AC-HUD-013**: Color change is instant when escalation level increases (no lerp for escalation bar itself).
- [ ] **AC-HUD-014**: At CRITICAL level, bar pulses (opacity oscillates 0.6–1.0) over 0.5s cycle continuously.
- [ ] **AC-HUD-015**: Pulsing stops and opacity returns to 1.0 when escalation drops below CRITICAL.
- [ ] **AC-HUD-016**: Bar correctly shows all four escalation levels (CALM, ALERT, HOSTILE, CRITICAL) with appropriate fills.

### 8.3 Objective Tracker
- [ ] **AC-HUD-017**: Objective tracker displays at top-center of screen, showing objective name + progress.
- [ ] **AC-HUD-018**: Text format is `"Objective: [name] [current/total]"` or similar (exact format TBD with gameplay team).
- [ ] **AC-HUD-019**: Tracker displays primary objective only; hides when no primary objective is active.
- [ ] **AC-HUD-020**: Tracker updates in real time when objective progress changes.
- [ ] **AC-HUD-021**: Tracker correctly displays progress strings for multi-stage objectives (e.g., `"[1/3]"`, `"[2/3]"`, `"[3/3]"`).
- [ ] **AC-HUD-022**: Text remains readable at all game resolutions (tested at 1080p, 1440p, 4K).

### 8.4 Extraction Countdown Timer
- [ ] **AC-HUD-023**: Extraction timer is hidden by default in S4-10 MVP (not rendered unless extraction is active).
- [ ] **AC-HUD-024**: When extraction is active, timer displays at viewport center in large font (72px, monospace, bold).
- [ ] **AC-HUD-025**: Timer format is `"M:SS"` with zero-padded seconds (e.g., `"2:34"`, `"0:05"`).
- [ ] **AC-HUD-026**: Timer updates every frame to show remaining seconds (no lag or skips).
- [ ] **AC-HUD-027**: Code structure supports future color transitions (white → yellow → red) without refactoring (future acceptance test in S4-11).

### 8.5 Signal Integration
- [ ] **AC-HUD-028**: HUD subscribes to `HealthComponent.health_changed(new_health, max_health)` signal and responds within 1 frame.
- [ ] **AC-HUD-029**: HUD subscribes to `EscalationManager.escalation_level_changed(new_level, level_name)` signal and responds within 1 frame.
- [ ] **AC-HUD-030**: HUD subscribes to `ObjectiveManager.objective_state_changed(objective_id, objective_name, progress_data)` signal and responds within 1 frame.
- [ ] **AC-HUD-031**: HUD never calls methods on gameplay systems (read-only via signals).
- [ ] **AC-HUD-032**: HUD gracefully handles missing or null signal data (no crashes if a signal field is uninitialized).

### 8.6 Layout & Rendering
- [ ] **AC-HUD-033**: All HUD elements are children of a CanvasLayer with sort_order = 100 (rendered on top).
- [ ] **AC-HUD-034**: HUD does not obscure critical gameplay or player view (verified via screenshot comparison).
- [ ] **AC-HUD-035**: HUD elements scale appropriately for 16:9 aspect ratio (primary target); degrade gracefully for 4:3 or ultrawide.
- [ ] **AC-HUD-036**: HUD text is readable at all supported resolutions (minimum font size tested at 1080p and 720p).
- [ ] **AC-HUD-037**: All HUD animations run at 60 FPS on target hardware (no frame drops due to HUD rendering).

### 8.7 Animation & Polish
- [ ] **AC-HUD-038**: Health bar color transitions are smooth and visible (not too fast, not too slow).
- [ ] **AC-HUD-039**: Escalation bar critical pulsing is noticeable without being distracting (tested by QA).
- [ ] **AC-HUD-040**: No visual glitches or tearing when animations overlap (health bar and escalation bar both animating simultaneously).
- [ ] **AC-HUD-041**: HUD remains frozen (no animation advancement) when game is paused (verified via pause/unpause test).

### 8.8 Edge Cases & Error Handling
- [ ] **AC-HUD-042**: Health bar correctly handles health = 0 (bar at 0%, color = red, visible).
- [ ] **AC-HUD-043**: Health bar clamps negative health to 0% (no negative bar widths or errors).
- [ ] **AC-HUD-044**: Objective tracker hides cleanly when objective is null or completed.
- [ ] **AC-HUD-045**: Escalation bar displays correctly at all levels 0–3 (and beyond if future levels are added).
- [ ] **AC-HUD-046**: Rapid health changes (10 damage × 5 frames) result in smooth final animation, not stuttering.
- [ ] **AC-HUD-047**: HUD responds correctly to out-of-order signals (e.g., objective change before escalation change in same frame).

### 8.9 Testing & Verification
- [ ] **AC-HUD-048**: Manual playtest: All HUD elements visible and responsive during a 5-minute gameplay session.
- [ ] **AC-HUD-049**: Screenshot comparison: Expected HUD layout vs. actual rendered output (stored in `tests/ui_baselines/hud/`).
- [ ] **AC-HUD-050**: Unit test: Health bar fill percentage calculated correctly for 10 test cases (0%, 25%, 50%, 75%, 100%, negative, overheal, etc.).
- [ ] **AC-HUD-051**: Unit test: Escalation bar fill and color correct for each level (0, 1, 2, 3).
- [ ] **AC-HUD-052**: Unit test: Objective tracker text formatting correct for various progress strings.
- [ ] **AC-HUD-053**: Integration test: All three signal subscriptions fire correctly when gameplay systems emit signals.
- [ ] **AC-HUD-054**: Performance test: HUD rendering does not cause frame drops (target 60 FPS maintained with HUD active).

---

**Document History**:
- **v1.0** (2026-03-25): Initial GDD draft for S4-10 MVP. Created by Agent.

**Next Steps**:
- Review with gameplay team and producer for approval.
- Create signal contracts in EscalationManager, HealthComponent, ObjectiveManager.
- Implement HUD.gd and associated UI scene (HUD.tscn).
- Write unit tests per AC-HUD-050 through AC-HUD-052.
- Schedule playtest and screenshot baseline capture.
