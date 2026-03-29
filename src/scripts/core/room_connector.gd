## RoomConnector
## Marker3D placed inside a room template's Connectors/ node.
## Defines an opening that the Procedural Generator uses to join rooms.
## Two connectors can join if their directions are opposite AND tags overlap.

class_name RoomConnector
extends Marker3D

## Unique ID within the room (e.g. "north_a", "south_b").
@export var connector_id: String = ""

## Unit vector pointing outward through the opening (room-local space).
## Normalised at _ready(). (0,0,-1) = north, (0,0,1) = south, (1,0,0) = east.
@export var direction: Vector3 = Vector3(0.0, 0.0, -1.0)

## Opening width × height in metres.
@export var size: Vector2 = Vector2(2.0, 2.4)

## Tags for connector matching. Two connectors join if they share ≥1 tag.
@export var tags: Array[String] = ["door"]

## True once the generator has connected this connector to another room.
var is_joined: bool = false

func _ready() -> void:
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	else:
		push_warning("RoomConnector '%s' in '%s': direction is zero vector." % [connector_id, get_parent().get_parent().name])
		direction = Vector3(0.0, 0.0, -1.0)

## Returns true if this connector can join with another connector.
## Checks opposite direction and shared tag.
func can_join(other: RoomConnector) -> bool:
	var dot := direction.dot(other.direction)
	if abs(dot - (-1.0)) > 0.02:  # must be facing each other
		return false
	for tag in tags:
		if tag in other.tags:
			return true
	return false
