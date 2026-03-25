# Sprint 2 — 2026-04-08 to 2026-04-21

## Sprint Goal

All three physics tools work in the production codebase. A player can open the
game, walk around a room full of physics objects, and use Gravity Flip, Time Slow,
and Force Push — including combos. The Physics Interaction Layer contract is
enforced: no tool touches RigidBody3D properties directly.

## Capacity

- Team: 1–2 people
- Total days: 10 working days × 1 person = 10 person-days
- Buffer (20%): 2 days
- Available: **8 person-days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-01 | Implement: PhysicsObject base script | Solo dev | 0.5 | S1-06 GDD | `physics_object.gd` exists; exposes `original_gravity_scale`, `is_gravity_flipped`, `is_time_slowed`; emits `physics_state_changed` |
| S2-02 | Implement: BaseTool + ToolManager | Solo dev | 1.0 | S1-08 GDD | `base_tool.gd` with activate/deactivate/is_active/signals; `tool_manager.gd` routes input actions to correct tool child |
| S2-03 | Implement: GravityFlipTool | Solo dev | 0.5 | S2-01, S2-02 | G key flips gravity on targeted RigidBody3D; pressing again restores; only 1 flipped object per player |
| S2-04 | Implement: TimeSlowTool | Solo dev | 1.0 | S2-01, S2-02 | T key hold slows all physics objects in 6m radius via gravity_scale + linear_damp; sleeping objects wake and slow |
| S2-05 | Implement: ForcePushTool | Solo dev | 0.5 | S2-01, S2-02 | F key applies 12N impulse on targeted RigidBody3D; direction from collision normal |
| S2-06 | Wire ToolManager into Player scene | Solo dev | 0.5 | S2-02, S2-03, S2-04, S2-05 | Player.tscn has ToolManager node with 3 tool children; tools activate in-game |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-07 | Add physics objects to test room | Solo dev | 0.5 | S2-06 | 10+ RigidBody3D objects (boxes and spheres) in main.gd test room; all have PhysicsObject script + layer 2 |
| S2-08 | Write GDD: Health & Death System | Solo dev | 0.5 | S1-03 | All 8 sections; HP pool, damage sources, death trigger, respawn hook |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-09 | Write GDD: Procedural Generation System | Solo dev | 1.0 | S1-07 | All 8 sections; assembly algorithm, connector matching, room count, seed system |

## Carryover from Sprint 1

- Character controller playtest verification (manual — open Godot, press F5, verify WASD/mouse/jump)

## Risks This Sprint

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Time Slow still broken on sleeping objects | MEDIUM | HIGH | New approach (gravity_scale + linear_damp) was designed to fix this; verify with resting objects first |
| Tool combo edge cases (gravity + time slow simultaneously) | MEDIUM | LOW | PhysicsObject flags track both independently; acceptable edge case behavior documented in GDD |

## Definition of Done for Sprint 2

- [x] S2-01 through S2-07 (all Must Have + Should Have) complete
- [ ] Time Slow works on a resting object (the key prototype failure is fixed) — *verify in Godot*
- [ ] All 3 tools + at least 1 combo verified manually in Godot — *verify in Godot*
- [x] No tool reads `gravity_scale` or `linear_velocity` directly (all access via PhysicsObject API)
- [x] `design/gdd/systems-index.md` progress tracker updated
- [x] S2-08 GDD Health & Death System complete
- [x] S2-09 GDD Procedural Generation System complete

## Completion Notes

All implementation tasks complete. 10 physics objects (7 boxes, 3 spheres) in test room.
PhysicsObject script + PhysicsObject-based collision setup on all objects.
ToolManager wired into Player.tscn with 3 tool children.
Two GDDs written (Health & Death, Procedural Generation) — 7/16 MVP systems now designed.

Outstanding: Manual Godot playtest to verify time slow fixes prototype failure (sleeping body wakeup).
