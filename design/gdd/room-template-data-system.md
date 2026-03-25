# GDD: Room Template Data System

> **Status**: Approved
> **Created**: 2026-03-25
> **System ID**: 4 (see systems-index.md)
> **Priority**: MVP
> **Depends On**: nothing
> **Required By**: Procedural Generation System, Lore Fragment System, Environmental Narrative System

---

## 1. Overview

The Room Template Data System defines the schema for hand-crafted room modules
that the Procedural Generation System assembles into facilities. Each room is a
Godot scene file with a standardised set of metadata: size, connector positions,
tags (room type, hazard slots, lore slots), and spawn markers. The Procedural
Generator never hard-codes room layouts — it queries this schema to select and
connect rooms at runtime. The system enforces that all rooms speak the same
structural language, so assembly is always valid.

---

## 2. Player Fantasy

Every run feels like a different facility, but never random garbage. Rooms feel
hand-crafted and intentional. Corridors connect logically. Rooms have a sense
of purpose (lab, storage, reactor, corridor). The player believes a real place
exists behind the randomness.

---

## 3. Detailed Rules

### 3.1 Room Template Scene Structure

Each room template is a Godot PackedScene (`.tscn`) with this root node tree:

```
Node3D  [name: RoomTemplate, script: room_template.gd]
├── Geometry/          (Node3D — all StaticBody3D walls, floor, ceiling)
├── Connectors/        (Node3D — all RoomConnector marker nodes)
├── SpawnPoints/       (Node3D — all Marker3D spawn positions)
├── HazardSlots/       (Node3D — Marker3D positions where hazards can spawn)
├── LoreSlots/         (Node3D — Marker3D positions where lore fragments can spawn)
└── PhysicsObjects/    (Node3D — pre-placed RigidBody3D objects)
```

### 3.2 RoomConnector Marker

Each connector is a `Marker3D` with a script that defines:

| Property | Type | Description |
|----------|------|-------------|
| `connector_id` | String | Unique ID within the room (e.g. "north_a") |
| `direction` | Vector3 | Unit vector pointing outward through the opening |
| `size` | Vector2 | Opening width × height in metres |
| `tags` | Array[String] | e.g. `["door", "large"]` — must match to connect |

Two connectors can join if: their `direction` vectors are opposite AND their
`tags` share at least one entry. Size mismatch is a warning, not an error (for
MVP — mismatched openings create interesting geometry).

### 3.3 Room Metadata (room_template.gd properties)

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `room_id` | String | Yes | Unique identifier (e.g. "storage_medium_01") |
| `room_type` | String | Yes | One of: `corridor`, `chamber`, `hub`, `entrance`, `exit` |
| `size_class` | String | Yes | One of: `small`, `medium`, `large` |
| `tags` | Array[String] | Yes | Descriptive tags: `["lab", "hazardous", "dark"]` |
| `min_exits` | int | Yes | Minimum connectors the generator must use |
| `max_exits` | int | Yes | Maximum connectors the generator may use |
| `weight` | float | Yes | Relative spawn probability (1.0 = normal) |

### 3.4 Spawn Point Types

Spawn points are `Marker3D` nodes with a `spawn_type` metadata key:

| spawn_type | Used By |
|------------|---------|
| `"player"` | Player Spawning & Respawn system |
| `"enemy"` | Enemy & Hazard System (Vertical Slice) |
| `"loot"` | Resource & Loot System (Vertical Slice) |

### 3.5 Room Type Roles

| room_type | Description | Required Count |
|-----------|-------------|----------------|
| `entrance` | Where the team starts the run | Exactly 1 per facility |
| `exit` | Extraction point | Exactly 1 per facility |
| `hub` | Large open space, multiple exits | 0–2 per facility |
| `chamber` | Self-contained room with 1–3 exits | 2–6 per facility |
| `corridor` | Connects two rooms, 2 exits minimum | As needed |

### 3.6 File Naming Convention

```
assets/rooms/[type]/[size]_[descriptor]_[variant].tscn

Examples:
  assets/rooms/chamber/medium_storage_01.tscn
  assets/rooms/corridor/small_straight_01.tscn
  assets/rooms/hub/large_reactor_01.tscn
  assets/rooms/entrance/medium_entrance_01.tscn
```

### 3.7 Room Catalogue File

A single resource file at `assets/rooms/room_catalogue.tres` stores:
- An array of all room template paths
- Pre-computed metadata (type, size, tags, weight) for fast querying
- Updated manually when new rooms are added (automated in Vertical Slice)

---

## 4. Formulas

### Room Selection Probability

```
P(room_i) = weight_i / sum(weight_j for all valid rooms j)

valid rooms = rooms where:
  - room_type matches requested type
  - size_class matches requested size (or "any")
  - not already used in this run (if deduplication is on)
```

Example: 3 chambers with weights [1.0, 1.0, 2.0] → probabilities [25%, 25%, 50%].

---

## 5. Edge Cases

| Situation | Behaviour |
|-----------|-----------|
| Catalogue has no room matching requested type | Procedural Generator logs error and falls back to `chamber` type |
| Room has 0 connectors in `Connectors/` | Room is invalid — skip and log warning. Cannot be placed. |
| Connector direction is not a unit vector | Normalise at load time. Log warning if magnitude differs from 1.0 by >0.01. |
| Two connectors in same room point same direction | Valid — generator may use either one. Both are offered. |
| room_catalogue.tres is missing | Game cannot start a run. Show error screen: "Room catalogue missing." |
| New room added but catalogue not updated | Room will never spawn. This is intentional for MVP — manual catalogue update required. |

---

## 6. Dependencies

- **Depends on**: Nothing — this is a foundation system.
- **Required by**:
  - Procedural Generation System (queries room catalogue, instantiates templates)
  - Lore Fragment System (reads LoreSlots from instantiated rooms)
  - Environmental Narrative System (reads room tags for context-appropriate storytelling)
  - Level Designer workflow (creates and validates room template scenes)

---

## 7. Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `weight` per room | room_template.gd | 1.0 | 0.1–5.0 | Relative spawn frequency — increase for "hero" rooms |
| `min_exits` | room_template.gd | 1 | 1–4 | Minimum connections the generator must make |
| `max_exits` | room_template.gd | 4 | 1–8 | Maximum connections — higher = more branching |

---

## 8. Acceptance Criteria

- [ ] At least 1 room of each `room_type` exists in the catalogue (5 rooms minimum for first playtest)
- [ ] Each room template has at least 1 `player` spawn point
- [ ] All `RoomConnector` nodes have valid `direction` unit vectors (test with a validator script)
- [ ] `room_catalogue.tres` loads without error in Godot 4.6
- [ ] Procedural Generation System can instantiate any room from the catalogue without errors
- [ ] Room naming convention is followed for all files in `assets/rooms/`
