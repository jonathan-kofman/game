# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do three physics tools feel satisfying to use in a 3D environment?
# Date: 2026-03-25

extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.003

@onready var camera: Camera3D = $Camera3D
@onready var ray_cast: RayCast3D = $Camera3D/RayCast3D
@onready var physics_tools: Node = $PhysicsTools
@onready var crosshair_label: Label = $Camera3D/CanvasLayer/Crosshair
@onready var tool_label: Label = $Camera3D/CanvasLayer/ToolLabel

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)

	# Release mouse (Escape)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Tools
	if event.is_action_pressed("tool_gravity"):
		physics_tools.activate_gravity_flip(ray_cast.get_collider())

	if event.is_action_pressed("tool_time_slow"):
		physics_tools.toggle_time_slow()

	if event.is_action_pressed("tool_force_push"):
		physics_tools.activate_force_push(
			ray_cast.get_collider(),
			ray_cast.get_collision_normal()
		)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Crosshair feedback — highlight when aiming at a physics object
	var collider := ray_cast.get_collider()
	if collider is RigidBody3D:
		crosshair_label.text = "[+]  " + collider.name
		crosshair_label.modulate = Color.CYAN
	else:
		crosshair_label.text = "+"
		crosshair_label.modulate = Color.WHITE
