# Sprint 5 — 2026-03-26 to 2026-04-08

## Sprint Goal

All three physics tools exist in the production codebase, Health & Death is
implemented, and the HUD + Mission Debrief UI are wired — completing every
remaining implementation requirement for Milestone 1 MVP.

## Capacity

- Team: 1 person
- Total days: 10 working days
- Buffer (20%): 2 days reserved for unplanned work
- Available: **8 person-days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S5-01 | Implement: BaseTool interface + ToolManager | gameplay-programmer | 1.0 | physics-tool-system.md, CONCEPT.md | `BaseTool` class with `activate()`, `deactivate()`, `can_activate()` interface; `ToolManager` coordinates switching and holds active tool reference; tools load as child nodes |
| S5-02 | Implement: GravityFlip tool (production) | gameplay-programmer | 1.0 | S5-01 | Toggles `gravity_scale` on targeted `RigidBody3D`; restores on second activation; color tint visual indicator on affected objects; audio feedback slot (no audio asset required); works with Jolt |
| S5-03 | Implement: ForcePush tool (production) | gameplay-programmer | 0.5 | S5-01 | `apply_central_impulse` in collision normal direction; impulse configurable (default 10N); VFX placeholder; audio slot |
| S5-04 | Implement: Health & Death System | gameplay-programmer | 1.0 | health-death-system.md | `HealthComponent` node; configurable `max_health`; `take_damage(amount)` method; `health_changed(current, max)` signal; `died` signal; no respawn logic required this sprint |
| S5-05 | Implement: HUD (minimal) | ui-programmer | 1.0 | hud.md, S5-04, escalation_manager.gd | Displays health bar (wired to HealthComponent), escalation level indicator (wired to EscalationManager), objective status text (wired to ObjectiveManager); visible during gameplay |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S5-06 | Time Slow retest (moving objects scenario) | gameplay-programmer | 0.5 | CONCEPT.md, R-07 | Run prototype with ramp-spawned moving objects; document whether velocity scaling is viable or requires redesign; update CONCEPT.md follow-up checklist |
| S5-07 | Implement: TimeSlow tool (production) | gameplay-programmer | 1.0 | S5-01, S5-06 | AoE slow works visibly on moving objects; Jolt sleeping bodies are woken before slowing; configurable radius + factor; togglable |
| S5-08 | Implement: Mission Debrief UI (minimal) | ui-programmer | 0.5 | mission-debrief-ui.md | Post-run screen triggered by `run_succeeded` / `run_failed` signals; shows outcome label, objective summary, time elapsed; returns to main menu or restarts run |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S5-09 | Performance baseline: 60fps with 10+ physics objects | gameplay-programmer | 0.5 | S5-02, S5-03 | Measure frame time in a scene with 10+ active RigidBody3Ds and tools active; document result in `docs/`; flag if over 16.6ms budget |
| S5-10 | Design review: physics-tool-system.md | lead-programmer | 0.5 | physics-tool-system.md | `/design-review` passes all 8 sections; CONCEPT.md findings incorporated (force push tuning, time slow caveat) |

## Carryover from Sprint 4

| Task | Reason | New Estimate |
|------|--------|-------------|
| Physics tools regression check | Sprint 4 DoD item left open — prototype tools unverified after mission loop wiring | Superseded by S5-01–S5-03 (full production rewrite) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Time Slow retest (S5-06) finds velocity scaling fundamentally broken | LOW | MEDIUM | CONCEPT.md already flags fallback approach (per-body drag/gravity scaling); S5-07 deferred until S5-06 result known |
| Health & Death scope expands (death animation, respawn UX) | MEDIUM | LOW | Cap at signal level only this sprint — no visual death, no respawn; both are Vertical Slice scope |
| HUD surfaces missing signal connections in existing systems | LOW | LOW | All systems emit standard signals per GDDs; HUD only reads, never writes |
| BaseTool interface design wrong on first pass | MEDIUM | MEDIUM | Design interface before writing tool implementations; consider `/architecture-decision` ADR |

## Dependencies on External Factors

- `physics-tool-system.md` GDD should be reviewed before S5-01 starts (or in parallel)
- Jolt Physics 4.6.1 sleeping body behavior (R-07) — testable locally, no external dependency

## Definition of Done for Sprint 5

- [ ] S5-01 through S5-05 (all Must Haves) complete
- [ ] All 3 physics tools callable from the production player scene (F5 → tools work)
- [ ] HealthComponent attached to player; escalation damage wires to it
- [ ] HUD visible and updating during a run
- [ ] Mission Debrief screen shown on run end (if S5-08 complete)
- [ ] No S1 or S2 bugs in the critical path (move → use tool → objective → extract)
- [ ] Design documents updated for any deviations from GDD
- [ ] `design/gdd/systems-index.md` progress tracker updated
