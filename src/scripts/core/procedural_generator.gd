## ProceduralGenerator
## Assembles a playable facility from room templates using a depth-first expansion
## algorithm. Given a seed, always produces the same layout (deterministic).
##
## Algorithm overview:
##   1. Place entrance room at the world origin.
##   2. Push all open (unconnected) connectors onto a stack.
##   3. While rooms_placed < MAX_ROOMS and stack is not empty:
##      a. Pop a connector.
##      b. Pick a compatible room from the catalogue (weighted random).
##      c. Align the room so its chosen connector faces the open connector.
##      d. AABB overlap check; retry up to MAX_ATTEMPTS times.
##      e. On success: instantiate, record in graph, push new open connectors.
##   4. When MAX_ROOMS approached (≥ MIN_EXIT_AFTER rooms), place exit instead of filler.
##   5. Cap any remaining open connectors with cap rooms.

class_name ProceduralGenerator
extends Node

# ── Constants ──────────────────────────────────────────────────────────────────

const MIN_ROOMS: int = 8
const MAX_ROOMS: int = 16
const MAX_ATTEMPTS: int = 10
const AABB_PADDING: float = 0.0

## Fraction of MAX_ROOMS after which an exit room is eligible.
const MIN_EXIT_AFTER: float = 0.5

# ── Exports ────────────────────────────────────────────────────────────────────

## Path to the RoomCatalogue .tres resource.
@export var catalogue_path: String = "res://assets/data/room_catalogue.tres"

# ── State ──────────────────────────────────────────────────────────────────────

var _catalogue: RoomCatalogue = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _placed_aabbs: Array[AABB] = []
var _graph: FacilityGraph = null
var _open_stack: Array[Dictionary] = []  # { connector: RoomConnector, room_index: int }

# ── Public API ─────────────────────────────────────────────────────────────────

## Generates a facility and returns a FacilityGraph resource.
## Pass seed=0 to use a random seed (stored in graph.facility_seed).
## The caller is responsible for instantiating scenes from the graph.
func generate(seed_value: int = 0) -> FacilityGraph:
	_catalogue = load(catalogue_path) as RoomCatalogue
	if _catalogue == null:
		push_error("ProceduralGenerator: failed to load catalogue at '%s'" % catalogue_path)
		return null

	_graph = FacilityGraph.new()
	_placed_aabbs.clear()
	_open_stack.clear()

	if seed_value == 0:
		seed_value = randi()
	_rng.seed = seed_value
	_graph.facility_seed = seed_value

	# Step 1: place entrance at origin
	var entrance_paths := _catalogue.get_rooms_by_type("entrance")
	if entrance_paths.is_empty():
		push_error("ProceduralGenerator: catalogue has no entrance rooms.")
		return null

	var entrance_path := entrance_paths[_rng.randi() % entrance_paths.size()]
	var entrance_template := _load_template(entrance_path)
	if entrance_template == null:
		push_error("ProceduralGenerator: could not load entrance template '%s'." % entrance_path)
		return null

	var entrance_transform := Transform3D.IDENTITY
	var entrance_index := _graph.add_room(entrance_path, entrance_transform, 0)
	_graph.entrance_index = entrance_index
	_register_aabb(entrance_template, entrance_transform)
	_push_connectors(entrance_template, entrance_transform, entrance_index)

	# Step 2–3: expand depth-first
	var exit_placed := false
	while not _open_stack.is_empty() and _graph.room_count() < MAX_ROOMS:
		var open := _open_stack.pop_back() as Dictionary
		var parent_connector := open["connector"] as RoomConnector
		var parent_index := open["room_index"] as int

		# Decide what to place next
		var candidate_path: String = ""
		var is_exit_attempt := false

		var rooms_placed := _graph.room_count()
		var exit_eligible := rooms_placed >= int(MAX_ROOMS * MIN_EXIT_AFTER)
		# One slot before MAX_ROOMS, force exit if not yet placed
		var must_exit := not exit_placed and rooms_placed >= MAX_ROOMS - 1

		if must_exit or (exit_eligible and not exit_placed and _rng.randf() < 0.25):
			candidate_path = _pick_from(_catalogue.get_rooms_by_type("exit"))
			is_exit_attempt = candidate_path != ""

		if candidate_path == "":
			candidate_path = _pick_from(_catalogue.get_filler_rooms())

		if candidate_path == "":
			# Nothing available — place a cap
			candidate_path = _pick_from(_catalogue.get_rooms_by_type("cap"))
			if candidate_path == "":
				continue

		# Try to place the candidate up to MAX_ATTEMPTS times
		var placed := false
		for _attempt in range(MAX_ATTEMPTS):
			var candidate_template := _load_template(candidate_path)
			if candidate_template == null:
				break

			# Find a compatible connector on the candidate
			var join_connector := _find_compatible(candidate_template, parent_connector)
			if join_connector == null:
				break  # No compatible connector — this room type cannot join here

			# Compute transform that aligns join_connector to face parent_connector
			var world_transform := _compute_alignment(
				parent_connector, join_connector, candidate_template)

			# AABB overlap check
			if _overlaps_any(candidate_template, world_transform):
				continue  # Try a different room from filler pool on next attempt if possible
				# (for MVP we just retry the same room; full impl would draw another)

			# Accepted
			var room_index := _graph.add_room(candidate_path, world_transform,
				rooms_placed)  # instance_id = placed count at time of placement
			_graph.add_connection(parent_index, room_index)
			_register_aabb(candidate_template, world_transform)
			_push_connectors(candidate_template, world_transform, room_index)

			if is_exit_attempt:
				_graph.exit_index = room_index
				exit_placed = true

			placed = true
			break

		if not placed:
			# Could not fit any room — place a cap to seal the connector
			var cap_path := _pick_from(_catalogue.get_rooms_by_type("cap"))
			if cap_path != "":
				var cap_template := _load_template(cap_path)
				if cap_template != null:
					var cap_join := _find_compatible(cap_template, parent_connector)
					if cap_join != null:
						var cap_transform := _compute_alignment(parent_connector, cap_join, cap_template)
						if not _overlaps_any(cap_template, cap_transform):
							var cap_index := _graph.add_room(cap_path, cap_transform, _graph.room_count())
							_graph.add_connection(parent_index, cap_index)
							_register_aabb(cap_template, cap_transform)
							# Caps have no open connectors — intentionally not pushed

	# Ensure exit was placed
	if not exit_placed:
		push_warning("ProceduralGenerator: exit room could not be placed (seed=%d)." % seed_value)

	return _graph

# ── Private helpers ────────────────────────────────────────────────────────────

func _load_template(scene_path: String) -> RoomTemplate:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("ProceduralGenerator: could not load scene '%s'" % scene_path)
		return null
	var instance := packed.instantiate()
	if instance is RoomTemplate:
		return instance as RoomTemplate
	instance.queue_free()
	push_warning("ProceduralGenerator: root node of '%s' is not a RoomTemplate" % scene_path)
	return null

## Picks a random path from an array using uniform distribution.
## Returns "" if the array is empty.
func _pick_from(paths: Array[String]) -> String:
	if paths.is_empty():
		return ""
	return paths[_rng.randi() % paths.size()]

## Returns the first connector on template that can join with open_connector.
func _find_compatible(template: RoomTemplate, open_connector: RoomConnector) -> RoomConnector:
	for c in template.get_connectors():
		if c.can_join(open_connector):
			return c
	return null

## Computes the world Transform3D such that join_connector (on template) is aligned
## to open_connector (already placed in the world, world-space position known).
##
## Strategy (axis-aligned MVP):
##   • Rotate the template so join_connector.direction faces opposite to open_connector.direction.
##   • Translate so the connector positions coincide.
func _compute_alignment(open_connector: RoomConnector,
		join_connector: RoomConnector,
		_template: RoomTemplate) -> Transform3D:

	# Direction the open connector is pointing (world space = local space for our
	# axis-aligned rooms; no rotation on placed rooms yet at MVP).
	var open_dir: Vector3 = open_connector.direction
	# The join connector must face the opposite direction.
	var desired_join_dir: Vector3 = -open_dir

	# Current direction of the join connector in template-local space.
	var local_join_dir: Vector3 = join_connector.direction

	# Rotation needed to turn local_join_dir into desired_join_dir.
	var rot := Basis()
	if local_join_dir.is_equal_approx(desired_join_dir):
		rot = Basis()
	elif local_join_dir.is_equal_approx(-desired_join_dir):
		# 180° rotation around Y
		rot = Basis(Vector3.UP, PI)
	else:
		rot = Basis(local_join_dir.cross(desired_join_dir).normalized(),
			local_join_dir.angle_to(desired_join_dir))

	# Position: move template so join_connector lands on open_connector's world pos.
	# join_connector.position is in template-local space.
	var rotated_join_pos: Vector3 = rot * join_connector.position
	var open_world_pos: Vector3 = open_connector.global_position \
		if open_connector.is_inside_tree() else open_connector.position

	var template_origin: Vector3 = open_world_pos - rotated_join_pos

	return Transform3D(rot, template_origin)

func _register_aabb(template: RoomTemplate, world_transform: Transform3D) -> void:
	var center := world_transform.origin
	var half := template.aabb_half_extents + Vector3.ONE * AABB_PADDING
	_placed_aabbs.append(AABB(center - half, half * 2.0))

func _overlaps_any(template: RoomTemplate, world_transform: Transform3D) -> bool:
	var center := world_transform.origin
	var half := template.aabb_half_extents + Vector3.ONE * AABB_PADDING
	var candidate := AABB(center - half, half * 2.0)
	for placed in _placed_aabbs:
		if placed.intersects(candidate):
			return true
	return false

## Pushes all unconnected connectors on template onto the open stack.
func _push_connectors(template: RoomTemplate, world_transform: Transform3D,
		room_index: int) -> void:
	for connector in template.get_connectors():
		if not connector.is_joined:
			# Temporarily set global_position for use in _compute_alignment later.
			# Since template is not in the scene tree, we store world position in a
			# helper by applying the transform to the connector's local position.
			var world_connector_pos := world_transform * connector.position
			var world_connector := connector.duplicate() as RoomConnector
			world_connector.position = world_connector_pos
			# Direction must also be rotated into world space.
			world_connector.direction = (world_transform.basis * connector.direction).normalized()
			_open_stack.push_back({ "connector": world_connector, "room_index": room_index })
