## TimeSlowTool
## Hold T to slow all PhysicsObjects within TIME_SLOW_RADIUS metres.
## Uses gravity_scale scaling + linear_damp to create the slow effect.
## This approach wakes Jolt-sleeping bodies — unlike velocity scaling (prototype failure).

class_name TimeSlowTool
extends BaseTool

# ── Tuning knobs ─────────────────────────────────────────────────────────────

## How slow "slow" is. 0.15 = 15% of normal gravity. Tune upward if barely visible.
@export var time_slow_factor: float = 0.15

## linear_damp applied to bleed off existing momentum. 8.0 = ~98% gone in 0.5s.
@export var high_damp_value: float = 8.0

## Radius in metres for the area-of-effect query.
@export var radius: float = 6.0

# ── State ─────────────────────────────────────────────────────────────────────

var _slowed_objects: Array[PhysicsObject] = []

# ── BaseTool interface ────────────────────────────────────────────────────────

## target and normal are unused — time slow is area-of-effect, not targeted.
func activate(_target: Node, _normal: Vector3) -> void:
	if is_active:
		return  # Already slowing

	_begin_time_slow()

func deactivate() -> void:
	if not is_active:
		return

	_end_time_slow()

# ── Private ───────────────────────────────────────────────────────────────────

func _begin_time_slow() -> void:
	var player := get_parent().get_parent()  # ToolManager -> Player
	if player == null:
		_fail("could not find player node")
		return

	var origin: Vector3 = player.global_position
	var space := player.get_world_3d().direct_space_state

	var sphere := SphereShape3D.new()
	sphere.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), origin)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 2  # layer 2: physics_objects only

	var results := space.intersect_shape(query, 64)

	_slowed_objects.clear()

	for result in results:
		var obj := get_physics_object(result["collider"])
		if obj != null:
			_slowed_objects.append(obj)
			obj.apply_time_slow(time_slow_factor, high_damp_value)

	is_active = true
	tool_activated.emit(name, null)
	print("[TimeSlowTool] slowing %d objects" % _slowed_objects.size())

func _end_time_slow() -> void:
	for obj in _slowed_objects:
		if is_instance_valid(obj):
			obj.remove_time_slow()

	_slowed_objects.clear()
	is_active = false
	tool_deactivated.emit(name)
	print("[TimeSlowTool] released")
