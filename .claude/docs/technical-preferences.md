# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.1
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical systems only)
- **Rendering**: Forward+ (3D default; use Mobile renderer for mobile targets)
- **Physics**: Jolt Physics (integrated in 4.4+, preferred for 3D — better performance and stability than default Godot Physics)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `apply_force()`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `tool_activated`)
- **Files**: snake_case matching class name (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`, `GRAVITY_SCALE`)
- **Enums**: PascalCase name, UPPER_SNAKE_CASE values (e.g., `enum ToolType { GRAVITY_FLIP, TIME_SLOW, FORCE_PUSH }`)

## Performance Budgets

- **Target Framerate**: 60fps (PC/Console), 30fps (Mobile)
- **Frame Budget**: 16.6ms (PC), 33.3ms (Mobile)
- **Draw Calls**: [TO BE CONFIGURED — set after art style prototype]
- **Memory Ceiling**: [TO BE CONFIGURED — set after first profiling pass]

## Networking

- **Architecture**: Client-Server (dedicated or listen server)
- **Sync Method**: Godot MultiplayerSynchronizer + @rpc annotations
- **Physics Authority**: Server-authoritative for all physics simulation
- **Player Count**: 1–4 players
- **Note**: Physics networking is the #1 technical risk — validate with RIFT mini-game prototype before committing to full architecture

## Testing

- **Framework**: GUT (Godot Unit Testing) — https://github.com/bitwes/Gut
- **Minimum Coverage**: Core game systems (tools, mission loop, base building)
- **Required Tests**: Physics tool interactions, networking sync, procedural generation determinism

## Forbidden Patterns

- No `get_node()` paths as strings in game logic — use typed `@onready` vars or signals
- No physics simulation on clients — server-authoritative only
- No blocking operations on the main thread — use async/await or threads
- No hardcoded level data — all rooms must be data-driven for procedural assembly

## Allowed Libraries / Addons

- **GUT** — Godot Unit Testing framework
- **Jolt Physics** — built into Godot 4.4+ (enable in Project Settings > Physics)
- [Additional addons to be approved via /architecture-decision]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]
