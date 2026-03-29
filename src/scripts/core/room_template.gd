## RoomTemplate
## Attached to the root node of every room .tscn file.
## Provides typed access to connectors and spawn points for the Procedural Generator.
## The root node must have two children: Connectors/ and SpawnPoints/.

class_name RoomTemplate
extends Node3D

## Unique identifier for this room template (e.g. "medium_entrance_01").
@export var room_id: String = ""

## Broad category used by the catalogue for query filtering.
@export_enum("entrance", "exit", "corridor", "chamber", "hub", "cap") var room_type: String = "corridor"

## Rough physical footprint for AABB overlap checks during generation.
@export_enum("small", "medium", "large") var size_class: String = "medium"

## Half-extents of the room bounding box in metres (X, Y, Z).
## Must match the actual geometry. Used by ProceduralGenerator for overlap detection.
@export var aabb_half_extents: Vector3 = Vector3(4.0, 2.0, 4.0)

## Tags used to filter which rooms may follow which. The generator matches rooms
## whose tags intersect the open connector's tags.
@export var tags: Array[String] = ["standard"]

## Minimum number of connectors that must be satisfied (joined or capped).
@export var min_exits: int = 1

## Maximum number of connectors the generator will attempt to fill.
@export var max_exits: int = 4

## Relative probability weight for this room in the catalogue draw.
## Higher = more likely to be selected when multiple rooms match.
@export var weight: float = 1.0

# ── Public API ─────────────────────────────────────────────────────────────────

## Returns all RoomConnector children under the Connectors/ node.
## Iterates get_children() directly — works on templates not yet in the scene tree,
## where get_node_or_null() may not resolve relative paths.
func get_connectors() -> Array[RoomConnector]:
	var result: Array[RoomConnector] = []
	var connectors_node: Node = null
	for child in get_children():
		if child.name == &"Connectors":
			connectors_node = child
			break
	if connectors_node == null:
		push_warning("RoomTemplate '%s': missing Connectors/ child node." % room_id)
		return result
	for child in connectors_node.get_children():
		if child is RoomConnector:
			result.append(child as RoomConnector)
	return result

## Returns spawn point Marker3D nodes whose name contains spawn_type (case-insensitive).
## Pass "" to return all spawn points.
func get_spawn_points(spawn_type: String = "") -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	var spawn_points_node: Node = null
	for child in get_children():
		if child.name == &"SpawnPoints":
			spawn_points_node = child
			break
	if spawn_points_node == null:
		push_warning("RoomTemplate '%s': missing SpawnPoints/ child node." % room_id)
		return result
	var lower_type := spawn_type.to_lower()
	for child in spawn_points_node.get_children():
		if child is Marker3D:
			if lower_type == "" or child.name.to_lower().contains(lower_type):
				result.append(child as Marker3D)
	return result

## Returns the world-space AABB for this room at its current global_position.
func get_world_aabb() -> AABB:
	return AABB(global_position - aabb_half_extents, aabb_half_extents * 2.0)
