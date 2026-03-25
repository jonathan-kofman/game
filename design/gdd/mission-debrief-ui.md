# Mission Debrief UI GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-11
**Created**: 2026-03-25

---

## 1. Overview

The Mission Debrief UI is a post-run summary screen displayed after the ExtractionZone signals the end of a mission (success, partial success, or failure). It presents mission outcomes, objective completion status, XP rewards, and loot collected in a single unified interface that informs players of their progress and provides closure to a run before returning to the main menu. This screen is a critical player feedback moment that communicates mission effectiveness and reinforces the gameplay loop.

---

## 2. Player Fantasy

Players want to **see at a glance whether they succeeded, understand what they accomplished, and feel rewarded for their effort**. The Debrief satisfies this by:

- **Instant visual feedback** on mission outcome (large, color-coded banner that is immediately readable)
- **Objective validation** (checkmark list confirms which goals were met, validating strategic decisions)
- **Tangible reward** (animated XP count-up creates a sense of earning and progression)
- **Completeness** (loot manifest grounds the run's impact in concrete items obtained)
- **Clear forward path** (single "Continue" button makes the next action obvious)

For co-op players (future), the fantasy includes **seeing individual contributions**—knowing how much XP they personally earned and comparing it to squadmates builds healthy group dynamics and shared ownership of outcomes.

---

## 3. Detailed Rules

### 3.1 Display Trigger
The Mission Debrief UI appears **immediately after** the ExtractionZone emits one of three signals:
- `run_succeeded`: Mission completed with all primary objectives met
- `run_partial_success`: Mission completed with some objectives met
- `run_failed`: Mission ended without meeting primary objectives

The screen is **non-dismissible** until the "Continue" button is pressed. The game enters a paused state (see Rule 3.5).

### 3.2 Layout Structure
The UI is composed of the following elements from top to bottom:

1. **Outcome Banner** (40% of vertical space)
   - Large text (80pt) displaying outcome: "SUCCESS", "PARTIAL SUCCESS", or "FAILED"
   - Color-coded background: green (#00C800), yellow (#FFD700), red (#FF4444)
   - Optional flavor text below outcome text (e.g., "Well done, agent!" for SUCCESS)

2. **Objective List** (20% of vertical space)
   - Title: "OBJECTIVES"
   - Bulleted list of mission objectives (max 4 objectives per mission MVP)
   - Each objective displays as: [✓ or ✗] Objective Name
   - ✓ (checkmark) if objective.is_complete == true
   - ✗ (cross) if objective.is_complete == false
   - Checkmark color: green (#00C800); cross color: red (#FF4444)

3. **XP Earned Section** (15% of vertical space)
   - Title: "XP EARNED"
   - Large animated number displaying final XP value
   - Animated count-up begins when screen appears (Rule 3.3)
   - Format: "[current_xp]" (right-aligned, 60pt font)

4. **Loot Manifest** (15% of vertical space)
   - Title: "LOOT"
   - List of items collected (format: "Item Name x count")
   - Placeholder text "No items collected" if loot_count == 0
   - **MVP Note**: Loot is displayed as text; no visual item cards in v1.0

5. **Action Button** (10% of vertical space)
   - Single "CONTINUE" button (centered, 48pt font)
   - Button is enabled only after XP animation completes (see Rule 3.3)
   - On press: emit debrief_dismissed signal, return to main menu

### 3.3 XP Count-Up Animation
When the Debrief UI appears, the XP value animates from 0 to the final value over a duration defined by XP_COUNT_DURATION.

- **Animation type**: Linear easing (no ease-in/ease-out in MVP)
- **Update frequency**: Every frame (using _process delta)
- **Visual effect**: Number updates 30–60 times per second depending on framerate
- **Completion behavior**: Once animation ends, CONTINUE button becomes enabled
- **Interruption**: If player closes game/minimizes, animation resumes from current value when window regains focus

### 3.4 Data Source
The Debrief receives a `MissionDebriefData` resource containing:
- `mission_name`: String (for debugging; not displayed in MVP)
- `outcome`: Enum {SUCCESS, PARTIAL_SUCCESS, FAILED}
- `objectives`: Array of ObjectiveResult objects
  - Each ObjectiveResult has: name (String), is_complete (bool)
- `xp_earned`: int (total XP from mission)
- `loot_items`: Array of LootItem objects
  - Each LootItem has: item_name (String), quantity (int)

### 3.5 Game Pause
When the Debrief appears, the game pauses:
```
get_tree().paused = true
```

When "Continue" is pressed and the Debrief transitions away:
```
get_tree().paused = false
```

This ensures players cannot perform actions during the summary screen.

### 3.6 Background Treatment
The Debrief UI is rendered **on top of the paused game world** with a semi-transparent overlay:
- Overlay color: black, alpha 0.5
- Blurs or darkens the mission scene behind the UI
- Prevents distraction while player reads results

### 3.7 Player Count Awareness
In single-player (MVP), the layout is centered and uses full width for text and buttons.

In co-op (future), the layout adapts:
- Objective and XP sections split into per-player columns
- Each column shows player name, individual XP, and player-specific achievements
- Loot manifest remains shared (all players see full manifest, not per-player)

---

## 4. Formulas

### 4.1 XP Count-Up Animation
**Formula**: Linear interpolation of displayed XP value over time

```
current_displayed_xp = floor(final_xp * (elapsed_time / XP_COUNT_DURATION))
```

**Variables**:
- `final_xp`: Total XP earned in the mission (int, from MissionDebriefData.xp_earned)
- `elapsed_time`: Seconds since animation started (float, tracked via delta in _process)
- `XP_COUNT_DURATION`: Animation duration in seconds (float, constant = 2.0)
- `current_displayed_xp`: Value shown on screen (int)

**Example Calculation**:
- `final_xp` = 500 XP
- `XP_COUNT_DURATION` = 2.0 seconds
- At `elapsed_time` = 1.0 second (halfway):
  - `current_displayed_xp` = floor(500 * (1.0 / 2.0)) = floor(250) = 250
- At `elapsed_time` = 2.0 seconds (complete):
  - `current_displayed_xp` = floor(500 * (2.0 / 2.0)) = floor(500) = 500

### 4.2 Outcome Determination
**Formula**: Outcome is determined by comparing completed objectives to total objectives

```
if completed_objectives == total_objectives:
    outcome = SUCCESS
elif completed_objectives > 0:
    outcome = PARTIAL_SUCCESS
else:
    outcome = FAILED
```

**Variables**:
- `completed_objectives`: Count of objectives with is_complete == true
- `total_objectives`: Total count of objectives in mission

**Example Calculation**:
- Mission with 3 objectives: [✓ Disable Device, ✓ Secure Data, ✗ Escape with Artifact]
  - `completed_objectives` = 2
  - `total_objectives` = 3
  - Outcome = PARTIAL_SUCCESS

### 4.3 XP Reward Accumulation (Future)
**Formula**: Total XP earned from bonuses and base mission rewards

```
total_xp = base_mission_xp + objective_bonus_xp + time_bonus_xp + difficulty_multiplier_xp
```

**Variables**:
- `base_mission_xp`: Fixed XP award for completing the mission (int)
- `objective_bonus_xp`: XP bonus per completed objective (int * completed_objectives)
- `time_bonus_xp`: Bonus XP for completing mission under a time threshold (int)
- `difficulty_multiplier_xp`: Multiplier applied based on mission difficulty (float, 1.0–2.0)

**Example Calculation**:
- `base_mission_xp` = 250
- `objective_bonus_xp` = 50 per objective; 2 objectives completed = 100
- `time_bonus_xp` = 100 (finished under time limit)
- `difficulty_multiplier_xp` = 1.5 (Hard difficulty)
- `total_xp` = (250 + 100 + 100) * 1.5 = 450 * 1.5 = 675 XP

---

## 5. Edge Cases

### 5.1 Zero Objectives
**Scenario**: Mission has no objectives defined (malformed MissionDebriefData).
**Handling**: Display "OBJECTIVES" section with message "No objectives defined". Do not crash. Treat outcome as FAILED if no objectives exist, since a mission without goals is inherently incomplete.

### 5.2 Zero XP Earned
**Scenario**: Mission grants 0 XP (e.g., tutorial mission, failed run with no partial credit).
**Handling**: XP Earned section displays "0". Count-up animation still plays, reaching 0 instantly. CONTINUE button is enabled after animation completes (0 seconds).

### 5.3 Empty Loot Manifest
**Scenario**: Player completed mission but collected no items.
**Handling**: Loot section displays "LOOT" title with "No items collected" message. Section is not hidden; it remains visible with placeholder text.

### 5.4 Loot Count Exceeds Display Space
**Scenario**: Mission generates >10 items, exceeding single-screen layout.
**Handling**: Loot manifest becomes scrollable within its 15% vertical allocation. Implement vertical scroll within the Loot section container (not full-screen scroll).

### 5.5 Very Long Objective Names
**Scenario**: An objective name is longer than available horizontal space (e.g., "Disable the primary reactor core without triggering the alarm system").
**Handling**: Objective name text wraps to next line or truncates with ellipsis (…). Maximum 2 lines per objective name; longer names truncate mid-word with "…" at line end.

### 5.6 Mission with Many Objectives (>4)
**Scenario**: Mission has 5+ objectives but MVP layout only allocates space for 4.
**Handling**: Objective list becomes scrollable within its 20% vertical allocation. All objectives are displayed and completable; UI adapts to show all.

### 5.7 Network Disconnect During Debrief (Co-op Future)
**Scenario**: In co-op, network disconnects while debrief is visible.
**Handling**: Debrief completes for local player. Other players' columns show "DISCONNECTED" status. CONTINUE button remains functional. When pressed, player returns to main menu solo.

### 5.8 Negative XP Value
**Scenario**: Data error passes negative XP (xp_earned = -50).
**Handling**: Clamp to 0 before display. Log error to debug output. Display "0" on screen.

### 5.9 Animation Frame Skip (Low FPS)
**Scenario**: Framerate drops below 10 FPS during count-up animation.
**Handling**: elapsed_time continues accumulating. Count-up reaches final value regardless of framerate. Animation is not paused or reset.

### 5.10 Player Presses Continue Before Animation Completes
**Scenario**: Player clicks CONTINUE button during XP count-up (if button were enabled early).
**Handling**: Button is disabled until animation completes. If somehow clicked early (code bug), handle gracefully: snap displayed XP to final value, emit debrief_dismissed signal, transition to main menu.

---

## 6. Dependencies

### 6.1 Required Systems
- **ExtractionZone (Mission End System)**: Emits `run_succeeded`, `run_partial_success`, or `run_failed` signal. Debrief UI listens for this signal to trigger display.
- **Mission Debrief System**: Constructs the MissionDebriefData resource and passes it to Debrief UI. Debrief UI does not calculate outcomes; it only displays pre-computed data.
- **Game Pause System**: Debrief UI calls `get_tree().paused = true/false` to manage pause state. This system must be active and functional.
- **Main Menu UI**: Debrief UI emits `debrief_dismissed` signal, which main menu (or mission controller) listens for to navigate back to main menu.

### 6.2 Godot Engine Features
- **CanvasLayer**: Debrief UI is rendered on a CanvasLayer to ensure it appears above game world.
- **Tween System**: Optional but recommended for smooth animations (Tween.tween_property for button fade-in, color transitions).
- **InputMap**: Requires "ui_accept" action (bound to Enter/A button) for CONTINUE button. Alternative: bind custom input action.

### 6.3 Scenes/Resources
- **MissionDebriefData.tres**: Resource definition (must exist in project before Debrief UI is functional).
- **ObjectiveResult Class**: Data structure for individual objectives.
- **LootItem Class**: Data structure for loot items.
- **Debrief UI Scene** (mission_debrief_ui.tscn): Main scene containing all UI elements.

### 6.4 Future Co-op Dependencies (Not in MVP)
- **MultiplayerSynchronizer**: Syncs per-player XP and objectives across clients.
- **Player Identity System**: Maps player IDs to names/colors for per-player columns.
- **Networking Manager**: Detects disconnections and handles them gracefully.

---

## 7. Tuning Knobs

### 7.1 XP_COUNT_DURATION
**Current Value**: 2.0 seconds
**Description**: Duration of the XP count-up animation in seconds.
**Range**: 0.5–5.0 seconds
**Tuning Notes**:
- Lower values (0.5–1.0s) feel snappy and energetic; good for arcade-style games.
- Higher values (3.0–5.0s) feel epic and allow more time for player to read objectives simultaneously.
- Recommended: 2.0s is a good baseline. Test with playtesters; adjust based on readability feedback.

### 7.2 Outcome Banner Colors
**Current Values**:
- SUCCESS: #00C800 (green)
- PARTIAL_SUCCESS: #FFD700 (golden yellow)
- FAILED: #FF4444 (red)

**Description**: RGB color codes for outcome banner backgrounds.
**Tuning Notes**:
- Colors should be **distinct and colorblind-friendly**. Current palette is accessible.
- If art style changes, update colors to match visual theme (e.g., neon cyan/magenta for cyberpunk).
- Test colors in-game under actual lighting conditions; monitors vary.

### 7.3 Overlay Alpha
**Current Value**: 0.5
**Description**: Alpha transparency of the semi-transparent overlay behind Debrief UI (0.0–1.0).
**Range**: 0.3–0.8
**Tuning Notes**:
- Lower (0.3): Game world is more visible; good for narrative games where world matters.
- Higher (0.8): More focus on Debrief; good for competitive games where distraction is a risk.
- Recommended: 0.5 for balanced readability and world visibility.

### 7.4 Objective Checkmark Color
**Current Value**: #00C800 (green)
**Description**: Color of checkmarks for completed objectives.
**Tuning Notes**:
- Must contrast with background. If background is dark, keep green or use lighter shade.
- Should match SUCCESS banner color for visual consistency.

### 7.5 Objective Cross Color
**Current Value**: #FF4444 (red)
**Description**: Color of crosses for incomplete objectives.
**Tuning Notes**:
- Must contrast with background.
- Should match FAILED banner color for visual consistency.

### 7.6 Font Sizes
**Current Values**:
- Outcome Banner Text: 80pt
- Section Titles: 32pt
- Objective Text: 24pt
- XP Number: 60pt
- Loot Text: 20pt
- Continue Button: 48pt

**Tuning Notes**:
- Sizes scale based on screen resolution and safe area (for console/mobile).
- Test on target display sizes (1080p monitor, 4K TV, mobile phone).
- Adjust if readability feedback indicates sizes are too small/large.

### 7.7 Per-Player Column Spacing (Co-op Future)
**Current Value**: TBD (not in MVP)
**Description**: Horizontal spacing between player columns in co-op debrief.
**Tuning Notes**:
- Should allow each column to fit 4+ player names without crowding.
- Consider 4-player maximum; adjust layout if game supports >4 players.

### 7.8 Scroll Speed (for overflow content)
**Current Value**: TBD (not in MVP)
**Description**: Speed at which objective or loot lists scroll if they exceed available space.
**Tuning Notes**:
- Recommend: 300px/second for smooth scrolling without overwhelming.
- Adjust based on content volume and playtest feedback.

---

## 8. Acceptance Criteria

### 8.1 Display & Rendering
- [ ] **AC-1.1**: Debrief UI appears within 0.5 seconds of ExtractionZone emitting run_succeeded/partial_success/failed signal.
- [ ] **AC-1.2**: Outcome banner displays correct text and color for each outcome type (SUCCESS=green, PARTIAL=yellow, FAILED=red).
- [ ] **AC-1.3**: Semi-transparent overlay renders behind UI with alpha 0.5, darkening game world without making it unreadable.
- [ ] **AC-1.4**: All UI elements fit on-screen at 1920x1080 and 1280x720 resolutions without clipping or overflow.

### 8.2 Objective Display
- [ ] **AC-2.1**: All mission objectives appear in the Objectives section with correct names from MissionDebriefData.
- [ ] **AC-2.2**: Completed objectives (is_complete=true) display with green checkmark (✓).
- [ ] **AC-2.3**: Incomplete objectives (is_complete=false) display with red cross (✗).
- [ ] **AC-2.4**: If mission has >4 objectives, list is scrollable; all objectives are visible and accessible.
- [ ] **AC-2.5**: Objective names that exceed line width wrap or truncate with ellipsis (…) without breaking layout.

### 8.3 XP Animation
- [ ] **AC-3.1**: XP count-up animation starts at 0 and animates to final value over XP_COUNT_DURATION (2.0s).
- [ ] **AC-3.2**: Animation uses linear easing (no ease-in/ease-out in v1.0).
- [ ] **AC-3.3**: Displayed XP value updates every frame during animation.
- [ ] **AC-3.4**: Animation completes and displays final value (no visual jump; smooth transition).
- [ ] **AC-3.5**: CONTINUE button is disabled during animation; becomes enabled after animation completes.
- [ ] **AC-3.6**: If XP earned is 0, animation displays "0" instantly and completes immediately.

### 8.4 Loot Manifest
- [ ] **AC-4.1**: Loot section displays all items from MissionDebriefData.loot_items array.
- [ ] **AC-4.2**: Each loot item displays format: "Item Name x quantity" (e.g., "Health Chip x3").
- [ ] **AC-4.3**: If no items were collected, Loot section displays "No items collected" placeholder.
- [ ] **AC-4.4**: If loot list exceeds available space, list is scrollable within the Loot section.

### 8.5 Game Pause
- [ ] **AC-5.1**: When Debrief UI appears, `get_tree().paused` is set to true; game is paused.
- [ ] **AC-5.2**: Player cannot interact with game world (move, shoot, use tools) while Debrief is visible.
- [ ] **AC-5.3**: When CONTINUE button is pressed, `get_tree().paused` is set to false; game resumes (if transitioning back to game).
- [ ] **AC-5.4**: If transitioning directly to main menu, pause state does not matter (main menu has own state).

### 8.6 Continue Button & Navigation
- [ ] **AC-6.1**: CONTINUE button is visible and clickable (left mouse button, gamepad A button).
- [ ] **AC-6.2**: CONTINUE button is disabled until XP animation completes.
- [ ] **AC-6.3**: When CONTINUE is pressed, Debrief UI emits `debrief_dismissed` signal.
- [ ] **AC-6.4**: Signal is received by mission controller (or main menu), triggering navigation away from Debrief.
- [ ] **AC-6.5**: Debrief UI cleanly removes itself from scene tree after transition (no orphaned nodes).

### 8.7 Data Integrity
- [ ] **AC-7.1**: Debrief correctly interprets MissionDebriefData.outcome enum and displays matching outcome banner.
- [ ] **AC-7.2**: If outcome data is malformed or missing, Debrief displays error placeholder (does not crash).
- [ ] **AC-7.3**: Objective counts match total objectives in mission (no missing or duplicate objectives).
- [ ] **AC-7.4**: Negative XP values are clamped to 0 and logged as data errors.

### 8.8 Outcome Verification (Manual Testing)
- [ ] **AC-8.1**: Run a mission to completion with all objectives met → Debrief shows SUCCESS with green banner, all checkmarks.
- [ ] **AC-8.2**: Run a mission with 2/3 objectives met → Debrief shows PARTIAL SUCCESS with yellow banner, 2 checkmarks, 1 cross.
- [ ] **AC-8.3**: Run a mission with 0 objectives met → Debrief shows FAILED with red banner, all crosses.
- [ ] **AC-8.4**: XP count-up plays smoothly without stuttering or visual artifacts.
- [ ] **AC-8.5**: Game remains paused during entire Debrief display; resumes only after Continue is pressed.

### 8.9 Accessibility (MVP Baseline)
- [ ] **AC-9.1**: All text meets minimum 14pt font size for readability.
- [ ] **AC-9.2**: Color choices are colorblind-friendly (tested with Deuteranopia simulator).
- [ ] **AC-9.3**: Continue button has clear visual focus state when selected via gamepad.
- [ ] **AC-9.4**: No time limit on Debrief display; player can read at their own pace.

### 8.10 Performance
- [ ] **AC-10.1**: Debrief UI loads and displays within 500ms of signal emission.
- [ ] **AC-10.2**: XP animation maintains 60fps on target hardware (PC baseline: GTX 1070).
- [ ] **AC-10.3**: No memory leaks after Debrief is dismissed (profiler shows no orphaned objects).
- [ ] **AC-10.4**: Debrief UI renders without causing frame stutters or hitches in paused game world.

---

## Revision History
| Date | Version | Author | Notes |
|------|---------|--------|-------|
| 2026-03-25 | 1.0 | Design | Initial GDD draft for MVP (single-player). Co-op multi-column layout documented as future scope. |

---

## References
- **Mission Debrief System GDD**: [To be created; defines data structure and outcome logic]
- **ExtractionZone Documentation**: Core mission-end system; emits signals that trigger Debrief UI
- **UI Architecture Decision**: [ADR pending for modal dialogs and pause state management]

