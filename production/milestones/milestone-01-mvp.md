# Milestone 1: RIFT MVP

> **Target**: Month 3 (≈ 2026-06-25)
> **Status**: In Progress — 4/7 exit criteria confirmed; 3 pending full-loop run

## Goal

A playable solo run of RIFT is completable from launch to extraction.
No enemies required. Physics tools work, a procedurally assembled facility
can be entered and exited, and a basic mission objective exists.
One player only. No networking. No base building.

## Exit Criteria

- [x] Player can launch the game, enter a procedurally assembled facility
      — Confirmed 2026-03-28: rooms=10 generated, facility loaded, player spawned
- [x] All 3 physics tools work in the production codebase (not prototype)
      — Confirmed 2026-03-28: GravityFlip, TimeSlow, ForcePush all activated in run log
- [x] At least 1 objective type exists and can be completed
      — Confirmed 2026-03-28: Terminal activated (1/1), "Primary objective COMPLETE" logged
- [x] Escalation pressure increases over time
      — Confirmed 2026-03-28: CALM → ALERT → HOSTILE → CRITICAL observed in run log
- [ ] Player can extract and see a mission debrief
      — ExtractionZone unlocked confirmed; manual extraction + debrief screen pending full run
- [ ] 60fps on a mid-range PC with 10+ physics objects active
      — Pending: requires manual profiler run (S6-03 carryover)
- [ ] No S1 bugs in the critical path (move → objective → extract)
      — Pending: 4 runtime bugs fixed 2026-03-28; clean full-loop run required to close

## Systems Required

See `design/gdd/systems-index.md` — all 16 MVP systems.

## Milestones Before This

None — this is Milestone 1.

## Risks

- Physics Tool System design iteration cost (HIGH)
- Procedural generation quality bar (MEDIUM)
- Scope creep from networking (MEDIUM — networking is Vertical Slice, not MVP)
