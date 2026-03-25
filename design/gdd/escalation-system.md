# Escalation System GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S3-09
**Created**: 2026-03-25

---

## 1. Overview

The Escalation System drives mounting pressure throughout a breach mission. It
operates as a timed state machine with four escalation levels: CALM → ALERT →
HOSTILE → CRITICAL. Escalation advances automatically over time and in response to
player actions (objective completions, loud tool use, combat). At CRITICAL,
extraction becomes a timed countdown. Each level spawns harder hazards, increases
enemy patrol frequency, and adds environmental pressure (alarms, locked doors,
environmental damage). The system is the pacing backbone of every run.

---

## 2. Player Fantasy

The player feels like a surgeon under the gun — early in the run, calm and
methodical; late in the run, improvising under fire as alarms blare and the facility
locks down. Escalation rewards players who work efficiently: the better you play,
the more time you spend in the easier states. At CRITICAL, every second counts and
extraction becomes a race. The system makes every run feel like it has a beginning,
middle, and desperate end.

---

## 3. Detailed Rules

### 3.1 Escalation Levels

| Level | Index | Entry Condition | Active Hazards |
|-------|-------|-----------------|----------------|
| CALM | 0 | Start of run | None. Facility is quiet. |
| ALERT | 1 | Timer OR first loud event | Cameras active, patrol routes extend |
| HOSTILE | 2 | Timer OR objective completion | Enemies summoned to objective area, some doors lock |
| CRITICAL | 3 | Timer OR all objectives complete | Extraction countdown begins, hazard traps activate |

### 3.2 Escalation Advancement

Escalation advances through two paths (whichever fires first):

**Path A — Passive Timer**: Each level has an automatic timeout. When it expires,
escalation advances to the next level regardless of player action.

**Path B — Event-Driven**: Specific in-game events add escalation pressure immediately:
- `loud_tool_used` (force push, large physics impact): +LOUD_PRESSURE points
- `enemy_alerted`: +ALERT_PRESSURE points
- `objective_completed`: advance escalation by 1 level immediately
- `player_detected_by_camera`: +CAMERA_PRESSURE points

Pressure accumulates in a float. When it reaches `PRESSURE_THRESHOLD`, the current
level's event counter triggers advancement. Pressure resets to 0 on level change.

### 3.3 Escalation Events on Level Enter

| Level | Events Fired |
|-------|-------------|
| CALM → ALERT | `alert_entered`: enable cameras, extend patrol radii |
| ALERT → HOSTILE | `hostile_entered`: summon reinforcements, lock secondary doors |
| HOSTILE → CRITICAL | `critical_entered`: start extraction countdown, activate hazard traps |

### 3.4 Extraction Countdown

- Begins when CRITICAL is entered.
- Duration: `EXTRACTION_COUNTDOWN_SECONDS` (default 120 s).
- If countdown reaches 0, all players take `OVERTIME_DAMAGE_PER_TICK` damage every
  `OVERTIME_TICK_INTERVAL` seconds until extraction or death.
- Countdown is paused while all players are in the extraction zone (zone acts as a
  "safe room" in the final phase).

### 3.5 Resetting Escalation

Escalation is one-directional within a run. It cannot decrease. A new run always
starts at CALM.

---

## 4. Formulas

### 4.1 Passive Timer Per Level

```
level_duration[CALM]     = BASE_CALM_DURATION     (default 60 s)
level_duration[ALERT]    = BASE_ALERT_DURATION    (default 90 s)
level_duration[HOSTILE]  = BASE_HOSTILE_DURATION  (default 60 s)
level_duration[CRITICAL] = ∞ (countdown takes over)
```

### 4.2 Pressure Accumulation

```
pressure += event_value
if pressure >= PRESSURE_THRESHOLD:
    advance_escalation()
    pressure = 0
```

Default event values:
- `loud_tool_used`: +25
- `enemy_alerted`: +40
- `player_detected_by_camera`: +60
- `PRESSURE_THRESHOLD` = 100

### 4.3 Overtime Damage

```
damage_per_tick = OVERTIME_DAMAGE_PER_TICK  # default 5
tick_interval   = OVERTIME_TICK_INTERVAL    # default 5.0 s
expected_time_to_kill = (MAX_HP / damage_per_tick) * tick_interval
                      = (100 / 5) * 5 = 100 s
```

Players have ~100 seconds of survival time in overtime before dying, incentivising
extraction over indefinite delay.

### 4.4 Escalation Speed Modifier (Difficulty Scaling)

```
effective_timer = level_duration[level] / difficulty_multiplier
difficulty_multiplier ∈ { Solo: 0.8, 2P: 1.0, 3P: 1.15, 4P: 1.3 }
```

More players = escalation runs slightly faster, keeping co-op tense.

---

## 5. Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Player uses loud tool in CRITICAL | Pressure accumulates but level cannot advance beyond CRITICAL; pressure is silently discarded |
| Objective completes while already in CRITICAL | `objective_completed` event fires normally (Extraction System listens for it); escalation level unchanged |
| All players die in CRITICAL countdown | Run ends; countdown stops; `run_failed` emitted |
| Two objectives complete on same frame | Both fire `objective_completed`; each advances level by 1 (may skip HOSTILE and land in CRITICAL in one frame) — this is intentional, rewarding fast clear |
| Timer fires same frame as event-driven advance | Both try to call `advance_escalation()`; guarded by `_is_advancing` flag; second call is no-op |
| Solo difficulty: shorter timers | `difficulty_multiplier = 0.8` means 60 s CALM becomes 75 s effectively — solo gets more time |

---

## 6. Dependencies

| System | Relationship |
|--------|-------------|
| **Objective System** | Emits `objective_completed(ObjectiveData)` → EscalationSystem.on_objective_completed(); each completion advances level |
| **Extraction System** | EscalationSystem emits `critical_entered` → ExtractionSystem unlocks extraction zone and starts countdown |
| **Enemy & Hazard System** (future) | EscalationSystem emits `alert_entered`, `hostile_entered` → triggers patrol expansion and reinforcements |
| **HUD** | Subscribes to `escalation_level_changed(new_level)` to update pressure bar and blinking alarm UI |
| **Audio System** (future) | Subscribes to level-change signals to shift ambient music layers and trigger alarm SFX |
| **Networking (future)** | EscalationSystem is server-authoritative; state broadcasted to all clients via MultiplayerSynchronizer |

---

## 7. Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `BASE_CALM_DURATION` | 60 s | 30–180 s | How long before the first pressure spike |
| `BASE_ALERT_DURATION` | 90 s | 45–180 s | Window for main objective completion |
| `BASE_HOSTILE_DURATION` | 60 s | 30–120 s | Time between hostile and critical |
| `PRESSURE_THRESHOLD` | 100 | 50–200 | How fast event-driven escalation fires |
| `LOUD_PRESSURE` | 25 | 10–50 | Punishment for noisy tool use |
| `ALERT_PRESSURE` | 40 | 20–80 | Punishment for alerting enemies |
| `CAMERA_PRESSURE` | 60 | 30–100 | Punishment for camera detection |
| `EXTRACTION_COUNTDOWN_SECONDS` | 120 s | 60–300 s | Final-phase time pressure |
| `OVERTIME_DAMAGE_PER_TICK` | 5 HP | 1–20 HP | Lethality of overtime |
| `OVERTIME_TICK_INTERVAL` | 5.0 s | 2.0–15.0 s | Frequency of overtime damage |
| `difficulty_multiplier` (per player count) | 0.8/1.0/1.15/1.3 | 0.5–2.0 | Co-op pacing |

---

## 8. Acceptance Criteria

| # | Criterion | Test Method |
|---|-----------|-------------|
| AC-01 | CALM timer expires and ALERT is entered without any player action | Unit test: set BASE_CALM_DURATION=2s; wait 3s; assert level == ALERT |
| AC-02 | Pressure events advance level when PRESSURE_THRESHOLD is reached | Unit test: emit 4 loud_tool_used events (4×25=100); assert level advances |
| AC-03 | `objective_completed` advances level by exactly 1 | Unit test: at CALM, emit objective_completed; assert level == ALERT |
| AC-04 | Escalation never decreases | Unit test: advance to HOSTILE, assert no API call can return it to ALERT |
| AC-05 | CRITICAL entered → extraction countdown timer starts | QA: advance to CRITICAL; verify ExtractionSystem shows countdown in HUD |
| AC-06 | Overtime damage fires at correct interval | Unit test: start overtime at 100HP, tick interval=1s, damage=10; after 10 ticks assert HP==0 |
| AC-07 | Same seed + player count produces identical escalation timeline | Run twice with seed=12345, 1 player; record level-change timestamps; assert ≤50ms deviation |
