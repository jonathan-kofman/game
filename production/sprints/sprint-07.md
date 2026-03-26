# Sprint 7 — 2026-04-23 to 2026-05-06

## Sprint Goal

Close the MVP milestone gate, define Milestone 2 (Vertical Slice), and design
the Enemy & Hazard and Audio systems — the two highest-priority gaps between
"run loop works" and "run loop is worth playing."

## Capacity

- Team: 1 person
- Total days: 10 working days
- Buffer (20%): 2 days
- Available: **8 person-days**

## Context: Entering Sprint 7

Sprint 6 was the MVP validation sprint. Sprint 7 assumes S6's manual tasks
(playtest, profiler run, gate check) are complete. The project enters Sprint 7
at one of two states:

| State | Condition | Sprint 7 Focus |
|-------|-----------|----------------|
| **A — MVP Closed** | Gate check passed; all 7 exit criteria checked | Vertical Slice kickoff: Milestone 2 + design sprints |
| **B — MVP Needs Fixes** | Playtest or profiler found blocking issues | Fix blocking issues first, then kick off VS |

Sprint 7 is planned for State A. If State B applies, S7-01 and S7-02 absorb
the fix work and the design tasks shift down in priority.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S7-01 | Define Milestone 2 — Vertical Slice | producer | 0.5 | Sprint 6 gate check passed | `production/milestones/milestone-02-vertical-slice.md` written: goal, exit criteria (5–7 criteria), systems required, target date, and risks documented |
| S7-02 | Sprint 6 retrospective | producer | 0.5 | Sprint 6 complete | `production/sprints/sprint-06-retrospective.md` written: velocity, blockers, estimation accuracy, action items |
| S7-03 | Fix ObjectiveManager GDD signal signature | godot-gdscript-specialist | 0.5 | sprint-05-retrospective.md action item #1 | `design/gdd/objective-system.md` §3 updated: `objective_state_changed` documented as `(id: String, state: String)`, not `(id, name, progress_dict)`; code comment in `hud.gd` updated to reference the corrected GDD |
| S7-04 | Design: Enemy & Hazard System GDD | game-designer | 2.0 | milestone-02-vertical-slice.md | `design/gdd/enemy-hazard-system.md` written with all 8 required sections; covers at least 1 enemy archetype (patrol guard), hazard types (alarm laser, pressure plate), detection flow, and combat interaction with physics tools |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S7-05 | Design: Audio System GDD | audio-director | 1.5 | milestone-02-vertical-slice.md | `design/gdd/audio-system.md` written: event-based audio architecture (no direct AudioStreamPlayer calls in gameplay code), bus layout, tool SFX slots, escalation music layers, and Godot 4 AudioServer integration |
| S7-06 | Code review: tool system + UI | lead-programmer | 1.0 | Sprint 5/6 code (carryover S6-09) | `/code-review` on `base_tool.gd`, `tool_manager.gd`, `hud.gd`, `tool_selection_ui.gd`; critical issues logged as tasks; style issues fixed in-place |
| S7-07 | Design: Camera System GDD | game-designer | 0.5 | milestone-02-vertical-slice.md | `design/gdd/camera-system.md` written: FPS camera, FOV, headbob parameters, camera shake triggers (tool fire, damage received), spring-arm fallback for third-person debugging |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S7-08 | Implement Camera System improvements | gameplay-programmer | 1.5 | camera-system.md GDD (S7-07) | Camera headbob visible during movement; camera shake fires on `tool_activated` signal; FOV tunable via `@export`; no regressions on movement or collision |
| S7-09 | Time Slow retest in production scene | gameplay-programmer | 0.5 | Running game (S6-10 carryover) | Time Slow visibly affects objects that were resting on the floor; Jolt sleep-wake path confirmed working in main scene; result documented in `docs/performance/baseline-sprint-05.md` |
| S7-10 | Refresh risk register for Vertical Slice phase | producer | 0.5 | S7-01 | `production/risk-register/risks.md` updated: R-04 (Physics Tool) closed; R-07 (Time Slow) resolved or escalated; 2–3 new VS-phase risks added (enemy AI performance, audio bus overhead, scope expansion) |

---

## Carryover from Sprint 6

| Task | Reason | New Estimate |
|------|--------|-------------|
| S6-09 Code review (tool system + HUD) | Not reached in S6 (Nice to Have); code is stable, review adds value before VS adds new files | S7-06 (Should Have) |
| S6-10 Time Slow retest | Requires manual editor run; blocked until user runs game | S7-09 (Nice to Have) |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S6 gate check failed; Sprint 7 absorbed by bug fixes | LOW | HIGH | S7-01 through S7-04 are flexible; bug fixes would replace S7-03/S7-04 in priority order |
| Enemy & Hazard GDD grows to 2+ archetypes and overruns budget | MEDIUM | MEDIUM | Cap S7-04 scope at exactly 1 enemy archetype and 2 hazard types; additional archetypes are VS sprint-N tasks |
| Audio System design requires researching Godot 4.6 AudioServer specifics (post-LLM cutoff) | MEDIUM | LOW | Use WebFetch on Godot docs; flag any API uncertainty in the GDD rather than guessing |
| Camera headbob implementation breaks FPS feel | LOW | MEDIUM | All headbob values are `@export`; can tune to zero and the system still compiles; no gameplay regression possible |

---

## Dependencies on External Factors

- **S6 gate check result** (user): Sprint 7 State A vs B determination requires the user to confirm MVP passed before design work begins. Code-only tasks (S7-03, S7-06) can proceed regardless.
- **S7-09 Time Slow retest**: Requires user to run the game in Godot editor with the production scene.
- **S7-08 Camera implementation**: Can be coded without running the game, but visual validation requires the user to press F5.

---

## Definition of Done for Sprint 7

- [ ] S7-01 through S7-04 (all Must Haves) complete
- [ ] `production/milestones/milestone-02-vertical-slice.md` exists with 5+ exit criteria
- [ ] Enemy & Hazard System GDD covers patrol enemy, detection flow, and tool interactions
- [ ] Sprint 6 retrospective written
- [ ] ObjectiveManager signal signature corrected in GDD
- [ ] Code review findings either fixed or logged as tracked tech debt tasks
- [ ] Audio System GDD written (if Should Have reached)
- [ ] `design/gdd/systems-index.md` updated to reflect new GDD completions
