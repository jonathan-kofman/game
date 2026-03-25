# Solo/Co-op Scaling System GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S4-08
**Created**: 2026-03-25

---

## 1. Overview

RIFT supports 1–4 players in solo and co-op modes. The Solo/Co-op Scaling System adjusts game difficulty, objectives, enemy composition, and rewards based on player count to maintain a consistent challenge curve and ensure fair progression across all modes. The system uses player count as the primary scaling lever, affecting escalation speed, objective density, enemy density/health, and solo bonuses. Physics tool power and range remain unchanged across all modes — tools feel mechanically identical whether playing alone or in a group.

---

## 2. Player Fantasy

**Solo players** want to experience the full RIFT roguelike progression loop without feeling punished for playing alone. They expect:
- Adequate time to engage with tools and obstacles before escalation forces extraction
- Fair XP rewards that don't require co-op synergy to achieve
- A sense of agency: their solo run should feel like a complete challenge, not a degraded co-op experience

**Co-op players** (2–4) want synergy and emergent chaos from tool combinations, with difficulty scaling to reward cooperation:
- More objectives to encourage tool sharing and team problem-solving
- More enemies and tougher challenges that benefit from coordinated tool use
- Clear feedback that having teammates makes the experience harder but richer

**All players** expect:
- Consistent tool mechanics across modes (a gravity flip radius is the same solo or co-op)
- Fair extraction and XP progression regardless of player count
- No mode feeling like a penalty (solo is slower but not impossible; co-op is harder but not overwhelming at any cap)

---

## 3. Detailed Rules

### 3.1 Difficulty Multiplier (Escalation Speed)

The escalation timer speed adjusts based on player count. Fewer players get proportionally more time per level to explore and execute strategies.

| Player Count | Difficulty Multiplier | Escalation Speed Modifier |
|--------------|------------------------|---------------------------|
| 1            | 0.8x                   | Timer runs 20% slower     |
| 2            | 1.0x                   | Timer runs at normal speed |
| 3            | 1.15x                  | Timer runs 15% faster     |
| 4            | 1.3x                   | Timer runs 30% faster     |

**Implementation**: Escalation timer's delta_time is multiplied by this factor. Lower multipliers = more actual seconds per level.

---

### 3.2 Secondary Objectives Scaling

The number of available secondary objectives per level increases with player count. More objectives encourage tool diversity and multi-player coordination.

| Player Count | Max Secondary Objectives |
|--------------|--------------------------|
| 1            | 0                        |
| 2            | 1                        |
| 3            | 2                        |
| 4            | 2                        |

**Rule**: At 1 player, only mandatory primary objectives are available. Secondary objectives are unlocked at 2+ players. No more than 2 secondary objectives per level regardless of player count (prevents objective bloat and decision paralysis).

---

### 3.3 Enemy Scaling

Enemy count and health scale proportionally with player count using multiplicative factors.

#### 3.3.1 Enemy Count Scaling

Base enemy count per level is determined by level difficulty (managed by Level System). The spawn quantity scales per player count:

| Player Count | Enemy Count Multiplier |
|--------------|------------------------|
| 1            | 0.8x                   |
| 2            | 1.0x                   |
| 3            | 1.2x                   |
| 4            | 1.4x                   |

**Rationale**: Solo players face fewer enemies to compensate for no tool synergy partners. Higher player counts see enemy density increase to maintain challenge.

#### 3.3.2 Enemy Health Scaling

Base enemy health per type is managed by the Enemy System. Effective health scales per player count:

| Player Count | Enemy Health Multiplier |
|--------------|------------------------|
| 1            | 0.9x                   |
| 2            | 1.0x                   |
| 3            | 1.15x                  |
| 4            | 1.3x                   |

**Rationale**: Solo players kill enemies faster to maintain engagement rhythm. Higher player counts see tougher enemies to reward coordinated damage strategies.

---

### 3.4 Solo Bonus (XP Reward Adjustment)

Solo players receive a flat XP bonus on extraction to offset the difficulty reduction and lack of co-op utility triggers (e.g., bonus XP from shared kills or successful tool chains). This bonus is applied once, at extraction, and is NOT multiplied by Objective System trigger bonuses.

**Solo Bonus Amount**: SOLO_BONUS_XP (tuning knob; baseline 20% of average level XP reward)

**When Applied**: Only when `player_count == 1` and the player successfully extracts (dies or quits = no bonus).

**Example**: If a solo run earns 100 XP from objectives, the extraction adds +SOLO_BONUS_XP flat (not a percentage of 100; a fixed amount defined at development time).

---

### 3.5 Physics Tool Mechanics

Physics tool power, range, radius, and cooldown **do not scale** with player count. A gravity flip has the same radius whether the player is alone or in a 4-player squad. This ensures:
- Tool mastery is learned once and applies everywhere
- No relearning tool mechanics per player count
- Co-op challenge comes from enemy density and objectives, not tool nerfs

---

### 3.6 Scaling Application Order

When a level is spawned:
1. Determine `player_count` from session state
2. Calculate `difficulty_multiplier` from lookup table (§3.1)
3. Calculate `enemy_count_multiplier` from lookup table (§3.3.1)
4. Calculate `enemy_health_multiplier` from lookup table (§3.3.2)
5. Query Level System for base enemy count and health
6. Multiply: `spawned_enemy_count = base_count * enemy_count_multiplier`
7. Multiply: `spawned_enemy_health = base_health * enemy_health_multiplier`
8. Set escalation timer speed: `escalation_speed = normal_speed * difficulty_multiplier`
9. Query Objective System for available objectives and apply `max_secondary_objectives` cap

---

## 4. Formulas

### 4.1 Effective Escalation Time Per Level

**Formula**:
```
effective_time_seconds = base_level_duration_seconds / difficulty_multiplier
```

**Variables**:
- `base_level_duration_seconds` = default time per level when 2 players (nominally 120 seconds; tunable)
- `difficulty_multiplier` = from §3.1 lookup table

**Example Calculations**:
- 1 player: `120 / 0.8 = 150 seconds` (25% more time)
- 2 players: `120 / 1.0 = 120 seconds` (baseline)
- 3 players: `120 / 1.15 ≈ 104 seconds` (13% less time)
- 4 players: `120 / 1.3 ≈ 92 seconds` (23% less time)

---

### 4.2 Spawned Enemy Count

**Formula**:
```
spawned_enemy_count = level_base_count * enemy_count_multiplier
```

**Variables**:
- `level_base_count` = designed enemy count at 2 players (varies per level)
- `enemy_count_multiplier` = from §3.3.1 lookup table

**Example Calculations** (assuming level designed for 2 players with 8 base enemies):
- 1 player: `8 * 0.8 = 6.4 → 6 enemies` (round down)
- 2 players: `8 * 1.0 = 8 enemies`
- 3 players: `8 * 1.2 = 9.6 → 10 enemies` (round up)
- 4 players: `8 * 1.4 = 11.2 → 11 enemies` (round up)

**Rounding Rule**: Round to nearest integer; if exactly 0.5, round up (ensures 1-player minimum of ≥1 enemy per type).

---

### 4.3 Spawned Enemy Health

**Formula**:
```
spawned_enemy_health = enemy_base_health * enemy_health_multiplier
```

**Variables**:
- `enemy_base_health` = designed HP for enemy type at 2 players (managed by Enemy System)
- `enemy_health_multiplier` = from §3.3.2 lookup table

**Example Calculations** (assuming base enemy health of 100 HP):
- 1 player: `100 * 0.9 = 90 HP`
- 2 players: `100 * 1.0 = 100 HP`
- 3 players: `100 * 1.15 = 115 HP`
- 4 players: `100 * 1.3 = 130 HP`

---

### 4.4 Total XP Reward (with Solo Bonus)

**Formula**:
```
total_xp = base_xp + objective_trigger_xp + (SOLO_BONUS_XP if player_count == 1 else 0)
```

**Variables**:
- `base_xp` = extraction reward (constant per run completion, independent of difficulty)
- `objective_trigger_xp` = bonus XP from completed objectives (managed by Objective System GDD)
- `SOLO_BONUS_XP` = flat bonus for solo runs (tuning knob; e.g., 20% of typical level XP)

**Note**: Solo bonus is added *after* objective triggers, not multiplied by them. This ensures solo players always get the intended bonus regardless of objective completion.

**Example Calculation** (base 50 XP, +30 XP from objectives, SOLO_BONUS_XP = 20):
- 1 player: `50 + 30 + 20 = 100 XP`
- 2 players: `50 + 30 + 0 = 80 XP`
- 3 players: `50 + 30 + 0 = 80 XP`
- 4 players: `50 + 30 + 0 = 80 XP`

---

## 5. Edge Cases

### 5.1 Rounding Fractional Enemies

**Situation**: Enemy count multiplier produces a non-integer (e.g., 8 * 0.8 = 6.4).

**Resolution**: Round to nearest integer. If exactly 0.5, round up. Minimum spawned count is always ≥1 per enemy type to ensure a level is never empty.

**Example**: 1 player, base 6 enemies, 0.8 multiplier = 4.8 → round to 5 enemies.

---

### 5.2 Zero Secondary Objectives at 1 Player

**Situation**: Solo player reaches a level with secondary objectives designed in.

**Resolution**: Secondary objectives are not generated or offered. The level presents only mandatory primary objectives. This is intentional: solo players have fewer tool synergies to leverage, so fewer objectives reduces decision fatigue.

---

### 5.3 Player Joins Mid-Run (Co-op Transition)

**Situation**: A player joins a solo session in progress, changing player count mid-run.

**Resolution**: Player count and scaling multipliers are snapshot at level spawn. Mid-level joins do not retroactively rescale enemies or escalation speed for that level. On the next level spawn, the new player count is used. This prevents unfair enemy health/count adjustments mid-combat.

**Implementation**: If the design permits dynamic join, record `player_count_at_spawn` per level and apply all multipliers using that value, not the current session count.

---

### 5.4 Player Leaves Mid-Run (Co-op Regression)

**Situation**: A player disconnects or quits during a co-op session, reducing player count mid-run.

**Resolution**: Remaining players continue with the current level's unchanged scaling (snapshot at spawn). On the next level, scaling recalculates for the reduced player count. This prevents "punishing" remaining players by suddenly making enemies harder.

---

### 5.5 Solo Bonus on Non-Extraction (Death/Quit Without Extraction)

**Situation**: Solo player dies or quits the run without extracting (e.g., failed run).

**Resolution**: Solo bonus is NOT applied. The bonus is an extraction reward, not a per-level bonus. Only players who successfully extract (reach the exit) receive the bonus.

---

### 5.6 Four-Player Objective Cap Clarity

**Situation**: A 4-player team runs a level; the Objective System has 3 secondary objectives available.

**Resolution**: The cap is 2. Only the first 2 secondary objectives (by priority or random selection, as defined by Objective System GDD) are offered. The third is greyed out or not spawned.

---

### 5.7 Negative Health Due to Scaling

**Situation**: Enemy base health is very low; multiplier rounds to <1 HP.

**Resolution**: Minimum enemy health is always ≥1 HP. If `enemy_base_health * multiplier < 1`, clamp to 1.

---

### 5.8 Escalation Timer Edge Cases

**Situation**: Level duration or difficulty multiplier is set to invalid values (0, negative, NaN).

**Resolution**: Validate at level load:
- `difficulty_multiplier` must be in range [0.5, 2.0]. Default to 1.0 if out of range.
- `base_level_duration` must be >0. Default to 120 seconds if invalid.
- Log a warning if defaults are used (indicates config error).

---

## 6. Dependencies

### 6.1 Hard Dependencies (Blocking)

1. **Godot 4.6.1 Session Management**: This system requires reliable `player_count` from the session/multiplayer manager. Must be available before level spawn.
2. **Level System**: Requires base enemy count and health values per level and enemy type. Must provide these values at level load.
3. **Objective System GDD**: Defines objective structure, triggers, and XP bonuses. Scaling applies the secondary objective cap and reads objective XP.
4. **Enemy System**: Manages enemy types, base health, and spawning. Scaling applies multipliers to health and count at spawn time.
5. **Escalation System**: Manages timer speed; Scaling System provides the `difficulty_multiplier` to apply.

### 6.2 Soft Dependencies (Consulted)

1. **Progression/MetaGame System**: May query solo bonus constants (SOLO_BONUS_XP) to balance long-term progression curves.
2. **UI/HUD System**: Displays current player count and may show difficulty/scaling indicators (informational, not mechanically required).
3. **Networking/Multiplayer System**: Provides player join/leave events for snapshot-at-spawn logic. See §5.3–5.4.

### 6.3 Integration Points

- **When**: Level spawn
- **What**: Query Level System for base counts/health; apply multipliers; set escalation speed; cap objectives
- **How**: Scaling System is called by Level Manager during level initialization
- **Where**: `src/gameplay/level/LevelManager.gd` (or equivalent) instantiates this system

---

## 7. Tuning Knobs

All tuning knobs must be stored in an external config file (JSON/YAML/GDScript resource) so they can be adjusted without code recompilation. Place in `assets/config/scaling_system_config.json` or similar.

### 7.1 Difficulty Multipliers

```
difficulty_multipliers:
  1_player: 0.8
  2_player: 1.0
  3_player: 1.15
  4_player: 1.3
```

**Tuning Guidance**: Lower 1-player value (e.g., 0.7) makes solo more forgiving; higher 4-player value (e.g., 1.5) makes large groups harder.

---

### 7.2 Enemy Count Multipliers

```
enemy_count_multipliers:
  1_player: 0.8
  2_player: 1.0
  3_player: 1.2
  4_player: 1.4
```

**Tuning Guidance**: Adjust to control enemy density. Lower values = fewer enemies for solo; higher values = more chaos for groups.

---

### 7.3 Enemy Health Multipliers

```
enemy_health_multipliers:
  1_player: 0.9
  2_player: 1.0
  3_player: 1.15
  4_player: 1.3
```

**Tuning Guidance**: Lower values = softer enemies for solo; higher values = tougher enemies that reward coordinated damage.

---

### 7.4 Solo Bonus XP

```
solo_bonus_xp: 20
```

**Expected Range**: 10–50 XP (adjust based on typical level rewards during balance testing).

**Tuning Guidance**: Playtest to ensure solo players don't earn significantly more XP than co-op (which would incentivize solo play). Aim for solo and co-op to converge after ~5 levels (diminishing returns on absolute bonus).

---

### 7.5 Base Level Duration

```
base_level_duration_seconds: 120
```

**Expected Range**: 60–180 seconds (varies per game feel; faster escalation = tenser gameplay).

**Tuning Guidance**: Test during vertical slice. If 1-player feels too leisurely, lower base duration and adjust 1-player multiplier downward. If 4-player feels overwhelming, lower 4-player multiplier.

---

### 7.6 Secondary Objectives Cap

```
secondary_objectives_max: 2
```

**Expected Range**: 1–3 (balance between tool synergy and decision paralysis).

**Tuning Guidance**: Start at 2. If 4-player groups ignore 1 objective consistently, lower to 2. If groups report boredom, raise to 3 (very high-level tool combos).

---

## 8. Acceptance Criteria

All criteria must be verifiable by QA. Each criterion includes a test case and pass condition.

### 8.1 Escalation Speed Scales Correctly

**Test Case**:
1. Load a level with 2-minute base duration
2. Spawn the same level with 1 player, 2 players, 3 players, 4 players separately
3. Measure actual escalation timer speed for each

**Pass Condition**:
- 1-player level: escalation_speed ≈ 0.8 (timer runs at 80% speed; 150 actual seconds)
- 2-player level: escalation_speed = 1.0 (timer runs at normal speed; 120 actual seconds)
- 3-player level: escalation_speed ≈ 1.15 (timer runs at 115% speed; ≈104 actual seconds)
- 4-player level: escalation_speed ≈ 1.3 (timer runs at 130% speed; ≈92 actual seconds)

Timing tolerance: ±2 seconds (allows for physics frame variance).

---

### 8.2 Enemy Count Scales Correctly

**Test Case**:
1. Configure a level with 10 base enemies (at 2-player scaling)
2. Spawn the level with 1 player, 2 players, 3 players, 4 players
3. Count actual spawned enemies each run

**Pass Condition**:
- 1-player: 8 enemies (10 * 0.8)
- 2-player: 10 enemies (10 * 1.0)
- 3-player: 12 enemies (10 * 1.2)
- 4-player: 14 enemies (10 * 1.4)

Rounding tolerance: ±1 enemy (due to integer rounding).

---

### 8.3 Enemy Health Scales Correctly

**Test Case**:
1. Spawn an enemy with 100 base HP (at 2-player scaling)
2. Measure its actual health in 1-player, 2-player, 3-player, 4-player sessions
3. Verify health doesn't change mid-combat

**Pass Condition**:
- 1-player: enemy has ≈90 HP (100 * 0.9)
- 2-player: enemy has 100 HP (100 * 1.0)
- 3-player: enemy has ≈115 HP (100 * 1.15)
- 4-player: enemy has ≈130 HP (100 * 1.3)

Tolerance: ±1 HP (due to floating-point arithmetic).

---

### 8.4 Secondary Objectives Cap Enforces Max of 2

**Test Case**:
1. Create a level with 4 secondary objectives available
2. Spawn the level with 1 player, 2 players, 3 players, 4 players
3. Count available secondary objectives shown to player(s)

**Pass Condition**:
- 1-player: 0 secondary objectives (solo gets none)
- 2-player: 1 secondary objective
- 3-player: 2 secondary objectives
- 4-player: 2 secondary objectives (capped)

---

### 8.5 Solo Bonus Applied Only on Successful Extraction

**Test Case**:
1. Play a solo run and extract successfully
2. Play a solo run and die without extracting
3. Play a solo run and quit without extracting
4. Measure XP earned in each case

**Pass Condition**:
- Successful extraction: total_xp = base_xp + objective_xp + SOLO_BONUS_XP
- Death/quit (no extraction): total_xp = base_xp + objective_xp (no bonus)

SOLO_BONUS_XP must be visually distinct in UI (e.g., gold text, "+Bonus" label).

---

### 8.6 Solo Bonus Not Applied in Co-op

**Test Case**:
1. Play a 2-player, 3-player, and 4-player run with same objectives completed
2. Measure XP for each player in each session

**Pass Condition**:
- All players earn base_xp + objective_xp (no solo bonus, regardless of session size)
- No bonus appears in UI for any player

---

### 8.7 Physics Tool Mechanics Unchanged Across Modes

**Test Case**:
1. Measure gravity flip radius in 1-player session
2. Measure gravity flip radius in 4-player session
3. Measure tool cooldown, power, and animation in both modes

**Pass Condition**:
- All tool metrics are identical (within floating-point epsilon, ±0.01 units)
- No conditional code branches based on player_count in Physics System

---

### 8.8 Snapshot-at-Spawn (Mid-Run Player Changes)

**Test Case** (requires live co-op join/leave):
1. Start a 2-player level
2. Player 1 joins mid-level
3. Measure enemy count/health midway through level
4. Advance to next level and verify rescaling

**Pass Condition**:
- Mid-level join: enemies already spawned do not change health/count
- Next level spawn: player count is now 3, enemies spawn with 3-player multipliers

---

### 8.9 Config Validation and Default Fallback

**Test Case**:
1. Set `difficulty_multiplier` to invalid values (0, -1, null, NaN, 10)
2. Set `base_level_duration` to invalid values (0, -60, NaN)
3. Attempt to spawn a level

**Pass Condition**:
- Invalid values are replaced with safe defaults (multiplier: 1.0, duration: 120 seconds)
- Console logs a warning per invalid value
- Level spawns and is playable (does not crash)

---

### 8.10 Load-Test: 100 Consecutive Levels (All Player Counts)

**Test Case**:
1. Run a session simulating 25 levels at each player count (1, 2, 3, 4)
2. Monitor for memory leaks, timer accumulation, and state corruption

**Pass Condition**:
- All 100 levels spawn correctly
- Multipliers are applied consistently across all levels
- No memory growth >5% from first to last level
- No rounding errors accumulate (enemy counts remain consistent)

---

## Appendix: Example Full-Run Walkthrough

**Scenario**: 3-player co-op session, Level 2, base 12 enemies, 100 HP each, 180 second base duration, 60 XP base reward.

**Calculations**:
1. `player_count = 3`
2. `difficulty_multiplier = 1.15` (from §3.1)
3. `enemy_count_multiplier = 1.2` (from §3.3.1)
4. `enemy_health_multiplier = 1.15` (from §3.3.2)
5. Effective time: `180 / 1.15 ≈ 156 seconds`
6. Spawned enemies: `12 * 1.2 = 14.4 → 14 enemies`
7. Enemy health: `100 * 1.15 = 115 HP`
8. Secondary objectives: cap 2 (available)
9. XP reward (if 2 objectives completed, each 30 XP): `60 + 60 + 0 = 120 XP` (no solo bonus)

**Player Experience**: The team has ~156 seconds to complete objectives, faces 14 enemies at 115 HP each, and earns 120 XP if successful. Difficulty is notably harder than 2-player (+15% escalation, +20% enemy count, +15% health) but still engaging.

---

**End of Document**
