# Risk Register

> Last updated: 2026-03-27 (refreshed for Vertical Slice phase)

| ID | Risk | Probability | Impact | Status | Mitigation |
|----|------|------------|--------|--------|------------|
| R-01 | Physics networking desync makes co-op feel broken | HIGH | HIGH | Open | Prototype networking with 2 clients before committing to architecture |
| R-02 | Scope grows beyond 1-3 person capacity | HIGH | HIGH | Open | Mini-game pipeline enforces scope gates; each phase has a shippable output |
| R-03 | GDScript learning curve slows early sprints | MEDIUM | MEDIUM | Closed | Sprints 3–5 delivered on schedule; GDScript overhead did not materialise |
| R-04 | Physics Tool System requires too many design iterations | MEDIUM | HIGH | Closed | Production implementation complete Sprint 5; prototype validated PROCEED |
| R-05 | Procedural generation produces unplayable layouts | MEDIUM | MEDIUM | Open | Hand-craft rooms with explicit connector tags; validate with playtest-report each sprint |
| R-06 | Solo/co-op balance fails at 1 or 4 players | MEDIUM | HIGH | Open | Design solo first; co-op scaling is a separate system layered on top |
| R-07 | Time Slow tool doesn't feel satisfying without moving targets | LOW | MEDIUM | Pending Validation | RampTestRoom.tscn built (S5-07) — open in Godot and press T on rolling objects to validate |
| R-08 | Enemy AI pathfinding performance degrades at 60fps with Jolt active | MEDIUM | HIGH | Open | Cap enemy count at 3 per room MVP; profile before adding navigation mesh; no A* until profiled |
| R-09 | Audio bus overhead spikes frame time during escalation music transitions | LOW | MEDIUM | Open | Pre-load all AudioStream assets at scene load; use AudioStreamPlayer not 3D for music layers |
| R-10 | Procedural generator cannot reliably place enemies + hazards in reachable rooms | MEDIUM | MEDIUM | Open | Tag rooms with spawn_type metadata; generator picks rooms by tag (same pattern as objective rooms) |
