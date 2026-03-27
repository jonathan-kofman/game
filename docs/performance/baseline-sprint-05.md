# Performance Baseline — Sprint 5

> **Status**: PENDING MEASUREMENT
> **Date**: 2026-03-26
> **Target**: 60fps on mid-range PC with 10+ active physics objects (Milestone 1 exit criterion)
> **Recorded by**: [run manually and fill in]

---

## Test Procedure

1. Build the project in Godot 4.6.1 (Project > Export, or run from editor with debug profiler enabled)
2. Open the Godot **Debugger > Profiler** tab before launching
3. Press **F5** to start (uses a random seed; use `--seed=42` for repeatability)
4. Walk to the physics objects near the spawn point
5. Activate all three tools in combination (G → T → F) on multiple objects simultaneously
6. Record frame time readings from the profiler while 10+ objects are active and tools are in use
7. Let escalation run to CRITICAL and read frame time again with HUD pulsing active

**Minimum hardware target**: GTX 1070 / RX 580, Intel i5-8600K, 16GB RAM, 1080p

---

## Metrics to Record

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| Frame time (idle, no tools) | ≤ 16.6ms | [X] ms | [ ] |
| Frame time (tools active, 5 objects) | ≤ 16.6ms | [X] ms | [ ] |
| Frame time (tools active, 10+ objects) | ≤ 16.6ms | [X] ms | [ ] |
| Frame time (CRITICAL escalation + HUD pulse) | ≤ 16.6ms | [X] ms | [ ] |
| Frame time (debrief UI open) | ≤ 16.6ms | [X] ms | [ ] |
| PhysicsShapeQueryParameters3D (time slow activate) | ≤ 1.0ms | [X] ms | [ ] |
| Memory usage at peak | ≤ 512MB | [X] MB | [ ] |

---

## Known Cost Vectors (from code review)

| System | Risk | Mitigation |
|--------|------|------------|
| `PhysicsShapeQueryParameters3D` in `TimeSlowTool._begin_time_slow()` | Called once per time-slow activation; sphere intersect query over all layer-2 bodies | Acceptable for MVP at ≤20 objects. Cache or event-drive if > 20 objects causes stutter. |
| `StandardMaterial3D.new()` per physics object in `main.gd` | Creates new material on each procedural spawn | Shared material dict would halve allocations. Defer until profiler confirms it's a bottleneck. |
| HUD `_process()` pulsing | Runs every frame at CRITICAL; `sin()` + `Color` alloc | Negligible. No action needed. |
| Debrief `_process()` during XP animation | 2-second window, one `str(int)` call per frame | Negligible. No action needed. |
| `_build_room_geometry()` at load time | Creates StaticBody3D + mesh per wall per room (4 rooms × 4 walls = 16 bodies) | Acceptable at MVP room count. Profile load time separately if room count grows. |

---

## Optimisation Backlog (do not act until profiler confirms)

| Item | Estimated Gain | Priority |
|------|---------------|----------|
| Shared material pool for procedural physics objects | ~50% fewer material allocs at spawn | Low |
| Event-based physics object registration (replace sphere query) | Eliminates per-activation spatial query | Medium (needed at 20+ objects) |
| LOD for distant physics objects | Reduces physics tick cost | Low (MVP room sizes are small) |
| Merge static room geometry into single MultiMesh | Reduces draw calls | Low (profiler will tell us if needed) |

---

## Result

> Fill in after running the test procedure above.

**Overall verdict**: [ ] PASS  [ ] CONCERNS  [ ] FAIL

**Notes**:
```
[paste profiler screenshot path or key numbers here]
```

**Actions taken**:
- [ ] None required (all targets met)
- [ ] [describe any optimisations applied]
