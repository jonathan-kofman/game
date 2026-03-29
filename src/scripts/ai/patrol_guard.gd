## PatrolGuard
## CharacterBody3D enemy — patrols fixed waypoints, detects the player via a
## proximity cone + line-of-sight raycast, and pursues using direct-vector
## movement (no NavigationAgent3D in VS — see sprint-08 risk note).
##
## State machine: PATROL → ALERT → PURSUE → STUNNED.
## Physics tool interactions (called by tool scripts):
##   apply_gravity_flip()          — GravityFlipTool
##   apply_force_push(dir, force)  — ForcePushTool
##   apply_time_slow() / remove_time_slow() — TimeSlowTool
##
## Call setup(player, escalation) after adding to the scene tree.
##
## TODO: Replace direct pursuit vector with NavigationAgent3D post-Vertical Slice.

class_name PatrolGuard
extends CharacterBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired on PATROL → ALERT. EscalationManager calls on_enemy_alerted().
signal guard_alerted(guard: PatrolGuard)

## Fired on PURSUE → PATROL (player lost).
signal guard_lost_player(guard: PatrolGuard)

## Fired on any stun entry (refresh also fires).
signal guard_stunned(guard: PatrolGuard)

# ── Enum ──────────────────────────────────────────────────────────────────────

enum State { PATROL, ALERT, PURSUE, STUNNED }

# ── Tuning knobs ──────────────────────────────────────────────────────────────

@export_group("Patrol")
## World-space waypoints. Guard cycles through them in order.
@export var patrol_waypoints: Array[Vector3] = []
## Horizontal movement speed while patrolling (m/s). GDD default: 2.5.
@export var patrol_speed: float = 2.5
## Flat distance at which a waypoint is considered reached (m).
@export var waypoint_reach_dist: float = 0.5

@export_group("Detection")
## Maximum detection range (m). GDD default: 8.0.
@export var detection_range: float = 8.0
## Half-angle of the detection cone (degrees). GDD default: 60°.
@export var detection_half_angle_deg: float = 60.0
## Seconds the guard must see the player in ALERT before switching to PURSUE.
@export var alert_buildup_time: float = 1.5
## Seconds without LOS before the guard returns to PATROL.
@export var lose_player_time: float = 3.0

@export_group("Pursuit")
## Movement speed while pursuing (m/s). GDD default: 4.5.
@export var pursue_speed: float = 4.5

@export_group("Stun")
## STUNNED duration when hit by GravityFlipTool (s). GDD default: 5.0.
@export var gravity_flip_stun_duration: float = 5.0
## STUNNED duration when hit by ForcePushTool (s).
@export var force_push_stun_duration: float = 3.0
## Deceleration rate applied to push velocity (m/s²). GDD: 8.0.
@export var guard_friction_decel: float = 8.0

@export_group("Time Slow")
## Speed multiplier while inside a TimeSlowTool area. GDD default: 0.15.
@export var time_slow_speed_factor: float = 0.15

# ── Internal state ────────────────────────────────────────────────────────────

var _state: State = State.PATROL
var _state_timer: float = 0.0
var _stun_duration: float = 0.0
var _current_waypoint: int = 0
var _is_time_slowed: bool = false
var _push_velocity: Vector3 = Vector3.ZERO
var _pursue_no_los_timer: float = 0.0
var _player: Node3D = null
var _escalation: EscalationManager = null

# ── Node refs (built in _ready) ───────────────────────────────────────────────

var _los_ray: RayCast3D = null
var _material: StandardMaterial3D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_collision()
	_build_visuals()
	_build_los_ray()
	add_to_group("enemies")
	_set_visual_state(_state)

func _physics_process(delta: float) -> void:
	_tick_state(delta)
	_apply_push_decel(delta)
	_apply_gravity(delta)
	move_and_slide()

# ── Public setup API ──────────────────────────────────────────────────────────

## Called by Main / ProceduralGenerator immediately after placing the guard.
func setup(player: Node3D, escalation: EscalationManager) -> void:
	_player = player
	_escalation = escalation

# ── Physics tool API ──────────────────────────────────────────────────────────

## GravityFlipTool: toss guard upward and enter STUNNED.
func apply_gravity_flip() -> void:
	velocity.y = 5.0
	_enter_stunned(gravity_flip_stun_duration)
	print("[PatrolGuard] gravity flipped — STUNNED %.1fs" % gravity_flip_stun_duration)

## ForcePushTool: apply lateral velocity impulse and enter STUNNED.
func apply_force_push(direction: Vector3, force: float) -> void:
	const GUARD_PUSH_SCALE: float = 0.6
	_push_velocity = direction.normalized() * force * GUARD_PUSH_SCALE
	_push_velocity.y = 0.0
	_enter_stunned(force_push_stun_duration)
	print("[PatrolGuard] force pushed — STUNNED %.1fs" % force_push_stun_duration)

## TimeSlowTool: slow guard movement while the tool is active.
func apply_time_slow() -> void:
	_is_time_slowed = true

## TimeSlowTool: restore full speed.
func remove_time_slow() -> void:
	_is_time_slowed = false

# ── State machine ─────────────────────────────────────────────────────────────

func _tick_state(delta: float) -> void:
	_state_timer += delta
	match _state:
		State.PATROL:  _tick_patrol(delta)
		State.ALERT:   _tick_alert(delta)
		State.PURSUE:  _tick_pursue(delta)
		State.STUNNED: _tick_stunned()

func _tick_patrol(delta: float) -> void:
	_move_toward_waypoint(delta)
	if _can_see_player():
		_enter_alert()

func _tick_alert(delta: float) -> void:
	_face_player()
	# Halt lateral movement while alerting
	velocity.x = 0.0
	velocity.z = 0.0
	if _can_see_player() and _state_timer >= alert_buildup_time:
		_enter_pursue()
	elif not _can_see_player() and _state_timer >= lose_player_time:
		_enter_patrol(false)

func _tick_pursue(delta: float) -> void:
	if _player == null:
		_enter_patrol(true)
		return
	if _can_see_player():
		_pursue_no_los_timer = 0.0
		_move_toward_position(_player.global_position, delta)
	else:
		_pursue_no_los_timer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _pursue_no_los_timer >= lose_player_time:
			_enter_patrol(true)

func _tick_stunned() -> void:
	# Halt intentional movement; _push_velocity drives lateral drift via _apply_push_decel
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_timer >= _stun_duration:
		_push_velocity = Vector3.ZERO
		_enter_patrol(false)

# ── Transitions ───────────────────────────────────────────────────────────────

func _enter_alert() -> void:
	_transition_to(State.ALERT)
	guard_alerted.emit(self)
	if _escalation != null:
		_escalation.on_enemy_alerted()
	print("[PatrolGuard] ALERT — player spotted")

func _enter_pursue() -> void:
	_pursue_no_los_timer = 0.0
	_transition_to(State.PURSUE)
	if _escalation != null:
		_escalation.on_enemy_alerted()
	print("[PatrolGuard] PURSUE")

func _enter_patrol(was_pursuing: bool) -> void:
	_transition_to(State.PATROL)
	if was_pursuing:
		guard_lost_player.emit(self)
		print("[PatrolGuard] PATROL — lost player")
	else:
		print("[PatrolGuard] PATROL")

func _enter_stunned(duration: float) -> void:
	# Stun refresh (GDD §5 edge case 2): reset timer, do not stack duration.
	_stun_duration = duration
	_transition_to(State.STUNNED)
	guard_stunned.emit(self)

func _transition_to(new_state: State) -> void:
	_state = new_state
	_state_timer = 0.0
	_set_visual_state(new_state)

# ── Movement helpers ──────────────────────────────────────────────────────────

func _move_toward_waypoint(delta: float) -> void:
	if patrol_waypoints.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target := patrol_waypoints[_current_waypoint]
	_move_toward_position(target, delta)
	var flat_dist := Vector2(
		global_position.x - target.x,
		global_position.z - target.z).length()
	if flat_dist <= waypoint_reach_dist:
		_current_waypoint = (_current_waypoint + 1) % patrol_waypoints.size()

func _move_toward_position(target: Vector3, _delta: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = dir.normalized()
	var speed := pursue_speed if _state == State.PURSUE else patrol_speed
	if _is_time_slowed:
		speed *= time_slow_speed_factor
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir)

func _face_player() -> void:
	if _player == null:
		return
	var dir := _player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		_face_dir(dir.normalized())

func _face_dir(dir: Vector3) -> void:
	basis = basis.slerp(Basis.looking_at(dir, Vector3.UP), 0.12)

func _apply_push_decel(delta: float) -> void:
	if _push_velocity.is_zero_approx():
		return
	_push_velocity = _push_velocity.move_toward(
		Vector3.ZERO, guard_friction_decel * delta)
	# Only override lateral velocity — _tick_stunned already zeroed it this frame
	velocity.x += _push_velocity.x
	velocity.z += _push_velocity.z

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

# ── Detection ─────────────────────────────────────────────────────────────────

func _can_see_player() -> bool:
	if _player == null:
		return false

	var to_player := _player.global_position - global_position
	if to_player.length() > detection_range:
		return false

	# Cone check (flat XZ — ignores height difference)
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length_squared() > 0.01:
		var forward := -global_transform.basis.z
		if forward.dot(flat.normalized()) < cos(deg_to_rad(detection_half_angle_deg)):
			return false

	# LOS raycast toward player chest
	if _los_ray == null:
		return true
	_los_ray.target_position = _los_ray.to_local(
		_player.global_position + Vector3(0.0, 0.9, 0.0))
	_los_ray.force_raycast_update()
	if _los_ray.is_colliding():
		var collider := _los_ray.get_collider()
		return (collider.is_in_group("player")
			or (collider.get_parent() != null
				and collider.get_parent().is_in_group("player")))
	return true  # No obstacle — clear LOS

# ── Node builders ─────────────────────────────────────────────────────────────

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.4
	col.shape = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

func _build_visuals() -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	mesh_inst.mesh = capsule
	mesh_inst.position = Vector3(0.0, 0.9, 0.0)
	_material = StandardMaterial3D.new()
	mesh_inst.set_surface_override_material(0, _material)
	add_child(mesh_inst)

func _build_los_ray() -> void:
	_los_ray = RayCast3D.new()
	_los_ray.name = "LOSRay"
	_los_ray.enabled = true
	_los_ray.add_exception(self)
	add_child(_los_ray)

func _set_visual_state(state: State) -> void:
	if _material == null:
		return
	match state:
		State.PATROL:  _material.albedo_color = Color(0.55, 0.55, 0.55)  # grey
		State.ALERT:   _material.albedo_color = Color(1.0,  0.85, 0.0)   # yellow
		State.PURSUE:  _material.albedo_color = Color(0.9,  0.1,  0.1)   # red
		State.STUNNED: _material.albedo_color = Color(0.1,  0.1,  0.5)   # dark blue
