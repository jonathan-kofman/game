# Systems Index: RIFT

> **Status**: Approved
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-26 (Sprint 6 — implementation status added)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

RIFT is a co-op physics-based roguelike with base building and environmental
storytelling. Its systems span five major domains: physics tool gameplay, breach
mission structure, persistent base building, multiplayer networking, and
narrative delivery through environment. The mini-game pipeline means MVP systems
(RIFT prototype) are designed and built first as a standalone slice, followed by
Vertical Slice systems, then full Alpha integration of all three mini-games into
one product. Physics and networking are the two highest-risk foundations and must
be validated early via prototype before the rest of the system stack is committed.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Input System | Core | MVP | ✅ Implemented | [input-system.md](input-system.md) | — |
| 2 | Audio System | Audio | Vertical Slice | Not Started | — | — |
| 3 | Save/Load System | Persistence | Alpha | Not Started | — | — |
| 4 | Room Template Data System | Core | MVP | ✅ Implemented | [room-template-data-system.md](room-template-data-system.md) | — |
| 5 | Networking Layer | Core | MVP | ⏸ Deferred (Vertical Slice) | — | — |
| 6 | Character Controller | Core | MVP | ✅ Implemented | [character-controller.md](character-controller.md) | Input System |
| 7 | Physics Interaction Layer | Core | MVP | ✅ Implemented | [physics-interaction-layer.md](physics-interaction-layer.md) | engine physics |
| 8 | Physics Tool System | Gameplay | MVP | ✅ Implemented | [physics-tool-system.md](physics-tool-system.md) | Character Controller, Physics Interaction Layer |
| 9 | Health & Death System | Core | MVP | ✅ Implemented | [health-death-system.md](health-death-system.md) | Character Controller |
| 10 | Player Spawning & Respawn | Core | MVP | 🔶 Partial (spawn ✅, respawn deferred) | [player-spawning-respawn.md](player-spawning-respawn.md) | Networking Layer, Character Controller |
| 11 | State Synchronization | Core | MVP | ⏸ Deferred (Vertical Slice) | — | Networking Layer, all Core systems |
| 12 | Procedural Generation System | Gameplay | MVP | ✅ Implemented | [procedural-generation-system.md](procedural-generation-system.md) | Room Template Data System |
| 13 | Objective System | Gameplay | MVP | ✅ Implemented | [objective-system.md](objective-system.md) | Procedural Generation System |
| 14 | Escalation System | Gameplay | MVP | ✅ Implemented | [escalation-system.md](escalation-system.md) | Objective System |
| 15 | Extraction System | Gameplay | MVP | ✅ Implemented | [extraction-system.md](extraction-system.md) | Escalation System |
| 16 | Enemy & Hazard System | Gameplay | Vertical Slice | Not Started | — | Character Controller, Health & Death System |
| 17 | Resource & Loot System | Economy | Vertical Slice | Not Started | — | Extraction System |
| 18 | Base Building System | Gameplay | Alpha | Not Started | — | Resource & Loot System, Physics Interaction Layer |
| 19 | Upgrade & Unlock Tree | Progression | Alpha | Not Started | — | Base Building System |
| 20 | Base Persistence System | Persistence | Alpha | Not Started | — | Base Building System, Save/Load System |
| 21 | Solo/Co-op Scaling System (inferred) | Gameplay | MVP | Design Complete | [solo-coop-scaling-system.md](solo-coop-scaling-system.md) | Networking Layer, Objective System |
| 22 | Lore Fragment System | Narrative | Alpha | Not Started | — | Room Template Data System |
| 23 | Environmental Narrative System | Narrative | Alpha | Not Started | — | Room Template Data System, Lore Fragment System |
| 24 | Mission Debrief System | Gameplay | MVP | ✅ Implemented | [mission-debrief-system.md](mission-debrief-system.md) | Objective System, Resource & Loot System |
| 25 | Camera System | Core | Vertical Slice | Not Started | — | Character Controller |
| 26 | Tool Selection UI | UI | MVP | ✅ Implemented | [tool-selection-ui.md](tool-selection-ui.md) | Physics Tool System |
| 27 | HUD | UI | MVP | ✅ Implemented | [hud.md](hud.md) | Health & Death System, Objective System, Escalation System |
| 28 | Base Building UI | UI | Alpha | Not Started | — | Base Building System |
| 29 | Codex/Journal UI | UI | Alpha | Not Started | — | Lore Fragment System |
| 30 | Lobby/Session UI | UI | Vertical Slice | Not Started | — | Networking Layer |
| 31 | Mission Debrief UI | UI | MVP | ✅ Implemented | [mission-debrief-ui.md](mission-debrief-ui.md) | Mission Debrief System |
| 32 | Main Menu & UI Flow | UI | Alpha | Not Started | — | Save/Load System |
| 33 | Visual Effects & Juice System | Meta | Vertical Slice | Not Started | — | Physics Tool System, Audio System |
| 34 | Performance & LOD System | Meta | Full Vision | Not Started | — | Procedural Generation System |
| 35 | Settings & Options System | Persistence | Full Vision | Not Started | — | Audio System, Input System |
| 36 | Accessibility System | Meta | Full Vision | Not Started | — | — |

---

## Categories

| Category | Description | RIFT Systems |
|----------|-------------|--------------|
| **Core** | Foundation systems everything depends on | Input, Character Controller, Physics Layer, Health/Death, Networking, Player Spawning, State Sync, Room Templates |
| **Gameplay** | The systems that make the game fun | Physics Tools, Procedural Gen, Objectives, Escalation, Extraction, Enemy/Hazard, Base Building, Scaling |
| **Progression** | How the player grows over time | Upgrade & Unlock Tree |
| **Economy** | Resource creation and consumption | Resource & Loot System |
| **Persistence** | Save state and continuity | Save/Load, Base Persistence, Settings |
| **UI** | Player-facing information | Tool Selection UI, HUD, Base Building UI, Codex UI, Lobby UI, Debrief UI, Main Menu |
| **Audio** | Sound and music | Audio System |
| **Narrative** | Story and lore delivery | Lore Fragment System, Environmental Narrative |
| **Meta** | Systems outside the core loop | Visual Effects & Juice, Performance & LOD, Accessibility, Camera |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems Count |
|------|------------|------------------|---------------|
| **MVP** | RIFT mini-game prototype — core loop playable and testable | Month 1–3 | 16 |
| **Vertical Slice** | Full one-run experience with polish; shippable BREACH mini-game | Month 3–5 | 7 |
| **Alpha** | All three mini-games integrated; full base building + lore | Month 5–7 | 9 |
| **Full Vision** | Polish, performance, options, accessibility | Month 7+ | 4 |

---

## Dependency Map

### Foundation Layer (no dependencies — design first)

1. **Input System** — nothing moves without it
2. **Audio System** — foundation for all SFX and music
3. **Save/Load System** — all persistence depends on this
4. **Room Template Data System** — procedural generation needs hand-crafted rooms to pull from
5. **Networking Layer** — all multiplayer systems depend on this

### Core Layer (depends on Foundation)

1. **Character Controller** — depends on: Input System
2. **Physics Interaction Layer** — depends on: engine physics (Jolt)
3. **Physics Tool System** — depends on: Character Controller, Physics Interaction Layer
4. **Health & Death System** — depends on: Character Controller
5. **Player Spawning & Respawn** — depends on: Networking Layer, Character Controller
6. **State Synchronization** — depends on: Networking Layer + all Core systems

### Feature Layer (depends on Core)

1. **Procedural Generation System** — depends on: Room Template Data System
2. **Objective System** — depends on: Procedural Generation System
3. **Escalation System** — depends on: Objective System
4. **Extraction System** — depends on: Escalation System
5. **Enemy & Hazard System** — depends on: Character Controller, Health & Death System
6. **Resource & Loot System** — depends on: Extraction System
7. **Base Building System** — depends on: Resource & Loot System, Physics Interaction Layer
8. **Upgrade & Unlock Tree** — depends on: Base Building System
9. **Base Persistence System** — depends on: Base Building System, Save/Load System
10. **Solo/Co-op Scaling System** — depends on: Networking Layer, Objective System
11. **Lore Fragment System** — depends on: Room Template Data System
12. **Environmental Narrative System** — depends on: Room Template Data System, Lore Fragment System
13. **Mission Debrief System** — depends on: Objective System, Resource & Loot System

### Presentation Layer (UI wrapping gameplay)

1. **Tool Selection UI** — depends on: Physics Tool System
2. **HUD** — depends on: Health & Death System, Objective System, Escalation System
3. **Base Building UI** — depends on: Base Building System
4. **Codex/Journal UI** — depends on: Lore Fragment System
5. **Lobby/Session UI** — depends on: Networking Layer
6. **Mission Debrief UI** — depends on: Mission Debrief System
7. **Main Menu & UI Flow** — depends on: Save/Load System

### Polish Layer (depends on all gameplay)

1. **Camera System** — depends on: Character Controller
2. **Visual Effects & Juice System** — depends on: Physics Tool System, Audio System
3. **Performance & LOD System** — depends on: Procedural Generation System
4. **Settings & Options System** — depends on: Audio System, Input System
5. **Accessibility System** — depends on: all UI systems

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Room Template Data System | MVP | Foundation | game-designer, level-designer | S |
| 2 | Input System | MVP | Foundation | lead-programmer, game-designer | S |
| 3 | Character Controller | MVP | Core | lead-programmer, gameplay-programmer | M |
| 4 | Physics Interaction Layer | MVP | Core | engine-programmer, godot-specialist | M |
| 5 | Physics Tool System | MVP | Core | gameplay-programmer, game-designer | L |
| 6 | Networking Layer | MVP | Foundation | network-programmer, lead-programmer | L |
| 7 | Health & Death System | MVP | Core | gameplay-programmer | S |
| 8 | Player Spawning & Respawn | MVP | Core | network-programmer | S |
| 9 | State Synchronization | MVP | Core | network-programmer, godot-specialist | L |
| 10 | Procedural Generation System | MVP | Feature | gameplay-programmer, level-designer | M |
| 11 | Objective System | MVP | Feature | game-designer, gameplay-programmer | S |
| 12 | Escalation System | MVP | Feature | game-designer, gameplay-programmer | S |
| 13 | Extraction System | MVP | Feature | game-designer, gameplay-programmer | S |
| 14 | Solo/Co-op Scaling System | MVP | Feature | game-designer, network-programmer | S |
| 15 | Mission Debrief System | MVP | Feature | game-designer, ui-programmer | S |
| 16 | Tool Selection UI | MVP | Presentation | ui-programmer, ux-designer | S |
| 17 | HUD | MVP | Presentation | ui-programmer, ux-designer | S |
| 18 | Mission Debrief UI | MVP | Presentation | ui-programmer | S |
| 19 | Audio System | VS | Foundation | audio-director, sound-designer | M |
| 20 | Enemy & Hazard System | VS | Feature | gameplay-programmer, game-designer | L |
| 21 | Resource & Loot System | VS | Feature | game-designer, gameplay-programmer | M |
| 22 | Camera System | VS | Polish | gameplay-programmer | S |
| 23 | Visual Effects & Juice System | VS | Polish | gameplay-programmer, godot-shader-specialist | M |
| 24 | Lobby/Session UI | VS | Presentation | ui-programmer, network-programmer | M |
| 25 | Save/Load System | Alpha | Foundation | lead-programmer | M |
| 26 | Base Building System | Alpha | Feature | game-designer, gameplay-programmer | L |
| 27 | Upgrade & Unlock Tree | Alpha | Feature | game-designer, economy-designer | M |
| 28 | Base Persistence System | Alpha | Feature | lead-programmer | S |
| 29 | Lore Fragment System | Alpha | Feature | narrative-director, game-designer | S |
| 30 | Environmental Narrative System | Alpha | Feature | narrative-director, level-designer | M |
| 31 | Base Building UI | Alpha | Presentation | ui-programmer, ux-designer | M |
| 32 | Codex/Journal UI | Alpha | Presentation | ui-programmer | S |
| 33 | Main Menu & UI Flow | Alpha | Presentation | ui-programmer | S |
| 34 | Performance & LOD System | Full Vision | Polish | engine-programmer, godot-specialist | L |
| 35 | Settings & Options System | Full Vision | Polish | ui-programmer | S |
| 36 | Accessibility System | Full Vision | Polish | accessibility-specialist | M |

---

## Circular Dependencies

- None found. The dependency graph is acyclic.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **Networking Layer** | Technical | Physics networking in Godot 4 with 1–4 players is unproven at this scope — syncing real-time physics simulation across clients is hard | **Prototype first** in RIFT mini-game before committing to full architecture |
| **State Synchronization** | Technical | Physics state is continuous; naive sync causes jitter, desync, and cheating vectors | Use server-authoritative simulation; clients predict, server corrects; research Godot MultiplayerSynchronizer limits early |
| **Physics Tool System** | Design | Three tools (gravity, time, force) must each be independently satisfying AND combine well in co-op — high design iteration cost | Prototype solo first, then co-op; budget extra design iterations |
| **Procedural Generation System** | Design | Bad generation breaks immersion and pacing; quality control on random assembly is hard | Hand-craft rooms with explicit "tags" (connectors, size, hazard slots); validate procedural output with playtest-report |
| **Solo/Co-op Scaling System** | Design | Balancing for 1–4 players simultaneously without making any count feel under/over-powered is a known hard design problem | Design for solo first; layer co-op bonuses on top; test each player count explicitly |
| **Base Building System** | Scope | Physics-simulated base building (structures that react to real physics) is technically expensive and design-heavy | Scope fallback: base building is grid-snapped with visual physics only (no structural simulation) if real physics proves too costly |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 36 |
| Design docs started | 18 |
| Design docs reviewed | 0 |
| Design docs approved | 18 |
| MVP systems designed | 14 / 16 |
| MVP systems implemented | 13 / 16 (deferred: Networking Layer, State Sync, Solo/Co-op Scaling) |
| Vertical Slice systems designed | 0 / 7 |
| Alpha systems designed | 0 / 9 |
| Full Vision systems designed | 0 / 4 |

---

## Next Steps

- [ ] Design MVP systems in order (use `/design-system [system-name]`)
- [ ] **Highest priority**: Prototype Physics Tool System + Networking Layer early — these are the two biggest risks
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when all MVP systems are designed
- [ ] Run `/prototype physics-tools` to validate core mechanic before full design commitment
