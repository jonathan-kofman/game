## RoomCatalogue
## Resource holding the full list of room template scene paths.
## The Procedural Generator queries this to find rooms that satisfy connector constraints.
## Load once at startup; keep a single shared instance via RoomCatalogue.tres.

class_name RoomCatalogue
extends Resource

## All known room template paths, grouped by type for fast lookup.
## Paths are res:// URIs to .tscn files.
@export var entrance_rooms: Array[String] = []
@export var exit_rooms: Array[String] = []
@export var corridor_rooms: Array[String] = []
@export var chamber_rooms: Array[String] = []
@export var hub_rooms: Array[String] = []
@export var cap_rooms: Array[String] = []

# ── Public API ─────────────────────────────────────────────────────────────────

## Returns all room paths whose type matches the given type string.
## Valid types: "entrance", "exit", "corridor", "chamber", "hub", "cap".
func get_rooms_by_type(type: String) -> Array[String]:
	match type:
		"entrance": return entrance_rooms
		"exit":     return exit_rooms
		"corridor": return corridor_rooms
		"chamber":  return chamber_rooms
		"hub":      return hub_rooms
		"cap":      return cap_rooms
	push_warning("RoomCatalogue.get_rooms_by_type: unknown type '%s'" % type)
	return []

## Returns all rooms across all types.
func get_all_rooms() -> Array[String]:
	var all: Array[String] = []
	all.append_array(entrance_rooms)
	all.append_array(exit_rooms)
	all.append_array(corridor_rooms)
	all.append_array(chamber_rooms)
	all.append_array(hub_rooms)
	all.append_array(cap_rooms)
	return all

## Returns all non-entrance, non-exit rooms — the pool used for general expansion.
func get_filler_rooms() -> Array[String]:
	var filler: Array[String] = []
	filler.append_array(corridor_rooms)
	filler.append_array(chamber_rooms)
	filler.append_array(hub_rooms)
	return filler
