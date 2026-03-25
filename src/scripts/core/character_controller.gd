## CharacterController
## Owns all first-person player movement: walk, strafe, jump, mouse-look.
## Reads from Input System named actions only — no raw keycodes.
## Emits signals so Audio/Camera systems can react without polling.

class_name CharacterController
extends CharacterBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired on the first frame the player lands after being airborne.
signal landed

## Fired on the frame jump velocity is applied.
signal jumped

# ── Tuning knobs (editor-adjustable) ─────────────────────────────────────────

@export_group("Movement")
## Horizontal movement speed in metres per second.
@export var move_speed: float = 6.0
## Upward velocity applied when jumping (m/s).
@export var jump_velocity: float = 5.0

@export_group("Camera")
## Mouse rotation speed in radians per pixel of movement.
@export var mouse_sensitivity: float = 0.003

# ── Node references ───────────────────────────────────────────────────────────

@onready var camera_mount: Node3D = $CameraMount
@onready var ray_cast: RayCast3D = $CameraMount/Camera3D/RayCast3D

# ── Internal state ────────────────────────────────────────────────────────────

var _was_on_floor: bool = false
## Cached downward velocity from the last landing frame. Read by HealthComponent.
var last_landing_velocity: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_mount.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, -PI / 2.0, PI / 2.0)

	# Pause / release mouse
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Interact with terminals and interactables
	if event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement()
	# Cache pre-slide downward velocity before move_and_slide zeroes it on collision
	var pre_slide_y := velocity.y
	move_and_slide()
	_detect_landing(pre_slide_y)

# ── Private helpers ───────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		jumped.emit()

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

func _detect_landing(pre_slide_y: float) -> void:
	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		last_landing_velocity = pre_slide_y
		landed.emit()
	_was_on_floor = on_floor_now

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the RayCast3D used for tool targeting and interaction.
func get_aim_ray() -> RayCast3D:
	return ray_cast

# ── Interaction ────────────────────────────────────────────────────────────────

func _try_interact() -> void:
	if not ray_cast.is_colliding():
		return
	var target := ray_cast.get_collider()
	if target is InteractableTerminal:
		(target as InteractableTerminal).try_interact(self)
