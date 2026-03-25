# Extraction System GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S3-10
**Created**: 2026-03-25

---

## 1. Overview

The Extraction System manages how players end a breach mission. An extraction zone
is placed in the exit room by the Procedural Generator. It is locked until the
primary objective is complete. Once unlocked, players who enter the zone and survive
a short extraction window trigger mission success. The system handles partial
extraction (some players escape, others die), co-op extraction timing, and failure
states. It is the terminal node of the mission loop — the moment of truth that
determines whether a run is a success, partial success, or failure.

---

## 2. Player Fantasy

Running for the extraction point with alarms blaring and enemies on your heels is
the payoff moment of every run. The countdown to extraction creates a shared goal
the whole team rallies around. Staying in the zone while under fire, watching the
bar fill, covering your teammate who's still running — this is the climactic beat
the rest of the system builds toward. Extracting after a clean run feels like a
job well done. Extracting with 2HP left, last player standing, feels like a miracle.

---

## 3. Detailed Rules

### 3.1 Extraction Zone

- An Area3D node placed in the exit room at the position tagged "extraction_zone"
  in the room template's SpawnPoints/ node.
- Locked state (default): visually dimmed, player entry does not start extraction.
- Unlocked state: visually active (glow), player entry starts extraction sequence.

### 3.2 Unlock Conditions

The extraction zone unlocks when ALL of the following are true:
1. The primary objective is in state `COMPLETE`.
2. The Escalation System is in state `CRITICAL` OR `primary_objective_complete`
   signal has been received (whichever fires first in the run).

Rule 2 exists so players cannot rush straight to extraction before doing anything —
either the mission must be done or the facility must be in lockdown.

### 3.3 Extraction Sequence

1. Player enters extraction zone Area3D → `body_entered` fires.
2. If zone is locked → play rejection effect, do nothing.
3. If zone is unlocked and player is `CharacterController`:
   - Start per-player `EXTRACTION_CHANNEL_TIME` timer (default 4.0 s).
   - Display extraction bar in HUD.
   - If player leaves zone, cancel their channel; bar resets.
   - If channel completes: player is marked `extracted`.
4. When all alive players are marked `extracted` → emit `run_succeeded`.

### 3.4 Co-op Extraction

- Each player has an independent channel timer — players do not need to channel
  simultaneously, but all must extract before the run ends.
- A player marked `extracted` stays extracted even if they die afterwards (they
  already escaped — flavour: they made it to the evac ship).
- If any player dies after channelling starts but before completing:
  - Their death is permanent for this run.
  - `run_partial_success` is evaluated on run end.

### 3.5 Partial Success

| Situation | Outcome |
|-----------|---------|
| All players extracted | `run_succeeded` |
| ≥1 player extracted, ≥1 dead | `run_partial_success(extracted_count, total_count)` |
| 0 players extracted, all dead | `run_failed` |
| Overtime countdown expires, 0 extracted | `run_failed` |

Partial success still awards XP and loot, scaled by `extracted_count / total_count`.

### 3.6 Failed Extraction

- The run fails if the Escalation System's overtime countdown reaches 0 AND no
  player is currently channelling or has already extracted.
- A player channelling at the moment overtime reaches 0 is allowed to complete their
  channel — a 1-second grace is added to their remaining channel time.

---

## 4. Formulas

### 4.1 Extraction Channel Time

```
effective_channel_time = EXTRACTION_CHANNEL_TIME / channel_speed_modifier
channel_speed_modifier = 1.0  # future: upgrades may reduce this
```

Default `EXTRACTION_CHANNEL_TIME = 4.0 s`.

### 4.2 Partial Success Reward

```
xp_awarded = base_run_xp * (extracted_count / total_player_count) * PARTIAL_MULTIPLIER
PARTIAL_MULTIPLIER = 0.75  # partial success is less rewarding than full
```

Example: 2 players, 1 extracts, base_xp=500:
`500 * (1/2) * 0.75 = 187.5 → 187 XP`

### 4.3 Zone Unlock Visual Lerp

```
material_emission = lerp(LOCKED_COLOR, UNLOCKED_COLOR, unlock_progress)
unlock_progress = 0.0 when locked, animates to 1.0 over UNLOCK_ANIM_DURATION (1.5 s)
```

---

## 5. Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Player channels extraction but is killed mid-channel | Channel cancels; they must re-enter zone if respawned (no respawn in MVP — run ends) |
| All players in zone simultaneously | Each runs their own 4-second timer; both extract at ~same time (within 1 frame) |
| Extraction zone spawned in unreachable room | ProceduralGenerator logs a warning; zone placed in any accessible exit-tagged room; if none accessible, zone falls back to the last placed room |
| Player is inside zone at moment of unlock | Zone unlock is detected in `_process`; extraction starts immediately on next frame |
| Player uses gravity flip tool while channelling | Channelling continues — no movement requirement; flip may throw them out of zone → channel cancels |
| Force push knocks player out of zone mid-channel | Channel cancels; body_exited fires; re-entry restarts channel |
| Solo player — no co-op coordination needed | Single player extracts; `run_succeeded` fires immediately |
| Networking (future) | ExtractionZone is server-authoritative; client sends extract_request RPC; server validates zone membership |

---

## 6. Dependencies

| System | Relationship |
|--------|-------------|
| **Objective System** | Emits `primary_objective_complete` → ExtractionSystem.unlock_zone() |
| **Escalation System** | Emits `critical_entered` as a secondary unlock path; emits overtime events that lead to forced failure |
| **Procedural Generation System** | Places exit room with "extraction_zone" spawn point; ExtractionSystem finds it via room node query |
| **Health & Death System** | Player death while channelling → channel cancels; death count tracked for partial success |
| **HUD** | Subscribes to `extraction_channel_started(player_id, remaining_time)`, `extraction_channel_cancelled(player_id)`, and `extraction_zone_unlocked` |
| **Audio System** (future) | Zone unlock SFX, channel fill tone, extraction success/fail stinger |
| **Character Controller** | Extraction zone uses `body_entered`; expects CharacterBody3D with CharacterController script |

---

## 7. Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `EXTRACTION_CHANNEL_TIME` | 4.0 s | 1.0–10.0 s | How long players must stand in zone — tension vs frustration |
| `PARTIAL_MULTIPLIER` | 0.75 | 0.5–1.0 | How much partial extraction is rewarded |
| `UNLOCK_ANIM_DURATION` | 1.5 s | 0.5–3.0 s | Satisfying feedback time when zone becomes active |
| `OVERTIME_GRACE_PERIOD` | 1.0 s | 0.0–5.0 s | Extra time for channelling players when overtime countdown ends |
| `LOCKED_COLOR` | Color(0.2, 0.2, 0.5) | any dark colour | Visual state of locked zone |
| `UNLOCKED_COLOR` | Color(0.3, 1.0, 0.5) | any bright colour | Visual state of active zone |

---

## 8. Acceptance Criteria

| # | Criterion | Test Method |
|---|-----------|-------------|
| AC-01 | Extraction zone is locked until primary objective completes | QA: enter zone before completing objective; confirm no channel starts |
| AC-02 | Completing primary objective unlocks zone (visual + functional) | QA: complete objective; confirm zone glows and channel starts on re-entry |
| AC-03 | Channel cancels if player leaves zone | QA: enter zone, move out mid-channel; confirm bar resets |
| AC-04 | Solo extraction emits `run_succeeded` | Unit test: mock single player, complete channel; assert `run_succeeded` fired |
| AC-05 | Partial extraction emits `run_partial_success` with correct counts | Unit test: 2 players, 1 extracts, 1 dies; assert `run_partial_success(1, 2)` |
| AC-06 | Channelling player gets overtime grace period | Unit test: channel at 0.5s remaining, start overtime; assert player still completes at 4s |
| AC-07 | Overtime with 0 extracted players emits `run_failed` | Unit test: set overtime_remaining=0, no players extracted; assert `run_failed` |
