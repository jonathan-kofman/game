# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6.1
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical only)
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Use Godot specialist agents: godot-specialist, godot-gdscript-specialist,
> godot-shader-specialist, godot-gdextension-specialist.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

## Active Development State

> **Read this before starting any session.** Also read `production/session-state/active.md`.

**Active Sprint**: Sprint 5 (in progress — 2026-03-27)
**Milestone**: milestone-01-mvp

### What Is Built (Sprint 3–5)

| System | File(s) | Status |
|--------|---------|--------|
| Procedural facility generation | `src/scripts/core/procedural_generator.gd`, `facility_graph.gd`, `room_catalogue.gd` | Complete |
| Room template base class | `src/scripts/core/room_template.gd` | Complete |
| Placeholder room scenes (7) | `src/assets/rooms/` | Complete |
| Room catalogue resource | `src/assets/data/room_catalogue.tres` | Complete |
| Character controller (FPS) | `src/scripts/core/character_controller.gd` | Complete |
| InteractableTerminal | `src/scripts/gameplay/interactable_terminal.gd` | Complete |
| ObjectiveManager | `src/scripts/gameplay/objective_manager.gd` | Complete |
| EscalationManager | `src/scripts/gameplay/escalation_manager.gd` | Complete |
| ExtractionZone | `src/scripts/gameplay/extraction_zone.gd` | Complete |
| Main scene (mission loop wired) | `src/scripts/core/main.gd` | Complete |
| PhysicsObject base script | `src/scripts/core/physics_object.gd` | Complete |
| Health & Death System | `src/scripts/core/health_component.gd` | Complete |
| BaseTool + 3 physics tools | `src/scripts/tools/` (base_tool, gravity_flip, time_slow, force_push) | Complete |
| ToolManager (wired in Player.tscn) | `src/scripts/tools/tool_manager.gd`, `src/scenes/gameplay/Player.tscn` | Complete |
| Ramp test scene (Time Slow validation) | `src/scenes/gameplay/RampTestRoom.tscn` | Built — needs playtest |

**Full run loop is code-complete**: `F5 → facility generated → interact terminal → escalation advances → extraction unlocks → channel 4s → run_succeeded`
**Physics tools complete**: G = gravity flip, T = time slow (hold), F = force push — all wired via ToolManager

### Design Progress

- **14 / 16 MVP** GDD sections designed — see `design/gdd/systems-index.md`
- Remaining gaps: Networking Layer, State Synchronization (deferred — prototype-first)
- All design docs: `design/gdd/`

### Physics Tools Prototype

Prototype at `prototypes/physics-tools/` — validated (PROCEED verdict). Production
implementation is in `src/scripts/tools/`. Prototype is reference-only.

### Collaboration Mode

The user works in **autonomous execution mode**: tasks are knocked out sequentially without
per-step approval. Still follow `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for design decisions
and multi-file changesets, but do not gate each file write on explicit confirmation during
an active sprint run.
