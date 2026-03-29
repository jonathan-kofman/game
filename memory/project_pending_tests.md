---
name: Pending manual tests and deferred tasks
description: Items implemented but not yet manually tested — read this before any attended game session
type: project
---

## Must do in next attended game session (F5 open)

These block milestone-01 closure and sprint-08 DoD:

1. **Full game loop run** (S8-01 / S6-01 carryover)
   - F5 → move → all 3 tools → terminal → escalation → extraction → debrief shown
   - Confirms milestone-01 criteria 5 (extraction+debrief) and 7 (no S1 bugs)
   - File to update: `production/milestones/milestone-01-mvp.md`

2. **Profiler run** (S6-03 carryover)
   - Open Godot profiler tab during same run as above
   - Record fps with 10+ physics objects active
   - File to update: `docs/performance/baseline-sprint-05.md`
   - Confirms milestone-01 criterion 6 (60fps)

3. **Verify bug fixes from 2026-03-28** (4 fixes applied, not yet confirmed clean)
   - `main.gd`: zone.global_position after add_child
   - `objective_manager.gd`: terminal.global_position after add_child + MeshInstance3D name
   - `camera_controller.gd`: tool_activated signal arg count fixed (3→2)
   - Expected: zero errors in output on F5 run

4. **PatrolGuard + hazards live test** (S8-02/S8-03/S8-06/S8-07 — all now wired)
   - Guards are placed via ProceduralGenerator reading GuardWaypoint markers
   - medium_lab_01 has 3 GuardWaypoints + AlarmLaser_01
   - medium_storage_01 has 2 GuardWaypoints + PressurePlate_01
   - Verify: patrol (grey) → alert (yellow) → pursue (red) → stun (dark blue) via each tool
   - Verify: walking through AlarmLaser beam triggers orange flash + escalation pressure
   - Verify: standing on PressurePlate 3s → TRIPPED (red) + alarm fires
   - Verify: physics object on PressurePlate prevents alarm while it rests there

5. **Time Slow retest on resting bodies** (S8-10 / S7-09 carryover, 3× carried)
   - Press T near resting physics objects on floor
   - Confirm they visibly slow (Jolt sleep-wake path)
   - File to update: `docs/performance/baseline-sprint-05.md`

**Why:** User couldn't run the game during the 2026-03-28/29 session. All code is correct
but unverified. First attended session should run all items above before adding more code.
