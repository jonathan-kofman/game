# Milestone 1: RIFT MVP

> **Target**: Month 3 (≈ 2026-06-25)
> **Status**: In Progress

## Goal

A playable solo run of RIFT is completable from launch to extraction.
No enemies required. Physics tools work, a procedurally assembled facility
can be entered and exited, and a basic mission objective exists.
One player only. No networking. No base building.

## Exit Criteria

- [ ] Player can launch the game, enter a procedurally assembled facility
- [ ] All 3 physics tools work in the production codebase (not prototype)
- [ ] At least 1 objective type exists and can be completed
- [ ] Escalation pressure increases over time
- [ ] Player can extract and see a mission debrief
- [ ] 60fps on a mid-range PC with 10+ physics objects active
- [ ] No S1 bugs in the critical path (move → objective → extract)

## Systems Required

See `design/gdd/systems-index.md` — all 16 MVP systems.

## Milestones Before This

None — this is Milestone 1.

## Risks

- Physics Tool System design iteration cost (HIGH)
- Procedural generation quality bar (MEDIUM)
- Scope creep from networking (MEDIUM — networking is Vertical Slice, not MVP)
