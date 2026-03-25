# GDD: Procedural Generation System

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 12 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: Room Template Data System
> **Required By**: Objective System, Lore Fragment System, Environmental Narrative System, Level Designer workflow

---

## 1. Overview

The Procedural Generation System assembles hand-crafted room templates into a
complete facility for each run. It queries the Room Catalogue for eligible rooms,
places them by matching connectors, and validates the result before handing off
to the Objective System. The generator is seed-based: the same seed always
produces the same facility, which is critical for co-op synchronisation. No
room layout is hardcoded — all structure comes from the room template metadata
and connector matching rules defined in the Room Template Data System GDD.

---

## 2. Player Fantasy

Every run feels like a real place that just happens to be new. The layout makes
spatial sense: you enter through a recognisable entrance, pass through corridors
and chambers, find a hub, and eventually locate the exit. Dead ends exist but
feel intentional. The player builds a mental map. The facility's mood is consistent
within a run — a reactor facility has reactor rooms, not random mismatched chunks.

---

## 3. Detailed Rules

### 3.1 Generation Algorithm (Depth-First Expansion)

The generator uses a depth-first room placement algorithm:

```
1. Place entrance room at origin (0, 0, 0).
2. Push all unconnected connectors of the entrance onto an open_connectors stack.
3. While open_connectors is not empty AND room_count < MAX_ROOMS:
   a. Pop a connector from the stack.
   b. Query the catalogue for eligible rooms (see 3.3).
   c. If no eligible room found: place a dead-end cap (small sealed room).
   d. Pick a room using weighted random selection (see §4).
   e. Pick a connector on the new room whose tags match the open connector.
   f. Align the new room so the two connectors face each other (see 3.4).
   g. Overlap-check: if the new room's AABB intersects any placed room, reject
      and try next candidate. If all candidates fail, place dead-end cap.
   h. Add the new room to placed_rooms.
   i. Push all remaining unconnected connectors of the new room onto the stack.
4. After loop: ensure exit room is placed. If no exit was placed during normal
   flow, force-place one at the farthest open connector from the entrance.
5. Return the completed room graph.
```

This algorithm guarantees the facility is fully connected and traversable —
every room can be reached from the entrance.

### 3.2 Facility Parameters

| Parameter | MVP Default | Notes |
|-----------|-------------|-------|
| `MIN_ROOMS` | 8 | Minimum rooms per facility |
| `MAX_ROOMS` | 16 | Maximum rooms before generator stops expanding |
| `SEED` | run-specific random int | Same seed = identical facility layout |
| Entrance rooms | Exactly 1 | Always placed first at origin |
| Exit rooms | Exactly 1 | Placed at farthest open connector if not placed naturally |
| Hub rooms | 0–2 | Spawned if catalogue has them and connector count allows |
| Dead-end caps | As needed | Small sealed rooms placed when no valid candidate exists |

### 3.3 Room Eligibility Query

Before picking a room, the generator filters the catalogue to eligible rooms:

```
eligible = rooms where ALL of:
  - room_type is in the allowed_types list for the current connector
  - At least one connector on the room has a matching tag (see 3.5)
  - room is not already used in this run (deduplication ON for MVP)
  - room is not the entrance or exit type (unless specifically needed)
```

`allowed_types` is determined by context:
- First 2 rooms after entrance: prefer `corridor` or `chamber`
- After a hub: any type
- When exit has not been placed and room_count > MIN_ROOMS: add `exit` to allowed_types
- Always: no second `entrance`

### 3.4 Room Alignment

To connect room B's connector `cb` to room A's open connector `ca`:

```
1. Compute the rotation that makes cb.direction == -ca.direction
   (they must face each other).
2. Rotate room B around its local origin by that rotation.
3. Compute the translation:
   position_B = position_A + ca.global_position - (rotation * cb.local_position)
4. Apply transform to room B's root node.
```

In Godot this is done by computing `Transform3D` for the room's root node before
instantiating, so the scene spawns at the correct world position and orientation.

### 3.5 Connector Tag Matching

Two connectors can join if:
1. Their `direction` vectors are opposite (dot product ≈ −1.0, within 0.01 tolerance).
2. Their `tags` arrays share at least one entry.

Example: connector with tags `["door", "large"]` can join with `["large", "corridor"]`
because they share `"large"`. It cannot join with `["door", "small"]` because the
directions would match but not the tags — wait, tags do share `"door"` so it would
connect. Tags are OR-matched: one shared tag is sufficient.

### 3.6 Overlap Detection

Before placing a room, the generator checks the room's AABB (axis-aligned bounding
box based on `size_class`) against all already-placed rooms. The AABB is padded
by 0.5 m on each side to prevent geometry from touching.

| size_class | AABB half-extents |
|------------|-------------------|
| small | 4 × 3 × 4 m |
| medium | 8 × 4 × 8 m |
| large | 12 × 5 × 12 m |

These are approximations — rooms may be non-rectangular. Godot's
`AABB.intersects()` is used for the check. False positives (rooms that could fit
but are rejected due to AABB approximation) are acceptable in MVP.

### 3.7 Room Graph Output

After generation, the system produces a `FacilityGraph` resource containing:
- Array of placed room instances (instantiated from PackedScenes)
- Dictionary mapping connector pairs to joined connector IDs
- Entrance room reference
- Exit room reference
- The seed used to generate this facility

The `FacilityGraph` is passed to the Objective System (to place objectives) and
the Lore Fragment System (to populate lore slots).

### 3.8 Dead-End Cap

A dead-end cap is a minimal room with one connector and no other exits. It
is used when the generator cannot find a valid room to place at an open connector.
The cap prevents open doorways leading to nothing. One universal cap scene covers
all connector sizes/tags in MVP (mismatched size creates visual interest — see
Room Template GDD §3.2).

Cap scene: `assets/rooms/corridor/small_cap_01.tscn`

---

## 4. Formulas

### Weighted Room Selection

```
# From Room Template Data System GDD §4:
P(room_i) = weight_i / sum(weight_j for all eligible rooms j)

Example: 3 eligible chambers with weights [1.0, 1.0, 2.0]
  sum = 4.0
  P(room_0) = 0.25
  P(room_1) = 0.25
  P(room_2) = 0.50
```

Selection is implemented with a single `rng.randf_range(0, total_weight)` call
and a linear scan of the cumulative weight array.

### Seed-Deterministic RNG

```
var rng := RandomNumberGenerator.new()
rng.seed = facility_seed

# All random choices use rng.randi_range() or rng.randf_range()
# No calls to randf() or randi() (global RNG is not seeded per-run)
```

The seed is generated at run start: `facility_seed = randi()` before passing
to the generator. In co-op, the server generates the seed and syncs it to clients
before generation begins (Networking Layer concern — not MVP scope).

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Room catalogue has fewer than MIN_ROOMS distinct rooms | Generator places duplicates until MIN_ROOMS is reached. Log a warning. |
| All candidate rooms fail overlap check | Place dead-end cap. Do not retry indefinitely — after 10 candidates, cap it. |
| No exit room in catalogue | Generator cannot place an exit. Log error, show "Facility error — no exit room." Stop the run. |
| Generator hits MAX_ROOMS before a natural exit placement | Force-place exit at the farthest open connector from entrance. |
| Seed produces a valid but unplayable layout (e.g. exit adjacent to entrance) | Acceptable for MVP — layout is valid by the algorithm's rules. Add a minimum distance check (exit must be ≥ 4 rooms from entrance) in Vertical Slice. |
| RoomConnector direction is not exactly normalised | Normalise before dot product check. If magnitude differs by > 0.01, log warning (from Room Template GDD §5). |
| Two rooms aligned correctly but geometrically intersecting (non-AABB shapes) | AABB check is an approximation. Penetration is acceptable for MVP. Fix with tighter bounds or physics-based validation in Vertical Slice. |
| room_catalogue.tres is missing | Game cannot start a run. Show error screen: "Room catalogue missing." (From Room Template GDD §5). |

---

## 6. Dependencies

- **Depends on**:
  - Room Template Data System (provides room catalogue, connector schema, metadata)

- **Required by**:
  - Objective System (reads facility graph to place objectives in rooms)
  - Lore Fragment System (reads LoreSlots from generated rooms)
  - Environmental Narrative System (reads room tags for context)
  - Level Designer workflow (hand-crafted rooms must pass generator integration test)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `MIN_ROOMS` | procedural_generator.gd | 8 | 5–12 | Minimum facility size — smaller = faster runs |
| `MAX_ROOMS` | procedural_generator.gd | 16 | 10–30 | Maximum facility size — larger = longer runs |
| `AABB_PADDING` | procedural_generator.gd | 0.5 m | 0.0–2.0 | Overlap rejection padding — higher = more sparse layouts |
| `MAX_PLACEMENT_ATTEMPTS` | procedural_generator.gd | 10 | 5–20 | Candidate tries before capping — higher = fewer dead ends |
| Room weights | room_template.gd per room | 1.0 | 0.1–5.0 | Relative frequency of specific rooms in generated facilities |

---

## 8. Acceptance Criteria

- [ ] Generator produces a facility with at least `MIN_ROOMS` rooms from a given seed
- [ ] Same seed always produces the same facility (determinism test: run generator twice with seed 12345, compare room IDs in order)
- [ ] Facility always has exactly 1 entrance and exactly 1 exit
- [ ] All rooms in the facility are reachable from the entrance (connectivity test: BFS from entrance visits all rooms)
- [ ] No two placed rooms overlap (AABB intersection check passes for all room pairs)
- [ ] Generator completes within 100ms for a 16-room facility on a mid-range PC
- [ ] If room catalogue contains 1 entrance, 1 exit, 2 corridors, 2 chambers: generator still produces a valid 8-room facility (minimum viable catalogue test)
- [ ] Open connectors with no valid candidate receive a dead-end cap, not an open doorway
