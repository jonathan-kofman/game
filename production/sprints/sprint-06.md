# Sprint 6 — 2026-04-09 to 2026-04-22

## Sprint Goal

Validate the complete MVP run loop end-to-end, close all milestone exit
criteria, and pass the pre-production gate check. Sprint 5 delivered every
implementation requirement — Sprint 6 is validation, polish, and closure.

## Capacity

- Team: 1 person
- Total days: 10 working days
- Buffer (20%): 2 days
- Available: **8 person-days**

## MVP Exit Criteria Status (entering Sprint 6)

| Criterion | Status |
|-----------|--------|
| Player launches, enters procedurally generated facility | ✅ Done (Sprint 3) |
| All 3 physics tools in production codebase | ✅ Done (Sprint 5) |
| At least 1 objective type completable | ✅ Done (Sprint 4) |
| Escalation pressure increases over time | ✅ Done (Sprint 4) |
| Player can extract and see mission debrief | ✅ Done (Sprint 5) |
| 60fps with 10+ active physics objects | ⬜ Needs manual profiler run |
| No S1 bugs in critical path | ⬜ Needs playtest |

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S6-01 | Full-path playtest: F5 → tools → terminal → extract → debrief | Solo dev | 1.0 | All Sprint 5 code | Run completes without crashes or script errors; all three tools fire signals; HUD updates; debrief shows correct outcome and XP |
| S6-02 | Fix any S1 bugs found in S6-01 | gameplay-programmer | 1.0 | S6-01 | Critical path clean; no errors on F5 run |
| S6-03 | Performance baseline: run procedure from docs/performance/baseline-sprint-05.md | Solo dev | 0.5 | S6-01 | Numbers recorded; PASS/FAIL verdict written; if FAIL, optimisation tasks created |
| S6-04 | Update milestone exit criteria checkboxes | Solo dev | 0.5 | S6-01, S6-03 | milestone-01-mvp.md has all 7 criteria checked or explicitly flagged |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S6-05 | Implement Tool Selection UI — active tool indicator in HUD | ui-programmer | 1.5 | tool-selection-ui.md GDD, ToolManager signals | HUD shows which tool is currently selected (G/T/F); switches visually when different tool is pressed |
| S6-06 | Run /gate-check pre-production | producer | 0.5 | S6-04 | Gate check report generated; PASS moves milestone to Vertical Slice phase |
| S6-07 | Update systems-index.md implementation status | Solo dev | 0.5 | S6-01 | Each implemented system marked; progress tracker accurate |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S6-08 | Sprint 5 retrospective | producer | 0.5 | Sprint 5 complete | Retrospective doc written in production/; velocity, blockers, lessons captured |
| S6-09 | Code review: tool system + HUD | lead-programmer | 1.0 | Sprint 5 code | /code-review passes on base_tool.gd, tool_manager.gd, hud.gd; any issues logged as tech debt |
| S6-10 | Time Slow retest in production scene | gameplay-programmer | 0.5 | S6-01 | Time slow visibly slows objects that were resting; Jolt wake path confirmed working in main scene |

## Carryover from Sprint 5

| Task | Reason | New Estimate |
|------|--------|-------------|
| S5-06 Time Slow retest | Requires editor run; blocked on manual testing | S6-10 (Nice to Have) |
| S5-09 Performance baseline (actual numbers) | Requires editor run | S6-03 (Must Have) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S6-01 playtest reveals S1 bug in signal wiring (HUD not updating) | MEDIUM | HIGH | S6-02 reserved — 1 day for fixes |
| Time Slow still broken on resting bodies in production scene | LOW | MEDIUM | Production code wakes bodies before slowing (unlike prototype); risk is low but retest confirms |
| Performance fails 60fps target | LOW | HIGH | Cost vector analysis already done; PhysicsShapeQueryParameters3D is the most likely culprit; mitigation is documented in baseline doc |
| Gate check reveals missing acceptance criteria | LOW | MEDIUM | All 16 MVP GDDs exist; 2 explicitly deferred (Networking, State Sync); gate check aware of deferred scope |

## Dependencies on External Factors

- Manual profiler run in Godot 4.6.1 editor required for S6-03 (cannot be automated)
- Manual playtest required for S6-01 (no automated test runner in place yet)

## Definition of Done for Sprint 6

- [ ] S6-01 through S6-04 (all Must Haves) complete
- [ ] Full run loop plays without S1 errors: F5 → move → use tools → interact terminal → escalation → extract → debrief shows
- [ ] Performance baseline numbers recorded; 60fps target confirmed or escalated
- [ ] milestone-01-mvp.md exit criteria updated
- [ ] systems-index.md implementation tracker updated (S6-07)
- [ ] Gate check run or explicitly deferred with reason documented
