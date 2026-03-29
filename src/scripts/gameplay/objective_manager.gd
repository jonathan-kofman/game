## ObjectiveManager
## Tracks the active primary and secondary objectives for a mission run.
## Attach as a child of the Main scene node. Receives the FacilityGraph after
## generation and places objective targets into the world.
##
## MVP implements the Activate objective type only (interact with N terminals).
## Other types (Destroy, Retrieve, Eliminate, Survive) are stubs for future sprints.

class_name ObjectiveManager
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired whenever an objective's state changes.
signal objective_state_changed(objective_id: String, new_state: String)

## Fired when the primary objective reaches COMPLETE.
signal primary_objective_complete

# ── Enums ─────────────────────────────────────────────────────────────────────

enum ObjectiveType { ACTIVATE }
enum ObjectiveState { INACTIVE, ACTIVE, COMPLETE, FAILED }

# ── Inner class ───────────────────────────────────────────────────────────────

class ObjectiveData:
	var id: String = ""
	var type: ObjectiveType = ObjectiveType.ACTIVATE
	var state: ObjectiveState = ObjectiveState.INACTIVE
	var required_count: int = 1
	var current_count: int = 0

	func is_complete() -> bool:
		return state == ObjectiveState.COMPLETE

# ── Exports ───────────────────────────────────────────────────────────────────

@export_group("Activate Objective")
## Number of terminals the player must interact with to complete the primary objective.
@export var terminals_required: int = 1
## Scene path for the terminal to spawn in the objective room.
@export var terminal_scene_path: String = "res://scenes/gameplay/InteractableTerminal.tscn"

# ── State ─────────────────────────────────────────────────────────────────────

var primary_objective: ObjectiveData = null
var _is_primary_complete: bool = false

# ── Setup ─────────────────────────────────────────────────────────────────────

## Called by Main after the facility is generated.
## graph: the FacilityGraph; room_nodes: Array of instantiated RoomTemplate nodes
## (parallel to graph.placed_rooms).
func setup(graph: FacilityGraph, room_nodes: Array) -> void:
	primary_objective = ObjectiveData.new()
	primary_objective.id = "primary"
	primary_objective.type = ObjectiveType.ACTIVATE
	primary_objective.required_count = terminals_required
	primary_objective.state = ObjectiveState.ACTIVE

	# Find the objective room — prefer a chamber; fall back to any non-entrance/exit room
	var objective_room_node: RoomTemplate = _pick_objective_room(graph, room_nodes)
	if objective_room_node == null:
		push_warning("ObjectiveManager: no suitable objective room found; skipping terminal placement.")
		return

	_place_terminals(objective_room_node)
	objective_state_changed.emit("primary", "ACTIVE")
	print("[ObjectiveManager] Primary objective ACTIVE — activate %d terminal(s) in '%s'" \
		% [terminals_required, objective_room_node.room_id])

# ── Private ───────────────────────────────────────────────────────────────────

func _pick_objective_room(graph: FacilityGraph, room_nodes: Array) -> RoomTemplate:
	# First pass: prefer chamber or hub rooms that aren't entrance/exit
	for i in room_nodes.size():
		if i == graph.entrance_index or i == graph.exit_index:
			continue
		var node: Node = room_nodes[i]
		if node is RoomTemplate:
			var t := node as RoomTemplate
			if t.room_type in ["chamber", "hub"]:
				return t

	# Second pass: any non-entrance, non-exit room
	for i in room_nodes.size():
		if i == graph.entrance_index or i == graph.exit_index:
			continue
		var node: Node = room_nodes[i]
		if node is RoomTemplate:
			return node as RoomTemplate

	return null

func _place_terminals(room: RoomTemplate) -> void:
	# Try to load the terminal scene; fall back to a procedural terminal if missing
	var packed: PackedScene = null
	if ResourceLoader.exists(terminal_scene_path):
		packed = load(terminal_scene_path) as PackedScene

	for i in terminals_required:
		var terminal: InteractableTerminal
		if packed != null:
			terminal = packed.instantiate() as InteractableTerminal
		else:
			terminal = _build_terminal_procedurally()

		# Place at room centre + small offset per terminal
		var offset := Vector3(float(i) * 1.5 - (terminals_required - 1) * 0.75, 0.0, 0.0)
		get_parent().add_child(terminal)
		terminal.global_position = room.global_position + offset + Vector3(0.0, 0.9, 0.0)
		terminal.interacted.connect(_on_terminal_interacted)

func _build_terminal_procedurally() -> InteractableTerminal:
	var terminal := InteractableTerminal.new()

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.8, 0.2)
	col.shape = shape
	terminal.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.8, 0.2)
	mesh_inst.mesh = mesh
	terminal.add_child(mesh_inst)

	return terminal

func _on_terminal_interacted(_terminal: InteractableTerminal, _interactor: Node) -> void:
	if primary_objective == null or _is_primary_complete:
		return

	primary_objective.current_count += 1
	print("[ObjectiveManager] Terminal activated (%d / %d)" \
		% [primary_objective.current_count, primary_objective.required_count])

	if primary_objective.current_count >= primary_objective.required_count:
		primary_objective.state = ObjectiveState.COMPLETE
		_is_primary_complete = true
		objective_state_changed.emit("primary", "COMPLETE")
		primary_objective_complete.emit()
		print("[ObjectiveManager] Primary objective COMPLETE")
