## FacilityGraph
## Resource produced by ProceduralGenerator.
## Stores the complete description of a generated facility: which rooms were placed,
## how they connect, and which nodes are entrance/exit.
## Serialisable — can be saved to disk for replay or seed verification.

class_name FacilityGraph
extends Resource

## The seed used to generate this facility. Same seed → same graph.
@export var facility_seed: int = 0

## Ordered list of placed room scene paths (res:// URIs).
## Index matches placed_transforms and placed_ids.
@export var placed_rooms: Array[String] = []

## World-space transforms for each placed room (parallel array to placed_rooms).
@export var placed_transforms: Array[Transform3D] = []

## Unique instance IDs assigned during generation (parallel array).
@export var placed_ids: Array[int] = []

## Adjacency list: maps placed_id → Array of connected placed_ids.
## Serialised as a flat Array[int] of pairs [from_id, to_id, from_id, to_id, ...].
@export var connection_pairs: Array[int] = []

## Index into placed_rooms for the entrance room.
@export var entrance_index: int = -1

## Index into placed_rooms for the exit room.
@export var exit_index: int = -1

# ── Public API ─────────────────────────────────────────────────────────────────

## Adds a placed room and returns its assigned index.
func add_room(scene_path: String, world_transform: Transform3D, instance_id: int) -> int:
	placed_rooms.append(scene_path)
	placed_transforms.append(world_transform)
	placed_ids.append(instance_id)
	return placed_rooms.size() - 1

## Records a bidirectional connection between two placed room indices.
func add_connection(index_a: int, index_b: int) -> void:
	connection_pairs.append(index_a)
	connection_pairs.append(index_b)

## Returns all room indices connected to the given index.
func get_connections(room_index: int) -> Array[int]:
	var result: Array[int] = []
	var i := 0
	while i < connection_pairs.size():
		var a := connection_pairs[i]
		var b := connection_pairs[i + 1]
		if a == room_index:
			result.append(b)
		elif b == room_index:
			result.append(a)
		i += 2
	return result

## Returns the total number of placed rooms.
func room_count() -> int:
	return placed_rooms.size()
