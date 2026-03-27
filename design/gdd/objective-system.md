# Objective System GDD
**Version**: 1.0
**Status**: Draft
**Sprint**: S3-08
**Created**: 2026-03-25

---

## 1. Overview

The Objective System defines what players must accomplish during a breach mission.
Each run procedurally selects a primary objective and 0–2 secondary objectives from
a catalogue. Objectives are tracked per-room and per-player, emit completion signals
the Escalation and Extraction systems consume, and support both solo play and co-op
credit sharing. Objectives are the central measure of mission success — extraction
without completing the primary objective yields a failed run.

---

## 2. Player Fantasy

The player enters a facility with a clear goal — "destroy the power core", "rescue
the scientist", "upload the data" — and must navigate a dangerous, unknown layout to
reach it. Secondary objectives reward exploration and skill without being mandatory.
Completing objectives under escalating pressure creates the tension arc of each run.
In co-op, multiple players can split objectives, making teamwork feel meaningful.

---

## 3. Detailed Rules

### 3.1 Objective Types

| Type | Description | Completion Trigger |
|------|-------------|-------------------|
| **Destroy** | Find and destroy a specific PhysicsObject (e.g., power core) | PhysicsObject.died signal OR HP ≤ 0 |
| **Retrieve** | Pick up an item and carry it to the extraction zone | Item enters ExtractionZone Area3D |
| **Eliminate** | Defeat N enemies of a given type | N-th enemy.died signal fires |
| **Activate** | Interact with N terminals/switches | N-th interaction signal fires |
| **Survive** | Stay alive for T seconds in a marked zone | Timer expires while player is in zone |

### 3.2 Objective Selection

- The ProceduralGenerator tags one room as "objective_room" based on room type.
- At facility generation, ObjectiveManager picks one **primary** objective type from
  the mission's allowed pool (configured per mission in MissionConfig resource).
- 0–2 secondary objectives are drawn from the remaining pool; no duplicates.
- Objectives are seeded with the facility seed for determinism.

### 3.3 Co-op Credit

- Any player can contribute to shared objectives (Destroy, Eliminate, Activate,
  Survive-in-zone).
- Retrieve objectives are player-locked: the player who picks up the item owns it.
  A dead carrier drops the item; any teammate can pick it up to continue.
- XP/reward credit is split equally among all alive players at completion, with a
  bonus share to the player who triggered the final completion event.

### 3.4 Failure Conditions

- Primary objective fails if all players are dead simultaneously (run ends).
- "Survive" objectives fail if the player(s) leave the zone for > SURVIVE_GRACE_PERIOD
  seconds (3.0 s default).
- Retrieve objectives do not fail if the carrier dies — item drops and can be
  recovered.

### 3.5 Objective State Machine

```
INACTIVE → ACTIVE → COMPLETE
                  → FAILED (Survive type only, or run ends)
```

### 3.6 Emitted Signals

| Signal | Parameters | When fired |
|--------|------------|------------|
| `objective_state_changed` | `objective_id: String, new_state: String` | On every state transition. `new_state` is one of `"ACTIVE"`, `"COMPLETE"`, `"FAILED"`. |
| `primary_objective_complete` | *(none)* | When the primary objective reaches COMPLETE. |

> **Implementation note**: `new_state` is a plain string (`"ACTIVE"`, `"COMPLETE"`, `"FAILED"`),
> not an ObjectiveData dictionary. HUD and other subscribers receive the string directly.
> Richer data (objective name, progress count) is deferred until a richer UI is needed.

---

## 4. Formulas

### 4.1 Objective Room Selection

```
eligible_rooms = [r for r in facility.rooms if r.room_type in OBJECTIVE_ROOM_TYPES]
objective_room = eligible_rooms[rng.randi() % eligible_rooms.size()]
```

`OBJECTIVE_ROOM_TYPES = ["chamber", "hub"]`

### 4.2 Secondary Objective Count

```
N_secondary = rng.randi() % (MAX_SECONDARY + 1)  # 0 to MAX_SECONDARY inclusive
MAX_SECONDARY = 2
```

### 4.3 Co-op Reward Split

```
base_reward = objective.base_xp
trigger_bonus = base_reward * TRIGGER_BONUS_FRACTION  # 0.25
per_player_share = (base_reward - trigger_bonus) / alive_player_count
trigger_player_share = per_player_share + trigger_bonus
```

Variables: `TRIGGER_BONUS_FRACTION = 0.25`, `alive_player_count ∈ [1, 4]`

Example: base_xp=100, 2 players alive, player A triggers final completion:
- Player A receives: (75 / 2) + 25 = 62.5 → 62 XP
- Player B receives: 75 / 2 = 37.5 → 37 XP

---

## 5. Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Objective room is unreachable (generator dead-ended) | ObjectiveManager logs a warning, picks the closest accessible room instead |
| All objective types disabled in MissionConfig | Primary objective defaults to Activate (1 terminal) |
| Carrier is teleported/killed by gravity flip | Item drops at carrier's last position; Retrieve stays ACTIVE |
| Two players both hit Destroy target on same frame | Both signals fire; ObjectiveManager uses a `completed` guard flag to emit once |
| Player disconnects mid-run (future: networking) | Disconnected player's contribution counts; their in-hand Retrieve item drops |
| Survive zone is occupied by a physics object blocking entry | Zone uses Area3D body_entered — objects do not count, only CharacterBody3D |

---

## 6. Dependencies

| System | Relationship |
|--------|-------------|
| **Procedural Generation System** | Provides facility layout and room tags; ObjectiveManager reads `facility_graph.objective_room_index` |
| **Health & Death System** | `died` signal from PhysicsObject and enemy nodes triggers Destroy/Eliminate completion |
| **Escalation System** | Receives `objective_completed(ObjectiveData)` signal to advance escalation state |
| **Extraction System** | Receives `primary_objective_complete` signal to unlock extraction zone |
| **HUD** | Subscribes to `objective_state_changed` to update objective tracker widget |
| **Player Spawning & Respawn** | On respawn, Retrieve item ownership is resolved (drops if carrier respawned) |

---

## 7. Tuning Knobs

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `MAX_SECONDARY` | 2 | 0–3 | Run depth and reward ceiling |
| `SURVIVE_GRACE_PERIOD` | 3.0 s | 1.0–10.0 s | Survive difficulty — too low is punishing |
| `TRIGGER_BONUS_FRACTION` | 0.25 | 0.0–0.5 | Co-op reward feel; higher rewards decisive action |
| `OBJECTIVE_ROOM_TYPES` | ["chamber", "hub"] | Any room types | Where objectives spawn in the facility |
| `base_xp` per type | Destroy=150, Retrieve=120, Eliminate=100, Activate=80, Survive=60 | 20–500 | Relative value of each objective type |

---

## 8. Acceptance Criteria

| # | Criterion | Test Method |
|---|-----------|-------------|
| AC-01 | Primary objective is always assigned before player spawns | Print objective type in `_ready()` of ObjectiveManager; verify non-null in 10 consecutive runs |
| AC-02 | Same facility seed + MissionConfig produces identical objective | Run twice with seed=12345; compare `objective_type` and `objective_room_index` |
| AC-03 | Completing primary objective emits `primary_objective_complete` signal | Connect signal to print call; verify fires exactly once per run |
| AC-04 | Co-op credit split follows the formula | Unit test: mock 2 players, base_xp=100; assert trigger player receives 62 XP and other receives 37 |
| AC-05 | Retrieve item drops on carrier death and can be recovered | QA: kill carrier holding item; confirm item visible at death position; second player picks up and completes |
| AC-06 | Survive objective fails after leaving zone for > GRACE_PERIOD | QA: enter zone, exit immediately; confirm FAILED state after 3+ seconds outside |
| AC-07 | Secondary objectives are optional — run can extract without them | QA: complete primary only, reach extraction; confirm success state |
