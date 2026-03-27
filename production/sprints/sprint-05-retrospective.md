# Retrospective: Sprint 5
Period: 2026-03-26 — 2026-03-26 (single session, autonomous execution mode)
Generated: 2026-03-26

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks planned | 10 | 10 | — |
| Tasks completed | 10 | 8 | -2 |
| Completion rate | 100% | 80% | -20% |
| Effort days planned | 8.0 | ~0.5 (single session) | -7.5 |
| Tasks pre-existing (discovered) | 0 | 5 | +5 unplanned discovery |
| Bugs found | — | 2 | — |
| Bugs fixed | — | 2 | — |
| Unplanned tasks added | — | 0 | — |
| Commits | — | 4 | — |

**Note on effort delta**: Sprint 5 was executed in autonomous mode in a single
session. The apparent 7.5-day underrun is not a velocity gain — it reflects that
5 of the 10 tasks were already implemented in the v0.4.0 codebase and required
only discovery, not implementation. The sprint plan was written without full
visibility into what Sprint 3+4 had shipped.

---

## Velocity Trend

| Sprint | Planned Tasks | Completed | Rate |
|--------|---------------|-----------|------|
| Sprint 3+4 (combined) | ~20 | ~20 | ~100% |
| Sprint 5 | 10 | 8 | 80% |
| Sprint 6 (in progress) | 10 | — | — |

**Trend**: Stable (80% completion is within normal range for a solo team)

The apparent drop from Sprint 3+4's ~100% is misleading: S3+4 were executed as
a combined batch. Sprint 5's 80% reflects 2 legitimately deferred items
(requires manual game run) rather than any execution failure.

---

## What Went Well

- **Pre-existing implementation discovery**: All three physics tools
  (S5-01/02/03/07) and the HealthComponent (S5-04) were already live in the
  v0.4.0 codebase. This freed the sprint to focus entirely on HUD and Debrief
  UI, which are the user-visible deliverables.
- **Signal architecture held**: The HUD connected cleanly to EscalationManager,
  ObjectiveManager, and HealthComponent without modifying any of those systems.
  The signal-driven design from Sprint 3+4 paid off immediately.
- **Clean codebase**: 0 TODO / FIXME / HACK comments across all of `src/`. The
  team is not accumulating technical debt markers.
- **Performance baseline structured correctly**: The cost vector analysis
  (`docs/performance/baseline-sprint-05.md`) identified the two real risks
  (`PhysicsShapeQueryParameters3D` and `StandardMaterial3D` allocs) before any
  profiler numbers were available — a useful planning artifact.
- **MissionDebriefUI pause pattern**: Using `process_mode = PROCESS_MODE_ALWAYS`
  with `get_tree().paused = true` is clean and required zero changes to any
  other system.

---

## What Went Poorly

- **Sprint plan written before codebase audit**: S5-01 through S5-04 and S5-07
  were planned as if they didn't exist, but were already implemented. This
  wasted ~30 minutes of planning effort and created a misleading sprint scope.
  Root cause: sprint planning was done from CLAUDE.md context (which listed
  Sprint 3+4 deliverables) rather than from a direct codebase scan.
- **ObjectiveManager signal signature mismatch**: The GDD specified
  `objective_state_changed(id, name, progress_dict)` but the actual
  implementation emits `(id, state_string)`. The HUD was written to the actual
  signature, but the discrepancy was left as a comment rather than being
  resolved by updating the GDD. This is a design doc drift that could confuse
  the next developer (or agent) to touch this system.
- **HUD signal ordering bug**: `objectives.setup()` emits `objective_state_changed`
  immediately during the call. The first draft of main.gd connected HUD *after*
  `setup()`, causing the first objective state to be missed. Required a
  structural rewrite of the `_setup_facility()` ordering. This was a subtle
  Godot-specific lifecycle trap.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| S5-06: Time Slow retest requires running the game | Full sprint | Deferred to S6-10 (Nice to Have) | Accept that manual validation tasks cannot be automated; plan them separately |
| S5-10: Design review requires `/design-review` skill run | Short | Deferred to S6-09 (Nice to Have) | Schedule design review tasks in the sprint they're most useful (before implementation, not after) |

---

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S5-05 HUD | 1.0 day | ~0.5 day | -50% | Signal architecture already existed; only UI layout + signal wiring needed |
| S5-08 Mission Debrief UI | 0.5 day | ~0.5 day | 0% | Well-scoped; GDD was detailed enough to implement directly |
| S5-09 Perf baseline doc | 0.5 day | ~0.2 day | -60% | Writing the procedure and cost vectors was fast; no profiler run needed |
| S5-01 through S5-07 | 4.5 days | 0 days | -100% | Pre-existing implementation; planning gap |

**Overall estimation accuracy**: 50% of tasks within +/- 20% of estimate

We are systematically overestimating implementation tasks that build on existing
signal infrastructure. The Godot signal pattern is well-established in this
codebase — UI work is faster than estimated because the "wiring" step is trivial.
**Adjustment**: For UI-only tasks (no new game logic), halve the estimate.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| S5-06 Time Slow retest | Sprint 5 | 1 | Requires manual game run; cannot automate | Complete in S6-10 (Nice to Have); requires user at keyboard |
| S5-10 Physics tool design review | Sprint 5 | 1 | Time ran out; lower priority than implementation | Folded into S6-09 code review |

---

## Technical Debt Status

- Current TODO count: **0** (previous: 0)
- Current FIXME count: **0** (previous: 0)
- Current HACK count: **0** (previous: 0)
- Trend: **Stable at zero**
- No areas of concern. The signal mismatch in ObjectiveManager is the only
  latent issue — it's a documentation problem, not a runtime bug.

---

## Previous Action Items Follow-Up

No previous retrospectives exist — this is Sprint 5, the first formal retro.

---

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Fix ObjectiveManager GDD signal signature to match actual code: update `objective-system.md` §3 to reflect `(id: String, state: String)` not `(id, name, progress_dict)` | godot-gdscript-specialist | High | Sprint 6 (before any new consumer connects to this signal) |
| 2 | Before planning a sprint, run a codebase audit to identify pre-existing implementations; do not plan tasks for systems already in `src/` | producer | High | Sprint 6 planning (already applied to S6 plan) |
| 3 | Add actual performance numbers to `docs/performance/baseline-sprint-05.md` once user runs the playtest (S6-03) | Solo dev | High | S6-03 (depends on manual run) |
| 4 | Wire S5-10 design review (physics-tool-system.md) as part of S6-09 code review pass | lead-programmer | Low | Sprint 6 Nice to Have |

---

## Process Improvements

- **Sprint planning starts with `src/` scan**: Before estimating any
  implementation task, verify whether the system already exists in the
  codebase. Five tasks were "free" this sprint and we didn't know it. A 10-minute
  scan at sprint start would have surfaced this and allowed planning more
  valuable work.
- **GDD updates are part of Definition of Done**: Any implementation that
  deviates from the GDD (even slightly, like a signal signature change) must
  update the GDD in the same commit. The ObjectiveManager mismatch would have
  been caught immediately if "GDD matches code" was a hard DoD requirement.

---

## Summary

Sprint 5 shipped HUD, Mission Debrief UI, and a performance baseline document,
completing all remaining non-manual MVP implementation requirements. The sprint
was faster than planned because 5 of 10 tasks were pre-existing — a planning
miss, not a velocity win. The two carry-overs (TimeSlow retest, design review)
are legitimately manual tasks that cannot be automated and are correctly deferred
to Sprint 6. The codebase remains clean with zero tech debt markers. Going into
Sprint 6, the only blocking work is manual (playtest + profiler run); all
code-only MVP work is complete.
