# Sprint 3 — 2026-04-22 to 2026-05-05

## Sprint Goal

The game can assemble a procedurally generated facility from room templates
and drop the player inside it. Health & Death is implemented. By end of sprint,
pressing F5 spawns the player in a procedurally assembled multi-room facility
(not the hand-built test room). This is the first time the game loop has a
real environment to run in.

## Capacity

- Team: 1–2 people
- Total days: 10 working days × 1 person = 10 person-days
- Buffer (20%): 2 days
- Available: **8 person-days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-01 | Implement: HealthComponent | Solo dev | 0.5 | S2-08 GDD | `health_component.gd` with take_damage, heal, kill; health_changed + died signals; fall damage from CharacterController.landed |
| S3-02 | Update Player.tscn with HealthComponent | Solo dev | 0.5 | S3-01 | Player has HealthComponent child; fall from 5m+ deals damage; death disables input |
| S3-03 | Implement: RoomConnector + RoomTemplate scripts | Solo dev | 0.5 | S1-07 GDD | Scripts match GDD schema; get_connectors() returns typed array; get_spawn_points() works |
| S3-04 | Create 7 placeholder room .tscn files | Solo dev | 1.0 | S3-03 | entrance×1, exit×1, corridor×2, chamber×2, cap×1; each has ≥1 player spawn; connectors valid |
| S3-05 | Implement: RoomCatalogue + FacilityGraph resources | Solo dev | 0.5 | S3-03 | Catalogue loads room paths; query by type returns correct rooms; FacilityGraph stores placed rooms |
| S3-06 | Implement: ProceduralGenerator | Solo dev | 2.0 | S3-04, S3-05 | Generates 8–16 room facility; same seed = same layout; entrance + exit always present; no overlapping rooms |
| S3-07 | Wire ProceduralGenerator into main scene | Solo dev | 0.5 | S3-06 | F5 launches into procedurally generated facility; player spawns at entrance spawn point |

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-08 | Write GDD: Objective System | Solo dev | 0.5 | S2-09 GDD | All 8 sections; objective types, completion triggers, co-op credit |
| S3-09 | Write GDD: Escalation System | Solo dev | 0.5 | S3-08 GDD | All 8 sections; pressure curve, escalation events, extraction trigger |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-10 | Write GDD: Extraction System | Solo dev | 0.5 | S3-09 GDD | All 8 sections; extraction zone, countdown, success/fail states |

## Risks This Sprint

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Procedural generator produces overlapping rooms | MEDIUM | HIGH | AABB check with 0.5m padding; cap at 10 attempts before dead-ending |
| Room .tscn files have connector alignment bugs | MEDIUM | MEDIUM | Simple axis-aligned connectors only in MVP; test with 2-room generation first |

## Completed Tasks

| ID | Status | Notes |
|----|--------|-------|
| S3-01 | ✅ Done | health_component.gd + character_controller.gd updated (last_landing_velocity cache) |
| S3-02 | ✅ Done | Player.tscn updated with HealthComponent child |
| S3-03 | ✅ Done | room_connector.gd + room_template.gd implemented |
| S3-04 | ✅ Done | 7 placeholder .tscn files: entrance×1, exit×1, corridor×2, chamber×2, cap×1 |
| S3-05 | ✅ Done | room_catalogue.gd + facility_graph.gd + room_catalogue.tres |
| S3-06 | ✅ Done | procedural_generator.gd — depth-first, seed-deterministic, AABB overlap check |
| S3-07 | ✅ Done | main.gd rewritten to use ProceduralGenerator; player spawns at entrance spawn point |
| S3-08 | ✅ Done | GDD: Objective System written to design/gdd/objective-system.md |
| S3-09 | ✅ Done | GDD: Escalation System written to design/gdd/escalation-system.md |
| S3-10 | ✅ Done | GDD: Extraction System written to design/gdd/extraction-system.md |

## Definition of Done for Sprint 3

- [x] S3-01 through S3-07 (all Must Haves) complete
- [x] F5 produces a different facility on each run
- [x] Same seed produces identical facility (verify with seed=12345 twice)
- [x] Player can walk from entrance to exit through connected rooms
- [x] `design/gdd/systems-index.md` progress tracker updated
