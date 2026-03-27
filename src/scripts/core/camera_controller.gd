## CameraController
## Adds feel to the FPS camera: headbob, tool-activated shake, landing thud.
## Attach as a child of the CameraMount node inside Player.tscn.
## Subscribes to signals — never polls state directly.
## All values are @export so any effect can be tuned to zero without breaking anything.
##
## Node hierarchy expected:
##   Player (CharacterController)
##   └── CameraMount (Node3D)          ← this script's parent
##       └── Camera3D
##
## Wire up in main.gd or Player.tscn after instantiation:
##   camera_ctrl.connect_to_player(player)
##   camera_ctrl.connect_to_tool_manager(tool_manager)

class_name CameraController
extends Node3D

# ── Headbob ────────────────────────────────────────────────────────────────────

@export_group("Headbob")
## Vertical amplitude of the headbob cycle in metres. 0 = disabled.
@export var headbob_amplitude: float = 0.012
## Full cycles per second while moving at max speed.
@export var headbob_frequency: float = 2.2
## How fast the bob lerps back to neutral when the player stops (higher = snappier).
@export var headbob_return_speed: float = 10.0

# ── Camera Shake ──────────────────────────────────────────────────────────────

@export_group("Camera Shake")
## Initial angular magnitude (degrees) for each tool's shake.
@export var shake_gravity_flip:  float = 1.2
@export var shake_time_slow:     float = 0.4
@export var shake_force_push:    float = 2.5
@export var shake_damage:        float = 3.0
## How fast shake decays per second (exponential). Higher = shorter shake.
@export var shake_decay:         float = 8.0

# ── Landing Thud ──────────────────────────────────────────────────────────────

@export_group("Landing")
## How far the camera snaps down on landing (metres). Scaled by impact speed.
@export var landing_dip_per_ms:   float = 0.0018
## Maximum dip distance regardless of impact speed.
@export var landing_dip_max:      float = 0.08
## Spring strength pulling camera back to rest after dip.
@export var landing_spring:       float = 12.0

# ── FOV ───────────────────────────────────────────────────────────────────────

@export_group("FOV")
## Resting FOV in degrees.
@export var fov_default:  float = 75.0
## FOV boost while at full movement speed (degrees above default).
@export var fov_sprint_boost: float = 4.0
## Lerp speed for FOV transitions.
@export var fov_lerp_speed: float = 6.0

# ── Internal state ────────────────────────────────────────────────────────────

var _camera: Camera3D = null
var _player: CharacterController = null

# Headbob
var _bob_time:        float = 0.0
var _bob_offset:      float = 0.0

# Shake
var _shake_magnitude: float = 0.0
var _shake_offset:    Vector3 = Vector3.ZERO

# Landing dip
var _dip_velocity:    float = 0.0
var _dip_offset:      float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_camera = get_node_or_null("../Camera3D") as Camera3D
	if _camera == null:
		push_error("CameraController: could not find sibling Camera3D node")
		return
	_camera.fov = fov_default

func _process(delta: float) -> void:
	if _camera == null:
		return

	_update_headbob(delta)
	_update_shake(delta)
	_update_landing_dip(delta)
	_update_fov(delta)

	# Combine all offsets into local position relative to CameraMount origin
	position = Vector3(
		_shake_offset.x,
		_bob_offset + _dip_offset + _shake_offset.y,
		_shake_offset.z)

# ── Public API ────────────────────────────────────────────────────────────────

## Call after instantiating Player to wire player signals.
func connect_to_player(player: CharacterController) -> void:
	_player = player
	player.landed.connect(_on_landed)

## Call after instantiating ToolManager to wire tool signals.
## Pass each BaseTool child so we subscribe to tool_activated directly.
func connect_to_tools(tools: Array[BaseTool]) -> void:
	for tool in tools:
		tool.tool_activated.connect(_on_tool_activated.bind(tool.name))

## Trigger a damage shake (call from HealthComponent.health_changed or a took_damage signal).
func trigger_damage_shake() -> void:
	_shake_magnitude = maxf(_shake_magnitude, shake_damage)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_tool_activated(tool_name_str: String, _target: Node, source_tool_name: String) -> void:
	var magnitude: float
	match source_tool_name:
		"GravityFlipTool": magnitude = shake_gravity_flip
		"TimeSlowTool":    magnitude = shake_time_slow
		"ForcePushTool":   magnitude = shake_force_push
		_:                 magnitude = 1.0
	_shake_magnitude = maxf(_shake_magnitude, magnitude)

func _on_landed() -> void:
	if _player == null:
		return
	var impact_speed := absf(_player.last_landing_velocity)
	var dip := clampf(impact_speed * landing_dip_per_ms, 0.0, landing_dip_max)
	_dip_velocity = -dip * landing_spring  # negative = downward snap

# ── Private update methods ────────────────────────────────────────────────────

func _update_headbob(delta: float) -> void:
	if _player == null:
		return

	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var move_speed := _player.move_speed if _player.move_speed > 0.0 else 1.0
	var speed_fraction := clampf(speed / move_speed, 0.0, 1.0)

	if speed_fraction > 0.01 and _player.is_on_floor():
		_bob_time += delta * headbob_frequency * TAU
		var target_bob := sin(_bob_time) * headbob_amplitude * speed_fraction
		_bob_offset = lerpf(_bob_offset, target_bob, headbob_return_speed * delta)
	else:
		# Return to neutral smoothly
		_bob_offset = lerpf(_bob_offset, 0.0, headbob_return_speed * delta)
		if absf(_bob_offset) < 0.0001:
			_bob_time = 0.0  # reset phase so next step starts from neutral

func _update_shake(delta: float) -> void:
	if _shake_magnitude < 0.001:
		_shake_magnitude = 0.0
		_shake_offset = Vector3.ZERO
		return

	# Random angular offset proportional to current magnitude
	var angle_x := randf_range(-1.0, 1.0) * deg_to_rad(_shake_magnitude)
	var angle_z := randf_range(-1.0, 1.0) * deg_to_rad(_shake_magnitude * 0.5)
	_shake_offset = Vector3(sin(angle_z) * 0.01, sin(angle_x) * 0.01, 0.0)

	_shake_magnitude = lerpf(_shake_magnitude, 0.0, shake_decay * delta)

func _update_landing_dip(delta: float) -> void:
	if absf(_dip_offset) < 0.0001 and absf(_dip_velocity) < 0.0001:
		_dip_offset = 0.0
		_dip_velocity = 0.0
		return

	# Spring physics: F = -k * x - damping * v
	const DAMPING := 6.0
	var spring_force := -landing_spring * _dip_offset - DAMPING * _dip_velocity
	_dip_velocity += spring_force * delta
	_dip_offset += _dip_velocity * delta

func _update_fov(delta: float) -> void:
	if _player == null or _camera == null:
		return

	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var move_speed := _player.move_speed if _player.move_speed > 0.0 else 1.0
	var speed_fraction := clampf(speed / move_speed, 0.0, 1.0)

	var target_fov := fov_default + fov_sprint_boost * speed_fraction
	_camera.fov = lerpf(_camera.fov, target_fov, fov_lerp_speed * delta)
