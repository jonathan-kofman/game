# Sprint 1 — 2026-03-25 to 2026-04-07

## Sprint Goal

Set up the production Godot project and have a player who can move, look,
and jump in the production codebase — not the prototype. Design docs for the
two simplest foundation systems (Input, Character Controller) are written and
approved so implementation can proceed without ambiguity.

## Capacity

- Team: 1–2 people
- Total days: 10 working days × 1 person = 10 person-days
- Buffer (20%): 2 days reserved for unplanned work and Godot learning overhead
- Available: **8 person-days**

> Note: Sprint 1 is deliberately conservative. The team is transitioning from
> Roblox to Godot 4.6. Velocity will increase once GDScript and the Godot editor
> feel familiar.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-01 | Set up production Godot project at `src/` with correct folder structure | Solo dev | 0.5 | — | Project opens in Godot 4.6, Jolt Physics enabled, Forward+ renderer, no errors |
| S1-02 | Write GDD: Input System | Solo dev | 0.5 | — | All 8 required sections complete; input actions listed; remapping noted as future scope |
| S1-03 | Write GDD: Character Controller | Solo dev | 1.0 | S1-02 | All 8 required sections complete; move speed, jump, gravity values defined with formulas |
| S1-04 | Implement: Input System | Solo dev | 0.5 | S1-02 | Input Map configured in project.godot; all game actions defined; tests pass (GUT) |
| S1-05 | Implement: Character Controller | Solo dev | 2.0 | S1-03, S1-04 | Player can move WASD, mouse-look, jump; snappy stop on release; no physics jitter at walls/floor |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-06 | Write GDD: Physics Interaction Layer | Solo dev | 1.0 | S1-03 | All 8 sections; defines what counts as a physics object, gravity_scale contract, Jolt-specific notes |
| S1-07 | Write GDD: Room Template Data System | Solo dev | 0.5 | — | All 8 sections; defines room schema (size, connectors, tags, hazard slots) |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-08 | Write GDD: Physics Tool System (production spec) | Solo dev | 1.0 | S1-06 | All 8 sections; documents changes from prototype findings (velocity scaling → proper time dilation, BaseTool interface) |
| S1-09 | Minimal test scene for character controller | Solo dev | 0.5 | S1-05 | Room with floor + walls; no setup instructions needed; run with F5 |

## Carryover from Previous Sprint

None — this is Sprint 1.

## Risks This Sprint

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Godot project setup takes longer than expected (unfamiliar editor) | MEDIUM | LOW | Keep S1-01 in Must Have; unblock it first |
| GDD writing blocked on design ambiguity | MEDIUM | MEDIUM | Write what is known; mark unknowns explicitly with [TBD]; don't let perfect block done |
| Character controller feel takes many iterations | MEDIUM | MEDIUM | Start from prototype values (SPEED=6, JUMP=5) — they worked |

## Dependencies on External Factors

- Godot 4.6.1 installed and working (confirmed — prototype ran)

## Definition of Done for Sprint 1

- [x] S1-01 through S1-05 (all Must Haves) complete
- [x] All tasks pass their acceptance criteria
- [ ] No S1 bugs in the character controller critical path (move, look, jump) — *verify in Godot*
- [x] Design documents updated for any deviations from the GDD spec
- [x] `design/gdd/systems-index.md` progress tracker updated

## Completion Notes

All Must Have and Should Have tasks completed. Nice to Have tasks also complete:
- S1-08: GDD Physics Tool System written (production redesign from prototype findings)
- S1-09: Test scene satisfied by main.gd (20×20m room, floor + 4 walls, player spawn)

Outstanding: Character controller requires manual playtest in Godot 4.6 to verify
feel (move, look, jump, no jitter at walls). This is a pre-Sprint 2 gate item.
