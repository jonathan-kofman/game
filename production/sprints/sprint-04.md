# Sprint 4 — 2026-05-06 to 2026-05-19

## Sprint Goal

A complete solo run is playable end-to-end: the player enters a procedurally
generated facility, activates a terminal (primary objective), escalation pressure
mounts over time, and the player extracts to end the mission. First time the full
RIFT loop is closeable without developer intervention.

## Capacity

- Team: 1–2 people
- Total days: 10 working days × 1 person = 10 person-days
- Buffer (20%): 2 days
- Available: **8 person-days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-01 | Implement: InteractableTerminal | Solo dev | 0.5 | S3-07 | StaticBody3D with `interacted` signal; player raycasts + presses "interact"; visual feedback on hover |
| S4-02 | Implement: ObjectiveManager | Solo dev | 1.0 | S4-01 | Activate objective type: N terminals to interact; `objective_state_changed` + `primary_objective_complete` signals; placed by ProceduralGenerator |
| S4-03 | Implement: EscalationManager | Solo dev | 1.0 | S4-02 | 4-level state machine; passive timer advances levels; `objective_completed` event advances level; `escalation_level_changed` signal |
| S4-04 | Implement: ExtractionZone | Solo dev | 0.5 | S4-03 | Area3D in exit room; locked until primary complete; 4s channel timer; `run_succeeded` / `run_partial_success` / `run_failed` signals |
| S4-05 | Wire mission loop into main scene | Solo dev | 0.5 | S4-04 | F5 → player spawns → terminal exists → interact → escalation advances → extraction unlocks → channel → run_succeeded prints |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-06 | Write GDD: Player Spawning & Respawn | Solo dev | 0.5 | S2-08 GDD | All 8 sections; solo respawn, co-op rally mechanics, spawn protection |
| S4-07 | Write GDD: Mission Debrief System | Solo dev | 0.5 | S3-08 GDD | All 8 sections; XP award, objective summary, loot manifest |
| S4-08 | Write GDD: Solo/Co-op Scaling System | Solo dev | 0.5 | S3-09 GDD | All 8 sections; difficulty multipliers per player count, objective count scaling |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-09 | Write GDD: Tool Selection UI | Solo dev | 0.5 | S2-06 GDD | All 8 sections; active tool indicator, cooldown display |
| S4-10 | Write GDD: HUD | Solo dev | 0.5 | S4-07 GDD | All 8 sections; health bar, escalation bar, objective tracker |
| S4-11 | Write GDD: Mission Debrief UI | Solo dev | 0.5 | S4-07 GDD | All 8 sections; post-run screen layout, XP + loot display |

## Completed Tasks

| ID | Task | Completed | Notes |
|----|------|-----------|-------|
| S4-01 | Implement: InteractableTerminal | 2026-03-25 | `src/scripts/gameplay/interactable_terminal.gd` — StaticBody3D, collision_layer=3, raycast detect, `interacted` signal, `set_highlighted()` |
| S4-02 | Implement: ObjectiveManager | 2026-03-25 | `src/scripts/gameplay/objective_manager.gd` — Activate type, terminal placement, `primary_objective_complete` signal |
| S4-03 | Implement: EscalationManager | 2026-03-25 | `src/scripts/gameplay/escalation_manager.gd` — 4-level FSM, passive timers, pressure accumulation, `escalation_level_changed` + `critical_entered` signals |
| S4-04 | Implement: ExtractionZone | 2026-03-25 | `src/scripts/gameplay/extraction_zone.gd` — Area3D, channel dict, `run_succeeded/partial/failed` signals |
| S4-05 | Wire mission loop into main scene | 2026-03-25 | `src/scripts/core/main.gd` updated — full signal chain wired; `--seed=<int>` CLI arg supported |
| S4-06 | Write GDD: Player Spawning & Respawn | 2026-03-25 | `design/gdd/player-spawning-respawn.md` |
| S4-07 | Write GDD: Mission Debrief System | 2026-03-25 | `design/gdd/mission-debrief-system.md` |
| S4-08 | Write GDD: Solo/Co-op Scaling System | 2026-03-25 | `design/gdd/solo-coop-scaling-system.md` |
| S4-09 | Write GDD: Tool Selection UI | 2026-03-25 | `design/gdd/tool-selection-ui.md` |
| S4-10 | Write GDD: HUD | 2026-03-25 | `design/gdd/hud.md` |
| S4-11 | Write GDD: Mission Debrief UI | 2026-03-25 | `design/gdd/mission-debrief-ui.md` |

## Risks This Sprint

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ProceduralGenerator doesn't reliably place terminal in reachable room | MEDIUM | HIGH | ObjectiveManager falls back to entrance room if objective room unreachable |
| "interact" input action not in project.godot → runtime error | LOW | MEDIUM | Add action registration guard in InteractableTerminal; log clear error |

## Definition of Done for Sprint 4

- [x] S4-01 through S4-05 (all Must Haves) complete
- [x] Full run loop closeable: spawn → interact terminal → escalation → extract → run_succeeded
- [x] `design/gdd/systems-index.md` progress tracker updated
- [ ] No regressions: physics tools still work after wiring mission loop
