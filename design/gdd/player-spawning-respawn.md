# Player Spawning & Respawn GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-06
**Created**: 2026-03-25

---

## 1. Overview

The Player Spawning & Respawn system manages player entry into the game world and recovery from defeat. In the Solo MVP, players respawn immediately at the nearest unlocked spawn point after a configurable delay. In co-op (Vertical Slice), dead players become ghosts and can be revived by teammates within a time window, with automatic respawn at the last checkpoint if the window expires. Spawn protection grants temporary invulnerability to prevent instant re-defeat. All respawns are unlimited—there is no token or life system.

---

## 2. Player Fantasy

Players experience respawn as a **clean second chance** rather than punishment. In solo play, the brief respawn delay creates a moment to plan the next attempt, building tension and reflection. In co-op, the revival mechanic transforms death into a **team problem to solve**—alive teammates must choose to rescue a downed partner or let them auto-respawn. This creates emergent cooperation without mandatory coordination. The invisible spawn protection ensures players have time to reorient after respawn, avoiding the frustration of instant re-death. Overall, the respawn flow should feel fast, fair, and encouraging of experimentation.

---

## 3. Detailed Rules

### 3.1 Solo Respawn (MVP)

1. **Death Trigger**: When `HealthComponent.died` signal fires, the player is marked as dead.
2. **Disable Input/Physics**: `CharacterController` input is disabled, physics simulation stops.
3. **Respawn Delay**: Player waits `RESPAWN_DELAY` seconds (default 3.0s) before respawning.
4. **Spawn Point Selection**: Player respawns at the **nearest unlocked spawn point** in the current room.
   - Spawn points are `Marker3D` nodes located under a `SpawnPoints/` node in the room template.
   - A spawn point is "locked" if the room is hostile (not cleared). Locked spawn points are skipped.
   - If no unlocked spawn points exist in the current room, spawn at the last checkpoint respawn point.
5. **Respawn Execution**:
   - Player is teleported to the selected spawn point's position and rotation.
   - Health is fully restored.
   - Input is re-enabled.
   - Physics simulation resumes.
6. **Spawn Protection**: Player receives `SPAWN_INVULNERABLE_TIME` seconds (default 2.0s) of invulnerability (i-frames) immediately after respawn.

### 3.2 Co-op Respawn (Vertical Slice)

1. **Death Trigger**: Same as solo—`HealthComponent.died` fires.
2. **Ghost State**: Dead player enters ghost state instead of respawning immediately.
   - Ghost appearance: translucent, grayed-out, or outlined visual.
   - Ghost is non-interactive (cannot pick up items, activate tools, collide with physics objects).
   - Ghost can be seen and heard (voice/SFX) by alive players.
3. **Revive Mechanic**:
   - An alive teammate can initiate a revive by **standing near the dead player's death location** and holding an interact button for `REVIVE_HOLD_TIME` (TBD, typically 1–2s).
   - Revive restores the dead player to full health at the death location.
   - Revived player receives `SPAWN_INVULNERABLE_TIME` seconds of invulnerability.
4. **Revive Window**: Dead player can be revived within `REVIVE_WINDOW` seconds (default 30s) of death.
   - Timer starts when death occurs and counts down visually for the dead player and nearby allies.
   - If the window expires, dead player **auto-respawns** at the last checkpoint respawn point (same as solo MVP fallback).
5. **Multiple Deaths**: If a player dies while already in ghost state, they remain in ghost state; the revive timer continues from the original death time.

### 3.3 Spawn Points

1. **Placement**: Spawn points are `Marker3D` nodes in the room template, placed under a `SpawnPoints/` child node.
2. **Locked vs. Unlocked**:
   - Locked: The room has not been cleared yet (hostile room state).
   - Unlocked: The room has been cleared or the spawn point is in a safe zone.
3. **Selection Algorithm**: On respawn, find all unlocked spawn points in the current room, then pick the one with **minimum distance** to the player's death location.
4. **Fallback Spawn**: If no unlocked spawn points exist:
   - Use the **last checkpoint respawn point** (e.g., the start of the current level or a major milestone).
   - Checkpoint respawn points are always unlocked and must exist in every room.

### 3.4 Spawn Protection

1. **Duration**: `SPAWN_INVULNERABLE_TIME` seconds (default 2.0s).
2. **Behavior**: Player cannot take damage from any source during this window.
3. **Visual Feedback**: Optional animated shader or translucent overlay to signal invulnerability.
4. **Expiration**: Protection expires automatically after the duration or is manually cancelled if the player voluntarily takes damage (e.g., activates a tool that damages self).

### 3.5 No Respawn Tokens (MVP Constraint)

- Players have unlimited respawns.
- There is no "lives" counter, permadeath, or respawn token mechanic in the MVP or Vertical Slice.

---

## 4. Formulas

### 4.1 Spawn Point Distance

**Nearest Spawn Point Selection**

```
nearest_spawn = argmin(spawn_points, key=distance(spawn_point.position, death_location))

where:
  spawn_points = list of unlocked Marker3D nodes under room/SpawnPoints/
  distance(a, b) = sqrt((a.x - b.x)² + (a.y - b.y)² + (a.z - b.z)²)  [Euclidean distance]
  death_location = Vector3 position where player died
  argmin returns the spawn point with minimum distance

Expected value ranges:
  - distance: 0.0 to 500.0 units (room-dependent)
  - Typical range in RIFT room templates: 5.0 to 100.0 units
```

### 4.2 Revive Window Countdown (Co-op)

```
revive_eligible_time_remaining = REVIVE_WINDOW - (current_time - death_time)

where:
  REVIVE_WINDOW = 30.0 seconds (tunable)
  current_time = world time when revive is attempted
  death_time = world time when HealthComponent.died signal fired

Revive is allowed if: revive_eligible_time_remaining > 0

Expected value ranges:
  - REVIVE_WINDOW: 15.0 to 60.0 seconds (typical 30.0s)
  - revive_eligible_time_remaining: 0.0 to REVIVE_WINDOW
  - Timer displayed to player counts down from REVIVE_WINDOW to 0.0

Example:
  REVIVE_WINDOW = 30.0s
  Player dies at world_time = 100.0s
  Teammate attempts revive at 120.0s
  revive_eligible_time_remaining = 30.0 - (120.0 - 100.0) = 10.0s > 0 ✓ Revive succeeds

  Player dies at world_time = 100.0s
  No revive attempt until 131.0s
  revive_eligible_time_remaining = 30.0 - (131.0 - 100.0) = -1.0s < 0 ✗ Auto-respawn triggered
```

### 4.3 Spawn Protection Duration

```
invulnerable_until = respawn_time + SPAWN_INVULNERABLE_TIME

where:
  respawn_time = Time.get_ticks_msec() when player respawns
  SPAWN_INVULNERABLE_TIME = 2.0 seconds (tunable)

Player is invulnerable if: current_time < invulnerable_until

Expected value ranges:
  - SPAWN_INVULNERABLE_TIME: 0.5 to 5.0 seconds (typical 2.0s)
  - invulnerable_until: respawn_time to respawn_time + SPAWN_INVULNERABLE_TIME

Example:
  Player respawns at Time = 5000.0 ms
  SPAWN_INVULNERABLE_TIME = 2000.0 ms
  invulnerable_until = 5000.0 + 2000.0 = 7000.0 ms
  At Time = 6000.0 ms: 6000.0 < 7000.0 → invulnerable ✓
  At Time = 7500.0 ms: 7500.0 < 7000.0 → vulnerable ✗
```

### 4.4 Respawn Delay (Solo MVP)

```
respawn_triggered_at = death_time + RESPAWN_DELAY

where:
  death_time = Time.get_ticks_msec() when HealthComponent.died fires
  RESPAWN_DELAY = 3.0 seconds (tunable)

Respawn executes when: current_time >= respawn_triggered_at

Expected value ranges:
  - RESPAWN_DELAY: 0.5 to 10.0 seconds (typical 3.0s)
  - respawn_triggered_at: death_time to death_time + RESPAWN_DELAY

Example:
  Player dies at Time = 50000.0 ms
  RESPAWN_DELAY = 3000.0 ms
  respawn_triggered_at = 50000.0 + 3000.0 = 53000.0 ms
  Respawn executes automatically at Time = 53000.0 ms
```

---

## 5. Edge Cases

### 5.1 Death During Respawn Delay
**Scenario**: Player dies, is waiting for respawn delay, and respawn delay completes while the player is somehow in an invalid state (e.g., level unloading).

**Behavior**:
- Respawn delay still completes and respawn is queued.
- If the room/level is no longer valid, respawn to the checkpoint respawn point in the new room.
- If input is already disabled (from a previous death), keep input disabled until respawn executes.

---

### 5.2 No Valid Spawn Points in Current Room
**Scenario**: All spawn points in the room are locked (room not cleared), and there are no unlocked spawn points.

**Behavior**:
- Skip current room's spawn points entirely.
- Respawn at the **last checkpoint respawn point** (always unlocked).
- Log a warning if checkpoint respawn point also doesn't exist (this is a level design error).

---

### 5.3 Death During Spawn Protection (Solo)
**Scenario**: Player respawns, takes damage while invulnerable, and dies before spawn protection expires.

**Behavior**:
- Player is immune to damage during spawn protection, so no death can occur.
- If player takes a self-damage action (e.g., activates tool with damage-to-self effect), spawn protection may be **manually cancelled**.
- After cancellation, invulnerability ends and subsequent damage is normal.

---

### 5.4 Co-op: Multiple Simultaneous Deaths
**Scenario**: All players die at roughly the same time.

**Behavior**:
- All dead players enter ghost state.
- No revive is possible (no alive players remain).
- All players auto-respawn at the checkpoint respawn point when their individual `REVIVE_WINDOW` expires (or all at once if all windows expire at the same time).

---

### 5.5 Co-op: Revive While Reviver Dies
**Scenario**: Player A is reviving Player B (holding interact button), but Player A takes lethal damage mid-revive.

**Behavior**:
- Player A's death interrupts the revive action (cancel the hold/cast).
- Player A enters ghost state.
- Player B remains in ghost state (revive was incomplete).
- Player B's revive timer continues from original death time.
- If a second alive player exists, they can revive either Player A or Player B (prioritize by proximity or player choice).

---

### 5.6 Spawn Point is Inside a Collision Hazard
**Scenario**: A spawn point's position is inside a wall, spike trap, or other lethal hazard.

**Behavior**:
- Player still respawns at the designated location.
- If spawn protection is enabled, player survives long enough to move away.
- If hazard deals damage that bypasses protection or after protection expires, player takes damage/dies immediately.
- This is a **level design error**; validate spawn point placement during level review.

---

### 5.7 Respawn Delay = 0.0 Seconds
**Scenario**: `RESPAWN_DELAY` is set to 0.0 (instant respawn).

**Behavior**:
- Player respawns immediately when death is processed.
- No respawn delay countdown is shown.
- Spawn protection still applies for `SPAWN_INVULNERABLE_TIME`.
- Valid for testing; not recommended for production (removes pause-to-plan moment).

---

### 5.8 Co-op: Checkpoint Respawn During Active Revive Timer
**Scenario**: Player dies, enters revive window, level transitions to a new room before revive window expires.

**Behavior**:
- Revive timer is **discarded** when changing rooms (ghosts cannot be revived across rooms).
- Player **immediately respawns** at the new room's checkpoint respawn point.
- This prevents "carried ghosts" between rooms.

---

## 6. Dependencies

### 6.1 Engine & Framework
- **Godot 4.6.1**: Core signal system (`HealthComponent.died`), physics simulation (`physics_enabled`), input system.
- **CharacterController**: Must support `disable_input()` and `enable_input()` for pausing during death.
- **HealthComponent**: Must emit `died` signal when health reaches 0. Must support `restore_health()` on respawn.

### 6.2 Level & Room Systems
- **Room Template System**: Each room must have a `SpawnPoints/` node with `Marker3D` spawn point children.
- **Room Clearing System**: Determines if spawn points are locked/unlocked based on room cleared state.
- **Checkpoint System**: Must designate a canonical checkpoint respawn point per level or section.

### 6.3 Co-op (Vertical Slice Only)
- **Player Ghost State System**: Handles ghost appearance, collision behavior, and ghost UI.
- **Multiplayer Synchronizer**: Syncs death state, ghost state, and revive timers across players.
- **Interaction System**: Supports revive interaction (hold input near dead player).

### 6.4 UI & Feedback
- **Respawn Timer UI**: Displays countdown during `RESPAWN_DELAY` (solo) or `REVIVE_WINDOW` (co-op).
- **Spawn Protection Indicator**: Optional visual feedback (shader overlay, HUD icon) during invulnerability.
- **Death Notification**: Notifies player of death and expected respawn time.

### 6.5 Audio & Visuals
- **Death Sound Effect**: Plays on death event.
- **Respawn Sound Effect**: Plays when player respawns.
- **Ghost Audio**: Quieter or pitch-shifted audio while in ghost state (co-op).

---

## 7. Tuning Knobs

All values below are exposed as configurable constants in the `RespawnConfig` or `GameConfig` singleton. Designers can adjust without code changes.

| Knob | Type | MVP Default | Min | Max | Notes |
|------|------|-------------|-----|-----|-------|
| `RESPAWN_DELAY` | float (seconds) | 3.0 | 0.0 | 10.0 | Time player waits after death before respawning (solo MVP). Set to 0.0 for instant respawn (testing only). |
| `SPAWN_INVULNERABLE_TIME` | float (seconds) | 2.0 | 0.5 | 5.0 | Duration of post-respawn invulnerability (i-frames). Prevents instant re-death after respawn. |
| `REVIVE_WINDOW` | float (seconds) | 30.0 | 15.0 | 60.0 | Time window during which a dead player can be revived by teammates (co-op only). After expiry, auto-respawn at checkpoint. |
| `REVIVE_HOLD_TIME` | float (seconds) | 1.5 | 0.5 | 3.0 | Duration an alive player must hold interact button to complete a revive (co-op only). Visual/audio feedback during hold. |
| `SPAWN_POINT_SEARCH_RADIUS` | float (units) | 1000.0 | 50.0 | 5000.0 | Maximum distance to search for spawn points. If no spawn points within radius, use checkpoint. Helps handle level layout edge cases. |

---

## 8. Acceptance Criteria

### Solo MVP Tests

- [ ] **AC-1.1**: Player dies → `HealthComponent.died` signal fires → `CharacterController` input is disabled.
- [ ] **AC-1.2**: Player waits exactly `RESPAWN_DELAY` (e.g., 3.0s) before respawning.
- [ ] **AC-1.3**: Player respawns at the nearest unlocked spawn point (measured by Euclidean distance).
- [ ] **AC-1.4**: If no unlocked spawn points exist in the room, player respawns at the checkpoint respawn point.
- [ ] **AC-1.5**: On respawn, player's health is restored to maximum.
- [ ] **AC-1.6**: On respawn, `CharacterController` input is re-enabled.
- [ ] **AC-1.7**: On respawn, physics simulation resumes (velocity is reset, gravity applies normally).
- [ ] **AC-1.8**: Player receives `SPAWN_INVULNERABLE_TIME` (e.g., 2.0s) of invulnerability immediately after respawn.
- [ ] **AC-1.9**: Damage is blocked during spawn protection. Health bar does not decrease; no knockback or stun effects apply.
- [ ] **AC-1.10**: Spawn protection expires after the configured duration, and player becomes vulnerable again.
- [ ] **AC-1.11**: Respawn timer is displayed in UI, counting down from `RESPAWN_DELAY` to 0.
- [ ] **AC-1.12**: Respawn can be triggered by any death (enemy contact, environmental hazard, self-damage).
- [ ] **AC-1.13**: Respawn works correctly after multiple consecutive deaths.

### Co-op Vertical Slice Tests

- [ ] **AC-2.1**: Player dies → enters ghost state (translucent appearance, no collision, no item pickup).
- [ ] **AC-2.2**: Ghost state has a visible timer counting down `REVIVE_WINDOW` (e.g., 30s).
- [ ] **AC-2.3**: Alive teammate can initiate revive by standing near dead player's death location and holding interact button.
- [ ] **AC-2.4**: Revive requires exactly `REVIVE_HOLD_TIME` (e.g., 1.5s) of continuous button hold; releasing cancels.
- [ ] **AC-2.5**: Successful revive restores dead player to full health at death location.
- [ ] **AC-2.6**: Revived player receives `SPAWN_INVULNERABLE_TIME` seconds of spawn protection.
- [ ] **AC-2.7**: If no revive occurs within `REVIVE_WINDOW`, dead player auto-respawns at checkpoint respawn point.
- [ ] **AC-2.8**: If reviver dies mid-revive, the revive is cancelled; both players remain in ghost state.
- [ ] **AC-2.9**: Revive timer is synced across all players in multiplayer session (via MultiplayerSynchronizer).
- [ ] **AC-2.10**: If all players die simultaneously, all respawn at checkpoint when revive windows expire.
- [ ] **AC-2.11**: Changing rooms (level transition) cancels active revive timers and triggers immediate checkpoint respawn.

### Configuration & Tuning Tests

- [ ] **AC-3.1**: `RESPAWN_DELAY` can be changed in config, and respawn time updates without code recompile.
- [ ] **AC-3.2**: `SPAWN_INVULNERABLE_TIME` can be changed in config, and protection duration updates.
- [ ] **AC-3.3**: `REVIVE_WINDOW` and `REVIVE_HOLD_TIME` can be changed in config (co-op).
- [ ] **AC-3.4**: Changing spawn point locked/unlocked state updates the respawn location selection immediately.

### Integration Tests

- [ ] **AC-4.1**: Respawn system integrates with `HealthComponent.died` signal without errors.
- [ ] **AC-4.2**: Respawn system integrates with `CharacterController` input enable/disable without errors.
- [ ] **AC-4.3**: Respawn system integrates with room clearing/lock state without errors.
- [ ] **AC-4.4**: Spawn protection is rendered correctly (optional shader overlay or UI indicator).
- [ ] **AC-4.5**: Death and respawn sounds play correctly in solo and co-op.

### Edge Case Tests

- [ ] **AC-5.1**: If spawn point is inside a collision hazard, player respawns there; spawn protection prevents instant death if hazard deals damage.
- [ ] **AC-5.2**: If `RESPAWN_DELAY` is 0.0, player respawns immediately.
- [ ] **AC-5.3**: Multiple consecutive deaths are handled correctly (respawn delay resets, spawn protection reapplies).
- [ ] **AC-5.4**: Co-op: Revive attempt outside `REVIVE_WINDOW` is rejected with visual/audio feedback.

---

**End of Document**
