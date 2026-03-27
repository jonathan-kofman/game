# Milestone 2: RIFT Vertical Slice

> **Target**: Month 5 (≈ 2026-08-25)
> **Status**: Planned
> **Predecessor**: milestone-01-mvp

## Goal

A polished, shippable solo run of RIFT that is worth playing as a standalone
experience. Enemies patrol the facility and react to the player. Physics tools
interact with enemies and hazards. Audio gives every action weight. The camera
feels alive. One complete, juiced breach run — the RIFT mini-game is shippable.

## Exit Criteria

- [ ] At least 1 enemy type (patrol guard) present and functional in generated facilities
- [ ] At least 2 hazard types (alarm laser, pressure plate) placed by procedural generator
- [ ] All 3 physics tools interact with enemies and hazards in documented ways
- [ ] Audio plays for all tool activations, escalation changes, terminal interaction, and extraction
- [ ] Escalation music layers audibly change across all 4 levels
- [ ] Camera headbob active during movement; camera shake fires on tool use and damage
- [ ] Full run loop plays at 60fps with enemies + 10+ physics objects active
- [ ] No S1 bugs in critical path (spawn → tools → enemies → objective → extract → debrief)

## Systems Required

| System | Status Entering VS |
|--------|-------------------|
| Enemy & Hazard System | Design pending (S7-04) |
| Audio System | Design pending (S7-05) |
| Camera System | Design pending (S7-07) |
| Visual Effects & Juice System | Not started |
| Resource & Loot System | Not started (stubs OK) |

All MVP systems already complete — see milestone-01-mvp.md.

## Milestones Before This

milestone-01-mvp — solo run loop without enemies or audio.

## Risks

- Enemy AI performance at 60fps with Jolt physics (MEDIUM)
- Audio system integration complexity in Godot 4.6 (LOW)
- Scope expansion: resist adding second enemy archetype until all 8 VS criteria are met (MEDIUM)
- Procedural generator must reliably place enemies and hazards in reachable rooms (MEDIUM)
