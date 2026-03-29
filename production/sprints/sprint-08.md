# Sprint 8 — 2026-05-07 to 2026-05-20

## Sprint Goal

Implement the Patrol Guard enemy and Alarm Laser hazard — bringing active
opposition into the facility and wiring all three physics tools to meaningful
enemy interactions.

## Capacity

- Team: 1 person
- Total days: 10 working days
- Buffer (20%): 2 days reserved for unplanned work
- Available: **8 person-days**

## Context: Entering Sprint 8

Sprint 7 closed all design work for VS Phase. Sprint 8 is the first
implementation sprint of the Vertical Slice. GDDs for Enemy & Hazard, Audio,
and Camera are all complete. Camera (headbob, shake, FOV) is already
implemented from Sprint 7. This sprint focuses on the enemy/hazard layer; audio
implementation follows in Sprint 9.

Milestone-01 (MVP) is 4/7 criteria confirmed. The remaining 3 (manual run,
profiler, S1 clean path) require an attended session — S8-01 captures this.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S8-01 | Full playtest + profiler run (attended session) | Solo dev | 0.5 | User at keyboard | F5 → move → all 3 tools → terminal → escalation → extraction → debrief shown; no script errors; Godot profiler open — 60fps result recorded in `docs/performance/baseline-sprint-05.md`; milestone-01-mvp.md criteria 5–7 ticked |
| S8-02 | Implement PatrolGuard — core patrol state machine | gameplay-programmer | 2.5 | enemy-hazard-system.md §3.2 | `src/scripts/ai/patrol_guard.gd` exists; PATROL → ALERT → PURSUE → STUNNED states implemented; waypoint patrol cycles at GUARD_PATROL_SPEED; detection gate (proximity sphere + LOS raycast) triggers ALERT; visual state colours (grey/yellow/red/dark-blue) on capsule placeholder; signals: `guard_alerted`, `guard_lost_player`, `guard_stunned` wired to EscalationManager |
| S8-03 | Physics tool × PatrolGuard interactions | gameplay-programmer | 0.5 | S8-02, Physics Tool System | GravityFlip: `up_direction = DOWN` + STUNNED for 5 s; ForcePush: velocity kick → STUNNED with friction decel; TimeSlow: guard moves at 15% speed while tool active; all three interactions logged in console and confirmed in play |
| S8-04 | Implement AlarmLaser | gameplay-programmer | 1.0 | enemy-hazard-system.md §3.3 | `src/scripts/gameplay/alarm_laser.gd` exists; TriggerVolume 15% larger than visual; player entry fires `laser_triggered` → EscalationManager +60 pressure; ARMED_TRIGGERED flash state for LASER_ALARM_DURATION; `src/scenes/gameplay/AlarmLaser.tscn` created with placeholder visual |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S8-05 | Implement PressurePlate | gameplay-programmer | 0.5 | enemy-hazard-system.md §3.4 | `src/scripts/gameplay/pressure_plate.gd` exists; player entry → ACTIVE state; held for PLATE_HOLD_ALARM_TIME (3 s) → TRIPPED → `plate_alarm_triggered` → +60 pressure; physics object can hold plate depressed (preventing trip); `src/scenes/gameplay/PressurePlate.tscn` created |
| S8-06 | Add guard and hazard spawn markers to room scenes | godot-specialist | 0.5 | S8-02, S8-04 | At least 2 room .tscn files updated with `SpawnPoints/GuardWaypoint_N` and `SpawnPoints/AlarmLaser_01` Marker3D nodes; spawn point naming convention documented in room_template.gd doc comment |
| S8-07 | Extend ProceduralGenerator to place guards and hazards | godot-gdscript-specialist | 1.0 | S8-06, enemy-hazard-system.md §3.1 | `procedural_generator.gd` reads `guard_waypoint` and `hazard` spawn points from placed room templates; instantiates PatrolGuard and AlarmLaser/PressurePlate nodes at those positions; `[Main] guards=N hazards=N` printed at startup |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| ~~S8-08~~ | ~~AudioManager stub + bus layout~~ | ~~godot-gdscript-specialist~~ | 0.5 | — | DONE — `src/scripts/core/audio_manager.gd` autoload; 5-bus layout (Master > Music / SFX / UI / Voice); registered in project.godot |
| ~~S8-09~~ | ~~Unit tests: PatrolGuard state machine~~ | ~~godot-gdscript-specialist~~ | 0.5 | — | DONE — `src/tests/unit/ai/test_patrol_guard.gd`; 18 tests covering stun entry/refresh/signals, time slow toggle, setup wiring |
| S8-10 | Time Slow retest + close S7-09 | Solo dev | 0.5 | S8-01 (attended session) | Time Slow visibly slows physics objects that were resting on floor; Jolt sleep-wake path confirmed; result noted in `docs/performance/baseline-sprint-05.md`; S7-09 closed |

---

## Carryover from Sprint 7

| Task | Reason | New Estimate |
|------|--------|-------------|
| S7-09 Time Slow retest | Requires manual game run | S8-10 (Nice to Have) — combine with S8-01 attended session |
| S6-01 Full playtest | Requires manual game run | S8-01 (Must Have) — opening task of first attended session |
| S6-03 Performance baseline (actual numbers) | Requires manual profiler | S8-01 (Must Have) — same session as playtest |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| NavigationAgent3D requires baked NavigationMesh; runtime baking of procedural rooms is non-trivial | HIGH | MEDIUM | Use direct-to-player vector for PURSUE in VS (no nav mesh); waypoint patrol uses Array[Vector3] directly. Full nav mesh is post-VS scope. Flag in guard script with `# TODO: replace with NavigationAgent3D post-VS` |
| PatrolGuard state machine interaction with Jolt physics (stun + gravity flip) degrades 60fps | MEDIUM | HIGH | Cap guard count at 2 per run for Sprint 8; profile before raising cap (R-08) |
| Procedural generator placing guards in unreachable positions | MEDIUM | MEDIUM | Spawn guards at floor-level Marker3D nodes inside room scenes (not at connector positions); rooms hand-authored with safe guard positions |
| S8-01 manual run blocked again (user unavailable) | MEDIUM | LOW | S8-02 through S8-04 proceed independently; S8-01 carries again as Must Have |

---

## Dependencies on External Factors

- **S8-01**: Requires user at keyboard in Godot editor — cannot be automated
- **S8-10**: Same attended session as S8-01
- **NavigationMesh**: Explicitly deferred — PURSUE mode uses direct vector for this sprint (see Risks)

---

## Definition of Done for Sprint 8

- [ ] S8-01 through S8-04 (all Must Haves) complete
- [ ] PatrolGuard patrols between waypoints and transitions through all 4 states
- [ ] All 3 physics tools interact with guards per GDD §3.6
- [ ] AlarmLaser triggers escalation on player entry
- [ ] milestone-01-mvp.md: all 7 exit criteria checked (requires S8-01)
- [ ] `docs/performance/baseline-sprint-05.md` has actual profiler numbers
- [ ] No S1 bugs introduced by guard/hazard code
- [ ] Sprint 8 retrospective written
