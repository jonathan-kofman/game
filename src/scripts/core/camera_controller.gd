## CameraController
## Layered FPS camera effects: headbob, landing thud, and shake.
## Sits between CameraMount (mouse-look) and Camera3D in the scene tree so that
## all effects applied to this node's position/rotation are automatically inherited
## by Camera3D — no direct writes to CameraMount or Camera3D.
##
## Node hierarchy required:
##   Player (CharacterController)
##   └── CameraMount (Node3D)            ← CharacterController writes mouse-look here
##       └── CameraController (Node3D)   ← this script; owns all offset state
##           └── Camera3D
##               └── RayCast3D
##
## Wire up after instantiating Player:
##   camera_ctrl.connect_to_player(player)
##   camera_ctrl.connect_to_tools(tools_array)

class_name CameraController
extends Node3D

# ── Headbob ────────────────────────────────────────────────────────────────────

@export_group("Headbob")
## Vertical amplitude of the bob cycle in metres. 0 = disabled.
@export var headbob_amplitude: float = 0.012
## Full cycles per second at maximum movement speed.
@export var headbob_frequency: float = 1.8
## Minimum horizontal speed (m/s) before bob activates.
@export var headbob_velocity_threshold: float = 0.5
## lerp rate back to neutral when the player stops (higher = snappier).
@export var headbob_return_speed: float = 10.0

# ── Landing Thud ───────────────────────────────────────────────────────────────

@export_group("Landing Thud")
## Converts downward landing speed (m/s) to camera drop distance (m).
@export var thud_velocity_scale: float = 0.008
## Maximum camera drop regardless of impact speed.
@export var thud_max_offset: float = 0.06
## lerp rate returning to neutral after landing (higher = snappier).
@export var thud_return_speed: float = 8.0

# ── Camera Shake (trauma model — GDD §4.3) ─────────────────────────────────────

@export_group("Camera Shake")
## Hard cap on accumulated trauma magnitude (radians).
@export var shake_max_magnitude: float = 0.12

@export_subgroup("Gravity Flip Profile")
@export var shake_gravity_magnitude:  float   = 0.04
@export var shake_gravity_frequency:  float   = 6.0
@export var shake_gravity_decay:      float   = 4.0
@export var shake_gravity_axis_bias:  Vector2 = Vector2(0.7, 0.3)

@export_subgroup("Time Slow Profile")
@export var shake_time_slow_magnitude:  float   = 0.02
@export var shake_time_slow_frequency:  float   = 3.0
@export var shake_time_slow_decay:      float   = 3.0
@export var shake_time_slow_axis_bias:  Vector2 = Vector2(0.5, 0.5)

@export_subgroup("Force Push Profile")
@export var shake_force_push_magnitude:  float   = 0.06
@export var shake_force_push_frequency:  float   = 8.0
@export var shake_force_push_decay:      float   = 5.0
@export var shake_force_push_axis_bias:  Vector2 = Vector2(0.3, 0.7)

@export_subgroup("Damage Profile")
@export var shake_damage_magnitude:  float   = 0.08
@export var shake_damage_frequency:  float   = 10.0
@export var shake_damage_decay:      float   = 6.0
@export var shake_damage_axis_bias:  Vector2 = Vector2(0.6, 0.4)

# ── FOV ────────────────────────────────────────────────────────────────────────

@export_group("FOV")
## Resting FOV in degrees.
@export var fov_base: float = 75.0
## Extra FOV at full speed. Default 0.0 (disabled) — see GDD §3.5.
@export var fov_boost_degrees: float = 0.0
## Speed fraction (0–1) at which FOV boost engages.
@export var fov_boost_threshold: float = 0.9
## lerp rate for FOV transitions.
@export var fov_lerp_speed: float = 6.0

# ── Internal state ─────────────────────────────────────────────────────────────

var _camera: Camera3D = null
var _player: CharacterController = null

# Headbob
var _bob_time:      float = 0.0
var _bob_offset_y:  float = 0.0

# Thud (tracked separately; summed with bob on write — GDD §3.3)
var _thud_offset_y: float = 0.0

# Shake — trauma model
var _shake_trauma:    float   = 0.0
var _shake_time:      float   = 0.0
var _shake_rotation:  Vector3 = Vector3.ZERO
# Active profile (set to the strongest trigger's values)
var _active_frequency:  float   = 6.0
var _active_decay:      float   = 4.0
var _active_axis_bias:  Vector2 = Vector2(0.5, 0.5)
var _active_magnitude:  float   = 0.0  # tracks which profile is dominant

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		push_error("CameraController: could not find child Camera3D node")
		return
	_camera.fov = fov_base

func _process(delta: float) -> void:
	if _camera == null:
		return
	_update_headbob(delta)
	_update_thud(delta)
	_update_shake(delta)
	_update_fov(delta)

	# Bob + thud: vertical offset on this node — Camera3D inherits via transform chain
	position.y = _bob_offset_y + _thud_offset_y

	# Shake: rotational offset on this node — Camera3D inherits via transform chain.
	# SET (not ADD) so that when trauma reaches zero the rotation returns to exactly neutral
	# without residual drift, and without interfering with CameraMount's mouse-look rotation.
	rotation = _shake_rotation

# ── Public API ─────────────────────────────────────────────────────────────────

## Wire player signals. Call once after Player.tscn is instantiated.
func connect_to_player(player: CharacterController) -> void:
	_player = player
	player.landed.connect(_on_landed)
	# jumped signal resets the bob phase so landing re-entry is clean (GDD §3.3)
	if player.has_signal("jumped"):
		player.jumped.connect(_on_jumped)
	# took_damage may not exist yet — see GDD §5.6
	var health := player.get_node_or_null("HealthComponent")
	if health != null and health.has_signal("took_damage"):
		health.took_damage.connect(_on_took_damage)

## Wire tool signals. Pass every BaseTool child of ToolManager.
func connect_to_tools(tools: Array[BaseTool]) -> void:
	for tool in tools:
		tool.tool_activated.connect(_on_tool_activated)

## Programmatic damage shake — call directly if took_damage signal is unavailable.
func trigger_damage_shake() -> void:
	_add_shake(shake_damage_magnitude, shake_damage_frequency,
			shake_damage_decay, shake_damage_axis_bias)

# ── Signal handlers ────────────────────────────────────────────────────────────

## tool_activated(tool_name: String, target: Node) — matches BaseTool signal signature
func _on_tool_activated(source_tool_name: String, _target: Node) -> void:
	match source_tool_name:
		"GravityFlipTool":
			_add_shake(shake_gravity_magnitude, shake_gravity_frequency,
					shake_gravity_decay, shake_gravity_axis_bias)
		"TimeSlowTool":
			_add_shake(shake_time_slow_magnitude, shake_time_slow_frequency,
					shake_time_slow_decay, shake_time_slow_axis_bias)
		"ForcePushTool":
			_add_shake(shake_force_push_magnitude, shake_force_push_frequency,
					shake_force_push_decay, shake_force_push_axis_bias)

func _on_landed() -> void:
	if _player == null:
		return
	var impact_speed := absf(_player.last_landing_velocity)
	var thud_drop := clampf(impact_speed * thud_velocity_scale, 0.0, thud_max_offset)
	# Additive — stacked landings sum without resetting (GDD §5.1); clamp prevents overflow
	_thud_offset_y = clampf(_thud_offset_y - thud_drop, -thud_max_offset, 0.0)

func _on_jumped() -> void:
	_bob_time = 0.0

func _on_took_damage() -> void:
	trigger_damage_shake()

# ── Private helpers ────────────────────────────────────────────────────────────

## Accumulate trauma for a shake trigger.  Stronger profile takes precedence.
func _add_shake(magnitude: float, frequency: float, decay: float, axis_bias: Vector2) -> void:
	if magnitude > _active_magnitude:
		_active_magnitude = magnitude
		_active_frequency = frequency
		_active_decay = decay
		_active_axis_bias = axis_bias
	_shake_trauma = minf(_shake_trauma + magnitude, shake_max_magnitude)

# ── Update methods ─────────────────────────────────────────────────────────────

func _update_headbob(delta: float) -> void:
	if _player == null:
		return
	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var move_speed := _player.move_speed if _player.move_speed > 0.0 else 1.0
	var speed_ratio := clampf(horizontal_speed / move_speed, 0.0, 1.0)

	if horizontal_speed >= headbob_velocity_threshold and _player.is_on_floor():
		_bob_time += delta * headbob_frequency * speed_ratio
		_bob_offset_y = sin(_bob_time * TAU) * headbob_amplitude * speed_ratio
	else:
		_bob_offset_y = lerpf(_bob_offset_y, 0.0, headbob_return_speed * delta)
		if absf(_bob_offset_y) < 0.0001:
			_bob_time = 0.0  # reset phase so next step starts from neutral zero-crossing

func _update_thud(delta: float) -> void:
	if absf(_thud_offset_y) < 0.0001:
		_thud_offset_y = 0.0
		return
	_thud_offset_y = lerpf(_thud_offset_y, 0.0, thud_return_speed * delta)

func _update_shake(delta: float) -> void:
	if _shake_trauma <= 0.0:
		_shake_rotation = Vector3.ZERO
		return

	_shake_trauma = maxf(0.0, _shake_trauma - _active_decay * delta)
	_shake_time += delta

	var effective_mag := _shake_trauma * _shake_trauma  # squared → smooth onset (GDD §4.3)
	var offset_x := effective_mag * _active_axis_bias.x \
			* sin(_shake_time * _active_frequency * TAU)
	var offset_y := effective_mag * _active_axis_bias.y \
			* cos(_shake_time * _active_frequency * TAU * 1.3)  # 1.3× desynchronises axes
	_shake_rotation = Vector3(offset_x, offset_y, 0.0)

	if _shake_trauma <= 0.0:
		_shake_rotation = Vector3.ZERO
		_active_magnitude = 0.0

func _update_fov(delta: float) -> void:
	if _player == null or _camera == null:
		return
	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var move_speed := _player.move_speed if _player.move_speed > 0.0 else 1.0
	var is_at_full_speed := horizontal_speed >= move_speed * fov_boost_threshold
	var target_fov := fov_base + (fov_boost_degrees if is_at_full_speed else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(fov_lerp_speed * delta, 0.0, 1.0))
