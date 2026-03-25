# Mission Debrief System GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-07
**Created**: 2026-03-25

---

## 1. Overview

The Mission Debrief System displays the outcome and rewards of a completed breach mission. It fires after ExtractionZone emits `run_succeeded`, `run_partial_success`, or `run_failed` — showing the run outcome (success/partial/fail), objectives completed, elapsed time, XP awarded (per player and total), a loot manifest placeholder (empty in MVP, populated when Loot System ships), and per-player performance stats.

In MVP, the Debrief is a data structure (MissionDebriefData resource) assembled by a MissionDebriefManager node and consumed by mission-debrief UI (future sprint). The system orchestrates XP calculations following the Objective System and Escalation System formulas, includes a time-bonus mechanic for fast runs, and prepares data for persistent progression tracking. This is the reward closure of the run loop — the moment players see what they earned and celebrate their strategy.

---

## 2. Player Fantasy

The player extracts, breathes a sigh of relief, and wants to know: Did we pull it off? How much loot? What did we each earn? In a co-op team, every player sees their own XP tally and the team's total, building a sense of shared accomplishment. Speed runners glimpse the time clock and feel the rush of a close call. The Debrief is the victory lap — a moment to reflect on the run before the next one begins. The system validates player skill by explicitly showing earned rewards tied to objectives and efficiency.

---

## 3. Detailed Rules

### 3.1 Debrief Trigger Conditions

Debrief is assembled and shown when ExtractionZone emits one of three run-terminal signals:

| Signal | Trigger | Debrief State |
|--------|---------|---------------|
| `run_succeeded` | All alive players extracted | `SUCCEEDED` |
| `run_partial_success(extracted: int, total: int)` | Some players extracted, mission failed | `PARTIAL_SUCCESS` (≥1 player extracted) |
| `run_failed` | Mission failed and no players extracted, or all players dead | `FAILED` |

### 3.2 Debrief Data Structure (MissionDebriefData)

The MissionDebriefData resource contains:

```
MissionDebriefData:
  ├─ run_outcome: String ("SUCCEEDED", "PARTIAL_SUCCESS", "FAILED")
  ├─ total_elapsed_time: float (seconds)
  ├─ objectives_completed: Array[ObjectiveData]
  │   └─ ObjectiveData: { type, description, contributed_players }
  ├─ total_xp_awarded: int
  ├─ per_player_xp: Dictionary[player_id → int]
  ├─ time_bonus_earned: bool
  ├─ time_bonus_xp: int
  ├─ loot_manifest: Array[LootItem] (empty in MVP, placeholder shown)
  ├─ per_player_stats: Dictionary[player_id → PlayerDebriefStats]
  │   └─ PlayerDebriefStats: {
  │        player_name: String,
  │        xp_earned: int,
  │        objectives_contributed: int,
  │        extracted: bool,
  │        damage_dealt: int,
  │        damage_taken: int,
  │        tools_used: int
  │      }
  └─ difficulty_applied: String ("Solo", "2P", "3P", "4P")
```

### 3.3 XP Award Flow

1. **Run outcome is determined** by ExtractionZone → Debrief Manager is signaled.
2. **Objective XP is calculated** for each completed primary and secondary objective using the Objective System formula (base_xp × partial_multiplier × difficulty_multiplier).
3. **XP is split among contributing players** according to Objective System co-op credit rules (equal split with bonus to trigger player).
4. **Time bonus is evaluated**: if elapsed time < FAST_RUN_THRESHOLD, all players earn TIME_BONUS_XP.
5. **Per-player totals are summed** and written to per_player_xp dictionary.
6. **Loot manifest is assembled** (empty placeholder in MVP).
7. **Per-player stats are tallied** from telemetry collected during the run.
8. **Complete MissionDebriefData is returned** to the UI system.

### 3.4 Outcome Logic

```
if run_succeeded:
    outcome = SUCCEEDED
    xp_multiplier = 1.0
elif run_partial_success:
    outcome = PARTIAL_SUCCESS
    xp_multiplier = 0.75
elif run_failed:
    outcome = FAILED
    xp_multiplier = 0.25
```

Partial and failed runs award reduced XP to discourage farming low-effort runs.

### 3.5 Debrief Lifecycle

1. **Assembly Phase**: MissionDebriefManager waits for ExtractionZone signals.
2. **Calculation Phase**: XP, bonuses, stats aggregated.
3. **Serialization Phase**: MissionDebriefData resource created and populated.
4. **Consumption Phase** (future sprint): Mission Debrief UI subscribes to debrief_ready signal, reads data, and renders screen.
5. **Dismissal**: Player presses "Continue" or "Next Run" → Debrief UI closed, Main scene returns to menu or starts next run.

---

## 4. Formulas

### 4.1 Objective XP Award (Per Objective)

```
objective_xp = base_xp × outcome_multiplier × difficulty_multiplier

base_xp = {
  Destroy:  150,
  Retrieve: 120,
  Eliminate: 100,
  Activate: 80,
  Survive:  60
}

outcome_multiplier = {
  SUCCEEDED:        1.0,
  PARTIAL_SUCCESS:  0.75,
  FAILED:           0.25
}

difficulty_multiplier = {
  1 player:  0.8,
  2 players: 1.0,
  3 players: 1.15,
  4 players: 1.3
}
```

**Variables:**
- `base_xp` ∈ [60, 150] (per Objective System GDD § 7)
- `outcome_multiplier` ∈ [0.25, 1.0]
- `difficulty_multiplier` ∈ [0.8, 1.3] (per Escalation System GDD § 4.4)

**Example:**
- Primary Destroy objective, 2 players, SUCCEEDED outcome
- objective_xp = 150 × 1.0 × 1.0 = 150 XP (total, split among players)

### 4.2 Co-op XP Split (Per Objective)

```
trigger_bonus = objective_xp × TRIGGER_BONUS_FRACTION  # 0.25
shared_pool = objective_xp - trigger_bonus
per_player_share = shared_pool / num_contributing_players

trigger_player_xp = per_player_share + trigger_bonus
other_player_xp = per_player_share
```

**Variables:**
- `TRIGGER_BONUS_FRACTION` = 0.25 (per Objective System GDD § 4.3)
- `num_contributing_players` ∈ [1, 4]

**Example:**
- Primary objective grants 150 XP; 2 players contributed; Player A triggered final completion
- trigger_bonus = 150 × 0.25 = 37.5 → 37 XP (truncated)
- shared_pool = 150 - 37 = 113 XP
- per_player_share = 113 / 2 = 56.5 → 56 XP
- Player A receives: 56 + 37 = 93 XP
- Player B receives: 56 XP
- Total distributed: 149 XP (1 XP loss due to truncation; acceptable variance)

### 4.3 Time Bonus

```
time_bonus_xp = 0

if total_elapsed_time < FAST_RUN_THRESHOLD:
    time_bonus_xp = TIME_BONUS_XP
    time_bonus_earned = true
else:
    time_bonus_earned = false

FAST_RUN_THRESHOLD = 300 seconds (5 minutes, tunable per difficulty)
TIME_BONUS_XP = 50 (flat bonus, all players receive equally)
```

**Variables:**
- `total_elapsed_time` ∈ [30, 1200] seconds (estimated min 30s for trivial run, max 20m for ultra-hard)
- `FAST_RUN_THRESHOLD` ∈ [120, 600] seconds (tuning knob)
- `TIME_BONUS_XP` ∈ [10, 100] (tuning knob)

**Example:**
- Run completed in 4 minutes 30 seconds (270 s)
- 270 < 300, so time_bonus_xp = 50 XP (all players get +50)

### 4.4 Total Per-Player XP

```
player_total_xp = sum(xp_per_objective) + time_bonus_xp

Example for Player A (triggered 1 primary, assisted 1 secondary):
  Primary: 93 XP (trigger bonus)
  Secondary: 60 XP (equal share, no trigger)
  Time bonus: 50 XP
  Total: 203 XP
```

### 4.5 Total Run XP

```
total_run_xp = sum(player_total_xp for all players)
```

---

## 5. Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Solo run, SUCCEEDED | outcome_multiplier=1.0, difficulty_multiplier=0.8; XP is base_xp × 0.8 |
| 4-player run, PARTIAL_SUCCESS, 2 extracted | outcome_multiplier=0.75; extracted players still receive full XP calculation; non-extracted players receive 0 XP |
| Objective completed by player who later dies (failed run) | Player's contribution to objective counts; they appear in objectives_completed; they receive 0 XP due to outcome_multiplier=0.25 for FAILED |
| Run succeeded but no objectives were completed (bypass?) | Primary objective locked extraction; impossible in normal flow. If it happens, objectives_completed is empty; no XP awarded beyond time_bonus (if applicable) |
| Time bonus triggers but outcome is FAILED | time_bonus_earned=true, time_bonus_xp=50 × outcome_multiplier (0.25) = 12.5 → 12 XP; all players receive bonus |
| Two players extract, one dies before extraction, outcome PARTIAL_SUCCESS | outcome=PARTIAL_SUCCESS; extracted players get full XP (outcome_multiplier=0.75); dead player gets 0 XP |
| Run exceeds 2 hours (3600+ seconds) | Total elapsed time is clamped to 3600s for telemetry; no time bonus (3600 > FAST_RUN_THRESHOLD) |
| Difficulty modifier is 0.8 (solo) and base_xp=150; result truncates to 120 | Float XP is cast to int (truncation); acceptable variance documented |
| MissionDebriefManager crashes before data is serialized | Debrief UI is never shown; run is lost from progression tracking; acceptable in MVP (future sprint adds save/recovery) |
| Player name contains special characters (future co-op) | PlayerDebriefStats.player_name is sanitized (quotes, newlines removed) before serialization |

---

## 6. Dependencies

| System | Relationship |
|--------|--------------|
| **ExtractionZone** | Debrief is triggered by ExtractionZone signals: `run_succeeded`, `run_partial_success(int, int)`, `run_failed`. MissionDebriefManager subscribes to all three. |
| **Objective System** | base_xp per objective type comes from Objective System GDD § 7. Co-op credit formula (TRIGGER_BONUS_FRACTION) also from § 4.3. |
| **Escalation System** | difficulty_multiplier per player count comes from Escalation System GDD § 4.4. Current escalation level is read to apply outcome_multiplier. |
| **Player Manager** | Reads total_players count and player_id list at run start. Debrief queries Player Manager for player names and final state (extracted/dead). |
| **Telemetry System** | During run, telemetry system collects per_player_stats (damage dealt/taken, tools used, objectives contributed). Debrief Manager reads final telemetry at run end. |
| **Loot System** (future) | When Loot System ships, loot_manifest will be non-empty. In MVP, placeholder text is shown ("Loot system coming soon"). |
| **Mission Debrief UI** (future sprint) | Consumes MissionDebriefData via `debrief_ready(MissionDebriefData)` signal. Responsible for rendering the screen. |
| **Progression System** (future) | Debrief data feeds into persistent progression (character level, cosmetics unlocked, etc.). Not in MVP scope. |

---

## 7. Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `FAST_RUN_THRESHOLD` | 300 s | 120–600 s | How fast you must complete the run to earn time bonus; tighter = harder to achieve bonus |
| `TIME_BONUS_XP` | 50 | 10–100 | Magnitude of speed reward; higher incentivizes rushing |
| `TRIGGER_BONUS_FRACTION` | 0.25 | 0.0–0.5 | Percentage bonus to player who completes objective; comes from Objective System (inherited) |
| `base_xp[Destroy]` | 150 | 80–250 | Base reward for destroy objectives (from Objective System) |
| `base_xp[Retrieve]` | 120 | 60–200 | Base reward for retrieve objectives (from Objective System) |
| `base_xp[Eliminate]` | 100 | 50–200 | Base reward for eliminate objectives (from Objective System) |
| `base_xp[Activate]` | 80 | 40–150 | Base reward for activate objectives (from Objective System) |
| `base_xp[Survive]` | 60 | 30–120 | Base reward for survive objectives (from Objective System) |
| `outcome_multiplier[SUCCEEDED]` | 1.0 | 0.8–1.2 | Base multiplier for successful runs; do not change |
| `outcome_multiplier[PARTIAL_SUCCESS]` | 0.75 | 0.5–1.0 | Penalty for partial success; higher value makes partial runs more rewarding |
| `outcome_multiplier[FAILED]` | 0.25 | 0.1–0.5 | Penalty for failed runs; discourages farming failed runs |

---

## 8. Acceptance Criteria

| # | Criterion | Test Method |
|---|-----------|-------------|
| AC-01 | Debrief fires exactly once per run when ExtractionZone emits run_succeeded | QA: complete a mission; confirm MissionDebriefManager receives signal once; no duplicate debrief data |
| AC-02 | XP calculation for solo run matches formula: base_xp × 1.0 × 0.8 | Unit test: mock solo 1-player, 1 Destroy primary (150 base); assert total_xp = 150 × 1.0 × 0.8 = 120 |
| AC-03 | XP calculation for 2-player SUCCEEDED with trigger bonus matches formula | Unit test: 2 players, 1 Destroy primary (150 base), player A triggers; assert A gets 93 XP, B gets 56 XP |
| AC-04 | Time bonus applies when elapsed_time < FAST_RUN_THRESHOLD | QA: complete run in 4m 30s (< 5m default); assert time_bonus_xp = 50 in debrief |
| AC-05 | Time bonus does not apply when elapsed_time ≥ FAST_RUN_THRESHOLD | QA: complete run in 6m (> 5m); assert time_bonus_earned = false, time_bonus_xp = 0 |
| AC-06 | PARTIAL_SUCCESS outcome applies multiplier 0.75 to all XP | Unit test: mock partial success, 1 primary objective completed; assert total_xp = base_xp × 0.75 × difficulty_multiplier |
| AC-07 | FAILED outcome applies multiplier 0.25 to all XP | Unit test: mock failed run, objectives completed but player dead; assert total_xp = base_xp × 0.25 × difficulty_multiplier |
| AC-08 | Difficulty multiplier is applied correctly per player count | Unit test: run formula with 1, 2, 3, 4 players; assert multipliers are 0.8, 1.0, 1.15, 1.3 respectively |
| AC-09 | Non-extracted players in PARTIAL_SUCCESS receive 0 XP | QA: 2-player run, 1 extracted, 1 dead; assert dead player.xp_earned = 0 in per_player_stats |
| AC-10 | Per-player names in debrief match spawned player names | QA: spawn 2 players named "Alice", "Bob"; extract and check per_player_stats[alice].player_name == "Alice" |
| AC-11 | MissionDebriefData is not null and contains all required fields | Unit test: complete run, call mission_debrief_manager.get_debrief_data(); assert not null; assert has keys: run_outcome, total_xp_awarded, per_player_xp, objectives_completed |
| AC-12 | Objectives_completed array matches primary + completed secondaries | QA: run with 1 primary, 2 secondaries; complete only primary + 1 secondary; assert objectives_completed.size() == 2 |
| AC-13 | Total run XP is sum of all per-player XP | Unit test: 2 players earning 100 and 80 XP + 50 time bonus each; assert total_run_xp = 100+50 + 80+50 = 280 |
| AC-14 | Loot manifest is empty array in MVP | Unit test: get_debrief_data(); assert loot_manifest == [] (empty); placeholder text shown by UI |
| AC-15 | Time bonus multiplied by outcome_multiplier when run fails/partial | Unit test: failed run in 3 minutes; assert time_bonus_xp = 50 × 0.25 = 12 (rounded) |
