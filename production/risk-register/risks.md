# Risk Register

> Last updated: 2026-03-27

| ID | Risk | Probability | Impact | Status | Mitigation |
|----|------|------------|--------|--------|------------|
| R-01 | Physics networking desync makes co-op feel broken | HIGH | HIGH | Open | Prototype networking with 2 clients before committing to architecture |
| R-02 | Scope grows beyond 1-3 person capacity | HIGH | HIGH | Open | Mini-game pipeline enforces scope gates; each phase has a shippable output |
| R-03 | GDScript learning curve slows early sprints | MEDIUM | MEDIUM | Mitigated | Sprints 3–5 delivered on schedule; GDScript overhead not materialising |
| R-04 | Physics Tool System requires too many design iterations | MEDIUM | HIGH | Mitigated | Prototype validated (PROCEED). Production implementation complete Sprint 5. |
| R-05 | Procedural generation produces unplayable layouts | MEDIUM | MEDIUM | Open | Hand-craft rooms with explicit connector tags; validate with playtest-report each sprint |
| R-06 | Solo/co-op balance fails at 1 or 4 players | MEDIUM | HIGH | Open | Design solo first; co-op scaling is a separate system layered on top |
| R-07 | Time Slow tool doesn't feel satisfying without moving targets | LOW | MEDIUM | Pending Validation | RampTestRoom.tscn built (S5-07) — open in Godot and press T on rolling objects to validate |
