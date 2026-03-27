# Sprint 5 — 2026-03-28 to 2026-04-10

## Sprint Goal

Implement the Physics Tool System in production: BaseTool architecture, all three
tools (Gravity Flip, Force Push, Time Slow) wired into the existing CharacterController
and mission loop. The MVP milestone exit criteria "all 3 physics tools work in the
production codebase" is met by end of sprint.

## Capacity

- Team: 1 person
- Total days: 10 working days × 1 person = 10 person-days
- Buffer (20%): 2 days
- Available: **8 person-days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-01 | Implement: PhysicsObject script | Solo dev | 0.5 | Physics Interaction Layer GDD | `scripts/tools/physics_object.gd` — `is_gravity_flipped`, `original_gravity_scale`, `wake()`, `set_time_scale()` API; attach to RigidBody3D layer 2 |
| S5-02 | Implement: BaseTool base class | Solo dev | 0.5 | S5-01 | `scripts/tools/base_tool.gd` — `activate()`, `deactivate()`, `is_active`, signals: `tool_activated`, `tool_deactivated`, `tool_failed` |
| S5-03 | Implement: GravityFlipTool | Solo dev | 1.0 | S5-02 | Toggle single object gravity via PhysicsObject API; one object per player at a time; `tool_activated` signal fires with target |
| S5-04 | Implement: ForcePushTool | Solo dev | 1.0 | S5-02 | Instantaneous impulse via PhysicsObject; tuned to 8–12N (not 18N prototype); `tool_activated` signal fires |
| S5-05 | Implement: TimeSlowTool | Solo dev | 1.5 | S5-02 | Sphere overlap detection; `wake()` all bodies before slowing; per-body gravity+drag scaling (not velocity snapshot); `tool_activated` / `tool_deactivated` signals |
| S5-06 | Implement: ToolManager + wire to CharacterController | Solo dev | 1.0 | S5-03, S5-04, S5-05 | `ToolManager` node routes `tool_gravity`/`tool_push`/`tool_slow` input actions to correct tool via `CharacterController.get_aim_ray()`; all three tools activatable in the running game |
| S5-07 | Build ramp test scene + validate Time Slow | Solo dev | 0.5 | S5-05 | Test room with ramp-dropped objects; Time Slow visibly slows moving RigidBody3Ds; R-07 risk resolved |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-08 | Implement: Health & Death System | Solo dev | 1.0 | Health & Death System GDD | `health_component.gd` with `take_damage()`, `heal()`, `died` signal; attached to CharacterController; respawn scaffolding stubbed |
| S5-09 | Reverse-document physics-tools prototype | Solo dev | 0.5 | REPORT.md | `prototypes/physics-tools/CONCEPT.md` written; startup doc gap warning resolved |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-10 | Performance baseline: 10+ physics objects at 60fps | Solo dev | 0.5 | S5-06 | Godot profiler screenshot logged; milestone exit criterion validated; frame time noted in session state |
| S5-11 | Write GDD: Networking Layer | Solo dev | 0.5 | Solo/Co-op Scaling GDD | All 8 sections; last MVP design gap |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| Physics-tools prototype documentation | Not blocked — skipped, flagged at startup | 0.5 days (S5-09) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Time Slow rearchitecture (wake + drag scaling) is harder than estimated | MEDIUM | HIGH | Timebox S5-05 at 1.5 days; if blocked, ship a clearly-flagged stub and retest in Sprint 6 with moving objects |
| Jolt Physics API differences from GDScript docs (knowledge gap) | MEDIUM | MEDIUM | Cross-reference `docs/engine-reference/godot/` before any physics API call; use WebSearch on blockers |
| PhysicsObject API contract too rigid, tools need to break it | LOW | MEDIUM | Tools may call `wake()` + `apply_central_impulse()` via cast to RigidBody3D if PhysicsObject API proves insufficient — log as tech debt |

## Dependencies on External Factors

- Godot 4.6.1 Jolt Physics behavior — cross-reference VERSION.md before physics API usage

## Definition of Done for Sprint 5

- [ ] S5-01 through S5-06 (all Must Haves) complete
- [ ] All three tools activatable in the running game via keyboard
- [ ] Time Slow visibly works on moving objects (ramp test — R-07 resolved)
- [ ] `systems-index.md` updated: Physics Tool System → Implementation Complete
- [ ] Prototype documentation gap resolved (S5-09)
- [ ] No regressions: mission loop (terminal → escalation → extraction) still closes

## Completed Tasks

| ID | Task | Completed | Notes |
|----|------|-----------|-------|
| S5-01 | Implement: PhysicsObject script | 2026-03-27 | `src/scripts/core/physics_object.gd` — full API: flip_gravity, restore_gravity, apply_time_slow, remove_time_slow, apply_push, physics_state_changed signal |
| S5-02 | Implement: BaseTool base class | 2026-03-27 | `src/scripts/tools/base_tool.gd` — activate(), deactivate(), is_active, tool_activated/deactivated/failed signals, get_physics_object() helper |
| S5-03 | Implement: GravityFlipTool | 2026-03-27 | `src/scripts/tools/gravity_flip_tool.gd` — toggle single object, one flip per player, auto-restores previous on re-target |
| S5-04 | Implement: ForcePushTool | 2026-03-27 | `src/scripts/tools/force_push_tool.gd` — 12N default (down from 18N prototype), collision normal push direction |
| S5-05 | Implement: TimeSlowTool | 2026-03-27 | `src/scripts/tools/time_slow_tool.gd` — gravity/damp scaling (Jolt-safe), wakes sleeping bodies, sphere overlap query layer 2 |
| S5-06 | Implement: ToolManager + wire to CharacterController | 2026-03-27 | `src/scripts/tools/tool_manager.gd` + `src/scenes/gameplay/Player.tscn` — all 3 tools wired, input actions registered in project.godot |
| S5-07 | Build ramp test scene + validate Time Slow | 2026-03-27 | `src/scenes/gameplay/RampTestRoom.tscn` + `src/scripts/gameplay/ramp_test_room.gd` — 5 boxes + 2 spheres on 31° ramp; open in Godot to validate |
| S5-08 | Implement: Health & Death System | 2026-03-27 | `src/scripts/core/health_component.gd` — take_damage, heal, kill, died signal, fall damage via CharacterController.landed; wired in Player.tscn |
| S5-09 | Reverse-document physics-tools prototype | 2026-03-27 | `prototypes/physics-tools/CONCEPT.md` written; startup doc gap resolved |
