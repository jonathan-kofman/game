# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do three physics tools feel satisfying to use in a 3D environment?
# Date: 2026-03-25

extends Node

# ── Tuning knobs (hardcoded for prototype iteration) ──────────────────────────
const FORCE_PUSH_IMPULSE    := 18.0   # Newtons — tweak until it feels punchy
const TIME_SLOW_FACTOR      := 0.15   # 0.0–1.0 — how slow "slow" is
const TIME_SLOW_RADIUS      := 6.0    # metres — area of effect
const GRAVITY_FLIP_DURATION := 0.0   # 0 = permanent toggle; set >0 for timed

# ── State ─────────────────────────────────────────────────────────────────────
var _time_slow_active := false
var _slowed_bodies: Array[RigidBody3D] = []
var _saved_gravity_scale: Dictionary = {}  # body -> original gravity_scale
var _saved_linear_damp: Dictionary = {}    # body -> original linear_damp
var _flipped_bodies: Array[RigidBody3D] = []

@onready var player: CharacterBody3D = get_parent()
@onready var tool_label: Label = get_parent().get_node("Camera3D/CanvasLayer/ToolLabel")

# ── Tool 1: Gravity Flip ───────────────────────────────────────────────────────
func activate_gravity_flip(target: Node) -> void:
	if not target is RigidBody3D:
		_feedback("GRAVITY  ✗  aim at a physics object")
		return

	var body := target as RigidBody3D

	if body in _flipped_bodies:
		# Restore gravity
		body.gravity_scale = _saved_gravity_scale.get(body, 1.0)
		_flipped_bodies.erase(body)
		_saved_gravity_scale.erase(body)
		_feedback("GRAVITY  ↓  restored on " + body.name)
	else:
		# Flip gravity
		_saved_gravity_scale[body] = body.gravity_scale
		body.gravity_scale = -abs(body.gravity_scale)  # always flip to negative
		_flipped_bodies.append(body)
		_feedback("GRAVITY  ↑  flipped on " + body.name)

# ── Tool 2: Time Slow ─────────────────────────────────────────────────────────
func toggle_time_slow() -> void:
	_time_slow_active = not _time_slow_active

	if _time_slow_active:
		_begin_time_slow()
	else:
		_end_time_slow()

func _begin_time_slow() -> void:
	var origin := player.global_position
	var space := player.get_world_3d().direct_space_state

	# Sphere overlap query — find RigidBody3Ds within radius
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = TIME_SLOW_RADIUS
	query.shape = sphere
	query.transform = Transform3D(Basis(), origin)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := space.intersect_shape(query, 32)

	_slowed_bodies.clear()
	_saved_gravity_scale.clear()

	for result in results:
		var body = result["collider"]
		if body is RigidBody3D and body not in _flipped_bodies:
			var rb := body as RigidBody3D
			_slowed_bodies.append(rb)
			_saved_gravity_scale[rb] = rb.gravity_scale
			# Scale gravity and damp velocity
			rb.gravity_scale *= TIME_SLOW_FACTOR
			rb.linear_velocity *= TIME_SLOW_FACTOR
			rb.angular_velocity *= TIME_SLOW_FACTOR

	_feedback("TIME  ⏸  slowing %d objects" % _slowed_bodies.size())

func _end_time_slow() -> void:
	for body in _slowed_bodies:
		if is_instance_valid(body):
			body.gravity_scale = _saved_gravity_scale.get(body, 1.0)
			# Restore velocity (inverse of slow factor — felt more satisfying in tests)
			body.linear_velocity /= TIME_SLOW_FACTOR
			body.angular_velocity /= TIME_SLOW_FACTOR

	_slowed_bodies.clear()
	_saved_gravity_scale.clear()
	_feedback("TIME  ▶  released")

# ── Tool 3: Force Push ────────────────────────────────────────────────────────
func activate_force_push(target: Node, collision_normal: Vector3) -> void:
	if not target is RigidBody3D:
		_feedback("PUSH  ✗  aim at a physics object")
		return

	var body := target as RigidBody3D

	# Push direction: away from the surface the ray hit
	# If we hit a face-on, push straight away from player
	var push_dir: Vector3
	if collision_normal.length() > 0.1:
		push_dir = collision_normal
	else:
		push_dir = (body.global_position - player.global_position).normalized()

	body.apply_central_impulse(push_dir * FORCE_PUSH_IMPULSE)
	_feedback("PUSH  →  %.0f N on %s" % [FORCE_PUSH_IMPULSE, body.name])

# ── Helpers ───────────────────────────────────────────────────────────────────
func _feedback(text: String) -> void:
	print("[PhysicsTools] ", text)
	if is_instance_valid(tool_label):
		tool_label.text = text
